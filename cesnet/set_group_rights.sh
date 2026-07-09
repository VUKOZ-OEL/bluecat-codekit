#!/bin/bash
set -euo pipefail

TARGET_DIR="/storage/projects2/InterCOST"

chgrp -R intercost "$TARGET_DIR"
chmod g+s "$TARGET_DIR"

echo "Applied intercost group rights to $TARGET_DIR"
