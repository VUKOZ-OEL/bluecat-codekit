#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <fixed.laz> <moving.laz>"
  exit 1
fi

A="$1"
B="$2"
B_NAME=$(basename "$B")
B_ALIGNED="${B_NAME%.laz}_aligned.laz"
LOG_FILE="${B}.align.log"

cesnet::require_file "$A"
cesnet::require_file "$B"
cesnet::enter_scratch
cesnet::load_modules
cesnet::copy_first_existing "$SCRATCHDIR/raycloudtools.img" /storage/brno2/home/krucek/bluecat/singularity_img/raycloudtools.img /storage/plzen1/home/krucek/singularity_img/raycloudtools.img
cesnet::copy_first_existing "$SCRATCHDIR/pdal.img" /storage/brno2/home/krucek/bluecat/singularity_img/pdal.img /storage/projects2/InterCOST/singularity_img/pdal.img

cp "$A" c1.laz
cp "$B" c2.laz

for f in c1 c2; do
cat > "pdal_pipeline_${f}.json" <<JSON
{
  "pipeline": [
    {"type":"readers.las","filename":"${f}.laz"},
    {"type":"filters.ferry","dimensions":"X=>GpsTime"},
    {"type":"writers.las","dataformat_id":1,"minor_version":2,"filename":"${f}_gpst.laz"}
  ]
}
JSON
singularity exec -B "$SCRATCHDIR":/data ./pdal.img pdal pipeline "/data/pdal_pipeline_${f}.json"
done

singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayimport c1_gpst.laz ray 0,0,-10
singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayimport c2_gpst.laz ray 0,0,-10
singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayalign c2_gpst.ply c1_gpst.ply
singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayexport c2_gpst_aligned.ply "$B_ALIGNED" traj.txt

cp "$B_ALIGNED" "$(dirname "$B")/$B_ALIGNED"
cesnet::clean_scratch
