#!/usr/bin/env bash
# =============================================================================
# rct_auto_tiling — SEAMLESS whole-plot pipeline (B=1 m buffer).
#
#   1. step1_tile_split.py       split + .rids sidecars + grid.json
#   2. per-tile rayprocess       rayimport -> rayextract terrain -> trees
#   3. stitch_terrain.py         ONE seamless terrain mesh
#   4. buffer_components.py      link segments sharing records across tiles,
#                                export multi-tile component clouds
#   5. per-component rayprocess  rayimport -> rayextract trees comp.ply mesh
#   6. merge_final.py            EVERY input record -> exactly one tree or the
#                                single unlabelled cloud (HARD invariant check)
#
# Per-tile / per-component RCT execution is environment-specific:
#   PBS_MODE=1   -> qsub array jobs (MetaCentrum, meta pbs_tile_job.sh)
#   RCT_DOCKER=1 -> run raycloudtools:local docker container here (Windows)
#   else         -> expect the outputs to already exist (manual/HPC steps)
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && cygpath -m "$(pwd)")"
SRC="$ROOT/src/rct_auto_tiling"

INPUT="${1:?usage: run_seamless.sh <input.ply> [length=10] [buffer=1] [outdir]}"
INPUT="$(cygpath -m "$(realpath "$INPUT")")"
LENGTH="${2:-10}"
BUFFER="${3:-1}"
OUT="$(cygpath -m "$(mkdir -p "${4:-$ROOT/test_runs_output/seamless_run}" && realpath "${4:-$ROOT/test_runs_output/seamless_run}")")"
TILE_DIR="$OUT/tiles"
COMP_DIR="$OUT/comps"
mkdir -p "$TILE_DIR" "$COMP_DIR"

run_rct_docker() {  # run_rct_docker <workdir> <cmd...>
    docker run --rm --platform linux/amd64 --entrypoint /bin/bash \
        -v "$(cygpath -m "$1"):/work" -w /work raycloudtools:local -c "$2"
}

echo "=== 1/6 split (length=${LENGTH}m buffer=${BUFFER}m) ==="
python "$SRC/step1_tile_split.py" "$INPUT" --length "$LENGTH" --buffer "$BUFFER" \
    --outdir "$TILE_DIR" --prefix tile

echo "=== 2/6 per-tile RCT ==="
if [ "${RCT_DOCKER:-0}" = "1" ]; then
    for tf in "$TILE_DIR"/tile_*.ply; do
        base="$(basename "$tf" .ply)"
        [ -f "$TILE_DIR/${base}_raycloud_segmented.ply" ] && continue
        run_rct_docker "$TILE_DIR" \
            "rayimport $base.ply 0,0,0 && rayextract terrain ${base}_raycloud.ply && rayextract trees ${base}_raycloud.ply ${base}_raycloud_mesh.ply"
    done
fi

echo "=== 3/6 stitch terrain ==="
python "$SRC/stitch_terrain.py" --meshes "$TILE_DIR"/tile_*_raycloud_mesh.ply \
    --out "$OUT/terrain_stitched.ply"

echo "=== 4/6 buffer components ==="
python "$SRC/buffer_components.py" --input "$INPUT" \
    --tiles "$TILE_DIR"/tile_*.ply --outdir "$COMP_DIR"

echo "=== 5/6 per-component RCT (against stitched terrain) ==="
if [ "${RCT_DOCKER:-0}" = "1" ]; then
    cp "$OUT/terrain_stitched.ply" "$COMP_DIR/"
    for cf in "$COMP_DIR"/comp_*.ply; do
        base="$(basename "$cf" .ply)"
        case "$base" in
            comp_[0-9]*) ;;
            *) continue ;;   # skip comp_*_raycloud intermediates
        esac
        case "$base" in
            *_raycloud) continue ;;
        esac
        [ -f "$COMP_DIR/${base}_raycloud_segmented.ply" ] && continue
        run_rct_docker "$COMP_DIR" \
            "rayimport $base.ply 0,0,0 && rayextract trees ${base}_raycloud.ply terrain_stitched.ply"
    done
fi

echo "=== 6/6 final assembly (hard invariant) ==="
python "$SRC/merge_final.py" --input "$INPUT" \
    --tiles "$TILE_DIR"/tile_*.ply \
    --components "$COMP_DIR/components.json" \
    --comp-dir "$COMP_DIR" --outdir "$OUT/trees_out" \
    --delta "${DELTA:-0.5}"

echo "=== DONE: $OUT/trees_out ==="
