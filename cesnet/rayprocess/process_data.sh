#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

DATA_PLY="cloud.ply"
TERRAIN_PLY="cloud_mesh.ply"
SEGMENTED_PLY="cloud_segmented.ply"
TREES_TXT="cloud_trees.txt"

singularity exec -B "$SCRATCHDIR":/data ./pdal.img pdal pipeline /data/pdal_pipeline.json

if [[ "${TRAJECTORY:-false}" != "false" ]]; then
  singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayimport cloud.laz "$TRAJECTORY"
else
  singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayimport cloud.laz ray 0,0,-10 --remove_start_pos
fi

singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayextract terrain "$DATA_PLY"
singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayextract trunks "$DATA_PLY"
singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayextract forest "$DATA_PLY"

cp "$DATA_PLY" cloud_decimated.ply
decimation_level=2
while true; do
  if singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayextract trees cloud_decimated.ply "$TERRAIN_PLY"; then
    mv cloud_decimated_segmented.ply "$SEGMENTED_PLY"
    mv cloud_decimated_trees.txt "$TREES_TXT"
    mv cloud_decimated_trees_mesh.ply cloud_trees_mesh.ply
    rm -f cloud_decimated.ply
    break
  fi
  decimation_level=$((decimation_level + 2))
  if [[ "$decimation_level" -ge 12 ]]; then
    cesnet::log ERROR "Tree extraction failed up to decimation=$decimation_level"
    break
  fi
  singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img raydecimate "$DATA_PLY" "$decimation_level" rays
 done

singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayextract leaves "$DATA_PLY" "$TREES_TXT"
singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img treeinfo "$TREES_TXT"

mkdir -p segments
cp "$SEGMENTED_PLY" "segments/$SEGMENTED_PLY"
singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img raysplit "segments/$SEGMENTED_PLY" seg_colour

for segment_file in "$SCRATCHDIR"/segments/*.ply; do
  [[ -e "$segment_file" ]] || continue
  singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayrender "$segment_file" right ends
  singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayexport "$segment_file" "${segment_file%.ply}.laz" "${segment_file%.ply}.txt"
  singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img raywrap "$segment_file" inwards 1.0
done

cesnet::log INFO "Data processing completed"
