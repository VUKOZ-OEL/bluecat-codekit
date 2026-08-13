#!/bin/bash

set -e

# Set processing variables before logging module and checkout status.
export SOURCE_DATA="$1" # Input filename, including its extension.
export DATADIR="$2"     # Directory containing the input data.

export VOXELIZE="${3:-true}"
export VOXEL_RES="${4:-0.02}"
export ADD_TIME="${5:-true}"
export TRAJECTORY="${6:-false}"
export LOG_FILE="$DATADIR/$SOURCE_DATA.info.txt"

# Move to the node-local scratch directory.
cd "$SCRATCHDIR"

# PBS starts a non-interactive shell, so the module command is not available
# until the system profile has been loaded.
source /etc/profile

# Get the processing scripts from the branch with georeferenced outputs.
module add git/ && echo "git loaded" >> "$LOG_FILE" || {
    echo "git not loaded" >> "$LOG_FILE"
    exit 1
}

git clone \
    --branch codex/rayprocess-georeferenced-results \
    --single-branch \
    https://github.com/VUKOZ-OEL/bluecat-codekit.git

cp bluecat-codekit/cesnet/rayprocess/*.sh "$SCRATCHDIR"

# Process the cloud.
source "$SCRATCHDIR/master_processor.sh"
