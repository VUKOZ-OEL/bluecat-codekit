#!/usr/bin/env bash
# =============================================================================
# rct_auto_tiling — PRODUCTION tiled tree segmentation (seamless pipeline)
#
# Segments a large point cloud into per-tree LAZ files with ZERO point loss
# and ZERO duplicate trees, even for trees spanning tile borders.
#
# Pipeline overview (all steps below are individually resumable - the script
# skips work whose outputs already exist):
#
#   [1/7] SPLIT      input cloud -> nominal tiles LxL m + B m buffer.
#                    Writes tile_<i>_<j>.ply + .rids (global input row ids,
#                    the permanent identity of every record) + grid.json.
#   [2/7] RCT/tile   rayimport -> rayextract terrain -> rayextract trees
#                    per tile (docker locally, PBS array on MetaCentrum).
#   [3/7] TERRAIN    stitch_terrain.py welds all tile terrain meshes into ONE
#                    seamless mesh (shared grid nodes averaged, duplicate
#                    triangles dropped).
#   [4/7] LINK       buffer_components.py: two tile segments are the same
#                    physical tree iff they colour the SAME input records.
#                    Universal link rule (recall-first):
#                      shared >= min_shared AND
#                      shared >= dup_frac * min(overlap-zone records)
#                    where overlap-zone = coloured records inside the tile's
#                    B m buffer band. True duplicates cover ~all of their
#                    band regardless of point density; touching crowns of
#                    different trees trade only a few band points.
#   [5/7] RCT/comp   every multi-tile component cloud is re-segmented ONCE
#                    MORE by RCT against the stitched whole-plot terrain
#                    (no tile edges inside => no cut crowns).
#   [6/7] ASSEMBLE   merge_final.py assigns EVERY input record to exactly
#                    one owner: re-segmented component (> tile segment) >
#                    unlabelled. Any point black in one tile but part of a
#                    tree elsewhere ALWAYS belongs to the tree.
#   [7/7] VERIFY     HARD invariant: N_input == sum(tree pts) + unlabelled.
#                    Script exits non-zero if it does not hold.
#
# Usage:
#   bash run_tiled_segmentation.sh <input.ply> <outdir> [options...]
#
# Options (env or flags):
#   LENGTH=50      tile edge length L in metres            (default 50)
#   BUFFER=1       tile buffer B in metres                 (default 1)
#   DUP_FRAC=0.05  link threshold vs overlap zone          (default 0.05)
#   MIN_SHARED=1   min shared records to consider linking  (default 1)
#   DELTA=0.5      base-proximity dedup for zero-shared whole-tree duplicates
#                  (only fires when two trees share NO records at all) (m)
#   TILE_JOBS=N    parallel local docker workers for step 2 (default 1)
#   COMP_JOBS=N    parallel local docker workers for step 5 (default 1)
#   RCT_RUNNER=... command template for RCT; placeholders %DIR %CMD:
#     local docker (default):
#       docker run --rm --platform linux/amd64 --entrypoint bash \
#           -v "%DIR:/work" -w /work raycloudtools:local -c "%CMD"
#     MetaCentrum apptainer (suggested):
#       singularity exec --bind "%DIR:/work" /path/rct.sif bash -c "%CMD"
#   SKIP_RCT=1     skip steps 2 and 5 (reuse existing RCT outputs)
#
# Outputs in <outdir>:
#   tiles/               tiles + RCT outputs per tile
#   terrain_stitched.ply single seamless terrain mesh
#   comps/               multi-tile component clouds + their re-segmentations
#   trees_out/tree_<gid>.laz      one LAZ per FINAL tree (RGB per tree)
#   trees_out/unlabelled.laz      ONE cloud with all non-tree points
#   trees_out/manifest.json       per-tree base coords, point count, source
#   pipeline.log                  full log of every step
#
# Requirements: python3 with numpy+scipy+laspy on PATH (or PYTHON=...),
# a working RCT runtime (docker image or singularity image), bash.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR"

# ------------------------------ arguments ------------------------------------
INPUT="${1:?usage: run_tiled_segmentation.sh <input.ply> <outdir> [env opts]}"
OUT="${2:?usage: run_tiled_segmentation.sh <input.ply> <outdir> [env opts]}"

LENGTH="${LENGTH:-50}"
BUFFER="${BUFFER:-1}"
DUP_FRAC="${DUP_FRAC:-0.05}"
MIN_SHARED="${MIN_SHARED:-1}"
DELTA="${DELTA:-0.5}"
TILE_JOBS="${TILE_JOBS:-1}"
COMP_JOBS="${COMP_JOBS:-1}"
SKIP_RCT="${SKIP_RCT:-0}"
PYTHON="${PYTHON:-python}"

RCT_RUNNER="${RCT_RUNNER:-docker run --rm --platform linux/amd64 --entrypoint bash -v \"%DIR:/work\" -w /work raycloudtools:local -c \"%CMD\"}"

# Resolve to absolute native paths (Windows docker mounts need them;
# cygpath may not exist on MetaCentrum, in which case we fall back to realpath).
to_abs() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -m "$(realpath "$1")"
    else
        realpath "$1"
    fi
}
INPUT="$(to_abs "$INPUT")"
mkdir -p "$OUT"
OUT="$(to_abs "$OUT")"

TILE_DIR="$OUT/tiles"
COMP_DIR="$OUT/comps"
TREE_DIR="$OUT/trees_out"
mkdir -p "$TILE_DIR" "$COMP_DIR" "$TREE_DIR"
LOG="$OUT/pipeline.log"

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

# Run an RCT command inside a working directory via RCT_RUNNER template.
run_rct() {  # run_rct <abs_workdir> "<rct command string>"
    local dir="$1" cmd="$2"
    local tmpl="${RCT_RUNNER//%DIR/$dir}"
    tmpl="${tmpl//%CMD/$cmd}"
    bash -c "$tmpl"
}

# parallel worker pool over a list file of "<workdir>|<command>"
run_pool() {  # run_pool <jobs> <listfile>
    local jobs="$1" list="$2" n
    n=$(wc -l < "$list" | tr -d ' ')
    log "  pool: $n jobs, $jobs workers"
    local active=0
    while IFS='|' read -r dir cmd; do
        [ -z "$dir" ] && continue
        run_rct "$dir" "$cmd" >> "$LOG" 2>&1 &
        active=$((active + 1))
        if [ "$active" -ge "$jobs" ]; then wait -n; active=$((active - 1)); fi
    done < "$list"
    wait
}

echo "================================================================" >> "$LOG"
log "=== tiled segmentation pipeline START ==="
log "input   : $INPUT"
log "outdir  : $OUT"
log "params  : L=${LENGTH}m B=${BUFFER}m dup_frac=${DUP_FRAC} min_shared=${MIN_SHARED} delta=${DELTA}m"

# ------------------------------ [1/7] split ----------------------------------
if [ -f "$TILE_DIR/grid.json" ] && ls "$TILE_DIR"/tile_[0-9]*_[0-9]*.ply >/dev/null 2>&1; then
    log "[1/7] split: tiles already exist, skipping"
else
    log "[1/7] split: $INPUT -> ${LENGTH}x${LENGTH} m + ${BUFFER} m buffer"
    "$PYTHON" "$SRC/step1_tile_split.py" "$INPUT" \
        --length "$LENGTH" --buffer "$BUFFER" \
        --outdir "$TILE_DIR" --prefix tile 2>&1 | tee -a "$LOG"
fi

# --------------------------- [2/7] per-tile RCT ------------------------------
ntiles=$(ls "$TILE_DIR"/tile_[0-9]*_[0-9]*.ply 2>/dev/null | wc -l | tr -d ' ')
log "[2/7] per-tile RCT on $ntiles tiles"
if [ "$SKIP_RCT" = "1" ]; then
    log "      SKIP_RCT=1 -> reusing existing RCT outputs"
else
    todo="$OUT/.todo_tiles.txt"; : > "$todo"
    for tf in "$TILE_DIR"/tile_[0-9]*_[0-9]*.ply; do
        base="$(basename "$tf" .ply)"
        if [ ! -f "$TILE_DIR/${base}_raycloud_segmented.ply" ]; then
            echo "$TILE_DIR|rayimport $base.ply 0,0,0 && rayextract terrain ${base}_raycloud.ply && rayextract trees ${base}_raycloud.ply ${base}_raycloud_mesh.ply" >> "$todo"
        fi
    done
    if [ -s "$todo" ]; then run_pool "$TILE_JOBS" "$todo"; else log "      all tiles already segmented"; fi
fi
# fail fast if any tile lacks RCT output
for tf in "$TILE_DIR"/tile_[0-9]*_[0-9]*.ply; do
    base="$(basename "$tf" .ply)"
    [ -f "$TILE_DIR/${base}_raycloud_segmented.ply" ] || { log "FATAL: missing $TILE_DIR/${base}_raycloud_segmented.ply"; exit 3; }
done

# --------------------------- [3/7] stitch terrain ----------------------------
if [ -f "$OUT/terrain_stitched.ply" ]; then
    log "[3/7] terrain: already stitched, skipping"
else
    log "[3/7] terrain: welding $(ls "$TILE_DIR"/tile_*_raycloud_mesh.ply | wc -l | tr -d ' ') tile meshes"
    "$PYTHON" "$SRC/stitch_terrain.py" \
        --meshes "$TILE_DIR"/tile_*_raycloud_mesh.ply \
        --out "$OUT/terrain_stitched.ply" 2>&1 | tee -a "$LOG"
fi

# --------------------- [4/7] link boundary segments --------------------------
if [ -f "$COMP_DIR/components.json" ]; then
    log "[4/7] link: components already exist, skipping"
else
    log "[4/7] link: boundary segments (dup_frac=$DUP_FRAC vs overlap zone)"
    "$PYTHON" "$SRC/buffer_components.py" --input "$INPUT" \
        --tiles "$TILE_DIR"/tile_[0-9]*_[0-9]*.ply \
        --outdir "$COMP_DIR" \
        --min-shared "$MIN_SHARED" --dup-frac "$DUP_FRAC" 2>&1 | tee -a "$LOG"
fi
ncomp=$(python -c "import json;print(json.load(open(r'$COMP_DIR/components.json'))['n_components'])" 2>/dev/null || echo 0)
log "[4/7] $ncomp multi-tile components to re-segment"

# ------------- [5/7] re-segment components vs stitched terrain ---------------
if [ "$ncomp" -gt 0 ] && [ "$SKIP_RCT" != "1" ]; then
    cp -f "$OUT/terrain_stitched.ply" "$COMP_DIR/terrain_stitched.ply"
    todo="$OUT/.todo_comps.txt"; : > "$todo"
    for cf in "$COMP_DIR"/comp_[0-9]*.ply; do
        base="$(basename "$cf" .ply)"
        if [ ! -f "$COMP_DIR/${base}_raycloud_segmented.ply" ]; then
            echo "$COMP_DIR|rayimport $base.ply 0,0,0 && rayextract trees ${base}_raycloud.ply terrain_stitched.ply" >> "$todo"
        fi
    done
    if [ -s "$todo" ]; then
        log "[5/7] re-segmenting $(wc -l < "$todo" | tr -d ' ') components"
        run_pool "$COMP_JOBS" "$todo"
    else
        log "[5/7] all components already re-segmented"
    fi
elif [ "$SKIP_RCT" = "1" ]; then
    log "[5/7] SKIP_RCT=1 -> reusing existing component segmentations"
else
    log "[5/7] no multi-tile components, nothing to re-segment"
fi

# ---------------------- [6/7] final assembly + [7/7] verify ------------------
log "[6/7] assemble: every input record -> exactly one tree or unlabelled"
"$PYTHON" "$SRC/merge_final.py" --input "$INPUT" \
    --tiles "$TILE_DIR"/tile_[0-9]*_[0-9]*.ply \
    --components "$COMP_DIR/components.json" \
    --comp-dir "$COMP_DIR" --outdir "$TREE_DIR" \
    --delta "$DELTA" 2>&1 | tee -a "$LOG"

log "[7/7] verify: hard point invariant"
"$PYTHON" - "$INPUT" "$TREE_DIR" <<'PY' 2>&1 | tee -a "$LOG"
import sys, glob, laspy
inp, outdir = sys.argv[1], sys.argv[2]
def nv_ply(p):
    # cheap PLY vertex count from header
    with open(p, 'rb') as f:
        while True:
            s = f.readline().split()
            if len(s) >= 3 and s[0] == b'element' and s[1] == b'vertex':
                return int(s[2])
n_in = nv_ply(inp)
tot = 0
for p in glob.glob(outdir + '/tree_*.laz') + glob.glob(outdir + '/unlabelled.laz'):
    with laspy.open(p) as h:
        tot += h.header.point_count
status = 'PASS' if tot == n_in else 'FAIL'
print(f'  input {n_in:,} == outputs {tot:,} -> {status}')
sys.exit(0 if status == 'PASS' else 7)
PY

log "=== DONE -> $TREE_DIR/ (tree_<gid>.laz + unlabelled.laz + manifest.json) ==="
