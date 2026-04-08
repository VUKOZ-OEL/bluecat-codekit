#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <input.laz> <output.laz> [voxel_size]"
  exit 1
fi

SOURCE_FILE="$1"
RESULT_FILE="$2"
VOXEL_SIZE="${3:-0.005}"
LOG_FILE="${RESULT_FILE}.log"

cesnet::require_file "$SOURCE_FILE"
cesnet::enter_scratch
cesnet::load_modules
cesnet::copy_first_existing "$SCRATCHDIR/pdal.img" /storage/projects2/InterCOST/singularity_img/pdal.img /storage/plzen1/home/krucek/singularity_img/pdal.img

cp "$SOURCE_FILE" in.laz
cat > pdal_pipeline.json <<JSON
{
  "pipeline": [
    {"type":"readers.las","filename":"in.laz"},
    {"type":"filters.voxeldownsize","cell":$VOXEL_SIZE,"mode":"center"},
    {"type":"writers.las","dataformat_id":1,"minor_version":2,"filename":"cloud.laz"}
  ]
}
JSON

singularity exec -B "$SCRATCHDIR":/data ./pdal.img pdal pipeline /data/pdal_pipeline.json
cp cloud.laz "$RESULT_FILE"
cesnet::clean_scratch
