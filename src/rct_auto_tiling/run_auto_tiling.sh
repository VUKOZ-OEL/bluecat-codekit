#!/usr/bin/env bash
# =============================================================================
# rct_auto_tiling — automatic lossless tiling of oversized rayclouds.
#
# Orchestrates the whole pipeline:
#   1. compute tile grid from the input cloud bbox (streaming, PDAL/python)
#   2. step1_tile_split.py  -> split into buffered nominal tiles (watertight)
#   3. rayprocess per tile  -> the existing MetaCentrum RayCloudTools pipeline
#                              (on Windows/Docker: --rayprocess executes it per
#                              tile via docker; otherwise a stub that copies the
#                              input treeInfo per tile so step2 can be tested)
#   4. step2_merge_segments -> merge per-tile treeInfo (dedup, no 2x/4x)
#   5. verify_point_counts  -> input points == sum(nominal tiles)   (HARD CHECK)
#
# Exit 0 = everything PASS, build merged output in OUTDIR/merged.
# Exit 2 = a hard invariant failed (point counts / duplicates).
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && cygpath -m "$(pwd)")"
SRC="$ROOT/src/rct_auto_tiling"

INPUT="${1:?usage: run_auto_tiling.sh <input.ply> [length] [buffer] [outdir]}"
LENGTH="${2:-10}"
BUFFER="${3:-10}"
OUT="${4:-$ROOT/test_runs_output/autotiling_run}"
TILE_DIR="$OUT/tiles"
STAGE="$OUT/stage"

mkdir -p "$TILE_DIR" "$STAGE"

echo "=== rct_auto_tiling: $INPUT  length=${LENGTH}m buffer=${BUFFER}m ==="

# --- 1+2: split ---------------------------------------------------------------
python "$SRC/step1_tile_split.py" "$INPUT" --length "$LENGTH" --buffer "$BUFFER" \
    --outdir "$TILE_DIR" --prefix tile

# --- 3: per-tile processing ---------------------------------------------------
# In production this is the MetaCentrum rayprocess pipeline run once per tile
# (PBS). Here, if a real per-tile rayprocess is configured via RCT_RAYPROCESS,
# run it; else simulate by copying the input's treeInfo to each tile so step 2
# can be exercised (LOCAL TEST ONLY).
echo "=== per-tile processing (rayprocess) ==="
if [ -n "${RCT_RAYPROCESS:-}" ]; then
    for tf in "$TILE_DIR"/tile_*.ply; do
        base="$(basename "$tf" .ply)"
        echo "  rayprocess $tf -> $STAGE/${base}.trees.json"
        python "$RCT_RAYPROCESS" "$INPUT" "$tf" "$STAGE/${base}.trees.json"
    done
else
    echo "  (local stub: no RCT_RAYPROCESS set — using input treeInfo for all tiles)"
    SRC_TREES="${RCT_TREES:-}"
    if [ -n "$SRC_TREES" ]; then
        for tf in "$TILE_DIR"/tile_*.ply; do
            base="$(basename "$tf" .ply)"
            cp "$SRC_TREES" "$STAGE/${base}.trees.json"
        done
    else
        echo "  NOTE: no per-tile trees available; merge test needs them. Skipping."
    fi
fi

# --- 4: merge -----------------------------------------------------------------
MERGE_OUT="$OUT/merged.treeInfo.geojson"
echo "=== merging segment trees ==="
if ls "$STAGE"/*.trees.json >/dev/null 2>&1; then
    python "$SRC/step2_merge_segments.py" --pattern "$STAGE/*.trees.json" \
        --delta "${DELTA:-0.1}" --out "$MERGE_OUT"
else
    echo "  no per-tile trees to merge"
fi

# --- 5: verify point counts (HARD) --------------------------------------------
echo "=== verifying point counts (input == sum nominal tiles) ==="
python "$SRC/verify_point_counts.py" --input "$INPUT" --tiles "$TILE_DIR/tile_*.owners.json"

echo "=== DONE ==="
[ -f "$MERGE_OUT" ] && echo "MERGED OUTPUT: $MERGE_OUT"
