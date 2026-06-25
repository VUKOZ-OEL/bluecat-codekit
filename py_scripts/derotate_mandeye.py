#!/usr/bin/env python3
"""
derotate_mandeye.py

Normalize MANDEYE data recorded with the scanner physically rotated 90 degrees
about its Y axis (Z pointing forward instead of up).

It applies ONE consistent rotation R to BOTH:
  - the IMU vectors (gyroX/Y/Z and accX/Y/Z) in every imu*.csv, and
  - the XYZ coordinates of every point in every LAZ/LAS file,
so that points and IMU stay mutually consistent and gravity returns to +Z (up).

Rotation used (maps sensor frame -> upright frame):
    R = R_y(+90 deg) = [[ 0, 0, 1],
                        [ 0, 1, 0],
                        [-1, 0, 0]]
Verified against the uploaded imu0035.csv: mean accelerometer (gravity) goes
from ~(-0.97, -0.03, -0.21) g  ->  ~(-0.21, -0.03, +0.97) g, i.e. up = +Z.

Because R is a proper rotation (det = +1), gyroscope (axial), accelerometer and
point coordinates all transform identically: v' = R @ v. No special handling.

USAGE
  # rotate a single IMU csv (writes alongside with _derot suffix):
  python3 derotate_mandeye.py --imu imu0035.csv

  # rotate every imu*.csv and every *.laz in a folder into an output folder:
  python3 derotate_mandeye.py --in-dir /path/to/raw --out-dir /path/to/derot

  # custom angle/axis if you ever need it:
  python3 derotate_mandeye.py --in-dir RAW --out-dir DEROT --axis Y --angle 90
"""

import argparse
import math
import os
import sys
from pathlib import Path

import numpy as np


def rotation_matrix(axis: str, angle_deg: float) -> np.ndarray:
    a = math.radians(angle_deg)
    c, s = math.cos(a), math.sin(a)
    axis = axis.upper()
    if axis == "X":
        return np.array([[1, 0, 0], [0, c, -s], [0, s, c]], dtype=float)
    if axis == "Y":
        return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]], dtype=float)
    if axis == "Z":
        return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]], dtype=float)
    raise ValueError(f"axis must be X, Y or Z (got {axis!r})")


# ---------------------------------------------------------------- IMU CSV ----
# Expected header (space separated):
# timestamp gyroX gyroY gyroZ accX accY accZ imuId timestampUnix
def derotate_imu_csv(in_path: Path, out_path: Path, R: np.ndarray) -> None:
    with open(in_path, "r") as f:
        lines = f.read().splitlines()

    if not lines:
        raise ValueError(f"{in_path} is empty")

    header = lines[0].split()
    # locate the columns by name so we don't depend on fixed positions
    try:
        gi = [header.index(c) for c in ("gyroX", "gyroY", "gyroZ")]
        ai = [header.index(c) for c in ("accX", "accY", "accZ")]
    except ValueError as e:
        raise ValueError(
            f"could not find gyro/acc columns in header: {header}"
        ) from e

    out_lines = [lines[0]]  # keep header verbatim
    for ln in lines[1:]:
        if not ln.strip():
            continue
        tok = ln.split()
        g = np.array([float(tok[gi[0]]), float(tok[gi[1]]), float(tok[gi[2]])])
        a = np.array([float(tok[ai[0]]), float(tok[ai[1]]), float(tok[ai[2]])])
        g2 = R @ g
        a2 = R @ a
        for k, idx in enumerate(gi):
            tok[idx] = repr(float(g2[k]))
        for k, idx in enumerate(ai):
            tok[idx] = repr(float(a2[k]))
        out_lines.append(" ".join(tok))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w") as f:
        f.write("\n".join(out_lines) + "\n")
    print(f"  IMU  {in_path.name} -> {out_path}  ({len(out_lines) - 1} rows)")


# ---------------------------------------------------------------- LAZ/LAS ----
def derotate_laz(in_path: Path, out_path: Path, R: np.ndarray) -> None:
    try:
        import laspy
    except ImportError:
        print(
            "  [skip LAZ] laspy not installed. Install with:\n"
            "      pip install 'laspy[laszip]'\n"
            f"  (wanted to process {in_path.name})",
            file=sys.stderr,
        )
        return

    las = laspy.read(str(in_path))
    # work in the file's own coordinate values (x/y/z are scaled+offset reals)
    xyz = np.vstack([las.x, las.y, las.z]).T  # (N,3)
    xyz_rot = xyz @ R.T  # apply R to each row vector

    # keep the same header/scales/offsets; just rewrite coordinates.
    las.x = xyz_rot[:, 0]
    las.y = xyz_rot[:, 1]
    las.z = xyz_rot[:, 2]

    out_path.parent.mkdir(parents=True, exist_ok=True)
    las.write(str(out_path))
    print(f"  LAZ  {in_path.name} -> {out_path}  ({len(xyz)} pts)")


# -------------------------------------------------------------------- main ---
def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--imu", type=Path, help="single IMU csv to derotate")
    p.add_argument("--laz", type=Path, help="single LAZ/LAS to derotate")
    p.add_argument("--in-dir", type=Path, help="folder with imu*.csv and *.laz")
    p.add_argument("--out-dir", type=Path, help="output folder (for --in-dir)")
    p.add_argument("--axis", default="Y", help="rotation axis (default Y)")
    p.add_argument("--angle", type=float, default=90.0,
                   help="rotation angle in degrees (default 90)")
    p.add_argument("--suffix", default="_derot",
                   help="suffix for single-file output (default _derot)")
    args = p.parse_args()

    R = rotation_matrix(args.axis, args.angle)
    print(f"Rotation R = R_{args.axis}({args.angle:g} deg):")
    print(np.array2string(R, precision=4, suppress_small=True))
    print()

    did_something = False

    if args.imu:
        out = args.imu.with_name(args.imu.stem + args.suffix + args.imu.suffix)
        derotate_imu_csv(args.imu, out, R)
        did_something = True

    if args.laz:
        out = args.laz.with_name(args.laz.stem + args.suffix + args.laz.suffix)
        derotate_laz(args.laz, out, R)
        did_something = True

    if args.in_dir:
        if not args.out_dir:
            print("--in-dir requires --out-dir", file=sys.stderr)
            return 2
        in_dir, out_dir = args.in_dir, args.out_dir
        imus = sorted(in_dir.glob("imu*.csv"))
        lazs = sorted(list(in_dir.glob("*.laz")) + list(in_dir.glob("*.las")))
        print(f"Found {len(imus)} IMU csv and {len(lazs)} LAZ/LAS files.\n")
        for f in imus:
            derotate_imu_csv(f, out_dir / f.name, R)
        for f in lazs:
            derotate_laz(f, out_dir / f.name, R)
        # copy through any .sn / calibration / other csv unchanged so the
        # session folder stays complete
        for f in in_dir.iterdir():
            if f.suffix.lower() in (".laz", ".las"):
                continue
            if f.name.startswith("imu") and f.suffix.lower() == ".csv":
                continue
            if f.is_file():
                dst = out_dir / f.name
                dst.parent.mkdir(parents=True, exist_ok=True)
                dst.write_bytes(f.read_bytes())
        did_something = True

    if not did_something:
        p.print_help()
        return 1
    print("\nDone.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
