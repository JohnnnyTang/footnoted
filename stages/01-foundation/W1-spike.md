# Stage 1 · W1 — M0 spike harness

**Opens after:** W0. **Parallel sessions:** S01-10, S01-11, S01-12, S01-13 (one dispatch). **Closes into:** W2.
**Purpose:** build the throwaway measurement harness and get first numbers on the dev machine and emulator, so that W2 spends device time only on measurement.

Everything under `spike/` is throwaway. It is deleted from the tree at G1 and kept under the tag `m0-spike`. **Exception (D-008):** the quadkey math written by S01-10 goes into `packages/footnoted_geo` and survives, because W3 hardens it rather than rewriting it.

## Kickoff obligations (orchestrator, foreground, before dispatch)

1. `git switch -c stage/01-foundation` from `main`; push.
2. Re-run the baseline: `dart analyze`, `flutter test` in `app/`, `dart test` in each package. Record the commands and counts in `notes/<date>-W1-kickoff.md`.
3. **Seams (implement once, read-only to sessions):**
   - `spike/FORMAT.md`, the data formats shared by every W1 session:
     - **Trace file** `*.trace.ndjson`: one JSON object per line, `{"ts":<epoch ms UTC>,"lat":<deg>,"lon":<deg>,"acc":<m|null>,"src":"gps"|"media","seg":<int>}`, sorted by `ts`. `seg` is the generator's ground-truth segment id. Each segment also has a header line `{"segment":<int>,"kind":"local"|"transit","mode":"straight"|"great_circle","buffer_m":<m>,"label":"…"}`.
     - **Cell dump** `*.cells.bin`: a little-endian int64 array of z20 cell IDs (F01.1 packing), sorted ascending, no duplicates, with a sibling `*.cells.json` carrying `{count, level, buffer_m, source_trace, sha256}`.
     - **Per-segment cell dump** `*.segcells.bin`: repeated records `[int64 segment_id][int64 n][n × int64 cell_id]`.
   - Workspace skeletons for `spike/tracegen` (Dart CLI), `spike/storage_bench` (Flutter app + `bin/` desktop CLI), `spike/render_bench` (Flutter app, Android + iOS) and `spike/h3_eval` (Flutter app). Add each to the root `pubspec.yaml` `workspace:` list and give each a placeholder test so `dart test` and `flutter test` are green.
   - `packages/footnoted_geo/lib/src/`: empty files `tile_math.dart`, `rasterize.dart`, `dilate.dart` exported from `footnoted_geo.dart`, so that S01-10 owns the content and nobody else needs to touch the barrel file.
4. Confirm ownership (table below), then dispatch all four with the `run-session` skill.

## File ownership

| Path | Owner |
| --- | --- |
| `spike/FORMAT.md`, the root `pubspec.yaml`, `packages/footnoted_geo/lib/footnoted_geo.dart` | **kickoff (frozen for W1)** |
| `spike/tracegen/**`, `packages/footnoted_geo/lib/src/{tile_math,rasterize,dilate}.dart`, `packages/footnoted_geo/test/**`, `packages/footnoted_geo/benchmark/**` | S01-10 |
| `spike/storage_bench/**` | S01-11 |
| `spike/render_bench/**` | S01-12 |
| `spike/h3_eval/**` | S01-13 |
| `stages/01-foundation/notes/*-S01-1n-*.md`, `stages/01-foundation/evidence/S01-1n/**` | each session, its own |

**Merge order:** S01-10 → S01-11 → S01-13 → S01-12. The generator and math come first because W2 consumes them, and the render benchmark goes last because it is the largest.

---

### S01-10 — Synthetic traces + quadkey cell math

**Wave:** W1 · **Branch:** `s01/10-trace-generator` · **Size:** L · **Depends on:** W1 seams

**Goal.** Produce the reproducible five-year dataset (exit criterion 1) and the first real version of the quadkey cell math (z20 tile math, polyline rasterisation, metre-accurate dilation) in `footnoted_geo`. Use it to produce the cell dumps every other spike consumes, and report the cell and row counts that decide G1(c).

**Owns:** `spike/tracegen/**`, `packages/footnoted_geo/lib/src/{tile_math,rasterize,dilate}.dart`, `packages/footnoted_geo/test/**`, `packages/footnoted_geo/benchmark/**`.
**Reads:** `spike/FORMAT.md`, `docs/HANDOFF.md` (Core architecture).

**Deliverables.**
1. `footnoted_geo`:
   - `tile_math.dart`: lon/lat ↔ Web Mercator tile/pixel at any zoom (clamp latitude to ±85.05112878°); `CellId` pack/unpack (F01.1); parent at level L; the cell's ground width in metres at its latitude.
   - `rasterize.dart`: a **supercover** rasteriser (every cell the segment touches, not Bresenham's thinner line) over z20 in Mercator space; a great-circle densifier (interpolate so that no sub-segment exceeds a configurable angular step); **antimeridian handling**: a leg crossing ±180° is split, never drawn the long way round.
   - `dilate.dart`: dilate a set of cells by `buffer_m`. The radius in cells is computed **per row** from that row's latitude (F01.6), using a disk mask rather than a square. Output is sorted unique IDs.
   - Tests: the equator, 60°, an antimeridian crossing, |lat| > 84°, a zero-length segment (a point reveals a disk), and a property test that dilating a rasterised line ⊇ the line.
   - `benchmark/`: time and cell count for a 1,000 km drive with 100 m and 500 m buffers.
2. `spike/tracegen`: `dart run tracegen --seed 42 --years 5 --out <dir>` writes `dataset.trace.ndjson`, `dataset.cells.bin` (union, at the default 100 m local / 500 m road-trip / endpoints-only flight buffers) and `dataset.segcells.bin`. Scenarios: a home city (pick a real dense city, sampled every 150–400 m), road trips of 1,000 km or more, at least ten flights including one across the antimeridian (for example Tokyo → Honolulu), and three foreign city stays.
3. A counts table in the session note: total unique cells, **total (cell, segment) rows**, the equivalent run-length span count, and generation time, **at z20 and z21**.

**Acceptance.**
- [ ] `dart test packages/footnoted_geo` is green with every geography case above.
- [ ] Two runs with `--seed 42` produce identical `sha256` values (recorded).
- [ ] The dataset has ≈1,000,000 unique z20 cells (±30%; adjust the scenario density and record the knob, because exit criterion 2 is defined at about 1 M).
- [ ] The counts table is present, including the 1,000 km × 500 m leg row count (the handoff estimates about 700 k).

**Owner steps:** none.
**Out of scope:** rollups, rectangle merge, H3, and any database. Those belong to W3 and the sibling spikes.
**Traps.** Great-circle interpolation near the poles; floating-point drift at tile boundaries (use integer pixel math at z20, which is 2^28 pixels at 256 px tiles); a dilation radius at 60° is about 2× its value at the equator in cells.

---

### S01-11 — Storage benchmark (layout × driver, under SQLCipher)

**Wave:** W1 · **Branch:** `s01/11-storage-bench` · **Size:** M · **Depends on:** W1 seams

**Goal.** Measure what G1(c) and G1(d) need: per-(cell, segment) rows vs run-length spans, Drift vs raw `sqlite3`, all under SQLCipher with R\*Tree confirmed working. Also settle **how SQLCipher is packaged** for Flutter today.

**Owns:** `spike/storage_bench/**`.
**Reads:** `spike/FORMAT.md`. Until S01-10 merges, generate stand-in corridors yourself; the format is fixed, and W2 swaps in the real dumps.

**Deliverables.**
1. A packaging finding: the current recommended way to get **SQLCipher** with the `sqlite3`/Drift packages on Android **and** iOS (for example `sqlite3` build-hook options vs `sqlcipher_flutter_libs`), whether **R\*Tree** is compiled in, and the licences. Verify by running it, not from the README.
2. Two schemas: **A** `cell_coverage(cell_id, segment_id) PRIMARY KEY WITHOUT ROWID` + `INDEX(segment_id)`; **B** `coverage_spans(segment_id, y, x_start, x_end)` + `INDEX(y, x_start)` + a derived `cell_stats(cell_id PRIMARY KEY, n) WITHOUT ROWID`.
3. Measure for each schema × {Drift batch, raw `sqlite3` prepared statement}, with **SQLCipher on**:
   - bulk-insert of one 1,000 km × 500 m leg, and of the whole dataset;
   - delete one long segment (including the `cell_stats` maintenance for B);
   - the "covered cells in one z10 tile at level L" query for L ∈ {12, 16, 20};
   - database size on disk after `VACUUM`;
   - also once with SQLCipher **off**, to report the encryption overhead.
4. A desktop CLI runner (Windows) **and** a Flutter app runner (Android, release mode) with identical code paths. The app prints a JSON result block to the log and saves it to the app documents directory.

**Acceptance.**
- [ ] A results table for the desktop run is in the note. The Android emulator numbers are marked *emulator* (W2 re-runs on the real phone).
- [ ] The SQLCipher packaging is shown working on the Android emulator: `PRAGMA cipher_version` is non-empty, an R\*Tree `CREATE VIRTUAL TABLE` succeeds, and the file header is not `SQLite format 3`.
- [ ] iOS: the app **compiles** in CI or the session records it as an owner step. No iOS numbers are claimed.

**Owner steps:** none in W1.
**Out of scope:** the production schema (S01-32) and rollup design.
**Traps.** Measure with `PRAGMA journal_mode=WAL` and `synchronous=NORMAL`, and record both. Wrap bulk inserts in one transaction. Warm the cache before timing reads.

---

### S01-12 — Fog render benchmark (`maplibre_gl`)

**Wave:** W1 · **Branch:** `s01/12-render-bench` · **Size:** L · **Depends on:** W1 seams

**Goal.** Find a fog rendering approach that holds exit criterion 2 (median ≥ 55 fps at z10 with about 1 M revealed cells) and a **repeatable fps measurement method** on Android, plus a matching runbook step for iOS.

**Owns:** `spike/render_bench/**`.
**Reads:** `spike/FORMAT.md`. Load a `*.cells.bin` from assets or the device's files directory; before S01-10 merges, use a synthetic random-cluster dump.

**Deliverables.**
1. A Flutter app with `maplibre_gl` showing the **OpenFreeMap dark** style (stock for now; the custom fork is S01-33), with attribution visible.
2. At least two fog strategies behind a toggle:
   - **(a)** a GeoJSON source per visible tile: a tile polygon whose holes are the scanline-merged covered rectangles at a zoom-dependent level, recomputed on camera idle with a cache;
   - **(b)** the inverse: draw dark rectangles over **uncovered** runs only;
   - optionally **(c)** an in-app tile source, to note the effort for the "soft fog" path.
   Implement a minimal rollup and rectangle merge locally in the spike (the production versions are S01-31's).
3. A scripted pan: a fixed camera path at z10 across the home city and a road-trip corridor, run for 20 s and repeated 3×.
4. **The fps method**: Android `adb shell dumpsys gfxinfo <pkg> framestats` and/or Perfetto, plus MapLibre's own frame callback if `maplibre_gl` exposes one. Record which surfaces each method actually measures (the platform view vs the Flutter raster thread). Write `spike/render_bench/MEASURE.md` with exact commands, including an iOS section (Instruments → Core Animation FPS / Animation Hitches) for the owner.
5. Measure both Android platform-view composition modes `maplibre_gl` supports (hybrid composition vs texture layer) and record the trade-offs.

**Acceptance.**
- [ ] The app runs on the Android emulator, and the pan script and fps capture produce numbers (marked *emulator*).
- [ ] `MEASURE.md` lets someone else reproduce the numbers without reading the code.
- [ ] `flutter build apk --profile` is green; the iOS build compiles in CI (or an owner step is recorded).
- [ ] The note recommends which strategy W2 measures on device, with reasons.

**Owner steps:** none in W1.
**Out of scope:** the custom style, the production `FogController` (S01-41), and the database.
**Traps.** The emulator GPU is not representative, so never conclude pass/fail from it. Measure in profile mode, never debug. `setGeoJsonSource` payload size dominates, so measure the serialisation time separately.

---

### S01-13 — H3 and cell-size evaluation

**Wave:** W1 · **Branch:** `s01/13-h3-eval` · **Size:** S · **Depends on:** W1 seams

**Goal.** Give G1(a) and G1(b) an evidence-based recommendation: quadkey z20 vs z21 vs H3 (a resolution of comparable size), weighed on cell counts, compute cost, native-dependency footprint, rendering consequences and stats semantics.

**Owns:** `spike/h3_eval/**`.
**Reads:** `spike/FORMAT.md`, `docs/HANDOFF.md` (Cell grid section).

**Deliverables.**
1. Check that `h3_flutter` (or its current successor) builds on Android, and whether it compiles for iOS in CI. Report its licence, native binary size added, and maintenance activity.
2. For the same corridors (a 1,000 km drive with a 500 m buffer, plus a 5 km city walk with 100 m): the number of H3 cells at the comparable resolution vs quadkey z20/z21, time to cover (H3 `polygonToCells` of the buffered line vs rasterise+dilate), and a compacted-set size.
3. The rendering consequence: vertices needed to draw the fog for a z10 view of the H3 set vs merged quadkey rectangles.
4. The z20 vs z21 consequence: storage ×4, visual blockiness at z16–z18 (screenshots, or a computed pixels-per-cell table), and whether 100 m buffers make the extra resolution pointless.
5. A one-page recommendation in the note.

**Acceptance.**
- [ ] The numbers table and the recommendation are in the note, with the commands used.
- [ ] Any claim about iOS is marked *CI-compile only* or turned into an owner step.

**Owner steps:** none.
**Out of scope:** production code of any kind.
