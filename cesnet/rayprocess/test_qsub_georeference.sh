#!/bin/bash
#PBS -N rct_georef_test
#PBS -l select=1:ncpus=16:mem=64gb:scratch_local=50gb
#PBS -l walltime=4:00:00
#PBS -j oe
#PBS -m abe

# Test opraveneho georeferencingu - vola tvuj segment_codex_v1.sh (taha z vetve)
# Pouziti:
#   qsub /storage/plzen1/home/krucek/scripts/test_qsub_georeference.sh
# nebo s vlastnim DATADIR:
#   qsub -v DATADIR=/cesta/k/vysledkum test_qsub_georeference.sh

SCRIPT="/storage/plzen1/home/krucek/scripts/segment_codex_v1.sh"
SOURCE_DATA="${SOURCE_DATA:-2022_q34_sample_25x25.laz}"
DATA_DIR="${DATA_DIR:-/storage/plzen1/home/krucek/data/testing}"
DATADIR="${DATADIR:-$DATA_DIR/georeference_test_$(date +%Y%m%d_%H%M%S)}"
VOXELIZE="${VOXELIZE:-false}"
VOXEL_RES="${VOXEL_RES:-0.01}"
ADD_TIME="${ADD_TIME:-true}"
TRAJECTORY="${TRAJECTORY:-false}"

mkdir -p "$DATADIR" || exit 2

echo "=== rct georeference test ==="
echo "job: $PBS_JOBID  host: $HOSTNAME"
echo "script: $SCRIPT"
echo "input: $DATA_DIR/$SOURCE_DATA ($(ls -lh "$DATA_DIR/$SOURCE_DATA" | awk '{print $5}'))"
echo "output: $DATADIR"
echo "voxelize=$VOXELIZE res=$VOXEL_RES add_time=$ADD_TIME trajectory=$TRAJECTORY"
echo "start: $(date)"
echo

cd "$DATA_DIR" || exit 2
"$SCRIPT" "$SOURCE_DATA" "$DATADIR" "$VOXELIZE" "$VOXEL_RES" "$ADD_TIME" "$TRAJECTORY"
RC=$?

echo
echo "exit code: $RC"
echo "end: $(date)"

# kontrola: scale prvniho segmentu (ma byt ~0.001, ne 1.0)
FIRST=$(find "$DATADIR" -name "cloud_segmented*.laz" -o -name "*_segment_*.laz" 2>/dev/null | head -1)
if [ -n "$FIRST" ]; then
    echo
    echo "=== first segment scale check: $FIRST ==="
    pdal info --metadata "$FIRST" 2>/dev/null | grep -E '"scale|"offset|"count' | head -10 || echo "pdal neni na frontendu - zkontroluj az na home"
fi

exit $RC
