#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <input.laz> <output.laz>"
  exit 1
fi

SOURCE_FILE="$1"
RESULT_FILE="$2"
LOG_FILE="${RESULT_FILE}.log"

cesnet::require_file "$SOURCE_FILE"
cesnet::enter_scratch
cesnet::load_modules
cesnet::copy_first_existing "$SCRATCHDIR/pdal.img" /storage/projects2/InterCOST/singularity_img/pdal.img /storage/plzen1/home/krucek/singularity_img/pdal.img

cp "$SOURCE_FILE" in.laz
singularity exec -B "$SCRATCHDIR":/data ./pdal.img pdal info /data/in.laz --metadata > metadata.json

read -r T_X T_Y T_Z < <(python3 - <<'PY'
import json
m=json.load(open('metadata.json'))['metadata']
mid_x=m['minx']+((m['maxx']-m['minx'])/2)
mid_y=m['miny']+((m['maxy']-m['miny'])/2)
min_z=m['minz']
print(-mid_x,-mid_y,-min_z)
PY
)

cat > pdal_translate.json <<JSON
{
  "pipeline": [
    {"type":"readers.las","filename":"/data/in.laz"},
    {"type":"filters.transformation","matrix":"1 0 0 $T_X 0 1 0 $T_Y 0 0 1 $T_Z 0 0 0 1"},
    {"type":"writers.las","filename":"/data/centered.laz","dataformat_id":1,"minor_version":2}
  ]
}
JSON

singularity exec -B "$SCRATCHDIR":/data ./pdal.img pdal pipeline /data/pdal_translate.json
cp centered.laz "$RESULT_FILE"
cesnet::clean_scratch
