#!/usr/bin/env python3
"""
rct_auto_tiling — merge buffered tile segmentations into per-tree LAZ outputs
(global join, point-level dedup, "a point always belongs to a tree").

Two-pass design (correct + memory-bounded):
  Pass A (read every tile once): build key(x,y,z quantized) -> tree gid.
        "tree wins": if a point is black (no colour) in one tile but belongs
        to a tree in another, the tree assignment wins (black is only kept
        when the point is black in EVERY tile it appears in).
  Pass B (read every tile again): write each physical point exactly once
        (first occurrence wins per its gid), into tree_<gid>.laz or
        unlabelled.laz.

Inputs (per tile, same order):
  * --segmented tile_<i>_<j>_raycloud_segmented.ply  (48-B raycloud PLY;
        RGB = convertIntToColour(contiguous tree id), black = unlabelled)
  * --trees-txt tile_<i>_<j>_trees.txt  (rayextract trees text; data-line
        order = local tree id; first 6-col group of each line = base)
  * --global-trees merged treeGeoJSON from step2_merge_segments.py
        (global tree id -> georeferenced base)

Local -> global tree mapping: local tree base snapped to nearest global base
within --eps (default 0.2 m).

Outputs (outdir/):
  * tree_<gid>.laz  — one LAZ per global tree (all its points, no dup)
  * unlabelled.laz  — points with no tree in ANY tile
  * manifest.json   — per-tree base + point count, unlabelled count
"""
from __future__ import annotations
import argparse, json, math, os, struct, sys, re

REC = 48  # x,y,z,time (dddd), nx,ny,nz (fff), rgba (BBBB)

def ply_data_start(path):
    with open(path, "rb") as f:
        ds = 0
        while True:
            ln = f.readline()
            if not ln:
                break
            ds += len(ln)
            if ln.startswith(b"end_header"):
                break
    return ds

def colour_to_int(r, g, b):
    ch = [r, g, b]
    res = 0
    for i in range(24):
        if ch[i % 3] & (1 << (7 - (i // 3))):
            res |= 1 << i
    return res - 1


def norm_colour(i):
    """convertIntToColour(i): bit i -> channel i%3, bit offset 7-(i//3)."""
    ch = [0, 0, 0]
    x = i + 1
    for b in range(24):
        if x & (1 << b):
            ch[b % 3] |= 1 << (7 - (b // 3))
    return ch[0], ch[1], ch[2]

def parse_trees_txt(path):
    bases = {}
    idx = 0
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            toks = re.split(r"[, ]+", line)
            try:
                vals = [float(t) for t in toks[:6]]
            except ValueError:
                continue
            if len(vals) < 6:
                continue
            x, y, z, r, parent, sect = vals
            bases[idx] = (x, y, z)
            idx += 1
    return bases

def load_global_trees(path):
    d = json.load(open(path))
    out = {}
    for f in d.get("features", []):
        c = f["geometry"]["coordinates"]
        gid = f.get("id")
        if gid is None:
            gid = f.get("properties", {}).get("tree_id")
        out[gid] = (float(c[0]), float(c[1]), float(c[2]))
    return out

def map_local_to_global(local_bases, global_bases, eps=0.2):
    mapping = {}
    gitems = list(global_bases.items())
    for lid, (x, y, z) in local_bases.items():
        best = None
        bd = 1e18
        for gid, (gx, gy, gz) in gitems:
            d = math.hypot(x - gx, y - gy)
            if d < bd:
                bd = d
                best = gid
        mapping[lid] = best if (best is not None and bd <= max(eps, 0.05)) else None
    return mapping

def write_las(path, rows, colour=None, gps_time=None):
    """Write LAZ (compressed) from rows [(x,y,z), ...] via laspy. Colour is
    (r,g,b) applied to every point (per-tree colour, convertIntToColour).
    Falls back to LAS 1.2 binary point-format-1 when laspy/LAZ unavailable."""
    if not rows:
        return
    import laspy
    import numpy as np
    from laspy.compression import LazBackend
    try:
        hdr = laspy.LasHeader(point_format=3, version="1.2")
        hdr.scales = (0.01, 0.01, 0.01)
        xs = np.array([r[0] for r in rows], dtype=np.float64)
        ys = np.array([r[1] for r in rows], dtype=np.float64)
        zs = np.array([r[2] for r in rows], dtype=np.float64)
        hdr.offsets = (math.floor(float(xs.min())), math.floor(float(ys.min())), math.floor(float(zs.min())))
        las = laspy.LasData(hdr)
        las.x = xs; las.y = ys; las.z = zs
        las.gps_time = np.array(gps_time, dtype=np.float64) if (gps_time is not None and len(gps_time) == len(rows)) else np.zeros(len(rows), dtype=np.float64)
        if colour is not None:
            las.red = np.full(len(rows), colour[0], dtype=np.uint16)
            las.green = np.full(len(rows), colour[1], dtype=np.uint16)
            las.blue = np.full(len(rows), colour[2], dtype=np.uint16)
        las.write(path, do_compress=True, laz_backend=LazBackend.Lazrs)
        return
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"  [warn] laspy LAZ write failed ({e}); writing LAS 1.2 binary")
        _write_las_raw(path, rows)

def _write_las_raw(path, rows):
    """Fallback: LAS 1.2 binary point-format-1 (no compression) from rows."""
    if not rows:
        return
    n = len(rows)
    xs = [r[0] for r in rows]; ys = [r[1] for r in rows]; zs = [r[2] for r in rows]
    minx, maxx = min(xs), max(xs); miny, maxy = min(ys), max(ys); minz, maxz = min(zs), max(zs)
    scale = 0.01
    offx, offy, offz = math.floor(minx), math.floor(miny), math.floor(minz)
    hdr = bytearray(227)
    hdr[0:4] = b"LASF"
    struct.pack_into("<H", hdr, 4, 1)          # version 1.2
    struct.pack_into("<H", hdr, 6, 2)
    struct.pack_into("<I", hdr, 20, 227)       # header size
    struct.pack_into("<I", hdr, 24, 227)       # point data offset
    struct.pack_into("<I", hdr, 107, n)        # number of points
    struct.pack_into("<dddddd", hdr, 131, minx, maxx, miny, maxy, minz, maxz)
    struct.pack_into("<ddd", hdr, 179, scale, scale, scale)
    struct.pack_into("<ddd", hdr, 191, offx, offy, offz)
    struct.pack_into("<B", hdr, 104, 1)        # point format 1 (gps time)
    struct.pack_into("<H", hdr, 105, 20)       # record length 20
    with open(path, "wb") as f:
        f.write(hdr)
        rec = bytearray(20)
        for (x, y, z) in rows:
            xi = int(round((x - offx) / scale))
            yi = int(round((y - offy) / scale))
            zi = int(round((z - offz) / scale))
            struct.pack_into("<iii", rec, 0, xi, yi, zi)
            f.write(rec)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--segmented", nargs="+", required=True)
    ap.add_argument("--trees-txt", nargs="+", required=True)
    ap.add_argument("--global-trees", required=True)
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--eps", type=float, default=0.2)
    ap.add_argument("--quant", type=float, default=0.01)
    ap.add_argument("--min-shared", type=int, default=50,
                    help="min shared points for a duplicate pair candidate")
    ap.add_argument("--dup-frac", type=float, default=0.05,
                    help="shared/(sum of both tree sizes) fraction above "
                         "which two global ids are the same physical tree")
    ap.add_argument("--base-max", type=float, default=1.0,
                    help="max base distance (m) for a duplicate pair; "
                         "blocks single-linkage chains through canopies")
    ap.add_argument("--dump-shared", default=None,
                    help="optional path to dump per-pair shared-point stats")
    args = ap.parse_args()

    if len(args.segmented) != len(args.trees_txt):
        sys.exit("--segmented and --trees-txt must have equal length (same order)")
    os.makedirs(args.outdir, exist_ok=True)

    gbases = load_global_trees(args.global_trees)
    print(f"global trees: {len(gbases)}")

    tiles = []
    for seg, tt in zip(args.segmented, args.trees_txt):
        m = re.search(r"tile_(\d+)_(\d+)", os.path.basename(seg))
        ti, tj = (int(m.group(1)), int(m.group(2))) if m else (-1, -1)
        loc = parse_trees_txt(tt)
        mapping = map_local_to_global(loc, gbases, eps=args.eps)
        n_g = sum(1 for v in mapping.values() if v is not None)
        print(f"  [{ti},{tj}] local {len(loc)} -> global {n_g}")
        tiles.append((ti, tj, seg, mapping))

    quant = args.quant
    def key_of(x, y, z):
        return (int(round(x / quant)), int(round(y / quant)), int(round(z / quant)))

    # ---- Pass A: key -> gid (tree wins over black) -----------------------
    # Point-proof duplicate detection, WEIGHTED: count how many points each
    # pair of global tree ids shares. Two ids are the SAME physical tree only
    # if the shared points are a substantial fraction of the smaller tree
    # (duplicate detections of one tree share most of their points; real
    # neighbouring trees only swap a few boundary/canopy-touch points —
    # unioning on ANY single shared point over-merges by single-linkage).
    print("\nPass A: building global point map (key -> tree id) ...")
    shared = {}   # (min_gid, max_gid) -> shared point count
    pt_map = {}   # key -> gid or -1(black)
    for ti, tj, seg, mapping in tiles:
        ds = ply_data_start(seg)
        with open(seg, "rb") as f:
            f.seek(ds)
            while True:
                buf = f.read(64 << 20)
                if not buf:
                    break
                rem = len(buf) % REC
                if rem:
                    buf = buf[:-rem]
                    f.seek(-rem, 1)
                for off in range(0, len(buf), REC):
                    x, y, z = struct.unpack_from("<ddd", buf, off)
                    r, g, b = struct.unpack_from("<BBB", buf, off + 44)
                    lid = colour_to_int(r, g, b)
                    gid = mapping.get(lid) if lid >= 0 else None
                    k = key_of(x, y, z)
                    if gid is not None:
                        old = pt_map.get(k)
                        if old is not None and old >= 0 and old != gid:
                            pair = (old, gid) if old < gid else (gid, old)
                            shared[pair] = shared.get(pair, 0) + 1
                        pt_map[k] = gid       # tree wins (last tile for contested pts)
                    else:
                        pt_map.setdefault(k, -1)   # first write black if unseen
        print(f"  pass A tile [{ti},{tj}] done — map size {len(pt_map):,}")

    # total points per gid (before any merging)
    totals = {}
    for v in pt_map.values():
        if v is not None and v >= 0:
            totals[v] = totals.get(v, 0) + 1

    # union only high-overlap pairs (point-proof + base-proximity gate).
    # The base gate stops single-linkage chains through the canopy: real
    # duplicate detections have bases within ~0.7 m of each other, while a
    # chain that merges distant trees through shared canopy points jumps
    # many metres per hop.
    parent = {}
    def find(a):
        parent.setdefault(a, a)
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            if ra < rb:
                parent[rb] = ra
            else:
                parent[ra] = rb
    n_unions = 0
    for (a, b), c in sorted(shared.items(), key=lambda kv: -kv[1]):
        if c < args.min_shared:
            continue
        ax, ay, _ = gbases.get(a, (0, 0, None))
        bx, by, _ = gbases.get(b, (0, 0, None))
        if math.hypot(ax - bx, ay - by) > args.base_max:
            continue
        frac = c / max(1, totals.get(a, 0) + totals.get(b, 0))
        if frac >= args.dup_frac:
            union(a, b)
            n_unions += 1
    if args.dump_shared:
        dump = [{"a": a, "b": b, "shared": c,
                 "final_a": totals.get(a, 0), "final_b": totals.get(b, 0)}
                for (a, b), c in sorted(shared.items(), key=lambda kv: -kv[1])]
        json.dump(dump, open(args.dump_shared, "w"), indent=1)
        print(f"shared-pair stats dumped to {args.dump_shared}")
    # resolve all unions: remap pt_map values to their roots
    for k in list(pt_map.keys()):
        v = pt_map[k]
        if v is not None and v >= 0 and v in parent:
            pt_map[k] = find(v)
    print(f"point-proof dedup: {n_unions} tree-id pairs merged "
          f"(min_shared={args.min_shared}, dup_frac={args.dup_frac}, "
          f"base_max={args.base_max}; {len(shared)} sharing pairs seen)")

    # ---- Pass B: write each point once -----------------------------------
    print("\nPass B: writing per-tree LAZ ...")
    # buffer per tree to limit file handles
    tree_rows = {}   # gid -> list[(x,y,z,r,g,b)]
    unlab_rows = []
    written = 0
    skip = 0
    done_keys = set()

    FLUSH = 2_000_000
    tree_count = 0   # running: physical pts assigned to a tree
    unlab_count = 0  # running: physical pts with no tree anywhere
    tree_chunks = {} # gid -> list of chunk file names (LAZ has no append)
    unlab_chunk = 0  # unlabelled_<chunk>.laz counter
    def write_las_chunk(path, rows, colour):
        write_las(path, [(r[0], r[1], r[2]) for r in rows], colour=colour)
    def flush_unlab(rows):
        nonlocal written, unlab_chunk
        if not rows:
            return
        write_las_chunk(os.path.join(args.outdir, f"unlabelled_{unlab_chunk:04d}.laz"),
                        rows, colour=(90, 90, 90))
        written += len(rows)
        unlab_chunk += 1
    def flush(gid):
        nonlocal written, tree_count
        rows = tree_rows.pop(gid, [])
        if rows:
            # colour = per-tree colour (convertIntToColour(global id))
            cr, cg, cb = norm_colour(gid)
            n = len(tree_chunks.get(gid, []))
            path = os.path.join(args.outdir, f"tree_{gid}.laz" if n == 0 else f"tree_{gid}_{n:03d}.laz")
            write_las_chunk(path, rows, colour=(cr, cg, cb))
            tree_chunks.setdefault(gid, []).append(path)
            written += len(rows)
    def concat_tree_chunks(gid):
        """Merge tree_<gid>_<n>.laz chunks into a single tree_<gid>.laz."""
        chunks = sorted(tree_chunks.get(gid, []))
        if len(chunks) <= 1:
            if chunks and chunks[0] != os.path.join(args.outdir, f"tree_{gid}.laz"):
                os.replace(chunks[0], os.path.join(args.outdir, f"tree_{gid}.laz"))
            return
        import laspy
        import numpy as np
        xs, ys, zs = [], [], []
        for c in chunks:
            with laspy.open(c) as h:
                las = h.read()
                xs.append(las.x); ys.append(las.y); zs.append(las.z)
        cr, cg, cb = norm_colour(gid)
        rows = [(float(a), float(b), float(cc)) for a, b, cc in zip(np.concatenate(xs), np.concatenate(ys), np.concatenate(zs))]
        final = os.path.join(args.outdir, f"tree_{gid}.laz")
        tmp = final + ".tmp.laz"
        write_las_chunk(tmp, rows, colour=(cr, cg, cb))
        for c in chunks:
            if c != tmp:
                os.remove(c)
        os.replace(tmp, final)
    def flush_all():
        nonlocal written
        for gid in list(tree_rows):
            flush(gid)
        if unlab_rows:
            flush_unlab(unlab_rows)

    try:
        for ti, tj, seg, mapping in tiles:
            ds = ply_data_start(seg)
            with open(seg, "rb") as f:
                f.seek(ds)
                while True:
                    buf = f.read(64 << 20)
                    if not buf:
                        break
                    rem = len(buf) % REC
                    if rem:
                        buf = buf[:-rem]
                        f.seek(-rem, 1)
                    for off in range(0, len(buf), REC):
                        x, y, z = struct.unpack_from("<ddd", buf, off)
                        k = key_of(x, y, z)
                        if k in done_keys:
                            skip += 1
                            continue
                        done_keys.add(k)
                        gid = pt_map.get(k, -1)
                        if gid >= 0:
                            tree_rows.setdefault(gid, []).append((x, y, z))
                            tree_count += 1
                            if len(tree_rows[gid]) >= FLUSH:
                                flush(gid)
                        else:
                            unlab_rows.append((x, y, z))
                            unlab_count += 1
                            if len(unlab_rows) >= FLUSH:
                                flush_unlab(unlab_rows)
                                unlab_rows = []
            print(f"  pass B tile [{ti},{tj}] done (written {written:,}, skip {skip:,})")
    finally:
        flush_all()
    # merge per-tree chunk files into single tree_<gid>.laz
    for gid in list(tree_chunks):
        concat_tree_chunks(gid)
    print(f"DEBUG: pt_map={len(pt_map):,} done_keys={len(done_keys):,} assigned tree pts={tree_count:,} unlab pts={unlab_count:,}")

    # ---- manifest --------------------------------------------------------
    manifest = {}
    for gid in gbases:
        p = os.path.join(args.outdir, f"tree_{gid}.laz")
        if os.path.exists(p):
            with open(p, "rb") as f:
                f.seek(107)
                n = struct.unpack("<I", f.read(4))[0]
            manifest[gid] = {"base": list(gbases[gid]), "points": n}
    unlab_total = 0
    import glob as _glob
    for up in sorted(_glob.glob(os.path.join(args.outdir, "unlabelled_*.laz"))):
        with open(up, "rb") as f:
            f.seek(107)
            unlab_total += struct.unpack("<I", f.read(4))[0]
    if unlab_total:
        manifest["_unlabelled"] = {"points": unlab_total}
    json.dump(manifest, open(os.path.join(args.outdir, "manifest.json"), "w"), indent=1)

    unlab_n = manifest.get("_unlabelled", {}).get("points", 0)
    print(f"\nunique points written : {written:,} (dedup; skip {skip:,})")
    print(f"trees (LAZ files)     : {len(manifest) - (1 if '_unlabelled' in manifest else 0)}")
    print(f"unlabelled points     : {unlab_n:,}")
    print(f"output: {args.outdir}/")

if __name__ == "__main__":
    main()
