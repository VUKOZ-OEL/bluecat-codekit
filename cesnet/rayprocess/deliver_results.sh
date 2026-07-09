#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

cesnet::require_env DATADIR SOURCE_DATA

if [[ -f cloud_trees_info.txt ]]; then
  cp cloud_trees_info.txt "$DATADIR/$SOURCE_DATA.treeInfo.txt"
fi

[[ -f "$LOG_FILE" ]] && cp "$LOG_FILE" log/ 2>/dev/null || true

ZIP_NAME="${SOURCE_DATA}_results.zip"
zip -r "$ZIP_NAME" . >/dev/null
cp "$ZIP_NAME" "$DATADIR"

cesnet::log INFO "Results delivered to $DATADIR/$ZIP_NAME"
