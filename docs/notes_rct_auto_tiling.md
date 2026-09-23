# Tiling / auto-tiling research — solution design (rct_auto_tiling)

Branch: `rct_auto_tiling`
Created: 2026-09-23 · Owner: krucek · Context: `bluecat-codekit`
(rayprocess pipeline: RayCloudTools + PDAL on MetaCentrum, PBS/singularity)

## Why (trigger)

`rayextract forest` and large-cloud tree extraction can push MetaCentrum nodes
out of RAM (see commit 2811991 "skip rayextract forest by default
(memory-crash on large clouds)"). Tiling a too-big LAZ into axis-aligned tiles,
processing each tile, and merging the segmentations back is the standard fix —
provided **zero points are lost** and no objects are cut at tile edges.

## The problem (restated)

* Input: one LAZ of a forest plot, potentially hundreds of GB / hundreds of
  millions of points (MLS/ULS), too large for one PBS node's RAM.
* The rayprocess pipeline (`rayimport → rayextract terrain → rayextract trees
  → … → georeferenced per-tree LAZ + treeInfo geoJSON/sqlite + DTM`) must keep
  producing georeferenced, quantisation-consistent outputs.
* Constraint: **nothing may be lost** — every input point/ray must end up in
  exactly one segmentation, no duplicates on tile borders, no tree cut in half.

## Surveyed approaches & verdict (2026-09-23)

### 1. PDAL — the natural primary tool (recommended)
* `pdal tile` (CLI, streaming): `-i cloud.laz -o tiles/tile_#.laz --length <L>
  --buffer <B> --origin_x --origin_y`. Streaming ⇒ bounded memory (~1–2 GB
  regardless of cloud size); `#` = `x_y` tile index; deterministic grid when
  origin is fixed. Docs: [pdal_apps_tile].
* `filters.splitter` (pipeline): same `length` / `origin` / `buffer` options but
  non-streaming (whole file in memory) — use `pdal tile` instead for huge files.
* Crop-back before write is the standard buffer discipline (process the buffer,
  crop to nominal extent so no point is ever written twice):
  `filters.crop` `bounds:<tile>` after processing. Sources: [pythonlidar_buffered_tiling],
  [forestry_gis_pdal]. This is the core of "nothing duplicated".

### 2. LAStools — classic alternative
* `lastile -i large.laz -tile_size 500 -buffer 10 -reversible -o tile.laz`
  → `-reverse_tiling` restores the original file bit-for-bit (VLR in header
  records the tiling; `-remove_buffer`, `-flag_as_withheld`, `-full_bb`).
  Source: [lastools_lastile], [lastools_buffers_blog].
* `lasmerge -i tiles/*.laz -o merged.laz` / `lasduplicate64 -lof files.txt
  -merged` for dedupe of overlapping tiles ([lastools_lasduplicate]).
* Licensing: LAStools is now non-commercial/restricted; prefer PDAL (open
  source, already the pipeline's geo backend). Keep laStools as fallback.

### 3. RayCloudTools native grid → the corrective reference
The only tool that understands "rays" (free space + surface). Official
`scripts/rayextract_trees_large.sh` does *exactly* this task:
```
raysplit cloud.ply grid L,L,0 5        # 5 m overlap to avoid edge artefacts
for each tile: rayextract terrain → rayextract trees --grid_width L
treecombine <tiles>_trees.txt → cloud_trees.txt (+ per-tile georef)
```
Source: [rct_rayextract_trees_large].
**Critical pitfalls found in the RayCloudTools community discussion:**
* `raysplit grid` **cuts rays** along tile planes; rays whose end contact is
  chopped get `alpha=0` ("non-return") — they are kept for free-space ops but
  are not surface, so georeference/rayexport can drop them. Buffer overlap (5 m)
  exists precisely to avoid cutting objects, but the cut is intrinsical to grid.
* **Tree IDs restart at 0 in each tile**; `raysplit seg_colour` per tile gives
  names like `cloud_0_0_segmented_1.ply` (tile+tree), so a global merge needs a
  rename/dedupe pass — you cannot naively concatenate.
* `raycombine` (merge types `all` / `min` / …) merges *ray clouds*, not
  per-tree segment IDs — resolution happens on volumes, not on features.
  See [rct_discussion_33], [rct_doi_2021].

### 4. lidR LAScatalog engine (R) — conceptual template only
Chunk+buffer processing is exactly the *pattern* we need (buffer ensures edge
trees detected; algorithms are run per chunk, output is written per chunk with
the buffer dropped). It is R-specific; our pipeline is bash+PDAL+RCT, so we
borrow the *buffer/crop-back* idea, not the implementation.
Source: [lidr_lascatalog_engine].

### 5. Plot-scale precedent
`wanxinyang/rct-pipeline` tiles scan positions with user-defined overlap and
runs RCT per tile in Docker — confirms tiling+RCT is a used pattern at plot
scale. Source: [rct_pipeline_wanxinyang].

## Recommended design (phase 1)

1. **Tile (streaming, deterministic grid):**
   `pdal tile -i cloud.laz -o tiles/tile_#.laz -l <L> -b <B> -origin_x <X> -origin_y <Y>`
   with `L` ≈ tile edge (e.g. 25–100 m depending on RAM), `B` = overlap buffer
   > widest tree / `rayextract trees` neighbourhood (start 5 m).
2. **Process per tile** with the existing `rayprocess` pipeline, but write every
   tile's nominal extent, crop-back the buffer with `filters.crop` before the
   georeferenced export, and keep the tile index in the output name.
3. **Merge segmentations** (dedupe/attribution, lossless):
   * per-tile `raysplit seg_colour` → per-tree PLY with `tile_x_y_N` naming;
   * dedupe duplicate on borders by a **spatial/token key**: (rounded georeferenced
     base coordinates + tree height) — stable across neighbours, not row order;
   * concatenate treeInfo geojson/sqlite rows under unique global IDs,
     reusing the first-point offset & common LAS scale/offset (already in the
     pipeline) so all tiles share one lattice;
   * keep `treecombine` only for identical-origin runs (single tile partition).
4. **Validate ("nothing lost"):** point count reconciliation (sum of nominal
   tile counts == input count; buffer counts excluded), a few border trees
   visually compared across tiles, LAS header lattice identical in all exports.

## Deliverables / targets of phase 1
* `docs/design_rct_auto_tiling.md` — as above (this file is the seed).
* `cesnet/rayprocess/tiling.sh` + PBS batch wrapper per tile (phase 2).
* `references/sources.yaml` entries listed above.

## Open questions
* `B` (buffer) for `rayextract trees` on our data — 5 m enough?
* `L` (tile size) vs. node RAM / RAS — needs benchmarking on `2022_q34_sample`.
* Merge at the PLY ray-cloud level or the LAS coordinate level? (RCT pitfall†)
* Trajectory-per-tile: a tree spanning two tiles has rays from both; global
  georeference must survive per-tile `rayimport`.

† RCT discussion: `raysplit grid` cuts rays at grid planes (alpha=0 non-returns),
tree IDs repeat per tile, so merge must re-key by geometry, not trust IDs.
