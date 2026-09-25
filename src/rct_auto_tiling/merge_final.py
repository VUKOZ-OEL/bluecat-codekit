#!/usr/bin/env python3
"""
rct_auto_tiling -- FINAL assembly: seamless per-tree LAZ for the whole plot.

Every INPUT record is assigned to exactly one owner, so both invariants hold
BY CONSTRUCTION:

    N_input == sum(tree points) + unlabelled points     (no loss)
    each record is written exactly once                 (no duplicates)

Assignment priority:
  1. re-segmented boundary components (buffer_components.py export +
     `rayimport` + `rayextract trees comp.ply <stitched terrain>`): each
     output colour = one seamless tree; black points inside a component join
     its largest segment. A component re-split into k colours yields k trees.
  2. single-tile tree segments (pieces never sharing a coloured record with a
     neighbour): one tree per (tile, colour).
  3. base-distance dedup (step2 rule, delta) collapses duplicate trees that
     share ZERO records (rare; only among single-tile trees).
  4. everything never coloured -> ONE global unlabelled cloud (chunked LAZ).

Tree outputs: <outdir>/tree_<gid>.laz (compressed, per-tree RGB colour,
gps_time). Unlabelled: <outdir>/unlabelled_NNNN.laz (grey).
Manifest: <outdir>/manifest.json.

Usage:
  merge_final.py --input cloud.ply --tiles tile_*_raycloud.ply \
      --components comps/components.json --comp-dir comps_seg \
      --outdir trees_out [--delta 0.5]
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys
from collections import defaultdict
from typing import Dict, List

import numpy as np

REC_DT = np.dtype([("x", "<f8"), ("y", "<f8"), ("z", "<f8"), ("t", "<f8"),
                   ("nx", "<f4"), ("ny", "<f4"), ("nz", "<f4"), ("rgba", "u1", 4)])
KEY_DT = np.dtype([("x", "<f8"), ("y", "<f8"), ("z", "<f8"), ("t", "<f8")])
FLUSH = 2_000_000


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
    ch = rgba[:, :3].astype(np.int32)
    res = np.zeros(len(ch), dtype=np.int32)
    for i in range(24):
        res |= ((ch[:, i % 3] >> (7 - (i // 3))) & 1) << i
    return res - 1


def norm_colour(i: int):
    out = [0, 0, 0]
    for k in range(24):
        if i & (1 << k):
            out[k % 3] |= 1 << (7 - (k // 3))
    return tuple(out)


def write_laz(path, x, y, z, t=None, colour=None):
    import laspy
    n = len(np.asarray(x))
    version = "1.4" if n > (1 << 32) - 2 else "1.2"
    las = laspy.create(point_format=3, file_version=version)
    las.x = np.asarray(x, dtype=np.float64)
    las.y = np.asarray(y, dtype=np.float64)
    las.z = np.asarray(z, dtype=np.float64)
    if t is not None:
        las.gps_time = np.asarray(t, dtype=np.float64)
    if colour is not None:
        las.red = np.full(len(las.x), int(colour[0]) * 257, dtype=np.uint16)
        las.green = np.full(len(las.x), int(colour[1]) * 257, dtype=np.uint16)
        las.blue = np.full(len(las.x), int(colour[2]) * 257, dtype=np.uint16)
    las.write(path, do_compress=True)


def tile_ij(path: str):
    parts = os.path.basename(path)[:-4].split("_")
    return int(parts[1]), int(parts[2])


def main() -> int:
    ap = argparse.ArgumentParser(description="seamless final assembly")
    ap.add_argument("--input", required=True)
    ap.add_argument("--tiles", nargs="+", required=True,
                    help="tile_*_raycloud.ply (with *_segmented.ply beside)")
    ap.add_argument("--components", required=True, help="components.json")
    ap.add_argument("--comp-dir", required=True,
                    help="dir with comp_*.ply re-run *_raycloud_segmented.ply")
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--delta", type=float, default=0.5,
                    help="base-distance dedup for zero-shared-record duplicates")
    args = ap.parse_args()
    os.makedirs(args.outdir, exist_ok=True)

    inp = read_records(args.input)
    N = len(inp)
    print(f"input records: {N:,}", flush=True)

    assigned = np.full(N, -1, dtype=np.int32)   # record -> tree gid
    trees: Dict[int, dict] = {}

    def new_tree(src: str, x: float, y: float, z: float) -> int:
        gid = len(trees)
        trees[gid] = {"source": src, "x": x, "y": y, "z": z}
        return gid

    # ---- 1) re-segmented components (priority) -----------------------------
    comp = json.load(open(args.components))
    comp_member_seg = set()          # (i,j,col) covered by a component
    ncomp = 0
    for entry in comp["components"]:
        cf = entry["file"]
        for (ti, tj, col) in entry["segments"]:
            comp_member_seg.add((ti, tj, int(col)))
        cpath = os.path.join(args.comp_dir, cf)
        cridp = os.path.join(args.comp_dir, cf + ".rids")
        seg_out = os.path.join(args.comp_dir, cf[:-4] + "_raycloud_segmented.ply")
        if not os.path.exists(cridp):
            sys.exit(f"missing {cridp} (component row ids)")
        rid_c = np.fromfile(cridp, dtype=np.int64)
        comp_mm = read_records(cpath)
        if len(rid_c) != len(comp_mm):
            sys.exit(f"{cf}: rids {len(rid_c)} != points {len(comp_mm)}")
        cx = np.asarray(comp_mm["x"]); cy = np.asarray(comp_mm["y"]); cz = np.asarray(comp_mm["z"])
        if os.path.exists(seg_out):
            segm = read_records(seg_out)
            if len(segm) != len(comp_mm):
                sys.exit(f"{seg_out}: row count differs from component")
            if not np.array_equal(np.asarray(segm["x"]), cx):
                sys.exit(f"{seg_out}: RCT reordered component rows")
            lab = colour_ids(np.asarray(segm["rgba"]))
        else:
            print(f"  WARN {cf}: no re-segmented output; treating whole as one tree")
            lab = np.zeros(len(comp_mm), dtype=np.int32)
        cols = np.unique(lab[lab >= 0])
        if cols.size == 0:
            lab = np.zeros(len(comp_mm), dtype=np.int32)
            cols = np.array([0], dtype=np.int32)
        sizes = {int(c): int((lab == c).sum()) for c in cols.tolist()}
        main_col = max(sizes, key=sizes.get)
        g_by_col: Dict[int, int] = {}
        for c in sorted(sizes):
            m = lab == c
            zi = int(np.argmin(cz[m]))
            g_by_col[c] = new_tree(f"comp:{cf}:{c}", float(cx[m][zi]), float(cy[m][zi]), float(cz[m][zi]))
        g_main = g_by_col[main_col]
        for c in np.unique(lab).tolist():
            g = g_main if c < 0 else g_by_col[c]
            rr = rid_c[lab == c]
            free = assigned[rr] < 0
            assigned[rr[free]] = g
        ncomp += 1
        if ncomp % 200 == 0:
            print(f"  components: {ncomp}/{len(comp['components'])}", flush=True)
    print(f"components assembled: {ncomp:,}", flush=True)

    # ---- 2) single-tile segments --------------------------------------------
    import re as _re
    tile_pat = _re.compile(r"^tile_(\d+)_(\d+)\.ply$")
    nseg = 0
    for tp in args.tiles:
        if not tile_pat.match(os.path.basename(tp)):
            continue  # ignore RCT intermediates matched by a loose glob
        i, j = tile_ij(tp)
        rid = np.fromfile(tp + ".rids", dtype=np.int64)
        segp = os.path.join(os.path.dirname(tp), os.path.basename(tp)[:-4] + "_raycloud_segmented.ply")
        tile = read_records(tp); segm = read_records(segp)
        if not (len(segm) == len(tile) == len(rid)):
            sys.exit(f"tile {i},{j}: row mismatch")
        if not np.array_equal(np.asarray(segm["x"]), np.asarray(tile["x"])):
            sys.exit(f"tile {i},{j}: segmented order differs from tile")
        lab = colour_ids(np.asarray(segm["rgba"]))
        x = np.asarray(tile["x"]); y = np.asarray(tile["y"]); z = np.asarray(tile["z"])
        for col in np.unique(lab[lab >= 0]).tolist():
            if (i, j, int(col)) in comp_member_seg:
                continue
            m = np.where(lab == col)[0]
            zi = int(np.argmin(z[m]))
            base = m[zi]
            g = new_tree(f"tile:{i},{j}:{col}", float(x[base]), float(y[base]), float(z[base]))
            rr = rid[m]
            free = assigned[rr] < 0
            assigned[rr[free]] = g
            nseg += 1
    print(f"single-tile segment trees: {nseg:,}", flush=True)

    # ---- 3) base-distance dedup among SINGLE-TILE trees ---------------------
    single = [g for g, t in trees.items() if t["source"].startswith("tile:")]
    cell = max(args.delta, 1e-9)
    buckets: Dict = defaultdict(list)
    for g in single:
        buckets[(math.floor(trees[g]["x"] / cell), math.floor(trees[g]["y"] / cell))].append(g)
    dsu = {g: g for g in trees}
    def fnd(a):
        while dsu[a] != a:
            dsu[a] = dsu[dsu[a]]
            a = dsu[a]
        return a
    def uni(a, b):
        ra, rb = fnd(a), fnd(b)
        if ra != rb and ra > rb:
            ra, rb = rb, ra
        if ra != rb:
            dsu[rb] = ra          # lower id (usually the component) wins
    merged = 0
    for (bx, by), gs in buckets.items():
        neigh = list(gs)
        for d in ((1, -1), (1, 0), (1, 1), (0, 1)):
            neigh += buckets.get((bx + d[0], by + d[1]), [])
        for a in gs:
            for b in neigh:
                if a >= b:
                    continue
                if fnd(a) == fnd(b):
                    continue
                if math.dist((trees[a]["x"], trees[a]["y"]), (trees[b]["x"], trees[b]["y"])) <= args.delta:
                    uni(a, b)
                    merged += 1
    # apply DSU as one vectorised lookup (no per-tree scans over N)
    lut = np.arange(len(trees), dtype=np.int32)
    for g in trees:
        lut[g] = fnd(g)
    assigned = np.where(assigned >= 0, lut[np.clip(assigned, 0, None)].astype(np.int32), -1)
    remap = int((np.array([lut[g] != g for g in trees])).sum())
    print(f"base-dedup: {merged} links, {remap} trees collapsed (delta={args.delta} m)", flush=True)

    # ---- 4) write -----------------------------------------------------------
    live = sorted(set(int(v) for v in np.unique(assigned) if v >= 0))
    print(f"final trees: {len(live):,}", flush=True)
    X = np.asarray(inp["x"]); Y = np.asarray(inp["y"]); Z = np.asarray(inp["z"]); T = np.asarray(inp["t"])
    manifest = {}
    written = 0
    # group records once: sort by gid, then contiguous slices
    valid = np.where(assigned >= 0)[0]
    order = valid[np.argsort(assigned[valid], kind="stable")]
    gsorted = assigned[order]
    bounds = np.flatnonzero(np.diff(gsorted)) + 1
    starts = np.concatenate([[0], bounds])
    ends = np.concatenate([bounds, [len(gsorted)]])
    for si, (s, e) in enumerate(zip(starts, ends)):
        g = int(gsorted[s])
        m = order[s:e]
        write_laz(os.path.join(args.outdir, f"tree_{g}.laz"), X[m], Y[m], Z[m], T[m], norm_colour(g))
        manifest[str(g)] = {"points": int(e - s), "source": trees[g]["source"],
                            "x": trees[g]["x"], "y": trees[g]["y"], "z": trees[g]["z"]}
        written += e - s
        if si % 200 == 0:
            print(f"  trees written: {si:,} ({written:,} pts)", flush=True)
    ul = np.where(assigned < 0)[0]
    # ONE unlabelled cloud for the whole plot (LAS 1.4 if > 4.29e9 pts)
    write_laz(os.path.join(args.outdir, "unlabelled.laz"),
              X[ul], Y[ul], Z[ul], T[ul])
    manifest["_unlabelled"] = {"points": int(len(ul))}
    with open(os.path.join(args.outdir, "manifest.json"), "w") as f:
        json.dump(manifest, f)
    total = written + len(ul)
    ok = total == N
    print(f"tree points {written:,} + unlabelled {len(ul):,} = {total:,} vs input {N:,} -> "
          f"{'PASS' if ok else 'FAIL'}", flush=True)
    return 0 if ok else 2


if __name__ == "__main__":
    sys.exit(main())
