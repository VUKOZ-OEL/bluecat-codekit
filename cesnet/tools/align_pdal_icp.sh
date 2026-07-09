#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <fixed.laz> <moving.laz>"
  exit 1
fi

FIXED_FILE="$1"
MOVING_FILE="$2"
RESULT_FILE="${MOVING_FILE%.laz}_icp.laz"
RESULT_METADATA="${MOVING_FILE%.laz}_icp_metadata.json"
LOG_FILE="${RESULT_FILE}.log"

cesnet::require_file "$FIXED_FILE"
cesnet::require_file "$MOVING_FILE"
cesnet::enter_scratch
cesnet::load_modules
cesnet::copy_first_existing "$SCRATCHDIR/pdal.img" /storage/projects2/InterCOST/singularity_img/pdal.img /storage/plzen1/home/krucek/singularity_img/pdal.img

cp "$FIXED_FILE" fixed.laz
cp "$MOVING_FILE" moving.laz

cat > pdal_icp.json <<'JSON'
{
  "pipeline": [
    {"type":"readers.las","filename":"fixed.laz"},
    {"type":"readers.las","filename":"moving.laz"},
    {"type":"filters.icp"},
    {"type":"writers.las","minor_version":2,"dataformat_id":1,"filename":"icp.laz"}
  ]
}
JSON

singularity exec -B "$SCRATCHDIR":/data ./pdal.img pdal pipeline /data/pdal_icp.json --metadata /data/icp_metadata.json
cp icp.laz "$RESULT_FILE"
cp icp_metadata.json "$RESULT_METADATA"
cesnet::clean_scratch
