# 2026-10-09 — S01-11 Storage benchmark (layout × driver, under SQLCipher)

**Stage:** 01 · **Wave/session:** W1 / S01-11 · **Branch:** `s01/11-storage-bench` (from `stage/01-foundation` @ `3e2226f`) · **Author:** session agent

## Summary

**Not landed / caveats first:**
1. **SQLCipher can't be switched on inside the repo without an out-of-contract change.** `sqlite3` 3.x selects its native library through build-hook user-defines, and Dart reads them **only from the workspace root `pubspec.yaml`**, which is kickoff-frozen. A `hooks:` block in a member pubspec is silently ignored. I verified this: with it in `spike/storage_bench/pubspec.yaml` the loaded library was upstream SQLite 3.53.4 and `cipher_version` was empty. Inside the workspace, `storage_bench` therefore runs the cipher-off configurations only. Every SQLCipher number below comes from a **standalone copy** of the same package, made by `tool/make_standalone.dart`. Only the pubspec differs (`resolution: workspace` removed, `hooks.user_defines.sqlite3.source: sqlcipher` added, root lock copied). See *Out-of-contract findings*.
2. **iOS + SQLCipher has not been compiled.** CI compiled `storage_bench` for iOS (run [37891597772](https://github.com/JohnnnyTang/footnoted/actions/runs/37891597772), job "Spike iOS build (storage_bench)": success), but that build is the in-workspace one, so it links **upstream SQLite**. The hook does ship prebuilt `libsqlcipher.arm64.ios.dylib` and simulator dylibs (sha256-pinned in `sqlite3-3.7.0/lib/src/hook/asset_hashes.dart`), but nothing has compiled or run them yet. That is a backlog row and an owner step. No iOS numbers are claimed.
3. The data is a **stand-in** (FORMAT.md §5): 503 segments, 1,217,666 unique z20 cells, 1,725,628 (cell, segment) rows, and a 1,000 km × 500 m leg of 741,034 rows. S01-10's dataset had not merged. The CLI and app take `--segcells` / a pushed `dataset.segcells.bin` so that W2 can re-run on it.
4. Schema B adds a `PRIMARY KEY (segment_id, y, x_start)` (WITHOUT ROWID) to the brief's `coverage_spans`, so that "delete one segment" is not a full scan. This mirrors A's PK + one index. Recorded in `lib/src/schema.dart`.

**What landed:** the packaging finding (below), both schemas, both drivers, SQLCipher on and off, a desktop CLI (Windows, AOT) and a Flutter app runner (Android release) sharing `lib/src/`. There are 3 desktop runs and 3 Android-emulator runs, with medians and spread. Every query result is checked against a Dart-computed expectation, and every insert and delete against row counts.

**SQLCipher packaging finding (one line):** use `sqlite3` ≥ 3.7.0 build hooks with `hooks: user_defines: sqlite3: source: sqlcipher` in the **workspace root** pubspec. That gives SQLCipher 4.19.0 community on SQLite 3.53.4 with OpenSSL 4.0.3, and R\*Tree compiled in. It works under Drift 2.35.2 (`NativeDatabase` `setup:` applies `PRAGMA key`). `sqlcipher_flutter_libs` and `sqlite3_flutter_libs` are EOL (`0.7.0+eol` / `0.6.0+eol`, "update to version 3.x of package:sqlite3").

## Changes

| File | What |
| --- | --- |
| `spike/storage_bench/pubspec.yaml`, root `pubspec.lock` | deps `sqlite3 ^3.7.0`, `drift ^2.35.2`, `path_provider ^2.1.6`, `path`, `crypto`; dev `drift_dev`, `build_runner`. Lock regenerated (kickoff rule). |
| `lib/src/dataset.dart` | Cell packing (FORMAT §1), `Segment`, run-length `spansOf`, `Dataset` (rows, union, spans). |
| `lib/src/standin.dart` | Deterministic stand-in corridors. Capsule rasteriser with the radius at the segment's latitude. Home city (Berlin), 3 stays, 2 × 50 km road trips, the 1,000 km leg (Chennai → NW, about 13–20° N), 10 endpoint-only flights. |
| `lib/src/dumps.dart` | Read/write `*.segcells.bin`/`.json` and `*.cells.bin`/`.json` (FORMAT §3–4, sha256). |
| `lib/src/schema.dart` | Shared DDL for A and B, plus the SQL for the query, insert, upsert and delete. |
| `lib/src/drift_db.dart` (+ `.g.dart`) | Drift tables that mirror the DDL; `onCreate` runs the shared DDL. |
| `lib/src/stores.dart` | `RawStore` (prepared statements) and `DriftStore` (typed batches, `DoUpdate.withExcluded`, typed select/update/delete). Pragmas and key. |
| `lib/src/probe.dart` | `sqlite_version`, `cipher_version`/provider, the `ENABLE_RTREE` compile option, an R\*Tree create + query, the file-header check. |
| `lib/src/bench.dart` | The runner: configs, timings, VACUUM size, tile queries, delete, correctness checks, result JSON. |
| `bin/storage_bench.dart` | Desktop CLI (`--segcells`, `--leg`, `--tiny`, `--dumps`, `--probe`, `--stats`, `--label`). |
| `lib/main.dart` | Flutter runner. Autoruns in a `compute` isolate, logs `BENCH` lines and chunked JSON, saves to the documents dir and the Android external files dir. |
| `tool/make_standalone.dart`, `tool/summarize.dart` | Standalone SQLCipher copy; Markdown tables (median across runs). |
| `test/storage_bench_test.dart` (replaces the placeholder) | spans, disk size, determinism + dump round-trip, an end-to-end tiny bench over all configs, app shell. |
| `README.md` | How to run on desktop and Android. |
| `stages/01-foundation/evidence/S01-11/*` | 3 desktop + 3 emulator result JSONs and a logcat excerpt. |

## Verification

~~~
# repo root, Windows, Flutter 3.47.7 / Dart 3.13.5
flutter pub get                                        → resolved
dart analyze --fatal-infos                             → No issues found!
dart format --output=none --set-exit-if-changed .      → Formatted 36 files (0 changed)
dart tool/check_deps.dart                              → 102 packages, none denylisted
(cd spike/storage_bench && flutter test)               → +5 All tests passed (was +1 placeholder)
(cd packages/footnoted_geo && dart test)               → +1   (cd packages/footnoted_data && dart test) → +1
(cd tool && dart test) → +3   (cd app && flutter test) → +1   (cd spike/tracegen && dart test) → +1

# member-level hook define is ignored (in-workspace run, hooks block in spike/storage_bench/pubspec.yaml)
dart run bin/storage_bench.dart   (probe)              → sqlite_version=3.53.4  cipher_version=[]

# standalone copy (tool/make_standalone.dart), Windows desktop
storage_bench.exe --probe → {"sqlite_version":"3.53.4","cipher_version":"4.19.0 community",
  "rtree_compile_option":true,"cipher_provider":"openssl","cipher_provider_version":"OpenSSL 4.0.3 29 Sep 2026",
  "rtree_query_ids":[1],"journal_mode":"wal","synchronous":1,"file_header_is_plain_sqlite":false,
  "file_header_hex":"e56ba30c1ad9bc635cb876c4b54817d9"}
dart build cli -t bin/storage_bench.dart → bundle/lib/sqlcipher.dll (4,688,896 B)

# Android emulator fn_api36 (Android 16, x86_64), release APK from the standalone copy
flutter build apk --release → app-release.apk 59.2 MB; libsqlcipher.so arm64-v8a 5,086,272 B,
  armeabi-v7a 4,103,172 B, x86_64 5,924,512 B (uncompressed sizes in the APK listing)
probe (result-emulator-*-run1.json "sqlite"): cipher_version "4.19.0 community", provider openssl / OpenSSL 4.0.3,
  rtree_compile_option true, rtree_query_ids [1], journal_mode wal, synchronous 1 (NORMAL),
  file_header_is_plain_sqlite false (hex b06e9e778200b27d94186806ff2e4f73)

# CI (push of f6eb8a8): run 37891597772 → success: checks, Android build, iOS build,
  Spike iOS build (storage_bench / render_bench / h3_eval)   [storage_bench iOS = upstream SQLite, see Summary 2]
# CI (push of 5dcc6ce, all code + this note's evidence): run 37899674174 → success, same six jobs
~~~

### Acceptance

- ✅ **Desktop results table in the note.** See *Measurements*: 3 runs, AOT, SQLCipher build, cipher on and off.
- ✅ **Android emulator numbers marked *emulator*.** 3 release runs on `fn_api36`. W2 re-runs on the real phone.
- ✅ **SQLCipher shown working on the Android emulator:** `cipher_version` = `4.19.0 community` (non-empty); R\*Tree `CREATE VIRTUAL TABLE … USING rtree` + query returned `[1]`; file header ≠ `SQLite format 3` (hex above). ⚠ This was from the standalone copy, not the in-workspace package (out-of-contract finding 1).
- ✅ **iOS compiles in CI** (run 37891597772, "Spike iOS build (storage_bench)") ⚠ **with upstream SQLite, not SQLCipher.** The iOS SQLCipher compile is recorded as an owner step and backlog row. No iOS numbers are claimed.
- ✅ **Packaging finding** verified by running on Windows and the Android emulator (not from the README), with licences (below).
- ✅ Two schemas × two drivers × SQLCipher on/off; leg and full insert, delete with `cell_stats` maintenance, z10 tile query at L12/16/20, size after VACUUM.
- ✅ WAL + `synchronous=NORMAL` set and read back (`journal_mode` = `wal`, `synchronous` = 1). Bulk inserts run in one transaction. Reads are warmed (one untimed run, which is also the correctness check) and the median of 5 is reported.

## Invariant check

1. Open source only: **held**. `sqlite3` MIT, `drift`/`drift_dev` MIT, `path`/`path_provider`/`crypto` BSD-3, SQLCipher community BSD-3-Clause (Zetetic), OpenSSL 4.x Apache-2.0. `check_deps` green.
2. Raw points only truth: **n/a** (synthetic data; tables rebuilt from the dumps).
3. Anchors never overwritten: **n/a**.
4. Mode is a view: **n/a**.
5. Reveal along segments: **held** (the stand-in rasterises whole corridors; flights are endpoint-only per FORMAT).
6. Coverage has provenance: **held**. A stores (cell, segment). B stores spans with `segment_id`, and `cell_stats` is derived. Delete paths are checked against expected row and `cell_stats` counts.
7. Local-first, encrypted: **held for the spike, RISK noted.** No runtime network; the key is never logged. The bench logs the dataset's densest z10 tile indices, which is harmless on synthetic data but would be a coarse home location on real data → `S01-V11e`. The sqlite3 hook downloads binaries from GitHub at **build** time → `S01-V11f`.
8. User decides: **n/a**. 9. History not held hostage: **n/a**. 10. No ads/analytics: **held** (none added).

Verdict: **PASS** (one RISK → backlog).

## Measurements

**Dataset** (stand-in, seed 42; identical in every run): 503 segments · 1,725,628 (cell, segment) rows · 1,217,666 unique z20 cells · 65,267 spans. Long leg: segment 492, 741,034 rows / 16,606 spans. Dumps (`--dumps`): `stand-in.segcells.bin` sha256 `e9bb74aa91791eee4e52d1bcf8029ee636362fed985271e1b9ed7c139559c01f`, `stand-in.cells.bin` sha256 `e3272ef397fbae92e89361135dcb395c498b325e9fb28b87eb86d7f7d6fc9068` (not committed; regenerate with `--dumps`). Query tiles (z10): densest = (550, 335) in Berlin, 190,566 cells at L20; on the long leg = (730, 466), 33,980 cells at L20.

**Method.** Each config gets a fresh DB. Steps: (1) insert the leg alone, timed, then discard; (2) insert the whole dataset in one transaction, timed; (3) `VACUUM` + `wal_checkpoint(TRUNCATE)`, then the main file size (the WAL is 0 B in every run); (4) tile queries, one warm-up/check run and then the median of 5; (5) delete the leg, timed. B's insert includes the `cell_stats` upsert, with counts aggregated in Dart per insert call. B's delete expands the spans to cells and runs `UPDATE n=n-1` + `DELETE … n<=0` per cell. The "Drift" driver is the typed batch API (`insertAll` in 20k-row batches inside `transaction`) on `NativeDatabase` in the calling isolate. The "raw" driver is `sqlite3` prepared statements. The key is a raw 256-bit `x'…'` key (no PBKDF2), as a keystore-held key would be applied. "Cipher off" means the SQLCipher library with no key. Numbers are **medians of 3 runs**.

### Desktop: Windows 11 Home 10.0.26300, Intel Family 6 Model 189 (8 logical CPUs), `dart build cli` AOT, SQLCipher build

Sibling W1 sessions may have been loading the same host; spread is given below.

| Layout | Driver | Cipher | Leg insert ms | Full insert ms | Delete leg ms | VACUUM ms | Size MB |
|---|---|---|---:|---:|---:|---:|---:|
| A | raw | on | 1084 | 3857 | 511 | 742 | 46.8 |
| A | drift | on | 2316 | 6689 | 547 | 774 | 46.8 |
| B | raw | on | 688 | 1567 | 1282 | 307 | 16.7 |
| B | drift | on | 3071 | 5538 | 3506 | 277 | 16.7 |
| A | raw | off | 1018 | 3048 | 246 | 562 | 45.8 |
| A | drift | off | 2283 | 6062 | 285 | 527 | 45.8 |
| B | raw | off | 631 | 1469 | 1231 | 190 | 16.3 |
| B | drift | off | 2892 | 5442 | 3494 | 188 | 16.3 |

z10 tile query, median ms at L12 / L16 / L20 (results: densest 8 / 857 / 190,566 cells; leg 8 / 232 / 33,980):

| Layout | Driver | Cipher | densest | long leg | densest via `cell_stats` | leg via `cell_stats` |
|---|---|---|---:|---:|---:|---:|
| A | raw | on | 70 / 93 / 149 | 3.1 / 3.8 / 15.0 | - | - |
| A | drift | on | 74 / 98 / 277 | 2.6 / 4.2 / 35.4 | - | - |
| B | raw | on | 25 / 32 / 43 | 0.6 / 0.6 / 3.4 | 28 / 42 / 107 | 3.1 / 3.3 / 15.7 |
| B | drift | on | 46 / 49 / 65 | 0.9 / 1.1 / 3.4 | 28 / 39 / 203 | 2.8 / 3.2 / 33.8 |
| A | raw | off | 56 / 82 / 130 | 2.6 / 3.5 / 16.1 | - | - |
| A | drift | off | 62 / 83 / 258 | 2.6 / 3.7 / 40.9 | - | - |
| B | raw | off | 27 / 31 / 44 | 0.7 / 0.7 / 2.7 | 26 / 32 / 102 | 2.6 / 3.8 / 16.3 |
| B | drift | off | 45 / 54 / 62 | 1.1 / 1.4 / 3.3 | 24 / 33 / 219 | 2.6 / 3.7 / 36.8 |

Spread, full insert ms (runs 1/2/3; config order A-raw-on, A-drift-on, B-raw-on, B-drift-on, A-raw-off, A-drift-off, B-raw-off, B-drift-off): run 1 `4659 7924 1774 6899 3436 6708 1655 5871` · run 2 `3116 6011 1511 5538 3048 5832 1333 4887` · run 3 `3857 6689 1567 5233 2709 6062 1469 5442`.

### *Emulator*: AVD `fn_api36`, Android 16 (`sdk_phone64_x86_64`), x86_64, 4 vCPUs, **release** APK, SQLCipher build (standalone copy)

Not representative of a phone. W2 re-runs this on the device.

| Layout | Driver | Cipher | Leg insert ms | Full insert ms | Delete leg ms | VACUUM ms | Size MB |
|---|---|---|---:|---:|---:|---:|---:|
| A | raw | on | 1400 | 4272 | 625 | 1276 | 46.8 |
| A | drift | on | 3532 | 9533 | 516 | 824 | 46.8 |
| B | raw | on | 887 | 2090 | 1500 | 361 | 16.7 |
| B | drift | on | 5023 | 9167 | 5167 | 341 | 16.7 |
| A | raw | off | 898 | 2933 | 313 | 561 | 45.8 |
| A | drift | off | 3381 | 8567 | 268 | 588 | 45.8 |
| B | raw | off | 932 | 2060 | 1271 | 215 | 16.3 |
| B | drift | off | 4707 | 9042 | 4966 | 223 | 16.3 |

*Emulator* z10 tile query, median ms at L12 / L16 / L20:

| Layout | Driver | Cipher | densest | long leg | densest via `cell_stats` | leg via `cell_stats` |
|---|---|---|---:|---:|---:|---:|
| A | raw | on | 82 / 98 / 194 | 3.3 / 4.4 / 25.9 | - | - |
| A | drift | on | 74 / 96 / 378 | 2.4 / 3.4 / 45.3 | - | - |
| B | raw | on | 26 / 35 / 97 | 0.8 / 1.3 / 5.2 | 29 / 38 / 149 | 2.7 / 3.5 / 16.8 |
| B | drift | on | 62 / 69 / 133 | 1.2 / 1.7 / 6.4 | 33 / 40 / 312 | 3.0 / 4.2 / 45.4 |
| A | raw | off | 54 / 80 / 167 | 3.4 / 3.7 / 18.0 | - | - |
| A | drift | off | 51 / 79 / 350 | 3.2 / 4.3 / 43.5 | - | - |
| B | raw | off | 30 / 39 / 96 | 0.8 / 0.7 / 5.0 | 25 / 30 / 124 | 3.3 / 3.6 / 14.1 |
| B | drift | off | 64 / 72 / 124 | 1.3 / 1.5 / 5.2 | 20 / 28 / 293 | 2.8 / 3.6 / 31.1 |

*Emulator* spread, full insert ms (same config order): run 1 `5939 17287 3043 12209 4269 9361 2327 285947` · run 2 `4272 9533 2090 9167 2933 8567 2060 9042` · run 3 `3715 9084 2089 7719 2334 7577 1825 6957`. Run 1 was slower across the board. Its **B/drift/off 285,947 ms** is a one-off outlier (9,042 and 6,957 ms in runs 2–3); the emulator and host were shared with sibling sessions at the time. The median absorbs it, but treat single emulator runs with suspicion.

### Readings for G1(c)/(d) (stand-in data; W2 confirms on the device)

- **Layout B (spans + `cell_stats`) vs A (per-cell rows):** B is **2.8× smaller** (16.7 vs 46.8 MB with the cipher on). With raw statements its full insert is **≈2.5× faster** (desktop 1.6 s vs 3.9 s; *emulator* 2.1 s vs 4.3 s), and the long-leg insert is ≈1.6× faster. Its tile query from spans is 2–4× faster at every level (densest tile at L20: desktop 43 vs 149 ms; *emulator* 97 vs 194 ms). The cost is **delete**: B maintains `cell_stats` per cell, so deleting the 741 k-cell leg takes 1.3 s vs 0.5 s (desktop) and 1.5 s vs 0.6 s (*emulator*). Querying B through `cell_stats` instead of the spans is about as slow as A, so the spans index is the reader's path. A's z10 query scans a full-height x-strip, because `id = (x<<20)|y` makes a tile contiguous in x only. That's worth recalling when F01.1 is frozen.
- **Drift (typed batch API) vs raw `sqlite3`:** Drift costs **1.7–4.5× on inserts** (companion objects plus batch plumbing: A 6.7 vs 3.9 s, B 5.5 vs 1.6 s on desktop; *emulator* B 9.2 vs 2.1 s) and 2.7–3.4× on B's per-cell delete. It costs 1.5–2× on the large L20 reads (row mapping). It's at parity for small reads and A's set-based delete. This compares the typed batch API, not Drift itself. Drift can run prepared SQL through `customStatement`/`customSelect` on the same connection, so a Drift-based app can still give the reveal pipeline's hot inserts a raw path. That is the D-003 question for G1.
- **SQLCipher overhead** (raw driver, on vs off): size +2% (per-page reserve). Full insert +27% A / +7% B on desktop; *emulator* +46% A / +1% B. A's set delete roughly doubles (511 vs 246 ms on desktop). VACUUM +30–60%. Reads +0–25%, within noise for most cells. Nothing here argues against having encryption on.

## Out-of-contract findings

1. **SQLCipher selection lives in the workspace root `pubspec.yaml` (kickoff-frozen).** Dart hooks read `hooks.user_defines` only from the root package or workspace pubspec (dart.dev/tools/hooks: "inside the root package `pubspec.yaml` file, or in the workspace `pubspec.yaml` file if you use a workspace"). I confirmed it empirically (member define ignored → upstream SQLite). I did **not** edit the root pubspec. The workaround stays inside my files: `tool/make_standalone.dart` produces a standalone copy for SQLCipher runs. **Consequence:** the define is **workspace-wide**, so when it is added, `app`, `footnoted_data` and every spike link SQLCipher. That is what production wants (S01-32), and per-OS maps (`source: {android: sqlcipher, ios: sqlcipher, default: …}`) are available. It is an orchestrator/G1 change → `S01-V11a`.
2. CI's `spike-ios` job compiles only the in-workspace (upstream SQLite) build, so iOS + SQLCipher is not compiled until finding 1 is resolved (`.github/**` is orchestrator-owned) → `S01-V11b`.

## Backlog rows

| ID | Row | Owner | Blocks |
| --- | --- | --- | --- |
| S01-V11a | Add `hooks: user_defines: sqlite3: source: sqlcipher` to the **root** `pubspec.yaml` (workspace-wide; consider per-OS map). Pin `sqlite3 ≥ 3.7.0`. Record in G1 / D-log. | orchestrator (G1) | S01-32; in-repo cipher runs in W2 (S01-20) |
| S01-V11b | iOS SQLCipher: CI compile once V11a lands, then on-device `cipher_version` / R\*Tree / header check by the owner (iOS runbook, S01-21). Not verified in W1. | orchestrator → owner | G1(d) iOS evidence |
| S01-V11c | Re-run `storage_bench` on S01-10's real dataset (`--segcells dataset.segcells.bin`, or push it to the app's external files dir) on the real Android phone, release mode. | S01-20 (W2) | G1(c)/(d) |
| S01-V11d | Native licence notices: SQLCipher (BSD-3-Clause, attribution required in binary distributions) and OpenSSL (Apache-2.0) are native libs that Flutter's `LicenseRegistry` does not list. Add them to About/Licences. | S01-30 | store submission |
| S01-V11e | Production logging must never include tile/cell indices of user coverage (a densest z10 tile is a coarse home location). The spike does this on synthetic data only. | S01-32 / reviewers | — |
| S01-V11f | Build-time network: the `sqlite3` hook downloads prebuilt binaries from `github.com` releases (sha256-pinned, SLSA attestations). Decide: accept, mirror via `url_pattern`, or `source: source`. Record it as a build-time host in `docs/network-hosts.md`. | S01-33 / G1 | — |

## Handover

- **Run instructions:** `spike/storage_bench/README.md`. For SQLCipher, make the standalone copy first (`dart run tool/make_standalone.dart <dest>`; a short `<dest>` path helps Gradle on Windows), then `dart build cli …` / `flutter build apk --release` there. `tool/summarize.dart` prints these tables from any number of result JSONs.
- **Real data:** the CLI takes `--segcells <file> [--leg <id>]`. The app picks up `/sdcard/Android/data/com.example.footnoted.spike.storage_bench/files/dataset.segcells.bin` if present. The default leg is the largest segment.
- **Release logcat** on the shared emulator rotated quickly, so the logcat excerpt only has the tail of run 1. The authoritative results are the JSON files (`adb pull …/files/storage_bench_result.json`; `run-as` doesn't work on release builds).
- B's delete could be cheaper (aggregate decrements in SQL, or rebuild `cell_stats` for the affected rows). I left it naive on purpose so that the number is an upper bound.
- Drift's `NativeDatabase` ran on the calling isolate. Production would likely use `createInBackground`, which adds isolate hops that aren't measured here.
