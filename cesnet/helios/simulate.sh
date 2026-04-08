#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <input.laz> <survey.xml> <loader.xml> <data_dir>"
  exit 1
fi

INPUT_DATA="$1"
SURVEY_XML="$2"
LOADER_XML="$3"
DATADIR="$4"
LOG_FILE="$DATADIR/$INPUT_DATA.log"

cesnet::enter_scratch
cesnet::log INFO "Starting HELIOS simulation"

wget -q https://github.com/3dgeo-heidelberg/helios/releases/download/v1.3.0/helios-plusplus-lin.tar.gz
tar -xzf helios-plusplus-lin.tar.gz
export LD_LIBRARY_PATH="$SCRATCHDIR/helios-plusplus-lin/run:${LD_LIBRARY_PATH:-}"

cp "$DATADIR/$INPUT_DATA" "$SCRATCHDIR/helios-plusplus-lin/"
cp "$DATADIR/$SURVEY_XML" "$SCRATCHDIR/helios-plusplus-lin/"
cp "$DATADIR/$LOADER_XML" "$SCRATCHDIR/helios-plusplus-lin/"

cd helios-plusplus-lin
./run/helios --test >> "$LOG_FILE" 2>&1
./run/helios "$SCRATCHDIR/helios-plusplus-lin/$SURVEY_XML"

zip -r "${INPUT_DATA}_helios.zip" output >/dev/null
cp "${INPUT_DATA}_helios.zip" "$DATADIR"

cesnet::clean_scratch
