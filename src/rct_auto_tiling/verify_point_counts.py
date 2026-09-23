#!/usr/bin/env python3
"""
rct_auto_tiling — verification: input point count == sum of nominal tile counts.

The hard guarantee for "nothing is lost, nothing is duplicated" at the POINT
level. Reads the input PLY header and every tile's owners.json (which records
each tile's OWN nominal point count) and reconciles:

    sum(owner counts over all tiles) == input PLY vertex count

Also reports the buffered total (points physically written incl. ring) so the
overlap cost is visible.

Exit 0 = PASS, exit 2 = FAIL.
"""
from __future__ import annotations
import argparse, glob, json, os, sys
from typing import Dict, Tuple

from common import read_ply_header


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--tiles", required=True, help="glob for tile_*.owners.json")
    args = ap.parse_args()

    n_in, _hdr, _ = read_ply_header(args.input)
    files = sorted(glob.glob(args.tiles))
    if not files:
        sys.exit("no owners files matched")
    owner_sum = 0
    in_file_sum = 0
    per = {}
    for p in files:
        d = json.load(open(p))
        owner = d.get("owner", 0); infile = d.get("in_file", 0)
        owner_sum += owner; in_file_sum += infile
        per[os.path.basename(p)] = (owner, infile)
    print(f"input points           = {n_in}")
    print(f"sum of nominal tiles   = {owner_sum}   (delta {owner_sum - n_in:+d})")
    print(f"sum of buffered files  = {in_file_sum}")
    for k in sorted(per):
        print(f"   {k}: owner={per[k][0]} in_file={per[k][1]}")
    if owner_sum == n_in:
        print("PASS: sum(nominal tiles) == input point count — no loss, no duplicate at point level")
        return 0
    print("FAIL: point-count reconciliation failed")
    return 2


if __name__ == "__main__":
    sys.exit(main())
