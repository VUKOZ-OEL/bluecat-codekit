#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <input.laz>"
  exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${INPUT_FILE}.first"
LOG_FILE="${OUTPUT_FILE}.log"

cesnet::require_file "$INPUT_FILE"
cesnet::enter_scratch
cesnet::load_modules

cesnet::copy_first_existing "$SCRATCHDIR/pdal.img" \
  /storage/plzen1/home/krucek/singularity_img/pdal.img \
  /storage/projects2/InterCOST/singularity_img/pdal.img

cp "$INPUT_FILE" "$SCRATCHDIR/cloud.laz"
singularity exec -B "$SCRATCHDIR":/data ./pdal.img pdal info -p 0 /data/cloud.laz > cloud.first
cp cloud.first "$OUTPUT_FILE"

cesnet::clean_scratch
