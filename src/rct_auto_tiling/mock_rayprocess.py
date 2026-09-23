#!/usr/bin/env python3
"""
rct_auto_tiling — LOCAL TEST stub for the per-tile rayprocess step.

On MetaCentrum this step is the real RayCloudTools pipeline run per tile
(rayimport -> rayextract terrain/trees -> georef -> treeInfo.geojson).

Locally we cannot run rayextract, so this stub builds per-tile treeInfo the way
a real run would: for each tile, a feature appears if its (global) base lies in
the tile's nominal extent OR within the buffer — i.e. the same boundary
behaviour rayextract would produce. This lets the full orchestration
(step1 -> stub -> step2 -> verify) be exercised end-to-end and the merge dedup
to be validated on realistic duplicate detections.

Usage:
  mock_rayprocess.py <input_cloud.ply> <tile.ply> <out.trees.json>
"""
from __future__ import annotations
import json, math, os, struct, sys
from typing import Dict, List, Tuple

# --- PLY header read ----------------------------------------------------------
def read_ply(path):
    n = 0; names = []; hdr = 0
    with open(path, "rb") as f:
        while True:
            line = f.readline(); hdr += len(line)
            if line.startswith(b"element vertex"): n = int(line.split()[-1])
            elif line.startswith(b"property "): names.append(line.decode().split()[-1])
            elif line.startswith(b"end_header"): break
    return n, hdr, names

def main():
    if len(sys.argv) < 4:
        sys.exit("usage: mock_rayprocess.py <cloud.ply> <tile.ply> <out.trees.json>")
    cloud, tile, out = sys.argv[1], sys.argv[2], sys.argv[3]

    # tile grid from tile filename tile_<i>_<j>.ply; derive origin from cloud bbox
    base = os.path.basename(tile)
    i = int(base.split("_")[1]); j = int(base.split("_")[2].split(".")[0])

    # We need origin + length: re-derive from cloud bbox the same way step1 does.
    # (Mock convenience: read bbox of cloud, replicate step1 origin = floor(min).)
    n, hdr, names = read_ply(cloud)
    rec = 4*8 + 3*4 + 4*1
    minx = miny = 1e18; maxx = maxy = -1e18
    with open(cloud, "rb") as f:
        f.seek(hdr)
        while True:
            buf = f.read(16 << 20)
            if not buf: break
            rem = len(buf) % rec
            if rem: buf = buf[:-rem]; f.seek(-rem, 1)
            for off in range(0, len(buf), rec):
                x, y = struct.unpack_from("<dd", buf, off)
                minx = min(minx, x); maxx = max(maxx, x)
                miny = min(miny, y); maxy = max(maxy, y)
    ox = float(os.environ.get("MOCK_ORIGIN_X", math.floor(minx)))
    oy = float(os.environ.get("MOCK_ORIGIN_Y", math.floor(miny)))
    L = float(os.environ.get("MOCK_LENGTH", 10.0))
    B = float(os.environ.get("MOCK_BUFFER", 10.0))
    x0, x1 = ox + i*L, ox + (i+1)*L
    y0, y1 = oy + j*L, oy + (j+1)*L

    # source treeInfo (global frame) provided via env MOCK_TREES
    src_trees = os.environ.get("MOCK_TREES", "")
    if not src_trees:
        # fallback: empty
        json.dump({"type": "FeatureCollection", "features": []}, open(out, "w"))
        return
    fc = json.load(open(src_trees))
    feats = []
    for f in fc.get("features", []):
        g = f.get("geometry") or {}
        if g.get("type") != "Point": continue
        c = g.get("coordinates") or []
        if len(c) < 3: continue
        x, y = c[0], c[1]
        if (x0 - B) <= x < (x1 + B) and (y0 - B) <= y < (y1 + B):
            feats.append(f)
    json.dump({"type": "FeatureCollection", "features": feats}, open(out, "w"))
    print(f"mock: tile {base}: {len(feats)} features", file=sys.stderr)

if __name__ == "__main__":
    main()
