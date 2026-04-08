#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <fixed.laz> <moving.laz> <decimation_level>"
  exit 1
fi

FIXED="$1"
MOVING="$2"
DECIMATION_LEVEL="$3"

"$(dirname "$0")/align_clouds.sh" "$FIXED" "$MOVING"

# Optional post-decimation alignment can be added here; keep script compatible with submit_job orchestration.
cesnet::log INFO "Decimation level requested: $DECIMATION_LEVEL (base alignment completed)."
