#!/bin/bash
source /etc/profile

########################################
# ARGUMENTS
########################################
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 /path/to/input_data.zip" >&2
    exit 1
fi

DATA_ZIP="$(readlink -f "$1")"

if [[ ! -f "${DATA_ZIP}" ]]; then
    echo "ERROR: Input zip not found: ${DATA_ZIP}" >&2
    exit 1
fi

DATA_DIRNAME="$(dirname "${DATA_ZIP}")"
DATA_BASENAME="$(basename "${DATA_ZIP}" .zip)"
OUTPUT_ZIP="${DATA_DIRNAME}/${DATA_BASENAME}_hdmapping_rawslam.zip"
STEP1_ZIP="${DATA_DIRNAME}/${DATA_BASENAME}_step1.zip"

########################################
# USER SETTINGS
########################################
SO_SRC_DIR="/storage/plzen1/home/krucek/HDMapping/build/bin/Release"

# --- Scanner derotation (sensor was mounted rotated 90 deg about Y, Z forward) ---
# Applied to BOTH points and IMU so they stay consistent and gravity -> +Z.
# R_y(+90) verified on imu data: gravity moves from -X to +Z.
export DEROT_AXIS="${DEROT_AXIS:-Y}"
export DEROT_ANGLE="${DEROT_ANGLE:-90}"
# Method:
#   laz (default)  - The validated path: rewrites every LAZ by R with laspy and
#                    rotates the IMU CSVs by R. Needs numpy + laspy available.
#                    Make laspy available in ONE of two ways:
#                      * DEROT_VENV=/path/to/venv  (pre-made user venv, preferred)
#                      * DEROT_PIP_INSTALL=1        (pip install in-job; needs net)
#   calib          - No external packages: IMU rotated in CSV (stdlib) and points
#                    rotated by the pipeline via a generated calibration.json.
#                    Use only for single-LiDAR data with a .sn file and no
#                    existing calibration json.
export DEROT_METHOD="${DEROT_METHOD:-laz}"
# Path to a pre-made virtualenv that has numpy + laspy (sourced only for the
# derotation step, in a subshell, so it does not affect the SLAM .so imports).
export DEROT_VENV="${DEROT_VENV:-}"
# Set to 1 to attempt 'pip install --user' inside the job (only if compute
# nodes have internet). Ignored if DEROT_VENV is set and works.
export DEROT_PIP_INSTALL="${DEROT_PIP_INSTALL:-0}"

# --- Loop closure (variant B: pre-seed tail onto start, then pose-graph SLAM) ---
# Apply loop closure when the survey returns near its start. Because step-1
# drift can push the *computed* end far from the start even though they
# coincide in reality, the gate is RELATIVE to trajectory length (drift-tolerant),
# not a fixed small distance. Set LOOP_CLOSURE_FORCE=1 to always apply,
# LOOP_CLOSURE_ENABLE=0 to disable entirely.
export LOOP_CLOSURE_ENABLE="${LOOP_CLOSURE_ENABLE:-1}"
export LOOP_CLOSURE_FORCE="${LOOP_CLOSURE_FORCE:-0}"
export LOOP_CLOSURE_ABS_FLOOR_M="${LOOP_CLOSURE_ABS_FLOOR_M:-3.0}"
export LOOP_CLOSURE_LEN_FRAC="${LOOP_CLOSURE_LEN_FRAC:-0.05}"

########################################
# ENV
########################################
export PAGER=cat
export LESS=FRX
export TERM=dumb

########################################
# MODULES
########################################
module add python/3.9.12-gcc-10.2.1-rg2lpmk

# laspy for the default 'laz' derotation. Make it available in ONE of these ways:
#   1) Pre-made venv (preferred), created once from a login node:
#        module add python/3.9.12-gcc-10.2.1-rg2lpmk
#        python3 -m venv $HOME/hdmap_venv
#        source $HOME/hdmap_venv/bin/activate
#        pip install numpy "laspy[lazrs]"
#      then submit with DEROT_VENV=$HOME/hdmap_venv
#   2) In-job pip (only if compute nodes have internet): DEROT_PIP_INSTALL=1
#   3) DEROT_METHOD=calib (no packages at all)

########################################
# SCRATCH
########################################
: "${SCRATCHDIR:?SCRATCHDIR is not set}"

RUN_NAME="${DATA_BASENAME}_hdmapping"
WORKDIR="${SCRATCHDIR}/${RUN_NAME}"

INPUT_DIR="${WORKDIR}/input"
ROTATED_DIR="${WORKDIR}/rotated"
WORKING_DIR="${WORKDIR}/work"
OUTPUT_DIR="${WORKDIR}/output"

PYMOD_DIR="${WORKDIR}/hdmapping_py"
PYREL_DIR="${PYMOD_DIR}/Release"

mkdir -p "${INPUT_DIR}" "${ROTATED_DIR}" "${WORKING_DIR}" "${OUTPUT_DIR}" "${PYREL_DIR}"

echo "=== INPUT ZIP   : ${DATA_ZIP}"
echo "=== STEP1 ZIP   : ${STEP1_ZIP}"
echo "=== OUTPUT ZIP  : ${OUTPUT_ZIP}"
echo "=== WORKDIR     : ${WORKDIR}"

########################################
# UNPACK INPUT
########################################
cp "${DATA_ZIP}" "${WORKDIR}/input.zip"
unzip -oq "${WORKDIR}/input.zip" -d "${INPUT_DIR}"

DATA_ROOT="${INPUT_DIR}"

shopt -s nullglob
top=( "${INPUT_DIR}"/* )
if [[ ${#top[@]} -eq 1 && -d "${top[0]}" ]]; then
    DATA_ROOT="${top[0]}"
fi
shopt -u nullglob

echo "=== DATA ROOT: ${DATA_ROOT}"

########################################
# STEP 0: DEROTATION (points + IMU)
########################################
# Rotates every imu*.csv and *.laz/*.las from DATA_ROOT into ROTATED_DIR by the
# same rotation R, copying all other files (calibration .sn/.json/.mjc) through
# unchanged. Step 1 then runs on ROTATED_DIR.
DEROT_SCRIPT="${WORKDIR}/derotate.py"
cat > "${DEROT_SCRIPT}" <<'PY'
import json
import math
import os
import sys
from pathlib import Path

AXIS = os.environ.get("DEROT_AXIS", "Y").upper()
ANGLE = float(os.environ.get("DEROT_ANGLE", "90"))
METHOD = os.environ.get("DEROT_METHOD", "calib").lower()
IN_DIR = Path(os.environ["DATA_ROOT"])
OUT_DIR = Path(os.environ["ROTATED_DIR"])


def rotation_matrix(axis, angle_deg):
    a = math.radians(angle_deg)
    c, s = math.cos(a), math.sin(a)
    if axis == "X":
        return [[1, 0, 0], [0, c, -s], [0, s, c]]
    if axis == "Y":
        return [[c, 0, s], [0, 1, 0], [-s, 0, c]]
    if axis == "Z":
        return [[c, -s, 0], [s, c, 0], [0, 0, 1]]
    raise ValueError("axis must be X, Y or Z")


def matvec(M, v):
    return [M[r][0] * v[0] + M[r][1] * v[1] + M[r][2] * v[2] for r in range(3)]


# --- IMU rotation: pure stdlib, no numpy ----------------------------------
def derotate_imu_csv(src, dst, R):
    lines = Path(src).read_text().splitlines()
    if not lines:
        Path(dst).write_text("")
        return
    header = lines[0].split()
    gi = [header.index(c) for c in ("gyroX", "gyroY", "gyroZ")]
    ai = [header.index(c) for c in ("accX", "accY", "accZ")]
    out = [lines[0]]
    for ln in lines[1:]:
        if not ln.strip():
            continue
        t = ln.split()
        g = matvec(R, [float(t[gi[0]]), float(t[gi[1]]), float(t[gi[2]])])
        a = matvec(R, [float(t[ai[0]]), float(t[ai[1]]), float(t[ai[2]])])
        for k, idx in enumerate(gi):
            t[idx] = repr(g[k])
        for k, idx in enumerate(ai):
            t[idx] = repr(a[k])
        out.append(" ".join(t))
    Path(dst).write_text("\n".join(out) + "\n")


def find_sn_file(d):
    for f in d.iterdir():
        if f.is_file() and f.suffix.lower() == ".sn":
            return f
    return None


def find_existing_calib(d):
    for f in d.iterdir():
        if not f.is_file():
            continue
        ext = f.suffix.lower()
        stem = f.stem.lower()
        if ext == ".mjc":
            return f
        if ext == ".json" and not (stem.startswith("status") or
                                   stem.startswith("cam0") or
                                   stem.startswith("cam1")):
            try:
                if "calibration" in json.load(open(f)):
                    return f
            except Exception:
                pass
    return None


def parse_sn(sn_path):
    pairs = []
    for line in Path(sn_path).read_text().splitlines():
        p = line.split()
        if len(p) >= 2:
            pairs.append((int(p[0]), p[1]))
    return pairs


# --- METHOD: calib (no deps) ----------------------------------------------
def run_calib(R):
    sn = find_sn_file(IN_DIR)
    if sn is None:
        sys.exit("ERROR [calib]: no .sn file in data. Cannot rotate points via "
                 "calibration. Use DEROT_METHOD=laz (install laspy) instead.")
    existing = find_existing_calib(IN_DIR)
    if existing is not None:
        sys.exit(f"ERROR [calib]: existing calibration '{existing.name}' found "
                 "(multi-LiDAR?). Overriding it would break inter-sensor "
                 "calibration. Use DEROT_METHOD=laz (install laspy) instead.")
    pairs = parse_sn(sn)
    if not pairs:
        sys.exit(f"ERROR [calib]: .sn file '{sn.name}' is empty/unparrseable.")

    # rotation as a 4x4 row-major matrix (translation 0)
    data = [R[0][0], R[0][1], R[0][2], 0.0,
            R[1][0], R[1][1], R[1][2], 0.0,
            R[2][0], R[2][1], R[2][2], 0.0,
            0.0, 0.0, 0.0, 1.0]
    sns = sorted({s for _, s in pairs})
    cal = {s: {"order": "ROW", "inverted": "FALSE", "data": data} for s in sns}
    imu_sn = dict(sorted(pairs))[min(i for i, _ in pairs)]  # SN of lowest id
    calib_json = {"calibration": cal, "imuToUse": imu_sn}

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    n_imu = n_copy = 0
    for f in sorted(IN_DIR.iterdir()):
        if not f.is_file():
            continue
        nm = f.name.lower()
        dst = OUT_DIR / f.name
        if nm.startswith("imu") and nm.endswith(".csv"):
            derotate_imu_csv(f, dst, R)
            n_imu += 1
        else:
            dst.write_bytes(f.read_bytes())  # LAZ copied as-is; rotated by pipeline
            n_copy += 1
    (OUT_DIR / "calibration.json").write_text(json.dumps(calib_json, indent=2))
    print(f"=== DEROTATION [calib]: rotated {n_imu} imu csv (stdlib); wrote "
          f"calibration.json rotating points by R for SNs {sns}; imuToUse={imu_sn}; "
          f"copied {n_copy} files")


# --- METHOD: laz (laspy) ---------------------------------------------------
def run_laz(R):
    try:
        import numpy as np
        import laspy
    except Exception as e:
        sys.exit(f"ERROR [laz]: numpy/laspy not importable ({e}). Install once "
                 "on a login node: pip install --user numpy 'laspy[lazrs]'  — or "
                 "use the default DEROT_METHOD=calib (no packages needed).")
    Rn = np.array(R, float)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    n_imu = n_laz = n_copy = 0
    for f in sorted(IN_DIR.iterdir()):
        if not f.is_file():
            continue
        nm = f.name.lower()
        dst = OUT_DIR / f.name
        if nm.startswith("imu") and nm.endswith(".csv"):
            derotate_imu_csv(f, dst, R)
            n_imu += 1
        elif nm.endswith(".laz") or nm.endswith(".las"):
            las = laspy.read(str(f))
            xyz = np.vstack([las.x, las.y, las.z]).T @ Rn.T
            las.x, las.y, las.z = xyz[:, 0], xyz[:, 1], xyz[:, 2]
            las.write(str(dst))
            n_laz += 1
        else:
            dst.write_bytes(f.read_bytes())
            n_copy += 1
    print(f"=== DEROTATION [laz]: {n_imu} imu csv, {n_laz} laz/las, {n_copy} copied")
    if n_laz == 0:
        print("WARNING: no LAZ/LAS point files found to rotate!", file=sys.stderr)


def main():
    R = rotation_matrix(AXIS, ANGLE)
    print(f"=== DEROTATION method={METHOD} R_{AXIS}({ANGLE:g}) = {R}")
    if METHOD == "calib":
        run_calib(R)
    elif METHOD == "laz":
        run_laz(R)
    else:
        sys.exit(f"ERROR: unknown DEROT_METHOD '{METHOD}' (use 'calib' or 'laz')")


if __name__ == "__main__":
    main()
PY

echo "=== RUN DEROTATION (method=${DEROT_METHOD}) ==="
# Run in a subshell so an activated venv does NOT leak into the SLAM steps
# (which must use the module python that the Release .so files were built for).
(
    if [[ "${DEROT_METHOD}" == "laz" ]]; then
        if [[ -n "${DEROT_VENV}" && -f "${DEROT_VENV}/bin/activate" ]]; then
            echo "=== Using derotation venv: ${DEROT_VENV}"
            # shellcheck disable=SC1090
            source "${DEROT_VENV}/bin/activate"
        elif [[ "${DEROT_PIP_INSTALL}" == "1" ]]; then
            echo "=== Attempting in-job pip install of numpy + laspy ..."
            python3 -m pip install --user --quiet numpy "laspy[lazrs]" || \
                echo "WARNING: in-job pip install failed (no internet?)."
        fi
    fi
    python3 "${DEROT_SCRIPT}"
) 2>&1 | tee "${WORKDIR}/derotate.log"
DEROT_EXIT=${PIPESTATUS[0]}
if [[ ${DEROT_EXIT} -ne 0 ]]; then
    echo "ERROR: Derotation failed (see derotate.log above)." >&2
    echo "  For DEROT_METHOD=laz, provide laspy via DEROT_VENV=/path/to/venv" >&2
    echo "  (pre-made on a login node) or DEROT_PIP_INSTALL=1 if nodes have net." >&2
    echo "  Or fall back to DEROT_METHOD=calib (no packages needed)." >&2
    exit ${DEROT_EXIT}
fi

########################################
# COPY PYTHON MODULES
########################################
cp "${SO_SRC_DIR}"/*.so "${PYREL_DIR}/"
touch "${PYREL_DIR}/__init__.py"

export PYTHONPATH="${PYMOD_DIR}:${PYTHONPATH:-}"
export DATA_DIR="${ROTATED_DIR}"
export WORKING_DIR="${WORKING_DIR}"
export OUTPUT_DIR="${OUTPUT_DIR}"

echo "=== IMPORT TEST ==="
python3 - <<'PY'
import Release.core_py as core
import Release.lidar_odometry_py as lo
import Release.multi_view_tls_registration_py as mvr
print("OK imports:", core, lo, mvr)
PY
IMPORT_EXIT=$?
if [[ ${IMPORT_EXIT} -ne 0 ]]; then
    echo "ERROR: Import test failed." >&2
    exit ${IMPORT_EXIT}
fi

########################################
# STEP 1: LIDAR ODOMETRY (on rotated data, robust+accurate)
########################################
STEP1_SCRIPT="${WORKDIR}/run_step1.py"
cat > "${STEP1_SCRIPT}" <<'PY'
import os
from pathlib import Path

import Release.lidar_odometry_py as lo

DATA_DIR = os.environ["DATA_DIR"]
WORKING_DIR = os.environ["WORKING_DIR"]
Path(WORKING_DIR).mkdir(parents=True, exist_ok=True)

params = lo.LidarOdometryParams()

# Forestry preset
params.decimation = 0.005

params.filter_threshold_xy_inner = 1.5
params.filter_threshold_xy_outer = 70.0
params.threshould_output_filter = 1.5

params.in_out_params_indoor.resolution_X = 0.1
params.in_out_params_indoor.resolution_Y = 0.1
params.in_out_params_indoor.resolution_Z = 0.1

params.in_out_params_outdoor.resolution_X = 0.3
params.in_out_params_outdoor.resolution_Y = 0.3
params.in_out_params_outdoor.resolution_Z = 0.3

params.max_distance_lidar = 70.0
params.nr_iter = 500
params.sliding_window_trajectory_length_threshold = 10000
params.threshold_initial_points = 10000
params.threshold_nr_poses = 20
params.use_motion_from_previous_step = True
params.useMultithread = True
params.num_constistency_iter = 10

params.fusionConventionNed = False
params.fusionConventionEnu = False
params.fusionConventionNwu = True

params.distance_bucket = 0.2
params.polar_angle_deg = 10.0
params.azimutal_angle_deg = 10.0

# --- Robust & accurate odometry ENABLED (variant A: reduce drift) ---
params.robust_and_accurate_lidar_odometry_iterations = 20
params.robust_and_accurate_lidar_odometry_rigid_sf_iterations = 30
params.use_robust_and_accurate_lidar_odometry = True
params.max_distance_lidar_rigid_sf = 70.0
params.distance_bucket_rigid_sf = 0.5
params.polar_angle_deg_rigid_sf = 10.0
params.azimutal_angle_deg_rigid_sf = 10.0

params.rgd_sf_sigma_x_m = 0.001
params.rgd_sf_sigma_y_m = 0.001
params.rgd_sf_sigma_z_m = 0.001
params.rgd_sf_sigma_om_deg = 0.01
params.rgd_sf_sigma_fi_deg = 0.01
params.rgd_sf_sigma_ka_deg = 0.01

params.use_mutliple_gaussian = False

print("=== RUNNING LIDAR ODOMETRY (robust_and_accurate=True) ===")
worker_data = lo.run_lidar_odometry(DATA_DIR, params)

print("=== SAVING LIDAR ODOMETRY RESULTS (initial) ===")
result_dir = lo.save_results_automatic(params, worker_data, WORKING_DIR, 0.0)
print("RESULT_DIR =", result_dir)

print("=== RUNNING LIDAR CONSISTENCY ===")
lo.run_consistency(worker_data, params)

print("=== SAVING LIDAR ODOMETRY RESULTS (after consistency) ===")
result_dir = lo.save_results_automatic(params, worker_data, WORKING_DIR, 0.0)
print("RESULT_DIR =", result_dir)
print("STEP1_DONE")
PY

echo "=== RUN STEP 1 ==="
python3 "${STEP1_SCRIPT}" 2>&1 | tee "${WORKDIR}/run_step1.log"
STEP1_EXIT=${PIPESTATUS[0]}
if [[ ${STEP1_EXIT} -ne 0 ]]; then
    echo "ERROR: Step 1 failed." >&2
    zip -qj "${OUTPUT_ZIP}" "${WORKDIR}/run_step1.log" "${WORKDIR}/derotate.log" 2>/dev/null || true
    exit ${STEP1_EXIT}
fi

########################################
# PACKAGE STEP 1 SESSION (openable in multi_view_tls_registration GUI)
########################################
# Locate the produced session directory (contains session.mjs + poses + clouds).
SESSION_MJS="$(find "${WORKING_DIR}" -type f -name "session.mjs" -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)"
if [[ -z "${SESSION_MJS}" || ! -f "${SESSION_MJS}" ]]; then
    echo "ERROR: session.mjs not found after step 1." >&2
    zip -qj "${OUTPUT_ZIP}" "${WORKDIR}/run_step1.log" 2>/dev/null || true
    exit 1
fi
SESSION_DIR="$(dirname "${SESSION_MJS}")"
echo "=== STEP1 SESSION DIR: ${SESSION_DIR}"

# Zip the whole session folder so it can be reopened in the GUI for manual
# loop closure (variant C) if the automatic path is not good enough.
rm -f "${STEP1_ZIP}"
( cd "${SESSION_DIR}" && zip -qr "${STEP1_ZIP}" . )
echo "=== STEP1 ZIP WRITTEN: ${STEP1_ZIP}"
echo "    (open with multi_view_tls_registration / Step 2 GUI if needed)"

########################################
# STEP 2: VARIANT B (seed loop) + MULTI-VIEW TLS REGISTRATION
########################################
export SESSION_MJS="${SESSION_MJS}"
STEP2_SCRIPT="${WORKDIR}/run_step2.py"
cat > "${STEP2_SCRIPT}" <<'PY'
import json
import math
import os
from pathlib import Path

import Release.multi_view_tls_registration_py as mvr

SESSION_PATH = os.environ["SESSION_MJS"]
OUTPUT_DIR = os.environ["OUTPUT_DIR"]
Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)

LC_ENABLE = os.environ.get("LOOP_CLOSURE_ENABLE", "1") == "1"
LC_FORCE = os.environ.get("LOOP_CLOSURE_FORCE", "0") == "1"
ABS_FLOOR = float(os.environ.get("LOOP_CLOSURE_ABS_FLOOR_M", "3.0"))
LEN_FRAC = float(os.environ.get("LOOP_CLOSURE_LEN_FRAC", "0.05"))


# ---- poses file I/O (RESSO-like .mrp written by step 1) -------------------
# Format: N, then per pose: <filename>, 3 matrix rows (3x4), then "0 0 0 1".
def poses_file_path(session_path):
    try:
        j = json.load(open(session_path))
        pf = j.get("poses_file_name") or j.get("out_poses_file_name")
        if pf and os.path.isfile(pf):
            return pf
    except Exception as e:
        print("=== WARN reading session.mjs:", e)
    cand = os.path.join(os.path.dirname(session_path), "session_poses.mrp")
    return cand if os.path.isfile(cand) else None


def read_poses(mrp):
    lines = [ln.rstrip("\n") for ln in open(mrp)]
    nz = [ln for ln in lines if ln.strip() != ""]
    n = int(nz[0].split()[0])
    names, mats = [], []
    idx = 1
    for _ in range(n):
        names.append(nz[idx])
        r0 = [float(x) for x in nz[idx + 1].split()]
        r1 = [float(x) for x in nz[idx + 2].split()]
        r2 = [float(x) for x in nz[idx + 3].split()]
        mats.append([r0, r1, r2])  # 3x4
        idx += 5
    return names, mats


def write_poses(mrp, names, mats):
    with open(mrp, "w") as f:
        f.write(f"{len(mats)}\n")
        for nm, m in zip(names, mats):
            f.write(nm + "\n")
            for r in m:
                f.write(f"{r[0]} {r[1]} {r[2]} {r[3]}\n")
            f.write("0 0 0 1\n")


def traj_length(session_path):
    try:
        j = json.load(open(session_path))
        return float(j.get("length of trajectory[m]", 0.0))
    except Exception:
        return 0.0


def seed_loop(mrp):
    """Variant B: bring trajectory tail back onto the start so the built-in
    overlap-based loop closure can lock on even after large step-1 drift.
    Distributes the start->end translational offset linearly over the nodes
    (node 0 fixed, last node moved onto node 0). Only the *initial guess* is
    changed; pose-graph SLAM recomputes the real edge by ICP/NDT registration,
    so no artificial correction is baked into the measurements."""
    names, mats = read_poses(mrp)
    n = len(mats)
    if n < 2:
        print("=== LOOP CLOSURE: <2 nodes, skipping seed")
        return None
    t0 = [mats[0][r][3] for r in range(3)]
    tN = [mats[-1][r][3] for r in range(3)]
    d = math.sqrt(sum((tN[r] - t0[r]) ** 2 for r in range(3)))

    L = traj_length(SESSION_PATH)
    ceil_m = max(ABS_FLOOR, LEN_FRAC * L) if L > 0 else ABS_FLOOR
    print(f"=== LOOP CLOSURE: start-end={d:.3f} m, trajectory={L:.1f} m, "
          f"ceiling={ceil_m:.2f} m, force={LC_FORCE}")

    if not LC_FORCE and d > ceil_m:
        print("=== LOOP CLOSURE: start-end beyond ceiling -> NOT seeding "
              "(likely an open trajectory). Set LOOP_CLOSURE_FORCE=1 to override.")
        return False

    # backup pristine poses, then seed
    import shutil
    shutil.copyfile(mrp, mrp + ".orig")
    corr = [t0[r] - tN[r] for r in range(3)]  # move last onto first
    for i in range(n):
        f = i / (n - 1)
        for r in range(3):
            mats[i][r][3] += f * corr[r]
    write_poses(mrp, names, mats)
    print(f"=== LOOP CLOSURE: seeded tail onto start (correction "
          f"{corr[0]:.2f},{corr[1]:.2f},{corr[2]:.2f} m). Backup: {mrp}.orig")
    return True


mvr_params = mvr.TLSRegistration()
mvr_params.save_laz = True
mvr_params.save_trajectories_csv = True

for attr in ("decimation", "output_decimation", "voxel_size"):
    if hasattr(mvr_params, attr):
        setattr(mvr_params, attr, 0.0)

seeded = False
if LC_ENABLE:
    mrp = poses_file_path(SESSION_PATH)
    if mrp is None:
        print("=== LOOP CLOSURE: poses file not found -> running without loop closure")
    else:
        res = seed_loop(mrp)
        seeded = bool(res)
        # Enable pose-graph SLAM whenever we seeded (or were forced). The
        # overlap threshold inside pgslam is the real guard against a false
        # closure, so enabling is safe.
        if seeded or LC_FORCE:
            mvr_params.use_pgslam = True
            print("=== LOOP CLOSURE: use_pgslam = True")
        else:
            mvr_params.use_pgslam = False
            print("=== LOOP CLOSURE: use_pgslam = False")
else:
    print("=== LOOP CLOSURE: disabled by LOOP_CLOSURE_ENABLE=0")

print("=== MVR: running multi_view_tls_registration ...")
mvr.run_multi_view_tls_registration(SESSION_PATH, mvr_params, OUTPUT_DIR)
print("=== MVR: finished. OUTPUT_DIR:", OUTPUT_DIR)
print("STEP2_DONE")
PY

echo "=== RUN STEP 2 (loop closure + MVR) ==="
python3 "${STEP2_SCRIPT}" 2>&1 | tee "${WORKDIR}/run_step2.log"
STEP2_EXIT=${PIPESTATUS[0]}
if [[ ${STEP2_EXIT} -ne 0 ]]; then
    echo "ERROR: Step 2 failed. Step 1 session is still available: ${STEP1_ZIP}" >&2
    zip -qj "${OUTPUT_ZIP}" "${WORKDIR}/run_step2.log" "${WORKDIR}/run_step1.log" 2>/dev/null || true
    echo "OUTPUT ZIP (diagnostics only): ${OUTPUT_ZIP}"
    exit ${STEP2_EXIT}
fi

########################################
# PACKAGE FINAL RESULTS (1x LAZ + 1x trajectory CSV)
########################################
mapfile -t POINT_CLOUDS < <(find "${OUTPUT_DIR}" -type f -iname "*.laz" | sort)
mapfile -t TRAJECTORY_CANDIDATES < <(find "${OUTPUT_DIR}" -type f -iname "*traj*.csv" | sort)
if [[ ${#TRAJECTORY_CANDIDATES[@]} -eq 0 ]]; then
    mapfile -t TRAJECTORY_CANDIDATES < <(find "${OUTPUT_DIR}" -type f -iname "*.csv" | sort)
fi

echo "=== Nalezená LAZ mračna       : ${#POINT_CLOUDS[@]} souborů"
echo "=== Nalezené CSV trajektorie  : ${#TRAJECTORY_CANDIDATES[@]} souborů"

if [[ ${#POINT_CLOUDS[@]} -lt 1 || ${#TRAJECTORY_CANDIDATES[@]} -lt 1 ]]; then
    echo "ERROR: Vystupni .laz mracno nebo .csv trajektorie nebyly nalezeny." >&2
    zip -qj "${OUTPUT_ZIP}" "${WORKDIR}/run_step2.log"
    echo "OUTPUT ZIP: ${OUTPUT_ZIP}"
    exit 1
fi

POINT_CLOUD="${POINT_CLOUDS[0]}"
TRAJECTORY="${TRAJECTORY_CANDIDATES[0]}"

PACKAGE_DIR="${WORKDIR}/package"
rm -rf "${PACKAGE_DIR}"
mkdir -p "${PACKAGE_DIR}"

cp "${POINT_CLOUD}" "${PACKAGE_DIR}/${DATA_BASENAME}.laz"
cp "${TRAJECTORY}" "${PACKAGE_DIR}/${DATA_BASENAME}_trajectory.csv"

rm -f "${OUTPUT_ZIP}"
zip -qj "${OUTPUT_ZIP}" "${PACKAGE_DIR}/${DATA_BASENAME}.laz" "${PACKAGE_DIR}/${DATA_BASENAME}_trajectory.csv"

echo
echo "====================================="
echo "DONE"
echo "STEP1 ZIP (GUI session): ${STEP1_ZIP}"
echo "OUTPUT ZIP (cloud+traj): ${OUTPUT_ZIP}"
echo "====================================="
exit 0
