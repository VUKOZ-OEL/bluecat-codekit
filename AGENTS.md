# AGENTS.md — project working contract

Contract version: 1.0 (adapted 2026-09-23 for the `bluecat-codekit` repository)
Applies to: every AI agent and every human working in this repository.
Owner: `krucek`
Agent name: `hermes` — recorded in every commit it makes (§10.2).
Base branch: `main`.
Remote: `origin` → `https://github.com/VUKOZ-OEL/bluecat-codekit`

> **Adaptation note (vs. the standard template).** This repository is a
> *pushed*, GitHub-hosted repo: `cesnet/segment.sh` clones a concrete remote
> branch of this very repository
> (`--branch codex/rayprocess-georeferenced-results`). Work therefore lives on
> **feature branches pushed to `origin`**, not on local-only `analysis/* /
> code/* / sandbox/*` branches. The branch model in §9 is adapted to this
> reality; the rest of this file follows the standard working contract.

An agent MUST read this file at the start of every session, before touching any file.

---

## 0. How to read this file

* **MUST / MUST NOT** — hard rule. If you cannot comply, stop and report; do not work around it.
* **SHOULD** — default behaviour. You may deviate, but the deviation MUST be recorded in the session record with a reason.
* Words in `code font` are literal paths, branches, or values.

This file is the only normative source for how work is done here. `README.md` and the per-directory READMEs are descriptive; where they disagree with this file, this file wins.

An agent MUST NOT edit this file unless explicitly instructed to. Proposed changes go into the session record / pull request description.

---

## 1. Session start

Every session, in this order:

1. Run `git status` and `git branch --show-current`; record the branch and whether the tree was dirty. Do not discard or stash unrelated changes.
2. Read `README.md` and the most recent `STATUS_*.md` for context; read `docs/PROJECT.md` if it exists.
3. If the task is analytical, read `docs/METHODS.md` if present, and the relevant per-directory READMEs (at least `cesnet/rayprocess/readme.md`, `cesnet/readme.md`).
4. `git pull --ff-only origin <current branch>` to sync with the remote before starting work.
5. Start a feature branch for this work (§9.3) if not already on one. Never commit on `main`.
6. **Restate the task in one sentence and name the expected output path — before producing anything.** If you cannot write that sentence, you do not understand the task: ask.

---

## 2. Two tiers of work

Not every task deserves the full record. Choose the tier explicitly and say which one you chose.

**Tier A — quick work.** Exploration, a one-off number, a formatting fix, a question answered from existing data. Answer in the chat; nothing else. Tier A output MUST NOT be presented as a project result.

**Tier B — registered work / feature.** Needs detailed HPC context, research output, or is a change that can plausibly be re-run, reviewed, or shipped to MetaCentrum. Full record: commit(s) with clear messages, a session-log Markdown file (e.g. `docs/notes_<topic>.md`), and a write-up of what was done, what was verified, and what is left.

Use Tier B if **any** of these is true:

* the result will be shown to anyone outside this session, or used in a decision;
* it reads a production dataset on MetaCentrum or runs a heavy computation;
* it will plausibly be re-run or updated later;
* it changes the behaviour of `cesnet/rayprocess/` or any script shipped to MetaCentrum;
* it produces a deliverable file.

If you are unsure which tier applies, use Tier B.

---

## 3. Stop and ask

An agent MUST stop and ask the owner rather than choose, when:

* the task can be read two ways and the readings give different results;
* a required input (dataset, image, trajectory) is missing or empty;
* code and documentation contradict each other;
* completing it would require one of the MUST NOTs in §4;
* the result contradicts previously published results in the repo.

Asking is never a failure. Guessing and proceeding is.

---

## 4. Prohibited actions

An agent MUST NOT:

1. **Invent any value.** Not numbers, results, dates, checksums, or file contents. Unknown values are written as `UNKNOWN` or left empty — never filled with a plausible-looking placeholder.
2. Modify, rename, clean, convert, re-save, or delete any production dataset on MetaCentrum. Test on copies in `test_runs_output/`, never on originals.
3. Commit secrets, credentials, tokens, `.env`, or any file matching `.gitignore`
   (which includes local test outputs: `test_runs_output/`, `.img`, `.tar`, and other generated data).
4. Rewrite Git history: no `rebase`, `cherry-pick`, `reset --hard`, `commit --amend`, `push --force`, `filter-branch`. Merging `main` is done by the owner (or by the agent from an *independent* feature branch per §9.4); never force anything.
5. Delete any tracked file. Move it to an `archive/`-style location or ask.
6. Run computationally heavy commands (PDAL, RayCloudTools, singularity images) unless the task requires it; say so when you do. Prefer the Docker workflow for RayCloudTools on Windows (see README) over native runs.
7. Present an unvalidated number as a result. Every number in a report MUST be traceable to a command that was actually run.

---

## 5. Data handling

* Datasets are large LiDAR files in LAS/LAZ/PLY format. They live on MetaCentrum
  (`/storage/.../krucek/...`) or in `test_runs_output/` — **never in Git**.
* Production datasets are owned by VÚKOZ / krucek and have contractual limits.
  Do not upload, publish, or paste them into third-party services.
* Test with small subsamples (e.g. the existing `2022_q34_sample_25x25` cloud)
  before full runs.
* External lookups (docs, papers, GitHub) are fine.

---

## 6. Directory map

```text
cesnet/               PBS/HPC payload: scripts pulled into the MetaCentrum scratch dir
  rayprocess/         the RayCloudTools + PDAL pipeline (the segmented-cloud producer)
  tools/              assorted helper scripts (voxelize, hdmap, filter_noise, …)
  helios/             HELIOS++ simulation assets
docker/               Docker / Singularity images (r-lidar-tools, cloudcompare, raycloudtools)
py_scripts/           one-off Python utilities
census_test_code/     R-based census verification code
docs/                 durable knowledge (PROJECT, METHODS, notes, STATUS)
config/               reproducibility-relevant parameters (tile size, buffer, thresholds)
src/                  canonical reproducible code
references/           registry of external sources used in research
working/              disposable scratch — never a dependency of finished work
archive/              superseded material retained for provenance
test_runs_output/     local test runs (git-ignored)
```

Rules that are not obvious from the map:

* A script that already works in `cesnet/rayprocess/` stays there; new
  reproducible logic SHOULD land in `src/` + `config/` where it can be tested.
* `working/` is git-ignored and may be wiped at any time.
* `test_runs_output/` is git-ignored: never commit run outputs.

---

## 7. Reproducibility

* Every derived value a reader might want to change — tile size, buffer/overlap
  width, voxel resolution, decimation levels, LAS scale/offset, grid origin —
  MUST be parameterised (script argument or `config/`), not hard-coded.
* Analytical corrections MUST be scripted, never done by hand in a derived file.
* Any randomness MUST have a fixed seed, recorded.
* Derived data / run outputs are by default NOT committed to Git; they must be
  regenerable from the scripts.

---

## 8. External sources

When external material contributes to a result:

1. Register each source in `references/sources.yaml` (create it if missing).
2. Associate important claims with the source ID in the write-up.
3. Never fabricate bibliographic metadata; fields you could not verify are left empty and marked `verified: false`.

---

## 9. Branching model (adapted — pushed repository)

### 9.1 The repository

The repository is hosted at `https://github.com/VUKOZ-OEL/bluecat-codekit`. It
**has** a remote, and `cesnet/segment.sh` clones concrete branches of it — so
the branches an agent works on MUST be reachable on `origin`.

### 9.2 Agent identity

```bash
git config user.name  "hermes"
git config user.email "hermes@agents.local"
```

Every commit also carries an `Agent:` trailer (§10.3).

### 9.3 Branches

| Branch | Holds | Merged into `main` |
| --- | --- | --- |
| `main` | production truth | — never worked on directly |
| `<topic>/<description>` | one cohesive piece of work (new branch per issue) | by the owner, after review |
| existing `codex/rayprocess-georeferenced-results`, … | historic work branches | by the owner |

**Which branch does this change belong on?** New work on the tiling pipeline
goes on a fresh branch such as `rct_auto_tiling` (or `codex/<topic>` for
smaller codex-style changes). Follow the existing naming convention:
`codex/<topic>` or `<topic>/<description>`. Push the branch to `origin` early
and keep it in sync.

### 9.4 Merging & pushing

* `main` is merged by the owner after review.
* The agent MAY fast-forward-merge its **own** feature branch into `main` only
  if the owner explicitly asked for it. Prefer pushing the branch and opening a
  PR / asking the owner to review and merge.
* If the owner already merged the branch into `main`, the agent continues work
  on a fresh branch from the updated `main` (never force anything).
* Push the feature branch to `origin` as soon as it has a first coherent commit,
  and keep it in sync: `git push -u origin <branch>`.

### 9.5 Why no local-only branches here

`analysis/*`, `code/*`, `sandbox/hermes` from the pristine template would be
the normal choice for a local-only repo. Here, scripts are deployed by cloning
specific remote branches, so a branch that exists only on a local disk cannot
be run on MetaCentrum. Feature branches therefore live on `origin`.

---

## 10. Committing

### 10.1 Starting

```bash
git pull --ff-only origin main   # sync
git switch -c <topic>/<description>
```

If the tree is dirty with changes the agent did not make, **stop and ask**.
Never stash, discard, or commit someone else's work.

### 10.2 Committing is automatic

The agent commits on its own initiative, without asking. `git add` and
`git commit` need no approval. A local commit is cheap and reversible; lost
work is not.

Commit at the first coherent stopping point after any trigger fires:

| # | Trigger |
| --- | --- |
| 1 | A unit of work is done |
| 2 | **Size** — ≥ 3 files changed or ≥ 150 lines since last commit |
| 3 | Before anything destructive (regenerating derived data, bulk rename) |
| 4 | Validation passed |
| 5 | Before asking the owner a question |
| 6 | Branch is about to change |
| 7 | End of session — never leave the tree dirty |

**One commit = one reason.** If the message needs the word "and" to describe
unrelated work, it should have been two commits.

### 10.3 When not to commit, and how

* The tree is knowingly broken → commit as `wip:` with the breakage named.
* Anything matching `.gitignore` (including `test_runs_output/`), anything
  containing a secret, or any modified production dataset → never stage.

**Never `git add -A` or `git add .`.** Read `git status --porcelain`, then stage
by explicit path. Blanket staging is how secrets and scratch files end up in
history.

Message format:

```text
<type>(<scope>): <what changed, imperative, ≤ 72 chars>

<why, when the diff does not make it obvious. Wrap at 72.>

Agent: hermes
```

Types: `feat` `fix` `data` `config` `docs` `report` `test` `chore` `wip`.

```text
docs(rct_auto_tiling): add tiling research notes and solution design

Surveyed PDAL splitter/tile, LAStools lastile/merge and the
RayCloudTools raysplit-grid + treecombine workflow; documented
edge/duplicate pitfalls and the recommended buffered-tile design.

Agent: hermes
```

### 10.4 Pushing

* Push after every coherent unit of work onto the feature branch:
  `git push -u origin <branch>`.
* `push --force` is prohibited (§4.4). If a push is rejected because the remote
  advanced, pull with `--ff-only` / merge carefully in a new commit — never rebase.

---

## 11. Completion

Work is complete only when the agent has emitted the block below, with real
evidence — a path, a command, or an explicit reason. `N/A` requires a reason.
An unfilled item means the work is not complete.

```text
COMPLETION REPORT
tier:              A | B
branch:            <branch>
commits:           <n> commits, <first sha>..<last sha>
tree clean         PASS | FAIL   (git status --porcelain is empty)
pushed to origin   PASS — <branch> | N/A — <reason>

production data untouched     PASS | FAIL
code in src/ or cesnet/       <paths> | N/A — <reason>
parameters in config/         <paths> | N/A — <reason>
no dependency on working/     PASS | FAIL
validation executed           <commands run + result> | N/A — <reason>
results reproducible          <exact commands a second person would run>
external sources registered   <source IDs or references/sources.yaml entry> | N/A
limitations documented        <where>
open questions                <list> | none
```

The last line is not optional. If nothing is uncertain, write `none`.

---

## 12. Definitions

* **Material / substantive** — changes a number in a deliverable, or would change a reader's conclusion.
* **Validation** — a check that could have failed: point counts against source, header checks, a test in `tests/`, a round-trip. Re-reading your own output is not validation.
* **Reproducible** — regenerable from scripts + parameters by running listed commands, with no manual step.
* **Owner** — `krucek`; the one who decides merges into `main` and production runs.
* **Coherent stopping point** — the tree is internally consistent: no file half-written, and the project's documented commands would still run.
