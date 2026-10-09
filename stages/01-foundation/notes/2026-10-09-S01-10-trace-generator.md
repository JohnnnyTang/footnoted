# 2026-10-09 — S01-10 Synthetic traces + quadkey cell math

**Stage:** 01 · **Wave/session:** W1 / S01-10 · **Branch:** `s01/10-trace-generator` (from `stage/01-foundation` @ `3e2226f`) · **Author:** session agent

## Summary

All four acceptance items are met. What needs attention:

- **The brief's ≈1 M target conflicts with "three road trips of 1,000 km or more at 500 m".** One distinct 1,000 km × 500 m corridor is 0.76 M cells at the equator and 1.44 M at 45°, so three distinct corridors would give 2.3 M to 4.3 M cells. I met both requirements inside my owned code: the home city is low-latitude (Mexico City, 19.4°N), and all three road trips reuse one highway corridor (CDMX → Querétaro → SLP → Saltillo → Monterrey → Nuevo Laredo). The orchestrator should confirm this reading at the W1 close.
- **`--walk-scale` is a weak knob.** Over the range 0.5 to 2.0 it moves the total by only −3 % to +2 %. The road corridor sets the count (907 k of 1.17 M cells).

What landed:

- `footnoted_geo` has the z20 tile math, a supercover rasteriser with a great-circle densifier and antimeridian handling, and a per-row disk dilation. It has 39 tests and a 1,000 km drive benchmark.
- `spike/tracegen` writes the FORMAT.md trace, the cell dump and the per-segment dump for any level, and the output is deterministic. Seed 42 over 5 years gives **1,169,242 unique z20 cells** and **9.7 M (cell, segment) rows**. Two runs gave identical SHA-256 values for every file.

## Changes

| File | What |
| --- | --- |
| `packages/footnoted_geo/lib/src/tile_math.dart` | `LatLng`; lon/lat ↔ Mercator ↔ integer pixel/tile at any level ≤ 22 (lat clamped to ±85.05112878°, lon 180 wraps to 0); `packCell`/`cellX`/`cellY`/`parentCell` (`(x << L) \| y`); `CellId` extension type (z20, F01.1); `groundResolutionMeters`, `rowWidthMeters`. |
| `packages/footnoted_geo/lib/src/rasterize.dart` | `supercoverPixels` is an integer grid walk with no division: it compares `bx·dy` with `by·dx` and visits both side cells at an exact corner. `densifyGreatCircle` uses slerp with a configurable max step and rejects antipodal pairs. `rasterizePolyline` handles straight and great-circle legs; a leg whose longitudes differ by more than 180° is unwrapped and drawn the short way, with columns taken modulo 2^L. Also `centralAngle`, `greatCircleMeters` and `sortedUnique`. |
| `packages/footnoted_geo/lib/src/dilate.dart` | `dilateCells` groups source cells into row runs. Each run adds one interval per target row from a disk mask (`dx² + dy² ≤ r²`, with `r = ceil(buffer / rowWidth(source row))`). Intervals are merged per row, wrapped at ±180°, and dropped beyond the world's edge rows. Output is sorted and unique. Also `dilationRadiusCells` and `diskHalfWidths`. |
| `packages/footnoted_geo/test/{tile_math,rasterize,dilate}_test.dart` | 38 new tests (the existing smoke test is kept). |
| `packages/footnoted_geo/benchmark/drive_benchmark.dart` | 1,000 km drives (equator, 45° E-W and diagonal, CDMX → N. Laredo, 40→49° N-S, 60°) × z20/z21 × 100/500 m. Reports time, cells and spans. |
| `spike/tracegen/lib/**`, `bin/`, `test/tracegen_test.dart`, `README.md`, `pubspec.yaml` | The generator: a SplitMix64 RNG, scenario, path sampling, reveal, writers and a CLI. Adds `args ^2.7.0` and `crypto ^3.0.7` (Dart team, BSD-3; both were already in the lock as transitive dependencies, and `pubspec.lock` did not change). |
| `stages/01-foundation/evidence/S01-10/*` | Stats and metadata JSON for z20 and z21, the determinism hashes, and the benchmark table. |

## Verification

~~~
$ (cd packages/footnoted_geo && dart test)
00:05 +39: All tests passed!            # baseline +1 → +39
$ (cd spike/tracegen && dart test)
00:36 +9: All tests passed!             # baseline +1 (placeholder, removed) → +9
$ dart analyze --fatal-infos            # repo root
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 34 files (0 changed)
$ dart tool/check_deps.dart
check_deps: 61 packages, none denylisted.
~~~

The geography cases are each a named test:

- **Equator:** cell widths; the 1 km east-west row; the disk with `r = 3`.
- **60°:** width 19.11 m; the disk with `r = 6`, which has about 4× the cells of the equator disk; the per-row widening of a north-south leg from 29 to 55 cells.
- **Antimeridian:** a 1 km straight leg; a 20° leg stays on the short side; great-circle Tokyo → Honolulu; dilation at x = 0 spills into the last column.
- **|lat| > 84°:** clamped rows on both hemispheres; dilation at the north edge (`r = 31`); a great-circle arc over the pole; the antipodal pair is rejected.
- **Zero-length:** a single point and a `[p, p]` leg give one cell, which dilates to the exact disk. Every cell centre within 100 m is revealed, and no cell beyond 100 m + one diagonal.
- **Property:** `dilate(rasterize(line)) ⊇ rasterize(line)` holds over 200 random lines worldwide.

Two checks compare against brute force. The supercover matches a reference on 3,000 random segments, including segments snapped to cell boundaries: every cell whose open interior is crossed is present, and no cell outside the closed squares. The dilation equals naive per-cell stamping on 80 random clusters at z20 and z21, at the poles, at x = 0 and x = n − 1.

The tracegen tests check the five-year scenario's shape: three road trips of more than 1,000 km each, including a single leg over 1,000 km; at least 10 flights with HND → HNL across ±180°; walks in Madrid, Tokyo and Helsinki; a median home fix gap of 200–350 m. They also check FORMAT.md conformance on a one-year run at z20 and z21: key order, sorted `ts`, headers before their points, segment IDs 0..n−1, cells sorted and unique, and the union of segcells equal to cells. The metadata `count`, `rows` and `sha256` must match the files, and two runs must be byte-identical.

**Determinism**, seed 42, 5 years, two separate runs on Windows (`evidence/S01-10/determinism-sha256.txt`, `sha256sum`):

| File | SHA-256 (run 1 = run 2) |
| --- | --- |
| `dataset.trace.ndjson` | `c7d51e69bd57c92bd8f590f1965cf04ecbf47f2e54a85b556cb8e2e587ea4742` |
| `dataset.cells.bin` | `4a893df6986893239134cc8e78753cce7fa4eebfc5ee7e548f44c2899e68c1c2` |
| `dataset.segcells.bin` | `22739288fc0633530a2436c0f1573de9d931984e27daceb1e0119fb09419b7c2` |
| `dataset.z21.cells.bin` | `dd5c3a4e547e250961afee3668271834a87349211ef535864af3ba50b0388355` |
| `dataset.z21.segcells.bin` | `c4eab21f77b3b98fd36fe435a32102c445a7fbee2ff23ad4fecedcef59566774` |

**Cross-platform.** The tracegen test prints the `--seed 7 --years 1 --levels 20,21` hashes. In CI on Linux ([run 37899518438](https://github.com/JohnnnyTang/footnoted/actions/runs/37899518438), job "spike tests") they are byte-identical to the same command run locally on Windows:

| File | SHA-256 |
| --- | --- |
| trace | `567dc0828bf138bd9fa3170c11d9cb340d1ee2554d76dbde8ce2ebecbdec2c57` |
| z20 cells | `cc7f6b88579ddccb97d586af3d00da1d6af44401edcd00ce3ad045e62406e8a0` |
| z20 segcells | `39537d5e5dc39980372c8fae3eeeb6f98c1cb1296a04c94da9a8cfcb36c75edb` |
| z21 cells | `a20de10885d61a40cb9cd17f94029d3135b41bc4ac8aeef7664deb69711c1246` |
| z21 segcells | `c92ccaf35874de43ae3c2e67091fced1826ed5489f7b8f9af20b45a1fd6bfb0c` |

The whole CI run is green, including the spike tests, the Android build and all iOS `--no-codesign` jobs. It ran on head `d3eaedf`, before this note was added.

### Acceptance

- ✅ `dart test packages/footnoted_geo` is green with every geography case: +39 (see above).
- ✅ Two `--seed 42` runs produce identical `sha256` values (table above).
- ✅ ≈1,000,000 unique z20 cells ±30 %: **1,169,242 (+17 %)**. Knobs and their effect are below.
- ✅ The counts table is present, including the 1,000 km × 500 m leg: **899,508 rows** at z20 for the 1,033 km CDMX → Nuevo Laredo leg. The handoff estimates about 700 k; the benchmark's equator leg gives 759,446.

## Invariant check

1. Open source only: held. `args` and `crypto` are BSD-3 Dart-team packages; check_deps is green.
2. Raw points are the only truth: held. Cells are derived from the trace, deterministically.
3. Anchors never overwritten: n/a (no database).
4. Connection mode is a view: held. The mode is read from the segment header, and nothing inferred is stored as recorded.
5. Reveal along segments: held. `line` reveals rasterise the joined geometry; flights reveal endpoints only, per FORMAT.md and D-007.
6. Coverage has provenance: held. `segcells` keeps one record per segment, and the union is derived from it.
7. Local-first: held. There are no network calls. The output is synthetic and git-ignored. The CLI prints counts and hashes only, never coordinates.
8. The user decides: n/a.
9. History is never held hostage: n/a.
10. No ads or analytics: held.

Verdict: **PASS**.

## Measurements

Windows dev machine, Dart 3.13.5, JIT (`dart run`), CPU only. The phone is not involved. Times are wall-clock from `Stopwatch`.

### Counts table (seed 42, 5 years; `dataset[.z21].stats.json`)

| | z20 | z21 | z21 / z20 |
| --- | --- | --- | --- |
| Segments / points | 2,982 / 115,312 | same trace | |
| **Unique cells** | **1,169,242** | **4,503,324** | 3.85× |
| **(cell, segment) rows** (F01.2 per-cell layout) | **9,714,696** | **36,757,276** | 3.78× |
| **Run-length spans**, summed per segment (F01.2 spans layout) | **458,360** | **914,809** | 2.0× |
| Spans of the union (for fog geometry) | 36,590 | 74,465 | 2.0× |
| 1,000 km × 500 m leg (seg 564, CDMX → N. Laredo, 1,033 km): rows / spans | **899,508 / 25,599** | 3,483,003 / 51,198 | 3.87× / 2.0× |
| Generation time: trace (generate + write) | 0.52 s | — | |
| Generation time: reveal (rasterise + dilate, all segments) | 2.4 s | 9.2 s | |
| Generation time: reveal + write cells/segcells | 8.8 s | 38.5 s | |
| `segcells.bin` size | 77.8 MB | 294 MB | |

By category, at z20 (rows are (cell, segment)):

| Category | Segments | Rows | Spans | Unique cells |
| --- | --- | --- | --- | --- |
| Home (Mexico City: commutes, walks, drives) | 2,896 | 4,933,400 | 318,076 | 148,042 |
| Road trips (10 legs, 3 trips) | 10 | 4,620,917 | 130,395 | 907,267 |
| Stays (Cancún, Madrid, Tokyo, Honolulu, Helsinki, Monterrey, SLP, N. Laredo; transfers) | 64 | 136,579 | 9,033 | 112,290 |
| Flights (12, endpoints only) | 12 | 23,800 | 856 | 9,507 |

For G1(c), the per-cell layout costs 8.3 rows per unique cell. Two things drive it:

- **Repeated commutes:** about 2,300 commutes give 4.9 M rows over only 148 k cells.
- **Corridor re-traversals:** six traversals of one corridor give 4.6 M rows.

Spans cut the rows by 21× overall and by 35× on the 1,000 km leg. At z21, rows grow 3.8× but spans only 2×.

### Knob runs (z20, seed 42 unless stated)

| Run | Unique cells | Rows |
| --- | --- | --- |
| `--walk-scale 0.5` | 1,131,635 | 9,389,757 |
| default (1.0) | 1,169,242 | 9,714,696 |
| `--walk-scale 2.0` | 1,188,667 | 10,112,000 |
| `--seed 43` | 1,165,312 | 9,821,158 |

The levers that move the total are geography and corridor reuse, and both are fixed in `scenario.dart`. A second distinct 1,000 km corridor would add about 0.9 M cells, and a mid-latitude home would multiply the corridor by about 1.7.

### Drive benchmark (`dart run benchmark/drive_benchmark.dart`, best of 5; full table in `evidence/S01-10/drive_benchmark.md`)

| 1,000 km drive, fix every 300 m | z20 100 m | z20 500 m | z21 500 m | z20 500 m dilate time |
| --- | --- | --- | --- | --- |
| Equator E-W | 183,210 | 759,446 | 2,880,584 | 120 ms |
| 45° E-W | 333,258 | 1,435,503 | 5,532,325 | 226 ms |
| 45° diagonal | 311,617 | 1,395,979 | 5,460,922 | 334 ms |
| CDMX → N. Laredo (19.4→27.5°) | 201,992 | 870,689 | 3,393,049 | 274 ms |
| 40→49° N-S | 331,168 | 1,431,258 | 5,576,485 | 499 ms |
| 60° E-W | 671,310 | 2,782,006 | 10,919,502 | 565 ms |

Rasterising takes 2–14 ms for every drive. Dilation dominates: about 0.3 s per 1 M output cells at z20 500 m, up to 2.5 s for 10.9 M cells at z21. The cell count for the same ground area scales with 1/cos²(lat), which confirms the brief's trap: radius ×2 at 60° gives ×3.7 cells.

## Out-of-contract findings

- **Worktree base.** My worktree started at `042f23f` (`main`), not `3e2226f`. I created the branch, then ran `git reset --hard 3e2226f` before any work, so the branch is based on the commit in the brief.
- **≈1 M target vs road trips.** See the Summary. I resolved it inside the scenario without touching other files; the orchestrator should confirm the reading.
- **Output naming outside FORMAT.md.** Levels other than 20 write `dataset.z<L>.{cells,segcells}.{bin,json}`, and each level also writes `dataset[.z<L>].stats.json`. Neither is in FORMAT.md, and the FORMAT.md formats themselves are unchanged. I suggest the orchestrator add one line to FORMAT.md §5 at the W1 close.
- **`pubspec.lock`.** It did not change, so there is no lock conflict to resolve.

## Backlog rows

| ID | Row | Owner | Blocks |
| --- | --- | --- | --- |
| S01-V10a | Cross-platform determinism. Windows and Linux CI matched for seed 7 / 1 year (above), but nothing guards it: the trace uses `dart:math` transcendental functions from the platform libm, rounded to 1e-7°. If the tracegen hashes ever differ between platforms, round intermediate values or use a pure-Dart sin/cos. macOS is unchecked. | W2 / S01-20 | none today |
| S01-V10b | Dilation rounding: `r = ceil(buffer / w)` with a `dx² + dy² ≤ r²` mask reveals up to one cell beyond the buffer. For 100 m that is 108 m in CDMX (r = 3 × 36 m) and 124 m in Tokyo (r = 4 × 31 m), and the step is discontinuous across latitude. Decide at G1 (F01.6): keep ceil, use round, or use a centre-distance mask with real-valued r. | G1 / S01-31 | none |
| S01-V10c | Near the poles the per-row radius uses only the source row's width, so the disk is not a true ground disk (rows shrink over the radius). This is negligible below about 80°; S01-31 may use the target row's width instead. | S01-31 | none |
| S01-V10d | Commute repetition dominates the per-cell row count (4.9 M rows / 148 k cells at home). S01-11 and S01-20 should measure with the real `dataset.segcells.bin`, not only single legs. | S01-11 / S01-20 | G1(c) |

## Handover

- **Regenerate the data:** `cd spike/tracegen && dart run tracegen --seed 42 --years 5 --levels 20,21 --out ../out`. This takes about 50 s and writes about 420 MB (the z21 segcells file is 294 MB). For z20 only, drop `--levels`; that takes about 10 s and writes about 100 MB.
- **For S01-11:** the 1,000 km × 500 m leg is segment **564** in `dataset.segcells.bin` (899,508 cells). The whole dataset is 9.7 M rows.
- **For S01-12:** `dataset.cells.bin` holds 1.17 M cells, about 90 % of them in one CDMX → Nuevo Laredo corridor plus Mexico City. For a z10 pan, Mexico City (z10 tile around x 230, y 455) and the corridor north of it are the dense areas.
- **For S01-31:** the code is a first version, not throwaway. The API is `LatLng`, `CellId`, `packCell`/`cellX`/`cellY`/`parentCell`, `rasterizePolyline(points, mode:, level:)`, `densifyGreatCircle`, `dilateCells(cells, bufferM, level:)` and `sortedUnique`. The integer pixel math needs 64-bit ints, so there is no web target. Rollups and rectangle merge are not started.
- **Spans:** `countSpans` lives in tracegen (`lib/src/reveal.dart`). The dilation already produces per-row merged intervals internally; a production spans writer could expose them directly.
