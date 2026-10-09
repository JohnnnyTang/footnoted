# Stage 1 — Foundation (M0 spike + M1 foundation)

**Stage opened:** 2026-10-08 (planning). **Branch:** `stage/01-foundation`, cut from `main` by the W1 kickoff.
**State:** `ACTIVE`. W0 and W1 (spike harness) are merged. **W2 waits on the owner's Android phone.**
**Milestones:** M0 (performance spike, throwaway harness) + M1 (foundation), per [`HANDOFF.md`](../../docs/HANDOFF.md#milestones) and D-002.
**Backlog:** [`VERIFICATION_BACKLOG.md`](VERIFICATION_BACKLOG.md) (`S01-V###`, `S01-E#`).
**Waves:** [W0](W0-bootstrap.md) · [W1](W1-spike.md) · [W2](W2-measure-and-decide.md) · [W3](W3-building-blocks.md) · [W4](W4-pipeline-and-fog.md) · [W5](W5-integrate-and-verify.md)

## Objective

Prove that the cell-grid model performs on real phones, settle the four storage/grid decisions from measurements instead of guesses, and then build the foundation every later milestone stands on: a Flutter app for both platforms, an encrypted SQLite database carrying the **full** schema, a tested cell-grid library, a reveal pipeline with per-segment provenance, and blocky fog on a custom dark map with correct attribution.

At the end of the stage, a hard-coded segment reveals correctly at every zoom, and deleting it restores the fog exactly. This is the M1 exit.

## Exit criteria

Tags: **[auto]** an automated test in CI · **[device-A]** run by an agent on the owner's Android phone · **[owner-iOS]** run by the owner on their Mac + iPhone (D-009) · **[doc]** a written artifact.

**M0: spike and decisions**

1. **[auto][doc] Reproducible dataset.** A seeded generator produces five years of synthetic traces: a dense home city (daily commutes plus weekend walks), at least three road trips of 1,000 km or more, at least ten flights including one across the antimeridian, and a few foreign city stays. Same seed → byte-identical output.
2. **[device-A][owner-iOS] Pan performance.** With about 1,000,000 revealed z20 cells loaded, a scripted 20-second pan at **z10** in a **profile/release** build holds a **median ≥ 55 fps with ≤ 5% of frames over 32 ms** on the owner's mid-range Android and on the owner's older iPhone. The method, device model, OS and build mode are recorded.
3. **[doc] Measured storage.** On-device database size, bulk-insert time, delete-segment time and tile-query latency for **per-(cell, segment) rows vs run-length spans**, plus **Drift vs raw `sqlite3`** on the write path, all under SQLCipher.
4. **[doc] Gate G1 ruled.** Written decisions on (a) quadkey vs H3, (b) z20 vs z21, (c) the coverage storage layout, (d) confirming or overturning D-003 (Drift), and (e) the fog geometry approach. Each cites its numbers. The **F01 contract** is frozen (see below). The `spike/` directory is removed from the tree and tagged `m0-spike`.

**M1: foundation**

5. **[auto] App builds on both platforms.** `flutter build apk` (Windows and CI) and `flutter build ios --no-codesign` (CI `macos-latest`) are green, using temporary IDs (D-006).
6. **[auto][device-A][owner-iOS] Map with identity.** A custom dark style derived from OpenFreeMap dark, rendered by `maplibre_gl`. Attribution is **always visible** on the map ("© OpenStreetMap contributors" linked to the ODbL page, and "OpenFreeMap © OpenMapTiles Data from OpenStreetMap"), and repeated on an About/Licences screen alongside the package licences.
7. **[auto] Full encrypted schema.** Every table in the handoff schema sketch, including the ones whose UI comes later, plus the derived tables (`segment_geometry`, coverage per F01, `cell_rollups`, per-cell stats) and `app_meta`. SQLCipher is on, and the key is held in the platform keystore. A test proves the database file is **not** readable as plain SQLite. R\*Tree works under SQLCipher. Migrations use Drift schema snapshots with a migration test harness (v1 baseline).
8. **[auto] Cell-grid library.** Rasterise (straight and great-circle), dilate by metres at latitude, rollups (for example z16/z12/z8), and scanline rectangle merge, with unit tests **at the equator, at 60°, across the antimeridian and near the poles**.
9. **[auto] Provenance and rebuild.** Adding, editing and deleting a segment returns per-cell counts **exactly** to their prior values. Dropping every derived table and rebuilding from raw data reproduces identical coverage, rollups and stats (compared by content hash). Switching connection mode preserves vias. A correction never alters the original `points` row.
10. **[auto][device-A][owner-iOS] Blocky fog.** For each visible tile, covered cells at the matching level are merged into rectangles, and "tile minus rectangles" is drawn as a dark fill. The fog stays correct at every zoom from z0 to z20.
11. **[auto][device-A][owner-iOS] The M1 exit.** A hard-coded segment set (a city walk, a 1,000 km drive, and a flight across the antimeridian) reveals correctly at every zoom, and deleting it restores the fog **exactly**. Automated: the covered-cell set and the fog geometry after delete equal the empty baseline. On device: a screenshot pair per platform.
12. **[auto] Invariant guards.** CI fails on a denylisted or non-open-licensed dependency (invariant 1) and on `ACCESS_BACKGROUND_LOCATION` in the Android manifest. The `Entitlements` service (every check true) and the first-use timestamp exist. No network host is contacted other than the tile/style/glyph hosts.
13. **[doc] Docs true.** `HANDOFF.md` is updated wherever the build diverged; the decision log, `docs/README.md` and this README are current.

## The F01 contract (frozen at G1)

These are the cross-package seams W3–W5 build against. Until G1 they are **proposals**, and the spike may change any of them.

| Clause | Proposal before G1 |
| --- | --- |
| F01.1 Cell ID | Web Mercator tile `(x, y)` at **z20**, `id = (x << 20) \| y`, stored in an int64. A level-`L` parent is `(x >> (20-L), y >> (20-L))` with the same packing at that level. |
| F01.2 Coverage storage | Logical model: one record per **(cell, segment)**. Physical layout chosen by G1: per-cell rows `cell_coverage(cell_id, segment_id) WITHOUT ROWID` **or** spans `coverage_spans(segment_id, y, x_start, x_end)` plus a derived `cell_stats(cell_id, n_segments)`. |
| F01.3 Rollups | Levels **16, 12, 8** (G1 may change them). `cell_rollups(level, cell_id, n_children_covered)`. A rebuildable cache. |
| F01.4 `CoverageReader` | `Future<List<CellId>> coveredCells(TileId tile, int level)` plus `Stream<CoverageChange>` for invalidation. This is the only API the fog renderer may use to read coverage. |
| F01.5 Display geometry | `SegmentGeometry { segmentId, mode, List<LatLng> vertices, bool inferred }`, derived from member points (corrections applied, latest wins) plus vias. `road` is unsupported in Stage 1 (falls back to `straight` with `inferred = true` and a log line). `none` → no line; the points reveal on their own. |
| F01.6 Buffer | The effective buffer is `segments.buffer_m ?? default(kind)` (D-007). Dilation radius is computed **per cell row** from that row's latitude, because a long north–south leg changes cell width along its length. |

## Waves at a glance

```
W0 ─▶ W1 (4 parallel) ─▶ W2 (measure) ─▶ G1 ─▶ W3 (4 parallel) ─▶ W4 (3 parallel) ─▶ W5 (integrate, verify) ─▶ exit
      spike harness        on-device       owner    building blocks    pipeline + fog         M1 exit on devices
                           numbers         rules
```

| Wave | Purpose | Sessions (parallel within the wave) | Owner involvement |
| --- | --- | --- | --- |
| [W0](W0-bootstrap.md) | Plan, repo, toolchain, Claude config, scaffold | S01-00 (this planning session, foreground) | Answered planning questions ✔ |
| [W1](W1-spike.md) | M0 harness and first measurements | **S01-10** trace generator + quadkey cell math · **S01-11** storage benchmark · **S01-12** fog render benchmark · **S01-13** H3 and cell-size evaluation | none |
| [W2](W2-measure-and-decide.md) | On-device numbers, then gate G1 | **S01-20** integrated spike + Android measurement · **S01-21** iOS measurement (owner runs the runbook) · *S01-22 conditional perf remediation* | **Plug in the Android phone; run the iOS runbook; rule G1** |
| [W3](W3-building-blocks.md) | M1 building blocks | **S01-30** app shell · **S01-31** cell-grid library · **S01-32** encrypted database · **S01-33** map + dark style + attribution | Confirm D-007 buffer at kickoff |
| [W4](W4-pipeline-and-fog.md) | Derived pipeline and fog | **S01-40** reveal pipeline + provenance · **S01-41** blocky fog renderer · **S01-42** invariant guards + CI hardening | none |
| [W5](W5-integrate-and-verify.md) | Wire end to end; verify the exit | **S01-50** end-to-end wiring + dev harness (wiring owner) · then **S01-51** exit verification + docs | **Android phone; iOS run on the Mac** |

**15 sessions** (plus one conditional) across 5 implementation waves. Each wave file carries the briefs, the file-ownership table and the merge order.

### Session index

| ID | Title | Size | Wave | Depends on |
| --- | --- | --- | --- | --- |
| S01-00 | Planning + bootstrap | L | W0 | — |
| S01-10 | Synthetic traces + quadkey cell math | L | W1 | W1 seams |
| S01-11 | Storage benchmark (layout × driver, SQLCipher) | M | W1 | W1 seams |
| S01-12 | Fog render benchmark (`maplibre_gl`) | L | W1 | W1 seams |
| S01-13 | H3 + cell-size evaluation | S | W1 | W1 seams |
| S01-20 | Integrated spike + Android measurement | M | W2 | W1 merged |
| S01-21 | iOS measurement runbook + owner run | S | W2 | S01-20's build |
| S01-22 | *(conditional)* perf remediation | M | W2 | a failed criterion 2 |
| S01-30 | App shell (structure, l10n, theme, about, entitlements) | M | W3 | G1 |
| S01-31 | Cell-grid library (production) | L | W3 | G1 |
| S01-32 | Encrypted database + full schema + migrations | L | W3 | G1 |
| S01-33 | Map widget + dark style + attribution | M | W3 | G1 |
| S01-40 | Reveal pipeline + provenance + rebuild | L | W4 | W3 merged |
| S01-41 | Blocky fog renderer | L | W4 | W3 merged |
| S01-42 | Invariant guards + CI hardening | M | W4 | W3 merged |
| S01-50 | End-to-end wiring + dev harness | M | W5 | W4 merged |
| S01-51 | Exit verification + docs | M | W5 | S01-50 |

## Risks carried into the stage

| Risk | Where it is tested | Fallback |
| --- | --- | --- |
| A 1,000 km × 500 m leg is about 0.7–1.4 M rows; per-cell rows may be too heavy. | S01-11, G1 | Run-length spans (F01.2). |
| A GeoJSON fog source with many holes stutters at z10. | S01-12, S01-20 | Pre-merged rollup levels; fewer, larger rectangles; or an in-app raster/vector tile source (the soft-fog path, pulled forward). |
| Packaging SQLCipher with Drift (`sqlite3` build hooks vs `sqlcipher_flutter_libs`) and R\*Tree availability in that build. | S01-11 | Pin whichever packaging gives SQLCipher + R\*Tree on both platforms; record it in G1. |
| `maplibre_gl` platform-view composition costs (hybrid vs texture) on Android. | S01-12 | Record both; choose at G1. |
| No Mac on the agent side. | All iOS rows | Owner runbooks (D-009); CI `--no-codesign` build. |
| Generated data is not representative. | S01-10 | Calibrate the density to the handoff's "a fix every few hundred metres". |

## Current status

- **2026-10-08. W0 / S01-00 done.** The handoff was read and the plan written (this directory plus kickoff docs for Stages 2–6). Owner rulings D-001…D-005 were obtained. The repo `JohnnnyTang/footnoted` was created (public, MPL-2.0). Flutter 3.47.7 and the Android SDK were installed on the dev machine. The workspace was scaffolded (`app/`, `packages/footnoted_geo`, `packages/footnoted_data`), along with CI, the Claude Code configuration (skills, hooks, plugins, Dart MCP) and the docs index. See [W0-bootstrap.md](W0-bootstrap.md). Local `flutter build apk --debug` is ✓ and the app runs on the AVD `fn_api36`. **The first CI run is green** on `21670f0`, in [run 37882963659](https://github.com/JohnnnyTang/footnoted/actions/runs/37882963659): checks 1m25s, Android build 3m26s, iOS `--no-codesign` 3m12s.
- **2026-10-09. W1 kickoff done.** `stage/01-foundation` cut from `main` @ `042f23f`; seams in `d25be78` (`spike/FORMAT.md`, four spike package skeletons, `footnoted_geo` src stubs, CI for spike + session branches). Baseline 11 tests green, analyze and format clean, check_deps 61 packages. See [the kickoff note](notes/2026-10-09-W1-kickoff.md). S01-10, S01-11, S01-12, S01-13 dispatched in parallel. **Correction of record (2026-10-09):** the baseline was 10 tests, not 11 (see the kickoff note).
- **2026-10-09. W1 merged.** [Close note](notes/2026-10-09-W1-close.md). Suite on the merged tree: 85 tests green (+75 on 10), analyze/format clean, check_deps 115 packages. **No exit criterion is decided yet**; every frame-rate and storage number is emulator or desktop.
  - **S01-10** ✓ seed-42 five-year dataset, 1.17 M unique z20 cells, 9.71 M (cell, segment) rows vs 458 k spans, deterministic; `footnoted_geo` tile math, supercover rasteriser, per-row disk dilation (+39 tests). Road trips reuse one corridor to hold the ≈1 M target.
  - **S01-11** ✓ with caveats: SQLCipher via `sqlite3` build hooks (root-pubspec setting, S01-V005); spans 2.8× smaller and 2–4× faster to query than per-cell rows, delete slower; Drift typed batch 1.7–4.5× slower than raw. Stand-in data; SQLCipher proven from a standalone copy; iOS SQLCipher not compiled yet.
  - **S01-12** ✓ emulator only: recommends fog (a) holes d6 on GLSurfaceView/VD; `MEASURE.md` runbook; needs JDK 21 and a GMS exclusion (S01-V012, S01-V013).
  - **S01-13** ✓ recommends quadkey z20 with an exact dilation radius over H3 and z21.
- **2026-10-09. W2 kickoff, part 1.** The owner ruled S01-V005 → **D-011**: the SQLCipher build-hook setting is in the root `pubspec.yaml`, and the in-workspace probe reports `cipher_version` 4.19.0 community with R\*Tree on. Suite unchanged at 85. Nothing dispatched. See [the W2 kickoff note](notes/2026-10-09-W2-kickoff.md).
- **Next:** the W2 kickoff, part 2 (`orchestrate-wave`): the owner connects the Android phone (S01-E1) and confirms the Mac + iPhone (S01-E2); then S01-20.

## Blockers that still bind

- `S01-E1` — **Owner's Android test phone**: the model and USB debugging are needed by W2 (S01-20). **Blocks the W2 kickoff.**
- `S01-E2` — **Owner's Mac + older iPhone** with Xcode, for S01-21 / S01-51. Not blocking W1.
- D-007 (default buffer) awaits owner confirmation at the W3 kickoff.
