#!/bin/bash
set -euo pipefail

source /etc/profile || true
module add matlab || true
echo "QSM environment ready"
