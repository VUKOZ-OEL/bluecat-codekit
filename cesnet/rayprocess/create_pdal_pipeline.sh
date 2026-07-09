#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

INPUT_FILE="${1:-${SOURCE_DATA:-cloud.laz}}"
OUTPUT_FILE="cloud.laz"
VOXELIZE="${VOXELIZE:-false}"
VOXEL_RES="${VOXEL_RES:-0.05}"
ADD_TIME="${ADD_TIME:-false}"

pipeline='{"pipeline":[{"type":"readers.las","filename":"'"$INPUT_FILE"'"}'

if [[ "$VOXELIZE" == "true" ]]; then
  pipeline+=',{"type":"filters.voxeldownsize","cell":'"$VOXEL_RES"',"mode":"center"}'
fi
if [[ "$ADD_TIME" == "true" ]]; then
  pipeline+=',{"type":"filters.ferry","dimensions":"X=>GpsTime"}'
fi
pipeline+=',{"type":"writers.las","dataformat_id":1,"minor_version":2,"filename":"'"$OUTPUT_FILE"'"}]}'

echo "$pipeline" > pdal_pipeline.json
cesnet::log INFO "PDAL pipeline created"
