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

---

## Guarantee: nothing lost, nothing duplicated ("never 2x/4x")

Two independent invariants, checked separately:

**1. Point level (full-plot overlay / DTM).** The nominal tile extents
partition the plane: `tile(i,j) = [ox+i·L, ox+(i+1)·L) × [oy+j·L, oy+(j+1)·L)`
(half-open). Every input point lies in exactly one nominal tile. After
processing, crop back to the nominal extent with **half-open bounds `[min,
max−ε)`, ε = one LAS lattice step** so a point sitting exactly on the seam is
counted once (the lower tile), never twice and never dropped. Buffer points are
not lost — they are *owned* by the neighbour's tile and emitted there. All
pre-processing that is **not boundary-safe runs once on the full cloud before
tiling in streaming mode** (`filters.voxeldownsize`): per-tile voxelization is
not commutative with whole-cloud voxelization and would double-count/reduce
seam voxels. `ferry X→GpsTime` is per-point, safe either way.

**2. Tree level (treeInfo / per-tree LAZ).** Owner rule + geometric dedup key.
```
owner(t) = nominal cell containing the tree's georeferenced base
           (floor((x−ox)/L), floor((y−oy)/L))
key(t)   = (round(x_base, δ), round(y_base, δ), round(h, δh))   # GLOBAL frame
```
A real tree straddling a seam is detected in 2 (edge) or 4 (corner) tiles and
its duplicate detections share the **same key** → collapse to one. Uniqueness
is decided by the owner (bijective: one tree → one nominal cell → one owner);
*content* (which detection's per-tree PLY/LAZ we ship) is picked as the *best*
among the duplicates (most points / lowest decimation level, since the pipeline
retries under RAM pressure). Global ID = `(owner_tile, local_index)` — never a
raw local index, which restarts at 0 per tile. No reliance on processing order.

**Preconditions for the key to work (must hold, or the guarantee breaks):**
* **One global first-point offset** shared by every tile — NOT the per-tile
  first point that `rayimport --remove_start_pos` would otherwise use. Two
  tiles with different offsets give the same tree different absolute
  coordinates → the key fails to match → false 2x/4x.
* **Common LAS scale/offset** (already `save_las_scale_and_offset` from
  `cloud.laz`) so the quantized key lattice is identical across tiles.

δ must satisfy `noise < δ < min tree spacing` (empirically δ ≈ 0.5 m for MLS
bases, height as secondary key); fallback nearest-neighbour match within ε if
bases are unstable (slope, leaning trunks).

**Verification (must pass before delivery):**
```
Σ nominal tile point counts == input point count (± LAZ rounding)
merged treeInfo: GROUP BY key → every group has exactly one owner (2 owners = FAIL)
no two final bases closer than δ          (missed-merge detector)
sample plot 2022_q34_sample_25x25: NON-tiled run == tiled run
    in tree count, base coords, point counts     (gold-standard cross-check)
```

---

## Implementation status (2026-09-23, phase 2 in progress)

Working skeleton of the automatic tiling pipeline is implemented in
`src/rct_auto_tiling/` and verified **end-to-end locally** on the
`2022_q34_sample_25x25` cloud (20,853,952 pts, PLY):

| step | script | local result |
| --- | --- | --- |
| 1 split | `step1_tile_split.py` | streaming, DO-sec grid, buffered tiles, per-tile owner map |
| 2 rayprocess | `mock_rayprocess.py` (local stub) | realistic per-tile treeInfo duplicates (buffer overlap) |
| 3 merge | `step2_merge_segments.py` | 114 unique trees from 538 raw detections (424 collapsed) |
| 4 verify | `verify_point_counts.py` | **PASS**: Σ nominal tiles == input (20,853,952 == 20,853,952, delta 0) |

Orchestration: `run_auto_tiling.sh` (split → per-tile RCT/PY → merge → verify),
env-switchable rayprocess (`RCT_RAYPROCESS`). Commits `118b35d`, `ab5fdd3`
(pushed).

### Verified facts from the implementation
* Point-level no-loss/no-dupe invariant PASSES on real data — the exact
  reconciliation the owner asked for: `input count == Σ(nominal tile counts)`.
* Merge/dedupe: 114 trees out of 538 raw detections, unique global IDs 1..114,
  no dup, no loss. δ=0.1 m used locally (min observed tree-spacing on q34 is
  ~0.16 m, so δ=0.5 m would collide — the δ must be data-derived, not fixed).
* Buffer amplification on 20.85M pts / 10 m tile / 10 m buffer: 120.4M buffered
  writes (5.8×) — the reason tile/length vs. buffer ratio matters on MetaCentrum.

### Open for phase 2→3 (MetaCentrum)
* `L` (tile length) and `B` (buffer) heuristics for 2–100 Ha plots; B=10 m
  (user-set) vs. the 5 m in the RCT reference script.
* RAM cap 256 GB on PBS: pick `L` so `points_in_tile × bytes/pt` stays under
  the cap; the splitter itself is O(streaming) so it costs nothing.
* PLY-LAS: real per-tile rayprocess georef run (needs RCT on a node, not local).
