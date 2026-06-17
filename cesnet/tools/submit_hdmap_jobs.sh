#!/bin/bash

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <zip_directory>"
    exit 1
fi

ZIP_DIR="$1"

for f in "$ZIP_DIR"/*.zip; do
    [ -e "$f" ] || continue

    qsub -l select=1:ncpus=12:mem=32gb:scratch_local=32gb \
         -l walltime=02:00:00 \
         -- /storage/plzen1/home/krucek/scripts/hdmap_process.sh "$f"
done
