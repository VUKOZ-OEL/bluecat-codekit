#!/bin/bash
#PBS -N hdmap_level
#PBS -j oe

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/input.zip" >&2
  exit 2
fi

INPUT_ZIP="$1"

if [ ! -f "$INPUT_ZIP" ]; then
  echo "ERROR: input zip does not exist: $INPUT_ZIP" >&2
  exit 2
fi

# CESNET PBS normally provides SCRATCHDIR. Fall back to /tmp for local tests.
WORKDIR="${SCRATCHDIR:-/tmp/hdmap_level_${PBS_JOBID:-$$}}"
mkdir -p "$WORKDIR"

INPUT_DIR="$(cd "$(dirname "$INPUT_ZIP")" && pwd)"
INPUT_BASE="$(basename "$INPUT_ZIP")"
INPUT_STEM="${INPUT_BASE%.zip}"

# Derive output stem:
#   plot_12-2_hdmapping_rawslam.zip -> 12-2
#   otherwise, use input stem with common suffixes stripped.
OUT_STEM="$(python3 - "$INPUT_STEM" <<'PY'
import re, sys
s = sys.argv[1]
# Prefer pattern plot_<ID>_...
m = re.search(r'(?:^|_)plot_([^_]+)', s, flags=re.I)
if m:
    print(m.group(1))
    raise SystemExit
# Also accept bare leading plot-ID style before known suffixes
s2 = re.sub(r'(?i)(_?hdmapping)?_?rawslam$', '', s)
s2 = re.sub(r'(?i)_?continuousscanning.*$', '', s2)
s2 = re.sub(r'(?i)^plot_', '', s2)
print(s2)
PY
)"

OUT_ZIP="${INPUT_DIR}/${OUT_STEM}_leveled.zip"
OUT_LAS="${OUT_STEM}.las"
OUT_TRAJ="${OUT_STEM}_trajectory.csv"
OUT_JSON="${OUT_STEM}_rotation.json"

cleanup() {
  if [ -n "${SCRATCHDIR:-}" ] && [ -d "$WORKDIR" ]; then
    rm -rf "$WORKDIR"
  fi
}
trap cleanup EXIT

cd "$WORKDIR"
mkdir -p in out
unzip -q "$INPUT_ZIP" -d in

LAS_FILE="$(find in -type f \( -iname '*.las' -o -iname '*.laz' \) | head -n 1)"
CSV_FILE="$(find in -type f -iname '*.csv' | head -n 1)"

if [ -z "$LAS_FILE" ] || [ -z "$CSV_FILE" ]; then
  echo "ERROR: zip must contain exactly one LAS/LAZ and one CSV file." >&2
  echo "Found LAS/LAZ:" >&2
  find in -type f \( -iname '*.las' -o -iname '*.laz' \) >&2 || true
  echo "Found CSV:" >&2
  find in -type f -iname '*.csv' >&2 || true
  exit 3
fi

LAS_COUNT="$(find in -type f \( -iname '*.las' -o -iname '*.laz' \) | wc -l)"
CSV_COUNT="$(find in -type f -iname '*.csv' | wc -l)"
if [ "$LAS_COUNT" -ne 1 ] || [ "$CSV_COUNT" -ne 1 ]; then
  echo "ERROR: zip must contain exactly one LAS/LAZ and exactly one CSV." >&2
  echo "LAS/LAZ count: $LAS_COUNT, CSV count: $CSV_COUNT" >&2
  exit 3
fi

cat > process_level.py <<'PY'
#!/usr/bin/env python3
import argparse
import csv
import json
import math
from pathlib import Path

import laspy
import numpy as np


def read_trajectory(path: Path):
    rows = []
    numeric_rows = []
    header = None

    with path.open("r", newline="") as f:
        sample = f.read(4096)
        f.seek(0)
        dialect = csv.Sniffer().sniff(sample, delimiters=",;\t ")
        reader = csv.reader(f, dialect)
        for row in reader:
            if not row or all(not c.strip() for c in row):
                continue
            rows.append(row)
            try:
                vals = [float(c.strip()) for c in row]
            except ValueError:
                if header is None:
                    header = row
                continue
            numeric_rows.append((len(rows) - 1, vals))

    if not numeric_rows:
        raise RuntimeError("trajectory CSV contains no numeric rows")

    arr = np.array([v for _, v in numeric_rows], dtype=float)
    if arr.shape[1] < 4:
        raise RuntimeError("trajectory CSV must have at least 4 numeric columns: time,x,y,z")

    return rows, numeric_rows, arr, header


def pca_rotation_from_trajectory(xyz: np.ndarray):
    center = xyz.mean(axis=0)
    X = xyz - center
    _, singular_values, vh = np.linalg.svd(X, full_matrices=False)
    normal = vh[-1].astype(float)

    # Keep normal in positive-Z half-space for deterministic output.
    if normal[2] < 0:
        normal *= -1.0

    z = np.array([0.0, 0.0, 1.0])
    dot = float(np.clip(np.dot(normal, z), -1.0, 1.0))
    angle = math.acos(dot)
    axis = np.cross(normal, z)
    axis_norm = float(np.linalg.norm(axis))

    if axis_norm < 1e-12:
        R = np.eye(3)
        axis_unit = np.array([0.0, 0.0, 1.0])
        angle = 0.0
    else:
        axis_unit = axis / axis_norm
        K = np.array([
            [0.0, -axis_unit[2], axis_unit[1]],
            [axis_unit[2], 0.0, -axis_unit[0]],
            [-axis_unit[1], axis_unit[0], 0.0],
        ])
        R = np.eye(3) + math.sin(angle) * K + (1.0 - math.cos(angle)) * (K @ K)

    return R, normal, axis_unit, angle, singular_values, center


def rotate_vectors(v: np.ndarray, R: np.ndarray):
    return v @ R.T


def rotate_quaternion_xyzw(q: np.ndarray, Rmat: np.ndarray):
    # q columns are assumed x,y,z,w. This avoids scipy dependency.
    # Convert rotation matrix to quaternion x,y,z,w.
    m = Rmat
    t = np.trace(m)
    if t > 0:
        s = math.sqrt(t + 1.0) * 2.0
        qw = 0.25 * s
        qx = (m[2, 1] - m[1, 2]) / s
        qy = (m[0, 2] - m[2, 0]) / s
        qz = (m[1, 0] - m[0, 1]) / s
    else:
        i = int(np.argmax([m[0, 0], m[1, 1], m[2, 2]]))
        if i == 0:
            s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2.0
            qw = (m[2, 1] - m[1, 2]) / s
            qx = 0.25 * s
            qy = (m[0, 1] + m[1, 0]) / s
            qz = (m[0, 2] + m[2, 0]) / s
        elif i == 1:
            s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2.0
            qw = (m[0, 2] - m[2, 0]) / s
            qx = (m[0, 1] + m[1, 0]) / s
            qy = 0.25 * s
            qz = (m[1, 2] + m[2, 1]) / s
        else:
            s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2.0
            qw = (m[1, 0] - m[0, 1]) / s
            qx = (m[0, 2] + m[2, 0]) / s
            qy = (m[1, 2] + m[2, 1]) / s
            qz = 0.25 * s

    rq = np.array([qx, qy, qz, qw], dtype=float)
    rq /= np.linalg.norm(rq)

    # Hamilton product rq * q, both in xyzw order.
    x1, y1, z1, w1 = rq
    x2, y2, z2, w2 = q.T
    out = np.empty_like(q)
    out[:, 0] = w1*x2 + x1*w2 + y1*z2 - z1*y2
    out[:, 1] = w1*y2 - x1*z2 + y1*w2 + z1*x2
    out[:, 2] = w1*z2 + x1*y2 - y1*x2 + z1*w2
    out[:, 3] = w1*w2 - x1*x2 - y1*y2 - z1*z2
    norms = np.linalg.norm(out, axis=1)
    ok = norms > 0
    out[ok] /= norms[ok, None]
    return out, rq


def write_rotated_trajectory(rows, numeric_rows, arr, R, out_path: Path):
    arr2 = arr.copy()
    arr2[:, 1:4] = rotate_vectors(arr[:, 1:4], R)

    rot_quaternion_xyzw = None
    if arr.shape[1] >= 8:
        q = arr[:, 4:8].copy()
        qnorm = np.linalg.norm(q, axis=1)
        if np.nanmedian(qnorm) > 0.5:
            q[qnorm > 0] /= qnorm[qnorm > 0, None]
            arr2[:, 4:8], rot_quaternion_xyzw = rotate_quaternion_xyzw(q, R)

    out_rows = [list(r) for r in rows]
    for arr_idx, (row_idx, vals) in enumerate(numeric_rows):
        formatted = [format(x, ".12g") for x in arr2[arr_idx, :len(vals)]]
        out_rows[row_idx] = formatted

    with out_path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerows(out_rows)

    return arr2, rot_quaternion_xyzw


def rotate_las(in_path: Path, out_path: Path, R: np.ndarray):
    las = laspy.read(in_path)
    pts = np.column_stack((las.x, las.y, las.z))
    pts2 = rotate_vectors(pts, R)
    las.x = pts2[:, 0]
    las.y = pts2[:, 1]
    las.z = pts2[:, 2]
    las.write(out_path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--las", required=True)
    ap.add_argument("--csv", required=True)
    ap.add_argument("--out-las", required=True)
    ap.add_argument("--out-csv", required=True)
    ap.add_argument("--out-json", required=True)
    args = ap.parse_args()

    rows, numeric_rows, arr, header = read_trajectory(Path(args.csv))
    xyz = arr[:, 1:4]
    R, normal, axis, angle, singular_values, center = pca_rotation_from_trajectory(xyz)

    traj_rot, rot_q = write_rotated_trajectory(rows, numeric_rows, arr, R, Path(args.out_csv))
    rotate_las(Path(args.las), Path(args.out_las), R)

    meta = {
        "method": "trajectory PCA leveling, rotation around origin 0,0,0",
        "input_las": str(args.las),
        "input_csv": str(args.csv),
        "trajectory_columns_assumed": "time,x,y,z[,qx,qy,qz,qw,...]",
        "pca_normal_before_rotation": normal.tolist(),
        "target_normal": [0.0, 0.0, 1.0],
        "rotation_axis": axis.tolist(),
        "rotation_angle_rad": angle,
        "rotation_angle_deg": math.degrees(angle),
        "rotation_matrix_3x3": R.tolist(),
        "homogeneous_matrix_4x4": [
            [float(R[0,0]), float(R[0,1]), float(R[0,2]), 0.0],
            [float(R[1,0]), float(R[1,1]), float(R[1,2]), 0.0],
            [float(R[2,0]), float(R[2,1]), float(R[2,2]), 0.0],
            [0.0, 0.0, 0.0, 1.0],
        ],
        "rotation_quaternion_xyzw": None if rot_q is None else rot_q.tolist(),
        "trajectory_centroid_before_rotation": center.tolist(),
        "trajectory_singular_values": singular_values.tolist(),
        "trajectory_bbox_before": {
            "min": xyz.min(axis=0).tolist(),
            "max": xyz.max(axis=0).tolist(),
        },
        "trajectory_bbox_after": {
            "min": traj_rot[:, 1:4].min(axis=0).tolist(),
            "max": traj_rot[:, 1:4].max(axis=0).tolist(),
        },
    }

    Path(args.out_json).write_text(json.dumps(meta, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
PY

# Load environment on CESNET. Adjust module names if your site uses different names.
if command -v module >/dev/null 2>&1; then
  module add python/3.10 >/dev/null 2>&1 || true
fi

# Install Python deps into scratch if not already available.
export PYTHONUSERBASE="$WORKDIR/pyuserbase"
export PATH="$PYTHONUSERBASE/bin:$PATH"
python3 - <<'PY' >/dev/null 2>&1 || python3 -m pip install --user --no-cache-dir numpy laspy lazrs
import numpy, laspy
PY

python3 process_level.py \
  --las "$LAS_FILE" \
  --csv "$CSV_FILE" \
  --out-las "out/$OUT_LAS" \
  --out-csv "out/$OUT_TRAJ" \
  --out-json "out/$OUT_JSON"

cd out
zip -q -9 "$OUT_ZIP" "$OUT_LAS" "$OUT_TRAJ" "$OUT_JSON"

echo "DONE: $OUT_ZIP"
