# storage_bench

M0 spike (S01-11, extended in S01-20a1): coverage storage benchmark - layout x driver under SQLCipher. Throwaway; removed at G1-B.

Briefs: `stages/01-foundation/W1-spike.md` → S01-11; `stages/01-foundation/notes/2026-10-09-W2-kickoff.md` → S01-20a1. Shared formats: [`../FORMAT.md`](../FORMAT.md). Results: the S01-11 and S01-20a1 notes in `stages/01-foundation/notes/`.

## What it measures

Layout **A** `cell_coverage` (per (cell, segment) rows) vs **B** `coverage_spans` + `cell_stats`, each written by **raw `sqlite3`** prepared statements and by **Drift** batches, with SQLCipher on and off (`PRAGMA journal_mode=WAL`, `synchronous=NORMAL`). Per configuration, on a fresh database:

1. insert of the long leg alone (then discarded);
2. insert of the whole dataset in one transaction;
3. `VACUUM` + `wal_checkpoint(TRUNCATE)`, then the file size;
4. the F01.3 rollups: `cell_rollups` at levels 16, 12 and 8, each timed (L16 from the z20 cells, L12 from L16, L8 from L12; `n` = covered z20 cells), and their size as the `page_count` growth;
5. the z10-tile query, one checked warm-up then the median of 5: rolled up on the fly at L8/L12/L16/L20 (B also via `cell_stats`), and read from `cell_rollups` at L16/L12/L8; densest tile and a tile on the long leg;
6. deleting the long leg (B maintains `cell_stats` per cell).

Every query result, row count and rollup row count is checked against a Dart-computed expectation. Each row also records `cipher_version` read on that store's own connection and whether the closed file starts with the plain SQLite header (it must not when the cipher is on).

Code: `lib/src/` (pure Dart, shared). Runners: `bin/storage_bench.dart` (desktop CLI) and `lib/main.dart` (Flutter app; runs on launch).

SQLCipher comes from the workspace root `pubspec.yaml` (`hooks: user_defines: sqlite3: source: sqlcipher`, D-011), so in-repo builds link it; the W1 standalone copy is no longer needed.

## Real dataset

```sh
(cd spike/tracegen && dart run tracegen --seed 42 --years 5 --out ../out)   # ~20 s, ~100 MB; z20 only
```

`dataset.segcells.bin`: 2,982 segments, 9,714,696 (cell, segment) rows, 1,169,242 unique z20 cells, 458,360 spans. The default long leg is the largest segment, 564 (the 1,033 km CDMX → Nuevo Laredo leg, 899,508 rows).

## Desktop (Windows)

```sh
cd spike/storage_bench
dart build cli -t bin/storage_bench.dart -o build/cli   # AOT, bundles sqlcipher.dll
build/cli/bundle/bin/storage_bench.exe --segcells ../out/dataset.segcells.bin --out <dir> --label "<machine>"
build/cli/bundle/bin/storage_bench.exe --probe --out <dir>   # library / cipher / R*Tree / header probe only
```

Without `--segcells` it runs the W1 stand-in (`--tiny` for a smoke run, `--dumps` to write it out). `--leg <id>` picks the segment to insert alone and delete. `--stats` prints dataset counts only. For exploratory runs, `--layout A|B`, `--driver raw|drift` and `--cipher on|off` narrow the configurations, `--cache-mb <n>` sets `PRAGMA cache_size` (default: SQLite's 2,000 KiB), and `--rollups 18,16,12,8` changes the rollup levels (finest first). A full real-dataset run needs about 1 GB of free disk for the throwaway databases. Results go to `<out>/result-desktop.json`; `dart run tool/summarize.dart <result.json>...` prints the Markdown tables (median across files).

## Android (release)

One command, from the repo root, with the device or emulator connected:

```sh
dart spike/device_run/run_android.dart --only storage [--serial S] [--out DIR]
```

The storage step (`spike/device_run/storage.dart`) builds the release APK, installs it, pushes `dataset.segcells.bin` to `/sdcard/Android/data/com.example.footnoted.spike.storage_bench/files/` and checks its sha256 on the device, then launches the app 3 times (a fresh process each time; `--runs N` when run directly). After each launch it pulls `storage_bench_result.json` and keeps the `BENCH` logcat lines of that process. It finishes with `summary.md` (medians across launches, labelled with `device.json`). Gradle gets the caller's `JAVA_HOME` unchanged. The step can also be run directly, with `--no-build` to reuse the last APK:

```sh
dart spike/device_run/storage.dart --serial emulator-5554 --out <dir> --dataset spike/out --device-json <dir>/device.json --runs 1 --no-build
```

The app runs once on launch (`--dart-define=AUTORUN=false` to disable; `--dart-define=TINY=true` for a smoke run), logs `BENCH` progress, prints the JSON between `BENCH_RESULT_BEGIN`/`BENCH_RESULT_END`, and saves it (write, then rename) to the documents directory and, on Android, the external app files directory. If the run throws, it writes `storage_bench_error.txt` there instead.
