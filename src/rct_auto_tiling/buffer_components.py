#!/usr/bin/env python3
"""
rct_auto_tiling -- buffer-zone segment components for seamless re-segmentation.

With a small buffer B (1 m) a tree whose crown crosses a tile boundary is
segmented in BOTH neighbours: the SAME physical records (verified exact
x,y,z+t identity against the input cloud) end up coloured in both tiles.
This script links those segments and exports one component per
cross-boundary tree:

  * node  = (tile, RCT colour id) = one segmented tree piece
  * edge  = the two nodes colour the SAME input record (records live in both
            tiles' 1 m buffer strips; corner trees link transitively through
            2-4 tiles)
  * a connected component with >=2 nodes is a split tree: its export cloud =
    FULL point sets of all member segments, de-duplicated at record level ->
    feed to `rayimport` + `rayextract trees <c> <stitched_terrain>` for a
    seamless standalone re-segmentation.

Components of 1 node are final trees already (kept from their tile).

Outputs:
  <outdir>/comp_XXXXX.ply     component clouds (input 48 B layout)
  <outdir>/components.json    manifest (file, points, segments[[tile_i,tile_j,
                              colour], ...], tiles)
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import defaultdict

import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

REC_DT = np.dtype([("x", "<f8"), ("y", "<f8"), ("z", "<f8"), ("t", "<f8"),
                   ("nx", "<f4"), ("ny", "<f4"), ("nz", "<f4"), ("rgba", "u1", 4)])
KEY_DT = np.dtype([("x", "<f8"), ("y", "<f8"), ("z", "<f8"), ("t", "<f8")])
PLY_HEADER_TMPL = (
    "ply\nformat binary_little_endian 1.0\ncomment rct_auto_tiling component\n"
    "element vertex {n:012d}\n"
    "property double x\nproperty double y\nproperty double z\nproperty double time\n"
    "property float nx\nproperty float ny\nproperty float nz\n"
    "property uchar red\nproperty uchar green\nproperty uchar blue\nproperty uchar alpha\n"
    "end_header\n")
SHIFT = 20  # node id = tile_index << SHIFT | colour


def data_start(path: str) -> int:
    d = 0
    with open(path, "rb") as f:
        while True:
            ln = f.readline()
            d += len(ln)
            if ln.startswith(b"end_header"):
                return d


def read_records(path: str) -> np.memmap:
    return np.memmap(path, dtype=REC_DT, mode="r", offset=data_start(path))


def n_vertex_count(path: str) -> int:
    with open(path, "rb") as f:
        while True:
            s = f.readline().decode(errors="replace").split()
            if s[:2] == ["element", "vertex"]:
                return int(s[2])
            if s and s[0] == "end_header":
                raise SystemExit(f"{path}: no vertex element")


def keyarr(a) -> np.ndarray:
    k = np.empty(len(a), dtype=KEY_DT)
    k["x"] = np.asarray(a["x"]); k["y"] = np.asarray(a["y"])
    k["z"] = np.asarray(a["z"]); k["t"] = np.asarray(a["t"])
    return k


def colour_ids(rgba: np.ndarray) -> np.ndarray:
    """Vectorised RCT convertColourToInt over (n,4) uint8."""
    ch = rgba[:, :3].astype(np.int32)
    res = np.zeros(len(ch), dtype=np.int32)
    for i in range(24):
        c = ch[:, i % 3]
        bit = (c >> (7 - (i // 3))) & 1
        res |= bit << i
    return res - 1  # black -> -1


def main() -> int:
    ap = argparse.ArgumentParser(description="buffer-zone segment components")
    ap.add_argument("--input", required=True, help="original input cloud PLY (RCT layout)")
    ap.add_argument("--tiles", nargs="+", required=True,
                    help="tile PLYs (tile_i_j.ply with .rids sidecar; RCT outputs beside them)")
    ap.add_argument("--outdir", required=True)
    args = ap.parse_args()
    os.makedirs(args.outdir, exist_ok=True)

    inp_hdr_rows = n_vertex_count(args.input)
    print(f"input records: {inp_hdr_rows:,}", flush=True)

    seg_tiles = []          # list of (i,j) in --tiles order
    seg_rids = []           # per tile: int64 global record id per row
    seg_lab = []            # per tile: int32 colour id per record (-1 black)
    tile_paths = []
    for tp in args.tiles:
        base = os.path.basename(tp)
        i, j = int(base[:-4].split("_")[1]), int(base[:-4].split("_")[2])
        ridp = tp + ".rids"
        if not os.path.exists(ridp):
            sys.exit(f"missing row-id sidecar {ridp} (re-run step1_tile_split.py)")
        rid = np.fromfile(ridp, dtype=np.int64)
        segp = os.path.join(os.path.dirname(tp), base[:-4] + "_raycloud_segmented.ply")
        rayp = os.path.join(os.path.dirname(tp), base[:-4] + "_raycloud.ply")
        if not os.path.exists(segp):
            sys.exit(f"missing segmented cloud for tile {i},{j}: {segp}")
        tile = read_records(tp)
        raym = read_records(rayp)
        segm = read_records(segp)
        if not (len(tile) == len(raym) == len(segm) == len(rid)):
            sys.exit(f"tile {i},{j}: row counts differ (tile {len(tile)}, ray {len(raym)}, "
                     f"seg {len(segm)}, rids {len(rid)})")
        # RCT preserves row order through rayimport/rayextract; verify on xyz
        if not (np.array_equal(np.asarray(raym["x"]), np.asarray(tile["x"]))
               and np.array_equal(np.asarray(segm["x"]), np.asarray(tile["x"]))):
            sys.exit(f"tile {i},{j}: RCT reordered rows - .rids mapping invalid")
        lab = colour_ids(np.asarray(segm["rgba"]))
        seg_tiles.append((i, j)); tile_paths.append(tp)
        seg_rids.append(rid); seg_lab.append(lab)
        print(f"  tile {i},{j}: {len(tile):,} pts, {int((lab >= 0).sum()):,} coloured", flush=True)

    # ---- segment linkage graph -------------------------------------------
    N = inp_hdr_rows
    first_owner = np.full(N, -1, dtype=np.int32)   # first node colouring record r
    eu, ev = [], []
    for tidx in range(len(seg_tiles)):
        lab = seg_lab[tidx]
        m = np.where(lab >= 0)[0]
        if m.size == 0:
            continue
        recs = seg_rids[tidx][m]
        nodes = (np.int32(tidx) << SHIFT) | lab[m].astype(np.int32)
        prev = first_owner[recs]
        fresh = prev < 0
        first_owner[recs[fresh]] = nodes[fresh]
        sh = ~fresh
        if sh.any():
            eu.append(prev[sh]); ev.append(nodes[sh])
    if eu:
        eu = np.concatenate(eu); ev = np.concatenate(ev)
    else:
        eu = ev = np.empty(0, dtype=np.int32)
    print(f"shared-record directed edges: {len(eu):,}", flush=True)

    allnodes = np.unique(np.concatenate([
        (np.int32(t) << SHIFT) | np.unique(lab[lab >= 0])
        for t, lab in enumerate(seg_lab)]))
    nidx = {int(v): k for k, v in enumerate(allnodes.tolist())}
    if len(eu):
        g = coo_matrix((np.ones(len(eu), dtype=np.int8),
                        (np.fromiter((nidx[int(a)] for a in eu), np.int32, len(eu)),
                         np.fromiter((nidx[int(b)] for b in ev), np.int32, len(ev)))),
                       shape=(len(allnodes), len(allnodes)))
        ncomp, comp = connected_components(g, directed=False)
    else:
        ncomp, comp = len(allnodes), np.arange(len(allnodes))
    members = defaultdict(list)
    for k, node in enumerate(int(v) for v in allnodes):
        members[int(comp[k])].append((node >> SHIFT, node & ((1 << SHIFT) - 1)))
    multi = {c: ms for c, ms in members.items() if len(ms) >= 2}
    singles = {c: ms[0] for c, ms in members.items() if len(ms) == 1}
    print(f"segments: {len(allnodes):,} | multi-tile components: {len(multi):,} | "
          f"single-tile trees: {len(singles):,}", flush=True)

    # ---- export multi-tile component clouds --------------------------------
    comp_of_segment = {}
    for c, ms in multi.items():
        for s in ms:
            comp_of_segment[s] = c
    manifest = []
    for n, c in enumerate(sorted(multi)):
        ms = sorted(multi[c])
        rid_parts, owner_tile, owner_pos = [], [], []
        for (tidx, col) in ms:
            sel = np.where(seg_lab[tidx] == col)[0]
            rid_parts.append(seg_rids[tidx][sel])
            owner_tile.append(np.full(len(sel), tidx, dtype=np.int32))
            owner_pos.append(sel.astype(np.int64))
        rids = np.concatenate(rid_parts)
        ot = np.concatenate(owner_tile)
        op = np.concatenate(owner_pos)
        _, keep = np.unique(rids, return_index=True)
        keep.sort()
        rids, ot, op = rids[keep], ot[keep], op[keep]
        recs = np.empty(len(rids), dtype=REC_DT)
        for tidx in np.unique(ot):
            mm = read_records(tile_paths[int(tidx)])
            sel = ot == tidx
            recs[sel] = np.asarray(mm[op[sel]])
        name = f"comp_{n:05d}.ply"
        with open(os.path.join(args.outdir, name), "wb") as f:
            f.write(PLY_HEADER_TMPL.format(n=len(recs)).encode())
            f.write(recs.tobytes())
        rids.astype(np.int64).tofile(os.path.join(args.outdir, name + ".rids"))
        manifest.append({"file": name, "points": int(len(rids)),
                         "segments": [[seg_tiles[t][0], seg_tiles[t][1], int(cc)]
                                      for (t, cc) in ms]})
        if (n + 1) % 100 == 0:
            print(f"  exported {n+1} components ...", flush=True)
    with open(os.path.join(args.outdir, "components.json"), "w") as f:
        json.dump({"n_components": len(manifest),
                   "total_points": sum(m["points"] for m in manifest),
                   "components": manifest}, f)
    print(f"components exported: {len(manifest)} -> {args.outdir}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
