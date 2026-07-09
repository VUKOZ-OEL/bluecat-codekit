#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

cesnet::require_env SCRATCHDIR DATADIR SOURCE_DATA

cesnet::copy_first_existing "$SCRATCHDIR/raycloudtools.img" \
  /storage/brno2/home/krucek/bluecat/singularity_img/raycloudtools.img \
  /storage/plzen1/home/krucek/singularity_img/raycloudtools.img

cesnet::copy_first_existing "$SCRATCHDIR/pdal.img" \
  /storage/brno2/home/krucek/bluecat/singularity_img/pdal.img \
  /storage/projects2/InterCOST/singularity_img/pdal.img \
  /storage/plzen1/home/krucek/singularity_img/pdal.img

cp "$DATADIR/$SOURCE_DATA" "$SCRATCHDIR/"

if [[ "${TRAJECTORY:-false}" != "false" ]]; then
  cp "$DATADIR/$TRAJECTORY" "$SCRATCHDIR/"
fi

cesnet::log INFO "Scratch prepared"
