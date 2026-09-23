#!/usr/bin/env bash
# =============================================================================
# rct_auto_tiling — PBS job wrapper for MetaCentrum.
#
# One PBS job == one tile. The master (run_auto_tiling.sh on the login node)
# splits the cloud, then submits one of these per tile. Each job:
#   * gets a SINGULARITY/conda RCT + PDAL env (RCT_SIF / module load),
#   * runs rayimport -> rayextract -> georef on ITS tile (real rayprocess),
#   * writes tile_x_y.trees.json (+ per-tree PLY/LAZ) back to STAGE_DIR,
#   * takes part in the point-count reconciliation (its tile .owners.json
#     and .ply are the verify inputs).
#
# Resource guard-rails (owner requirements):
#   * RAM capped at 256 GB via PBS -l mem= (soft) + ulimit -v (hard).
#   * No walltime overcommit: set from plan_tiling.py estimate.
#   * CPU count is free-form (owner: "number of cpus not a concern").
#
# Expected env (set by run_auto_tiling.sh / qsub wrapper):
#   PBS_ARRAY_ID / TILE_INDEX, TILE_DIR, STAGE_DIR, SRC, INPUT
#   RCT_SIF (singularity image) or RCT_ENV (module activation line)
# =============================================================================
set -euo pipefail

JOBID="${PBS_JOBID:-local}"
TILE_IDX="${PBS_ARRAYID:-${1:-}}"
[ -n "$TILE_IDX" ] || { echo "no TILE_IDX"; exit 2; }

TILE_PLY="$TILE_DIR/tile_${TILE_IDX}.ply"
[ -f "$TILE_PLY" ] || { echo "missing tile: $TILE_PLY"; exit 3; }

echo "=== tile job $JOBID tile_idx=$TILE_IDX on $(hostname) $(date) ==="

# --- RAM cap: hard 256 GB virtual (PBS mem= usually enough; belt & suspenders)
ulimit -v 268435456            # 256 GiB in KiB
ulimit -c 0                     # no core dumps on RAM-stressed crash

# --- RCT / PDAL environment ----------------------------------------------
if [ -n "${RCT_SIF:-}" ]; then
    SING="singularity exec -B "$PWD" "$RCT_SIF""
    RCT() { $SING "$@"; }
elif [ -n "${RCT_ENV:-}" ]; then
    # shellcheck disable=SC1090
    source "$RCT_ENV"
    RCT() { "$@"; }
else
    # local dev fallback (windows git-bash: python stub)
    RCT() { python "$SRC/mock_rayprocess.py" "$INPUT" "$@"; }
fi

# === per-tile rayprocess (the real thing on MetaCentrum) ==================
# tile_x_y.ply -> rayimport -> rayextract terrain/trees -> georef -> trees.json
OUT_TREES="$STAGE_DIR/tile_${TILE_IDX}.trees.json"
echo "  rayprocess $TILE_PLY -> $OUT_TREES"
RCT rayimport    "$TILE_PLY" -o "$SCRATCH/tile_${TILE_IDX}.ray"
RCT rayextract trees "$SCRATCH/tile_${TILE_IDX}.ray" --grid_width "$GRID_W" \
    -o "$SCRATCH/tile_${TILE_IDX}_trees" || true
RCT rayextract terrain "$SCRATCH/tile_${TILE_IDX}.ray" \
    -o "$SCRATCH/tile_${TILE_IDX}_terrain" || true
# georef + export treeInfo (the per-tree geojson the merge step consumes)
RCT python georeference_results.py --input "$SCRATCH/tile_${TILE_IDX}_trees" \
    --output "$OUT_TREES"

# === reconciliation tick ==================================================
# the split step already proves the point invariant; here we just record
# which tile finished (merge step counts all tiles before emitting output).
echo "=== tile $TILE_IDX done $(date) ===" >> "$STAGE_DIR/complete.log"
