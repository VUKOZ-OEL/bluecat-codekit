#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <input.laz> <clip_polygon.geojson> <output.laz>"
  exit 1
fi

SOURCE_FILE="$1"
CLIP_POLY="$2"
RESULT_FILE="$3"
LOG_FILE="${RESULT_FILE}.log"

cesnet::require_file "$SOURCE_FILE"
cesnet::require_file "$CLIP_POLY"
cesnet::enter_scratch
cesnet::load_modules
cesnet::copy_first_existing "$SCRATCHDIR/pdal.img" /storage/plzen1/home/krucek/singularity_img/pdal.img /storage/projects2/InterCOST/singularity_img/pdal.img

cp "$SOURCE_FILE" in.laz
cp "$CLIP_POLY" clip.geojson
POLY_GEOJSON=$(python3 -c 'import json;import sys;d=json.load(open("clip.geojson"));print(json.dumps(d["features"][0]["geometry"]))')

cat > pdal_pipeline.json <<JSON
{
  "pipeline": [
    {"type":"readers.las","filename":"in.laz"},
    {"type":"filters.crop","polygon":$POLY_GEOJSON},
    {"type":"writers.las","dataformat_id":1,"minor_version":2,"filename":"output.laz"}
  ]
}
JSON

singularity exec -B "$SCRATCHDIR":/data ./pdal.img pdal pipeline /data/pdal_pipeline.json
cp output.laz "$RESULT_FILE"
cesnet::clean_scratch
