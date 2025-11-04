#!/bin/bash

INPUT="$1"

# Získání jména a cesty
ZIP_NAME=$(basename "$INPUT")                # petrova_skala.zip
BASENAME="${ZIP_NAME%.zip}"                  # petrova_skala
INPUT_DIR=$(dirname "$INPUT")                # /storage/plzen1/home/krucek/tis
OUTPUT_ZIP="${INPUT_DIR}/${BASENAME}_odm.zip"

# Cesta k image
ODM_IMAGE="/storage/plzen1/home/krucek/singularity_img/odm.img"

# --- Přenos dat ---
cp "$ODM_IMAGE" "$SCRATCHDIR"
cp "$INPUT" "$SCRATCHDIR"
cd "$SCRATCHDIR"

# --- Rozbalení ---
unzip "$ZIP_NAME"

# --- Příprava obrázků pro ODM ---
mkdir -p "$BASENAME/images"
find "$BASENAME" -type f -name '*.tif' -exec mv {} "$BASENAME/images/" \;

# --- Spuštění ODM ---
module add singul
singularity exec -B "$SCRATCHDIR:/data" odm.img /code/run.sh --project-path /data "$BASENAME"

# --- Archivace výsledku ---
zip -r "$BASENAME"_odm.zip "$BASENAME"
cp "$BASENAME"_odm.zip "$OUTPUT_ZIP"

clean_scratch

