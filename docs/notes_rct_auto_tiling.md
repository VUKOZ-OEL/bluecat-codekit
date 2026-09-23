# Reshearch notes — automatic tiling of oversized clouds (rct_auto_tiling)

Branch: `rct_auto_tiling` (created from `codex/rayprocess-georeferenced-results`)
Created: 2026-09-23
Owner: krucek

Reference implementation (from the RayCloudTools repo, CSIRO):

```
./rayextract_trees_large cloudname 50
# raysplit $1.ply grid $2,$2,0 5   # 5 m overlap to avoid edge artefacts
# for each $1_*.ply: rayextract terrain -> rayextract trees --grid_width $2
# treecombine $1_*_trees.txt -> cloudname_trees.txt
```

Source: https://github.com/csiro-robotics/raycloudtools/blob/master/scripts/rayextract_trees_large.sh

## Why (trigger)

`rayextract forest` and large-cloud tree extraction can push MetaCentrum nodes
out of RAM (see commit 2811991 "skip rayextract forest by default
(memory-crash on large clouds)"). Tiling a too-big LAZ into axis-aligned tiles,
processing each tile, and merging the segmentations back is the standard fix —
provided zero points are lost and no objects are cut at tile edges.
