#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

SYS_LOG_FILE="system_usage.log"
INTERVAL=5

echo -e "Time\tCPU(%)\tCores\tRAM" > "$SYS_LOG_FILE"

while true; do
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  CPU_USAGE=$(top -bn1 | awk -F',' '/Cpu\(s\)/ {gsub("%us", "", $1); gsub("%sy", "", $2); split($1,a,":"); print a[2]+$2 }')
  CPU_CORES=$(nproc)
  RAM_USAGE=$(free -m | awk '/Mem:/ {printf "%d/%dMB (%.2f%%)", $3, $2, ($3*100)/$2}')
  echo -e "$TIMESTAMP\t$CPU_USAGE\t$CPU_CORES\t$RAM_USAGE" >> "$SYS_LOG_FILE"
  sleep "$INTERVAL"
done
