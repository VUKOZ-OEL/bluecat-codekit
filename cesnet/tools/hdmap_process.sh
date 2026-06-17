#!/bin/bash
set -u
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

########################################
# SCRATCH
########################################
: "${SCRATCHDIR:?SCRATCHDIR is not set}"

RUN_NAME="${DATA_BASENAME}_hdmapping"
WORKDIR="${SCRATCHDIR}/${RUN_NAME}"

INPUT_DIR="${WORKDIR}/input"
WORKING_DIR="${WORKDIR}/work"
OUTPUT_DIR="${WORKDIR}/output"

PYMOD_DIR="${WORKDIR}/hdmapping_py"
PYREL_DIR="${PYMOD_DIR}/Release"

mkdir -p "${INPUT_DIR}" "${WORKING_DIR}" "${OUTPUT_DIR}" "${PYREL_DIR}"

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
touch "${PYREL_DIR}/__init__.py"

########################################
# PYTHON PIPELINE
########################################
PY_SCRIPT="${WORKDIR}/run_pipeline.py"

cat > "${PY_SCRIPT}" <<'PY'
import glob
import os
from pathlib import Path

import Release.core_py as core
import Release.lidar_odometry_py as lo
import Release.multi_view_tls_registration_py as mvr

DATA_DIR = os.environ["DATA_DIR"]
WORKING_DIR = os.environ["WORKING_DIR"]
OUTPUT_DIR = os.environ["OUTPUT_DIR"]

Path(WORKING_DIR).mkdir(parents=True, exist_ok=True)
Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)


def newest_session_mjs(base_dir):
    candidates = glob.glob(os.path.join(base_dir, "**", "session.mjs"), recursive=True)
    if not candidates:
        raise FileNotFoundError(f"No session.mjs found under: {base_dir}")
    return max(candidates, key=os.path.getmtime)


# ---------------------------
# 1) Lidar odometry
# ---------------------------
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

params.robust_and_accurate_lidar_odometry_iterations = 20
params.robust_and_accurate_lidar_odometry_rigid_sf_iterations = 30
params.use_robust_and_accurate_lidar_odometry = False
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

print("=== RUNNING LIDAR ODOMETRY ===")
worker_data = lo.run_lidar_odometry(DATA_DIR, params)

print("=== SAVING LIDAR ODOMETRY RESULTS (STEP 1) ===")
result_dir = lo.save_results_automatic(params, worker_data, WORKING_DIR, 0.0)
print("RESULT_DIR =", result_dir)

print("=== RUNNING LIDAR CONSISTENCY ===")
lo.run_consistency(worker_data, params)

print("=== SAVING LIDAR ODOMETRY RESULTS (STEP 2, AFTER CONSISTENCY) ===")
result_dir = lo.save_results_automatic(params, worker_data, WORKING_DIR, 0.0)
print("RESULT_DIR =", result_dir)

# ---------------------------
# 2) Multi-view TLS registration on produced session
# ---------------------------
SESSION_PATH = os.path.join(WORKING_DIR, "lidar_odometry_result_1", "session.mjs")
if not os.path.isfile(SESSION_PATH):
    SESSION_PATH = newest_session_mjs(WORKING_DIR)
print("=== MVR: Using SESSION_PATH:", SESSION_PATH)

mvr_params = mvr.TLSRegistration()

# Output: one full-resolution LAZ point cloud + trajectory CSV.
mvr_params.save_laz = True
mvr_params.save_trajectories_csv = True

# Disable output decimation when this build exposes such a parameter.
for attr in ("decimation", "output_decimation", "voxel_size"):
    if hasattr(mvr_params, attr):
        setattr(mvr_params, attr, 0.0)
        print(f"=== MVR: {attr} set to 0.0 (no decimation)")

# Optional GNSS directory if this build exposes such a parameter.
gnss_guess = os.path.join(DATA_DIR, "gnss")
for cand in ("gnss_dir", "gnss_path", "input_gnss_dir", "gnss_folder"):
    if hasattr(mvr_params, cand):
        setattr(mvr_params, cand, gnss_guess)
        print(f"=== MVR: set {cand} =", gnss_guess)

print("=== MVR: Running multi_view_tls_registration...")
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
    zip -qj "${OUTPUT_ZIP}" "${WORKDIR}/run_pipeline.py" 2>/dev/null || true
    exit ${IMPORT_EXIT}
fi

echo "=== RUN PIPELINE ==="
python3 "${PY_SCRIPT}" 2>&1 | tee "${WORKDIR}/run.log"
PIPELINE_EXIT=${PIPESTATUS[0]}

if [[ ${PIPELINE_EXIT} -ne 0 ]]; then
    echo "ERROR: Pipeline failed. Packaging run.log only for diagnostics." >&2
    zip -qj "${OUTPUT_ZIP}" "${WORKDIR}/run.log"
    echo "OUTPUT ZIP: ${OUTPUT_ZIP}"
    exit ${PIPELINE_EXIT}
fi

########################################
# PACKAGE RESULTS
########################################
# Required output: exactly one .laz point cloud and one trajectory .csv.
mapfile -t POINT_CLOUDS < <(find "${OUTPUT_DIR}" -type f -iname "*.laz" | sort)
mapfile -t TRAJECTORY_CANDIDATES < <(find "${OUTPUT_DIR}" -type f -iname "*traj*.csv" | sort)

if [[ ${#TRAJECTORY_CANDIDATES[@]} -eq 0 ]]; then
    mapfile -t TRAJECTORY_CANDIDATES < <(find "${OUTPUT_DIR}" -type f -iname "*.csv" | sort)
fi

echo "=== Nalezená LAZ mračna       : ${#POINT_CLOUDS[@]} souborů"
echo "=== Nalezené CSV trajektorie  : ${#TRAJECTORY_CANDIDATES[@]} souborů"

if [[ ${#POINT_CLOUDS[@]} -lt 1 || ${#TRAJECTORY_CANDIDATES[@]} -lt 1 ]]; then
    echo "ERROR: Výstupní .laz mračno nebo .csv trajektorie nebyly nalezeny." >&2
    echo "       Zabaluji pouze run.log pro diagnostiku." >&2
    zip -qj "${OUTPUT_ZIP}" "${WORKDIR}/run.log"
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
echo "DONE - vystup obsahuje 1x LAZ + 1x CSV trajektorii"
echo "OUTPUT ZIP: ${OUTPUT_ZIP}"
echo "====================================="
exit 0
