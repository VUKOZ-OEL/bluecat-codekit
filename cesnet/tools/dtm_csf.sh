#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <input.laz>"
  exit 1
fi

INPUT="$1"
R_SCRIPT="/storage/plzen1/home/krucek/npo_sumava/dtm_csf.R"
LOG_FILE="${INPUT%.laz}_csf.log"

cesnet::require_file "$INPUT"
cesnet::require_file "$R_SCRIPT"
cesnet::enter_scratch
cp "$INPUT" cloud.laz
cp "$R_SCRIPT" dtm_csf.R

source /etc/profile || true
module add r/ || true
Rscript dtm_csf.R
cp ground_pts.laz "${INPUT%.laz}_csf_pts.laz"
cesnet::clean_scratch
