# D:\rct_segmentation — helper directories (tiling work)

These folders follow the working contract in `AGENTS.md`:

- `docs/` — durable project knowledge: `notes_rct_auto_tiling.md` (research
  + solution design for the automatic tiling pipeline).
- `config/` — reproducibility-relevant parameters (tile length, buffer/overlap,
  grid origin, voxel resolution). Scripts must read tunables from here or from
  explicit arguments, not hard-code them.
- `src/` — canonical reproducible code (bash/python extracted from the
  `cesnet/rayprocess/` payload, or new components of the tiling pipeline).
- `working/` — disposable scratch (git-ignored).
- `references/sources.yaml` — registry of external sources used by the research.
