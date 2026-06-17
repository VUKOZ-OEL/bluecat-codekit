#!/bin/bash
set -euo pipefail
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

########################################

# USER SETTINGS

########################################
SO_SRC_DIR="/storage/plzen1/home/krucek/HDMapping/build/bin/Release"

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
module add opencv/4.5.4-gcc-10.2.1-663hk5g

########################################

# SCRATCH

########################################
: "${SCRATCHDIR:?SCRATCHDIR is not set}"

RUN_NAME="${DATA_BASENAME}_hdmapping"

WORKDIR="${SCRATCHDIR}/${RUN_NAME}"

INPUT_DIR="${WORKDIR}/input"
WORKING_DIR="${WORKDIR}/work"

PYMOD_DIR="${WORKDIR}/hdmapping_py"
PYREL_DIR="${PYMOD_DIR}/Release"

mkdir -p "${INPUT_DIR}"
mkdir -p "${WORKING_DIR}"
mkdir -p "${PYREL_DIR}"

echo "=== INPUT ZIP  : ${DATA_ZIP}"
echo "=== OUTPUT ZIP : ${OUTPUT_ZIP}"
echo "=== WORKDIR    : ${WORKDIR}"

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

# COPY PYTHON MODULES

########################################


cp "${SO_SRC_DIR}"/*.so "${PYREL_DIR}/"

touch "${PYREL_DIR}/**init**.py"

########################################

# PYTHON PIPELINE

########################################
PY_SCRIPT="${WORKDIR}/run_pipeline.py"

cat > "${PY_SCRIPT}" <<'PY'
import os
from pathlib import Path

import Release.lidar_odometry_py as lo

DATA_DIR = os.environ["DATA_DIR"]
WORKING_DIR = os.environ["WORKING_DIR"]

Path(WORKING_DIR).mkdir(parents=True, exist_ok=True)

params = lo.LidarOdometryParams()

# Forestry preset

params.decimation = 0.01

params.in_out_params_indoor.resolution_X = 0.1
params.in_out_params_indoor.resolution_Y = 0.1
params.in_out_params_indoor.resolution_Z = 0.1

params.in_out_params_outdoor.resolution_X = 0.3
params.in_out_params_outdoor.resolution_Y = 0.3
params.in_out_params_outdoor.resolution_Z = 0.3

params.filter_threshold_xy_inner = 0.3
params.filter_threshold_xy_outer = 70.0

params.nr_iter = 100

params.sliding_window_trajectory_length_threshold = 200

params.distance_bucket = 0.2
params.polar_angle_deg = 10.0
params.azimutal_angle_deg = 10.0

params.robust_and_accurate_lidar_odometry_iterations = 20
params.use_robust_and_accurate_lidar_odometry = False

params.max_distance_lidar = 70.0

params.fusionConventionNed = True
params.fusionConventionNwu = False
params.fusionConventionEnu = False

params.threshold_nr_poses = 20
params.num_constistency_iter = 10
params.threshould_output_filter = 0.3

print("=== RUNNING LIDAR ODOMETRY ===")

worker_data = lo.run_lidar_odometry(
DATA_DIR,
params
)

print("=== SAVING RESULTS ===")

result_dir = lo.save_results_automatic(
params,
worker_data,
WORKING_DIR,
0.0
)

print("RESULT_DIR =", result_dir)
print("DONE")
PY

########################################

# RUN

########################################
export PYTHONPATH="${PYMOD_DIR}:${PYTHONPATH:-}"

export DATA_DIR="${DATA_ROOT}"
export WORKING_DIR="${WORKING_DIR}"

echo "=== IMPORT TEST ==="

python3 - <<'PY'
import Release.lidar_odometry_py as lo
print("OK imports")
PY

echo "=== RUN PIPELINE ==="

python3 "${PY_SCRIPT}" 2>&1 | tee "${WORKDIR}/run.log"

########################################

# PACKAGE RESULTS

########################################
TMP_ZIP_DIR="${WORKDIR}/tozip"

mkdir -p "${TMP_ZIP_DIR}"

cp -a "${WORKING_DIR}" "${TMP_ZIP_DIR}/work"
cp -a "${WORKDIR}/run.log" "${TMP_ZIP_DIR}/run.log"

(
cd "${TMP_ZIP_DIR}"
zip -qr "${OUTPUT_ZIP}" .
)

echo
echo "====================================="
echo "DONE"
echo "OUTPUT ZIP:"
echo "${OUTPUT_ZIP}"
echo "====================================="
