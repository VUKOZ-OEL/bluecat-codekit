#!/usr/bin/env python3
"""
Convert rayextract trees.txt (RCT output) into the treeInfo GeoJSON shape
that step2_merge_segments.py consumes.

trees.txt rows:
  leading columns:  x, y, z, radius, parent_id, section_id    (per segment)
  each row = one segment of one tree. The tree's base is the row with
  parent_id == -1 (root segment), first two values x,y,z.

GeoJSON FeatureCollection: one Point feature per tree (base + height + radius),
with global coordinates (already global for georeferenced rayclouds).

Usage: trees_txt_to_geojson.py <trees.txt> <out.geojson>
"""
from __future__ import annotations
import json, math, sys

def main():
    if len(sys.argv) != 3:
        sys.exit("usage: trees_txt_to_geojson.py <trees.txt> <out.geojson>")
    src, dst = sys.argv[1], sys.argv[2]

    trees = []          # each: {base:[x,y,z], segs:[[x,y,z,radius,parent],...]}
    cur = None
    with open(src) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.replace(",", " ").split()
            # tolerate optional leading attribute cols before x,y,z,radius
            # (e.g. 'height,crown_radius, ' -> skip unknown width). We detect
            # the header row by non-numeric fields.
            try:
                vals = [float(p) for p in parts]
            except ValueError:
                continue  # header
            # find the 6 expected: x y z radius parent section ... (may be more)
            # Each line is ONE full tree (segments as repeated csv groups), so
            # a data row always starts a new tree.
            if len(vals) >= 6:
                segs = []
                for k in range(0, len(vals) - 5, 6):
                    x, y, z, r, parent, sect = vals[k:k + 6]
                    segs.append([x, y, z, r, parent])
                x, y, z, r, parent = vals[0], vals[1], vals[2], vals[3], vals[4]
                trees.append({"base": [x, y, z], "base_radius": r, "segs": segs})
    # wire parent_id references (for height)
    feats = []
    for ti, t in enumerate(trees, 1):
        base = t.get("base")
        if base is None:
            continue
        zmax = max(s[2] for s in t["segs"]) if t["segs"] else base[2]
        h = zmax - base[2]
        feats.append({
            "type": "Feature",
            "id": ti,
            "properties": {
                "tree_id": ti,
                "height": round(h, 3),
                "base_radius": round(t.get("base_radius", 0), 4),
                "n_segments": len(t["segs"]),
            },
            "geometry": {"type": "Point", "coordinates": base},
        })
    out = {"type": "FeatureCollection", "features": feats}
    json.dump(out, open(dst, "w"), indent=1)
    print(f"{src}: {len(trees)} trees -> {dst} ({len(feats)} features)")

if __name__ == "__main__":
    main()
