#!/usr/bin/env python3
"""
rct_auto_tiling — plan the tile grid for a MetaCentrum run under a RAM cap.

Derives recommended tile length L (and per-tile point budget) from plot size
and point density so that the per-tile rayprocess stays under the PBS node RAM
limit (default 256 GB per the owner), with buffer B as an input (default 10 m).

Model (conservative):
  density_d = pts/m^2  (from plot area + total points, or given directly)
  tile_pts_nom  = (L)^2 * density_d
  tile_pts_buf  = (L + 2*B)^2 * density_d     # what rayprocess actually loads
  RAM_est GB    = tile_pts_buf * BYTES_PER_PT / 1e9
  BYTES_PER_PT  ~ 64 (ray cloud floats: x,y,z,time + normal + rgb) * safety 2
  RAM residency  = max(RAM_est, fixed overhead ~2 GB)

The splitter itself streams (O(1) memory regardless of L), so only the
per-tile rayprocess RAM matters. We pick L = largest L with RAM_est <= cap,
rounded to a grid step, and cap L to a sane max (default 200 m) to keep tiles
parallel-friendly.

Usage:
  python plan_tiling.py --density 200 --area_ha 5 [--buffer 10] [--ram_gb 256]
  python plan_tiling.py --points 2e9 --width_m 200 --height_m 100 [--buffer 10] [--ram_gb 256]
"""
from __future__ import annotations
import argparse, math

BYTES_PER_PT = 64.0          # conservative ray-cloud bytes/point
OVERHEAD_GB = 2.0
MAX_L_M = 200.0

def solve(density, buffer, ram_gb):
    """Return (L, tile_pts_nom, tile_pts_buf, ram_est)."""
    budget = (ram_gb - OVERHEAD_GB) * 1e9 / BYTES_PER_PT
    # points = (L+2B)^2 * density <= budget  ->  L+2B <= sqrt(budget/density)
    side = math.sqrt(budget / density) - 2 * buffer
    L = math.floor(side / 5.0) * 5.0          # round down to 5 m grid
    if L < 1:
        L = 1.0
    L = min(L, MAX_L_M)
    tile_pts_nom = (L * L) * density
    tile_pts_buf = ((L + 2 * buffer) ** 2) * density
    ram_est = tile_pts_buf * BYTES_PER_PT / 1e9 + OVERHEAD_GB
    return L, tile_pts_nom, tile_pts_buf, ram_est

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--density", type=float, help="pts/m^2 (direct)")
    ap.add_argument("--area_ha", type=float, help="plot area in hectares")
    ap.add_argument("--points", type=float, help="total points (alt to density+area)")
    ap.add_argument("--width_m", type=float, default=100.0)
    ap.add_argument("--height_m", type=float, default=100.0)
    ap.add_argument("--buffer", type=float, default=10.0, help="buffer m (default 10)")
    ap.add_argument("--ram_gb", type=float, default=256.0, help="RAM cap, default 256")
    args = ap.parse_args()

    if args.density:
        density = args.density
    elif args.area_ha:
        density = args.points / (args.area_ha * 1e4)
    else:
        density = args.points / (args.width_m * args.height_m)
    if density <= 0 or not math.isfinite(density):
        raise SystemExit("need --density or enough info to derive it")

    L, nom, buf, ram = solve(density, args.buffer, args.ram_gb)
    area_ha = args.area_ha or (args.width_m * args.height_m) / 1e4
    n_tiles_x = max(1, math.ceil(args.width_m / L)) if args.width_m else "?"
    n_tiles_y = max(1, math.ceil(args.height_m / L)) if args.height_m else "?"
    if isinstance(n_tiles_x, int) and isinstance(n_tiles_y, int):
        n_tiles = n_tiles_x * n_tiles_y
    else:
        n_tiles = "?"

    print(f"density         : {density:,.0f} pts/m^2")
    print(f"area            : {area_ha:.2f} ha ({args.width_m:.0f} x {args.height_m:.0f} m)")
    print(f"buffer B        : {args.buffer:.1f} m")
    print(f"RAM cap         : {args.ram_gb:.0f} GB")
    print(f"---")
    print(f"recommended L   : {L:.0f} m")
    print(f"points/tile nom : {nom:,.0f}")
    print(f"points/tile buf : {buf:,.0f}")
    print(f"RAM/tile (est)  : {ram:.1f} GB  (cap {args.ram_gb:.0f})")
    print(f"grid            : {n_tiles_x} x {n_tiles_y} = {n_tiles} tiles" if isinstance(n_tiles, int) else "grid: ?")

if __name__ == "__main__":
    main()
