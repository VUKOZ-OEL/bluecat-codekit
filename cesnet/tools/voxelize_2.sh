#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <input.laz> <output.laz> [voxel_size] [tile_buffer] [cores]"
  exit 1
fi

SOURCE_FILE="$1"
RESULT_FILE="$2"
VOXEL_SIZE="${3:-0.02}"
TILE_BUFFER="${4:-0}"
CORES="${5:-1}"

cesnet::require_file "$SOURCE_FILE"
cesnet::enter_scratch
cp "$SOURCE_FILE" in.laz
mkdir -p tiles_25m tiles_1m voxelized

wget -q https://downloads.rapidlasso.de/LAStools.tar.gz
tar xzf LAStools.tar.gz

./bin/lasindex64 -i in.laz
./bin/lastile64 -i in.laz -odir tiles_25m -tile_size 25 -buffer "$TILE_BUFFER" -cores "$CORES"
./bin/lastile64 -i tiles_25m/*.las -odir tiles_1m -tile_size 1 -buffer "$TILE_BUFFER" -cores "$CORES"
rm -rf tiles_25m
./bin/lasvoxel64 -i tiles_1m/*.las -odir voxelized -step "$VOXEL_SIZE" -cores "$CORES"
./bin/lasmerge64 -i voxelized/*.las -o merged.laz

cp merged.laz "$RESULT_FILE"
cesnet::clean_scratch
