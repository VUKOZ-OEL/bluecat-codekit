#!/usr/bin/env bash
set -euo pipefail

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
OUTPUT_ZIP="${DATA_DIRNAME}/${DATA_BASENAME}_hdmap.zip"

########################################
# USER SETTINGS
########################################
SO_SRC_DIR="/storage/plzen1/home/krucek/HDMapping/build/bin/Release"

########################################
# ENV (avoid interactive pagers in jobs)
########################################
export PAGER=cat
export LESS=FRX
export TERM=dumb

########################################
# MODULES (make sure 'module' exists)
########################################
if ! command -v module >/dev/null 2>&1; then
  if [[ -r /etc/profile.d/modules.sh ]]; then
    # shellcheck disable=SC1091
    source /etc/profile.d/modules.sh
  elif [[ -r /usr/share/Modules/init/bash ]]; then
    # shellcheck disable=SC1091
    source /usr/share/Modules/init/bash
  fi
fi

if ! command -v module >/dev/null 2>&1; then
  echo "ERROR: 'module' command not found. Run inside a login shell (bash -l) or initialize modules." >&2
  exit 1
fi

module purge
module add python/3.9.12-gcc-10.2.1-rg2lpmk
module add opencv/4.5.4-gcc-10.2.1-663hk5g

########################################
# SCRATCH WORKDIR
########################################
: "${SCRATCHDIR:?SCRATCHDIR is not set (must run as MetaCentrum job)}"

RUN_NAME="${DATA_BASENAME}_hdmapping"
WORKDIR="${SCRATCHDIR}/${RUN_NAME}"

INPUT_DIR="${WORKDIR}/input"
WORKING_DIR="${WORKDIR}/work"
OUTPUT_DIR="${WORKDIR}/output"
PYMOD_DIR="${WORKDIR}/hdmapping_py"
PYREL_DIR="${PYMOD_DIR}/Release"

mkdir -p "${INPUT_DIR}" "${WORKING_DIR}" "${OUTPUT_DIR}" "${PYREL_DIR}"

echo "=== INPUT ZIP   : ${DATA_ZIP}"
echo "=== OUTPUT ZIP  : ${OUTPUT_ZIP}"
echo "=== WORKDIR     : ${WORKDIR}"

########################################
# STAGE INPUT DATA
########################################
echo "=== Copying and unpacking input data..."
cp "${DATA_ZIP}" "${WORKDIR}/input.zip"
unzip -oq "${WORKDIR}/input.zip" -d "${INPUT_DIR}"

# Detect actual data root (many zips contain one top-level folder)
DATA_ROOT="${INPUT_DIR}"
shopt -s nullglob
top=( "${INPUT_DIR}"/* )
if [[ ${#top[@]} -eq 1 && -d "${top[0]}" ]]; then
  DATA_ROOT="${top[0]}"
fi
shopt -u nullglob

echo "=== DATA_ROOT   : ${DATA_ROOT}"

########################################
# STAGE PYBIND MODULES
########################################
for f in core_py.so lidar_odometry_py.so multi_view_tls_registration_py.so; do
  if [[ ! -f "${SO_SRC_DIR}/${f}" ]]; then
    echo "ERROR: Missing ${f} in ${SO_SRC_DIR}" >&2
    echo "Available files:" >&2
    ls -la "${SO_SRC_DIR}" >&2 || true
    exit 1
  fi
done

cp -v "${SO_SRC_DIR}/"*.so "${PYREL_DIR}/"
touch "${PYREL_DIR}/__init__.py"

########################################
# GENERATE PYTHON SCRIPT
########################################
PY_SCRIPT="${WORKDIR}/run_pipeline.py"

cat > "${PY_SCRIPT}" <<'PY'
import os
from pathlib import Path

import Release.lidar_odometry_py as lo
import Release.core_py as core
import Release.multi_view_tls_registration_py as mvr

DATA_DIR = os.environ["DATA_DIR"]
WORKING_DIR = os.environ["WORKING_DIR"]
OUTPUT_DIR = os.environ["OUTPUT_DIR"]

Path(WORKING_DIR).mkdir(parents=True, exist_ok=True)
Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)

def newest_session_mjs(workdir: str) -> str:
    p = Path(workdir)
    candidates = list(p.glob("lidar_odometry_result_*/session.mjs"))
    if not candidates:
        candidates = list(p.rglob("session.mjs"))
    if not candidates:
        raise FileNotFoundError(f"No session.mjs found under {workdir}")
    candidates.sort(key=lambda x: x.stat().st_mtime, reverse=True)
    return str(candidates[0])

# ---------------------------
# 1) Lidar odometry + consistency
# ---------------------------
dummy_session = core.Session()

lo_params = lo.LidarOdometryParams()

lo_params.decimation = 0.01

lo_params.in_out_params_indoor.resolution_X = 0.1
lo_params.in_out_params_indoor.resolution_Y = 0.1
lo_params.in_out_params_indoor.resolution_Z = 0.1

lo_params.in_out_params_outdoor.resolution_X = 0.3
lo_params.in_out_params_outdoor.resolution_Y = 0.3
lo_params.in_out_params_outdoor.resolution_Z = 0.3

lo_params.filter_threshold_xy_inner = 0.3
lo_params.filter_threshold_xy_outer = 70.0

lo_params.nr_iter = 100
lo_params.sliding_window_trajectory_length_threshold = 200

lo_params.distance_bucket = 0.2
lo_params.polar_angle_deg = 10.0
lo_params.azimutal_angle_deg = 10.0

lo_params.robust_and_accurate_lidar_odometry_iterations = 20
lo_params.max_distance_lidar = 30.0
lo_params.use_robust_and_accurate_lidar_odometry = False

lo_params.fusionConventionNed = True
lo_params.fusionConventionNwu = False
lo_params.fusionConventionEnu = False

lo_params.threshold_nr_poses = 20
lo_params.num_constistency_iter = 10
lo_params.threshould_output_filter = 0.3

print("=== LO: Loading data..")
worker_data = lo.run_lidar_odometry(DATA_DIR, lo_params)

print("=== LO: Saving automatic results (step 1)..")
lo.save_results_automatic(lo_params, worker_data, WORKING_DIR, 0.0)

print("=== LO: Running consistency..")
lo.run_consistency(worker_data, lo_params)

print("=== LO: Saving automatic results (step 2)..")
lo.save_results_automatic(lo_params, worker_data, WORKING_DIR, 0.0)

# ---------------------------
# 2) Multi-view TLS registration on produced session
# ---------------------------
SESSION_PATH = os.path.join(WORKING_DIR, "lidar_odometry_result_1", "session.mjs")
if not os.path.isfile(SESSION_PATH):
    SESSION_PATH = newest_session_mjs(WORKING_DIR)

print("=== MVR: Using SESSION_PATH:", SESSION_PATH)

mvr_params = mvr.TLSRegistration()

mvr_params.save_laz = True
mvr_params.save_trajectories_csv = True

# optional: try to set GNSS dir if such attribute exists in this build
gnss_guess = os.path.join(DATA_DIR, "gnss")
for cand in ("gnss_dir", "gnss_path", "input_gnss_dir", "gnss_folder"):
    if hasattr(mvr_params, cand):
        setattr(mvr_params, cand, gnss_guess)
        print(f"=== MVR: set {cand} =", gnss_guess)

print("=== MVR: Running multi_view_tls_registration..")
# IMPORTANT: your build signature is (input_file_name, tls_registration, output_dir) -> None
mvr.run_multi_view_tls_registration(SESSION_PATH, mvr_params, OUTPUT_DIR)
print("=== MVR: Finished. Check OUTPUT_DIR:", OUTPUT_DIR)


print("DONE")
PY

########################################
# RUN
########################################
export PYTHONPATH="${PYMOD_DIR}:${PYTHONPATH:-}"
export DATA_DIR="${DATA_ROOT}"
export WORKING_DIR="${WORKING_DIR}"
export OUTPUT_DIR="${OUTPUT_DIR}"

echo "=== Python version:"
python3 -c "import sys; print(sys.version)"

echo "=== Import tests:"
python3 -c "import Release.lidar_odometry_py as lo; import Release.core_py as core; import Release.multi_view_tls_registration_py as mvr; print('OK imports')"

echo "=== Running pipeline..."
python3 "${PY_SCRIPT}" 2>&1 | tee "${WORKDIR}/run.log"

########################################
# PACKAGE OUTPUT
########################################
echo "=== Packaging results..."
TMP_ZIP_DIR="${WORKDIR}/tozip"
mkdir -p "${TMP_ZIP_DIR}"

cp -a "${WORKING_DIR}" "${TMP_ZIP_DIR}/work"
cp -a "${OUTPUT_DIR}" "${TMP_ZIP_DIR}/output"
cp -a "${WORKDIR}/run.log" "${TMP_ZIP_DIR}/run.log"

(
  cd "${TMP_ZIP_DIR}"
  zip -qr "${OUTPUT_ZIP}" .
)

echo "=== DONE"
echo "Result ZIP: ${OUTPUT_ZIP}"


