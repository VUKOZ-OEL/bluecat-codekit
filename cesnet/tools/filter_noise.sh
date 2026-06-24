#!/bin/bash
# PBS/CESNET noise filtering for MLS/ULS LAS/LAZ point clouds using PDAL in Singularity.
# Input: .las/.laz OR .zip containing exactly one .las/.laz plus optional sidecar files.
# Output: if input is ZIP -> <prefix>_denoised.zip; otherwise -> <prefix>_denoised.<las|laz>
#
# Usage:
#   qsub -l select=1:ncpus=12:mem=32gb:scratch_local=32gb -l walltime=02:00:00 -- \
#     /storage/plzen1/home/krucek/scripts/noise_filter_hdmapslam.sh input.zip
#
# Optional env vars:
#   PDAL_IMG=/storage/plzen1/home/krucek/singularity_img/pdal.img
#   MODE=statistical|radius|both       default: statistical
#   KEEP_NOISE=0|1                     default: 0; 0 removes class 7, 1 only classifies noise
#   MEAN_K=16                          statistical neighbors
#   MULTIPLIER=2.5                     statistical stddev multiplier
#   RADIUS=0.20                        radius mode search radius, in cloud units
#   MIN_K=4                            radius mode minimum neighbors
#   RUN_ELM=0|1                        default: 0; ELM mostly catches low outliers, often ALS-like
#   ELM_CELL=1.0
#   ELM_THRESHOLD=1.0
#   OUT_SUFFIX=_denoised
#   OUTPUT=/path/to/custom_output.zip|las|laz

set -euo pipefail

usage() {
  echo "Usage: $0 input.zip|input.las|input.laz" >&2
  exit 2
}

[ "$#" -eq 1 ] || usage

INPUT=$(readlink -f "$1")
[ -f "$INPUT" ] || { echo "ERROR: input not found: $INPUT" >&2; exit 1; }

PDAL_IMG=${PDAL_IMG:-/storage/plzen1/home/krucek/singularity_img/pdal.img}
MODE=${MODE:-statistical}
KEEP_NOISE=${KEEP_NOISE:-0}
MEAN_K=${MEAN_K:-16}
MULTIPLIER=${MULTIPLIER:-2.5}
RADIUS=${RADIUS:-0.20}
MIN_K=${MIN_K:-4}
RUN_ELM=${RUN_ELM:-0}
ELM_CELL=${ELM_CELL:-1.0}
ELM_THRESHOLD=${ELM_THRESHOLD:-1.0}
OUT_SUFFIX=${OUT_SUFFIX:-_denoised}

case "$MODE" in
  statistical|radius|both) ;;
  *) echo "ERROR: MODE must be statistical, radius or both" >&2; exit 1 ;;
esac
case "$KEEP_NOISE" in 0|1) ;; *) echo "ERROR: KEEP_NOISE must be 0 or 1" >&2; exit 1 ;; esac
case "$RUN_ELM" in 0|1) ;; *) echo "ERROR: RUN_ELM must be 0 or 1" >&2; exit 1 ;; esac

# Load Singularity module if available; ignore failure when already available.
module add singul/ >/dev/null 2>&1 || true
command -v singularity >/dev/null 2>&1 || { echo "ERROR: singularity command not found" >&2; exit 1; }
[ -f "$PDAL_IMG" ] || { echo "ERROR: PDAL image not found: $PDAL_IMG" >&2; exit 1; }

IN_DIR=$(dirname "$INPUT")
IN_BASE=$(basename "$INPUT")
IN_NAME=${IN_BASE%.*}
IN_EXT=${IN_BASE##*.}
IN_EXT_LC=$(echo "$IN_EXT" | tr '[:upper:]' '[:lower:]')

# Derive project prefix: for rawslam names trim common suffixes, otherwise use basename.
PREFIX="$IN_NAME"
PREFIX=${PREFIX%_hdmapping_rawslam}
PREFIX=${PREFIX%_rawslam}
PREFIX=${PREFIX%_leveled}

if [ "$IN_EXT_LC" = "zip" ]; then
  IS_ZIP=1
  DEFAULT_OUTPUT="$IN_DIR/${PREFIX}${OUT_SUFFIX}.zip"
elif [ "$IN_EXT_LC" = "las" ] || [ "$IN_EXT_LC" = "laz" ]; then
  IS_ZIP=0
  DEFAULT_OUTPUT="$IN_DIR/${PREFIX}${OUT_SUFFIX}.${IN_EXT_LC}"
else
  echo "ERROR: input must be .zip, .las or .laz" >&2
  exit 1
fi
OUTPUT=${OUTPUT:-$DEFAULT_OUTPUT}
LOG_FILE="${OUTPUT}.log"

SCRATCH_BASE=${SCRATCHDIR:-${TMPDIR:-/tmp}}
WORKDIR="$SCRATCH_BASE/noise_filter_${PBS_JOBID:-$$}"
mkdir -p "$WORKDIR"

cleanup() {
  rm -rf "$WORKDIR" || true
}
trap cleanup EXIT

log() { echo "$(date '+%F %T') - $*" | tee -a "$LOG_FILE" >&2; }

log "start"
log "input: $INPUT"
log "output: $OUTPUT"
log "scratch: $WORKDIR"
log "mode: $MODE, keep_noise: $KEEP_NOISE, run_elm: $RUN_ELM"

cp "$PDAL_IMG" "$WORKDIR/pdal.img"
cd "$WORKDIR"

if [ "$IS_ZIP" -eq 1 ]; then
  cp "$INPUT" input.zip
  unzip -q input.zip -d unpacked
  mapfile -t LAS_FILES < <(find unpacked -type f \( -iname '*.las' -o -iname '*.laz' \) | sort)
  if [ "${#LAS_FILES[@]}" -ne 1 ]; then
    echo "ERROR: ZIP must contain exactly one LAS/LAZ file, found ${#LAS_FILES[@]}" >&2
    printf '%s\n' "${LAS_FILES[@]}" >&2
    exit 1
  fi
  SRC_LAS="${LAS_FILES[0]}"
  SRC_EXT=$(basename "$SRC_LAS" | awk -F. '{print tolower($NF)}')
else
  cp "$INPUT" "input.${IN_EXT_LC}"
  SRC_LAS="input.${IN_EXT_LC}"
  SRC_EXT="$IN_EXT_LC"
fi

OUT_POINTCLOUD="${PREFIX}${OUT_SUFFIX}.${SRC_EXT}"

# Build PDAL pipeline. filters.outlier marks noise as LAS Classification 7.
# The downstream expression stage removes class 7 unless KEEP_NOISE=1.
python3 - <<PY
import json

src = ${SRC_LAS@Q}
out = ${OUT_POINTCLOUD@Q}
mode = ${MODE@Q}
keep_noise = int(${KEEP_NOISE@Q})
run_elm = int(${RUN_ELM@Q})
mean_k = int(float(${MEAN_K@Q}))
multiplier = float(${MULTIPLIER@Q})
radius = float(${RADIUS@Q})
min_k = int(float(${MIN_K@Q}))
elm_cell = float(${ELM_CELL@Q})
elm_threshold = float(${ELM_THRESHOLD@Q})

pipeline = [{"type": "readers.las", "filename": "/data/" + src}]

if run_elm:
    pipeline.append({
        "type": "filters.elm",
        "cell": elm_cell,
        "threshold": elm_threshold
    })

if mode in ("statistical", "both"):
    pipeline.append({
        "type": "filters.outlier",
        "method": "statistical",
        "mean_k": mean_k,
        "multiplier": multiplier,
        "class": 7
    })

if mode in ("radius", "both"):
    pipeline.append({
        "type": "filters.outlier",
        "method": "radius",
        "radius": radius,
        "min_k": min_k,
        "class": 7
    })

if not keep_noise:
    pipeline.append({
        "type": "filters.expression",
        "expression": "Classification != 7"
    })

writer = {
    "type": "writers.las",
    "filename": "/data/" + out,
    "forward": "all"
}
if out.lower().endswith(".las"):
    writer["compression"] = "false"
else:
    writer["compression"] = "laszip"

pipeline.append(writer)

with open("pdal_noise_pipeline.json", "w", encoding="utf-8") as f:
    json.dump({"pipeline": pipeline}, f, indent=2)

metadata = {
    "input": src,
    "output": out,
    "mode": mode,
    "keep_noise": bool(keep_noise),
    "run_elm": bool(run_elm),
    "statistical": {"mean_k": mean_k, "multiplier": multiplier},
    "radius": {"radius": radius, "min_k": min_k},
    "elm": {"cell": elm_cell, "threshold": elm_threshold},
    "noise_classification": 7
}
with open("${PREFIX}${OUT_SUFFIX}_noise_filter.json", "w", encoding="utf-8") as f:
    json.dump(metadata, f, indent=2)
PY

log "PDAL pipeline:"
cat pdal_noise_pipeline.json >> "$LOG_FILE"

singularity exec -B "$WORKDIR/:/data" ./pdal.img pdal pipeline /data/pdal_noise_pipeline.json >> "$LOG_FILE" 2>&1

if [ "$IS_ZIP" -eq 1 ]; then
  # Preserve non-LAS sidecars from the ZIP, but replace point cloud with denoised output.
  mkdir -p outzip
  find unpacked -type f ! \( -iname '*.las' -o -iname '*.laz' \) -exec cp -t outzip {} + 2>/dev/null || true
  cp "$OUT_POINTCLOUD" "outzip/$OUT_POINTCLOUD"
  cp "${PREFIX}${OUT_SUFFIX}_noise_filter.json" "outzip/${PREFIX}${OUT_SUFFIX}_noise_filter.json"
  (cd outzip && zip -q -r output.zip .)
  cp outzip/output.zip "$OUTPUT"
else
  cp "$OUT_POINTCLOUD" "$OUTPUT"
  cp "${PREFIX}${OUT_SUFFIX}_noise_filter.json" "${OUTPUT}.json"
fi

log "done"
