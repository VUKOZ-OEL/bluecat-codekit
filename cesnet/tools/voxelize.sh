#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <input.laz> <output.laz> [voxel_size] [tile_size] [tile_buffer] [cores]"
  exit 1
fi

SOURCE_FILE="$1"
RESULT_FILE="$2"
VOXEL_SIZE="${3:-0.02}"
TILE_SIZE="${4:-10}"
TILE_BUFFER="${5:-0}"
CORES="${6:-1}"
LOG_FILE="${RESULT_FILE}.log"

cesnet::require_file "$SOURCE_FILE"
cesnet::enter_scratch
cp "$SOURCE_FILE" in.laz
mkdir -p tiles voxelized

wget -q https://downloads.rapidlasso.de/LAStools.tar.gz
tar xzf LAStools.tar.gz

./bin/lasindex64 -i in.laz
./bin/lastile64 -i in.laz -odir tiles -tile_size "$TILE_SIZE" -buffer "$TILE_BUFFER" -cores "$CORES"
rm -f in.laz
./bin/lasvoxel64 -i tiles/*.las -odir voxelized -step "$VOXEL_SIZE" -cores "$CORES"
./bin/lasmerge64 -i voxelized/*.las -o merged.laz

cp merged.laz "$RESULT_FILE"
cesnet::clean_scratch
