#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

rm -rf bluecat-codekit "${SOURCE_DATA:-}" cloud.laz raycloudtools.img pdal.img
rm -f segments/cloud_segmented.laz segments/cloud_segmented.ply segments/cloud_segmented.txt

mkdir -p segments/ply segments/laz segments/png log
mv -f segments/*.ply segments/ply/ 2>/dev/null || true
mv -f segments/*.laz segments/laz/ 2>/dev/null || true
mv -f segments/*.png segments/png/ 2>/dev/null || true
mv -f *.sh pdal_pipeline.json system_usage.log log/ 2>/dev/null || true

cesnet::log INFO "Scratch cleaned"
