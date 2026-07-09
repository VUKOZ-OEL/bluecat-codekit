#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

cesnet::require_env DATADIR SOURCE_DATA
LOG_FILE="$DATADIR/$SOURCE_DATA.info.txt"
export LOG_FILE DATADIR SOURCE_DATA TRAJECTORY VOXELIZE VOXEL_RES ADD_TIME SCRATCHDIR

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

cesnet::enter_scratch
cesnet::load_modules
cesnet::log INFO "Master processor started"

"$SCRIPT_DIR/sys_monitor.sh" &
SYS_MONITOR_PID=$!

cleanup() {
  kill "$SYS_MONITOR_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

"$SCRIPT_DIR/setup_scratch.sh"
"$SCRIPT_DIR/create_pdal_pipeline.sh"
"$SCRIPT_DIR/process_data.sh"
"$SCRIPT_DIR/cleanup_scratch.sh"
"$SCRIPT_DIR/deliver_results.sh"

cesnet::log INFO "Master processor finished"
cesnet::clean_scratch
