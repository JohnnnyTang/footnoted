# storage_bench

M0 spike (S01-11): coverage storage benchmark - layout x driver under SQLCipher. Throwaway; removed at G1.

Brief: `stages/01-foundation/W1-spike.md` → S01-11. Shared formats: [`../FORMAT.md`](../FORMAT.md). Results and the packaging finding: `stages/01-foundation/notes/2026-10-09-S01-11-storage-bench.md`.

## What it measures

Layout **A** `cell_coverage` (per (cell, segment) rows) vs **B** `coverage_spans` + `cell_stats`, each written by **raw `sqlite3`** prepared statements and by **Drift** batches, with SQLCipher on and off (`PRAGMA journal_mode=WAL`, `synchronous=NORMAL`). Per configuration: insert of the long leg, insert of the whole dataset, `VACUUM` + size, the z10-tile query at L12/L16/L20 (densest tile and a tile on the long leg; B also via `cell_stats`), and deleting the long leg. Every query result is checked against a Dart-computed expectation.

Code: `lib/src/` (pure Dart, shared). Runners: `bin/storage_bench.dart` (desktop CLI) and `lib/main.dart` (Flutter app; runs on launch).

## SQLCipher needs a standalone copy

`sqlite3` 3.x picks its native library through build-hook user-defines, which are read **only from the workspace root `pubspec.yaml`**. Inside the workspace this package therefore links upstream SQLite (no cipher; the cipher-on configurations are skipped). To run with SQLCipher, make a standalone copy whose own pubspec selects it:

```sh
cd spike/storage_bench
dart run tool/make_standalone.dart <dest>        # adds hooks.user_defines.sqlite3.source: sqlcipher
cd <dest> && flutter pub get
```

## Desktop (Windows)

```sh
dart build cli -t bin/storage_bench.dart -o build/cli   # AOT, bundles sqlcipher.dll
build/cli/bundle/bin/storage_bench.exe --out out/run1 --dumps --label "<machine>"
build/cli/bundle/bin/storage_bench.exe --probe --out out   # library / cipher / R*Tree / header probe only
```

`--segcells <file>` runs on a FORMAT.md `*.segcells.bin` (the real dataset from `tracegen`) instead of the stand-in; `--leg <id>` picks the segment to insert alone and delete (default: the largest). `--stats` prints dataset counts only. Results go to `<out>/result-desktop.json`; `dart run tool/summarize.dart <result.json>...` prints the Markdown tables (median across files).

## Android (release)

```sh
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb push dataset.segcells.bin /sdcard/Android/data/com.example.footnoted.spike.storage_bench/files/   # optional; stand-in otherwise
adb shell am start -n com.example.footnoted.spike.storage_bench/.MainActivity
adb logcat --pid=$(adb shell pidof com.example.footnoted.spike.storage_bench) | grep BENCH
adb pull /sdcard/Android/data/com.example.footnoted.spike.storage_bench/files/storage_bench_result.json
```

The app runs once on launch (`--dart-define=AUTORUN=false` to disable; `--dart-define=TINY=true` for a smoke run), logs `BENCH` progress, prints the JSON between `BENCH_RESULT_BEGIN`/`BENCH_RESULT_END`, and saves it to the documents directory and (Android) the external app files directory.
