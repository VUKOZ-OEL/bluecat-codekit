#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <input_zip>"
  exit 1
fi

INPUT="$1"
ZIP_NAME=$(basename "$INPUT")
BASENAME="${ZIP_NAME%.zip}"
INPUT_DIR=$(dirname "$INPUT")
OUTPUT_ZIP="${INPUT_DIR}/${BASENAME}_odm.zip"
ODM_IMAGE="/storage/plzen1/home/krucek/singularity_img/odm.img"

cesnet::require_file "$INPUT"
cesnet::require_file "$ODM_IMAGE"
cesnet::enter_scratch
cp "$ODM_IMAGE" .
cp "$INPUT" .
unzip -q "$ZIP_NAME"
mkdir -p "$BASENAME/images"
find "$BASENAME" -type f -name '*.tif' -exec mv {} "$BASENAME/images/" \;

cesnet::load_modules
singularity exec -B "$SCRATCHDIR":/data odm.img /code/run.sh --project-path /data "$BASENAME"
zip -rq "${BASENAME}_odm.zip" "$BASENAME"
cp "${BASENAME}_odm.zip" "$OUTPUT_ZIP"
cesnet::clean_scratch
