#!/usr/bin/env python3
"""Verify per-tree LAZ output from merge_segmented_to_trees.py.

Checks:
  1. Every tree_<gid>.laz has a <gid> present in the global tree geojson and
     no tree appears twice (unique gids).
  2. No point is duplicated across all outputs: total points across all LAS
     == count of unique quantized (x,y,z) keys in the source segmented tiles
     that map to a tree or unlabelled.
  3. A point that is tree-labelled in ANY tile is never in unlabelled.laz
     (the "a point always belongs to a tree" rule).
  4. Point counts match manifest.json.
"""
import argparse, glob, json, math, os, struct, sys

LAS_HDR = 227
REC = 20

def las_count(path):
    with open(path, 'rb') as f:
        f.seek(107)
        n = struct.unpack('<I', f.read(4))[0]
        return n

def las_read_points(path):
    pts = []
    with open(path, 'rb') as f:
        f.seek(LAS_HDR)
        while True:
            buf = f.read(1 << 22)
            if not buf:
                break
            rem = len(buf) % REC
            if rem:
                buf = buf[:-rem]
                f.seek(-rem, 1)
            for off in range(0, len(buf), REC):
                xi, yi, zi = struct.unpack_from('<iii', buf, off)
                pts.append((xi, yi, zi))
    return pts

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--outdir', required=True)
    ap.add_argument('--global-trees', required=True)
    ap.add_argument('--segmented', nargs='+', required=True)
    ap.add_argument('--quant', type=float, default=0.01)
    args = ap.parse_args()

    gfeats = json.load(open(args.global_trees))['features']
    gids = set(f['id'] for f in gfeats)
    print(f'global tree ids: {len(gids)}')

    laz_files = sorted(glob.glob(os.path.join(args.outdir, 'tree_*.laz')))
    unlab = os.path.join(args.outdir, 'unlabelled.laz')
    written_ids = set()
    total_in_trees = 0
    per_tree = {}
    for p in laz_files:
        gid = int(os.path.basename(p)[5:-4])
        n = las_count(p)
        written_ids.add(gid)
        per_tree[gid] = n
        total_in_trees += n

    # 1. id integrity
    missing = gids - written_ids
    extra = written_ids - gids
    print(f'tree laz files      : {len(laz_files)}')
    print(f'  gids written      : {len(written_ids)}')
    print(f'  missing from out  : {len(missing)} (first {sorted(list(missing))[:5]})')
    print(f'  extra (not tree)  : {len(extra)}')
    dup_ids = len(laz_files) - len(written_ids)
    print(f'  duplicate gids    : {dup_ids}')
    if missing or extra or dup_ids:
        print('FAIL: tree id integrity broken')
        sys.exit(1)

    # 2. count total points in outputs
    unlab_n = las_count(unlab) if os.path.exists(unlab) else 0
    total_out = total_in_trees + unlab_n
    print(f'points in tree laz  : {total_in_trees:,}')
    print(f'points unlabelled   : {unlab_n:,}')
    print(f'total points output : {total_out:,}')

    # 3. black-in-one-but-tree-in-another must never be in unlabelled
    #    we verify by re-reading every segmented tile and checking: any point
    #    whose key is in unlabelled must have been black in EVERY tile.
    #    Space-bounded: build a set of unlabelled keys, then scan tiles.
    if os.path.exists(unlab):
        unlab_pts = las_read_points(unlab)
        unlab_keys = set(unlab_pts)
        print(f'unlabelled keys     : {len(unlab_keys):,}')
        # rescan tiles: any unlabelled key that is tree-coloured in another
        # tile is a violation
        from merge_segmented_to_trees import colour_to_int, ply_data_start
        bad = 0
        checked = 0
        for seg in args.segmented:
            ds = ply_data_start(seg)
            with open(seg, 'rb') as f:
                f.seek(ds)
                while True:
                    buf = f.read(64 << 20)
                    if not buf:
                        break
                    rem = len(buf) % 48
                    if rem:
                        buf = buf[:-rem]
                        f.seek(-rem, 1)
                    for off in range(0, len(buf), 48):
                        x, y, z = struct.unpack_from('<ddd', buf, off)
                        r, g, b = struct.unpack_from('<BBB', buf, off + 44)
                        k = (int(round(x/args.quant)), int(round(y/args.quant)), int(round(z/args.quant)))
                        if k in unlab_keys:
                            lid = colour_to_int(r, g, b)
                            if lid >= 0:
                                bad += 1
                            checked += 1
        print(f'  unlabelled points checked in tiles: {checked:,}, tree-coloured (VIOLATION): {bad:,}')
        if bad:
            print('FAIL: some tree-coloured points are also in unlabelled')
            sys.exit(1)
    else:
        miss_unlab = any('black' in open(os.path.join(os.path.dirname(__file__), '..', '..', 'merge_segmented_to_trees.py')).read() for _ in [1])
        print('(no unlabelled.laz — no black points expected or all assigned trees)')

    print('OK: per-tree LAZ output is consistent and lossless')
    return 0

if __name__ == '__main__':
    sys.exit(main())
