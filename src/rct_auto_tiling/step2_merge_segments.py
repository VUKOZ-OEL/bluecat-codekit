#!/usr/bin/env python3
"""
rct_auto_tiling — step 2: merge per-tile treeInfo segment results back into one.

Consumes, per tile, the per-tree georeferenced treeInfo GeoJSON (Point features
with the tree base in the GLOBAL georeferenced frame) and returns a merged
FeatureCollection in which every real tree appears exactly once.

Deduplication = single-linkage clustering of detections by base XY distance:
two detections belong to the SAME tree iff they are within DELTA metres in the
GLOBAL frame. This is robust to small base-localisation noise across tiles
(cm–dm) while separating genuinely different trees (typical min spacing >> δ).

  δ must satisfy:  noise < δ < min tree base spacing
  (dataset-dependent; run with --delta. For the q34 sample, min spacing is
   0.156 m and duplicate-detection noise is ~cm → δ=0.1 m is safe.)

Algorithm (scalable): grid-bucket the detections at δ, union-find over the 3×3
neighbour buckets. O(N) average. The surviving feature = detection with fewest
missing properties / most points; coordinates = the group's representative.
"""
from __future__ import annotations
import argparse, glob, json, math, os, sys
from typing import Dict, List, Tuple

DELTA_DEFAULT = 0.1


def load_features(path: str) -> List[Dict]:
    if not os.path.exists(path):
        return []
    with open(path) as f:
        fc = json.load(f)
    out = []
    for feat in fc.get("features", []):
        g = feat.get("geometry") or {}
        if g.get("type") != "Point":
            continue
        coords = g.get("coordinates") or []
        if len(coords) < 3:
            continue
        props = dict(feat.get("properties") or {})
        x, y, z = float(coords[0]), float(coords[1]), float(coords[2])
        h = float(props.get("height", props.get("length", z)) or z)
        missing = sum(1 for k in ("height", "DBH", "volume") if k not in props)
        out.append({"feat": feat, "x": x, "y": y, "z": z, "h": h,
                    "missing": missing, "npoints": int(props.get("n_seg_points", 0))})
    return out


def single_linkage(dets: List[Dict], delta: float) -> List[List[Dict]]:
    """Group detections by XY distance <= delta (union-find over grid buckets)."""
    n = len(dets)
    if n == 0:
        return []
    parent = list(range(n))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb

    xs = [d["x"] for d in dets]; ys = [d["y"] for d in dets]
    minx, miny = min(xs), min(ys)
    bx = [int((x - minx) / delta) for x in xs]
    by = [int((y - miny) / delta) for y in ys]
    buckets: Dict[Tuple[int, int], List[int]] = {}
    for idx in range(n):
        buckets.setdefault((bx[idx], by[idx]), []).append(idx)
    # compare within 3x3, INCLUDING the same bucket
    for (bi, bj), ids in buckets.items():
        for ni in (bi - 1, bi, bi + 1):
            for nj in (bj - 1, bj, bj + 1):
                other = buckets.get((ni, nj))
                if not other:
                    continue
                if (ni, nj) < (bi, bj):
                    continue  # this pair was already handled from the other side
                for a in ids:
                    for b in other:
                        if (dets[a]["x"] - dets[b]["x"]) ** 2 + (dets[a]["y"] - dets[b]["y"]) ** 2 <= delta * delta:
                            union(a, b)
    groups: Dict[int, List[int]] = {}
    for idx in range(n):
        groups.setdefault(find(idx), []).append(idx)
    return [[dets[i] for i in g] for g in groups.values()]


def merge(dets: List[Dict], delta: float) -> List[Dict]:
    groups = single_linkage(dets, delta)
    features = []
    for g in groups:
        if len(g) > 1:
            # representative = group centroid? keep base of detection with fewest missing; coords = first
            best = min(g, key=lambda d: (d["missing"], -d["npoints"]))
        else:
            best = g[0]
        features.append(best["feat"])
    print(f"unique trees = {len(features)}  (raw detections = {len(dets)}, collapsed = {len(dets) - len(features)})")
    return features


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tiles", nargs="+", default=None)
    ap.add_argument("--pattern", default=None)
    ap.add_argument("--delta", type=float, default=DELTA_DEFAULT)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    files = sorted(glob.glob(args.pattern)) if args.pattern else (args.tiles or [])
    if not files:
        sys.exit("no per-tile files given")
    dets = []
    for path in files:
        dets.extend(load_features(path))
    feats = merge(dets, args.delta)
    fc = {"type": "FeatureCollection", "features": feats}
    with open(args.out, "w") as f:
        json.dump(fc, f, indent=1, ensure_ascii=False)
    print(f"wrote {args.out} with {len(feats)} trees")
    return 0


if __name__ == "__main__":
    sys.exit(main())
