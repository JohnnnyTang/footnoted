# render_bench — how to measure fog pan performance

Reproduces the S01-12 numbers, and the W2 numbers for exit criterion 2 (median ≥ 55 fps and ≤ 5 % of frames over 32 ms during a scripted 20 s pan at z10, with about 1 M revealed z20 cells, in a profile or release build). You do not need to read the code.

Always write down the **device model, OS version, build mode (profile), the platform-view mode and the fog strategy** next to every number. Numbers from an emulator are labelled *emulator* and never decide pass or fail.

## 1. What the app does

- Shows the OpenFreeMap **dark** style (`https://tiles.openfreemap.org/styles/dark`; style, tiles, glyphs and sprites all come from `tiles.openfreemap.org`, nothing else). The credits are always visible at the bottom left.
- **Coverage from SQLCipher (default, since S01-20a2).** On first launch it builds a keyed SQLCipher database `rb_coverage_<A|B>.db` in its files directory from `dataset.segcells.bin` (FORMAT.md §4, S01-10's seed-42 dump), using `storage_bench`'s schema (layout **B**, spans + `cell_stats`, by default; layout **A**, one row per (cell, segment), by a switch). The build happens before any pass and is reused on later launches while the pushed file's size and modification time are unchanged (`rb_coverage_<L>.db.json`). The fog reads coverage **only** through the tile query "covered cells in tile at level L" (B: `coverage_spans` by `(y, x_start)`, rolled up in Dart; A: `cell_coverage` rolled up in SQL), on a worker isolate that owns the connection, so fog updates during the pan include the I/O. The log line `RENDER_BENCH_DB {…}` and `app_result.json` → `data.db` carry `cipher_version`, `cipher_provider`, `sqlite_version` and the row count, read back from that same connection.
- **Control: in-memory coverage** (`source=memory`, W1's path): loads `dataset.cells.bin` (FORMAT.md §3) and rolls it up in memory. If there is none, it generates the deterministic stand-in (≈1.03 M z20 cells: Berlin plus a Berlin → Florence corridor).
- Draws the fog as one GeoJSON source + one fill layer. Two strategies:
  - **(a) `holes`**: per visible tile, one polygon = the tile with the scanline-merged covered rectangles as holes.
  - **(b) `inverse`**: per visible tile, a MultiPolygon of the merged **uncovered** rectangles (no holes).
  The cell level is `tile zoom + detail` (default detail 6: at z10, z16 cells of 8 logical px). Tiles are the visible ones plus one tile of padding; the fog is rebuilt only when the viewport leaves that padded set.
- **Scripted pan** (▶ button, or autorun): z10 by default, north-up, 20 s at a constant screen speed along a fixed path: west → east across Mexico City (Chapultepec → Roma → Centro, S01-10's home city), then north along the CDMX → Querétaro → San Luis Potosí → Matehuala → Saltillo → Monterrey road-trip corridor (`lib/src/pan.dart`; ≈23 z10 tile widths in 20 s, about 3× the W1 Berlin path's speed). **Spot runs** at other zooms (`zoom` extra / `RB_ZOOM`) keep the z10 screen speed: above z10 a pass covers the first 2^(10−z) of the path (z14: Mexico City only; z18: a few hundred metres of it); at z10 and below it covers the whole path. Each pass first jumps to the start, waits 2 s, then moves the camera once per vsync with `moveCamera` (if the previous move has not been acknowledged yet, that frame's move is skipped and counted). By default there is one unmeasured warm-up pass (pass 0, it also fills the tile cache) and then 3 measured passes.
- At the end it writes `results/rb_<strategy>_<vd|tex>_<epoch>.json` into its files directory and logs `RENDER_BENCH_DONE <path>`. Each pass also logs one `RENDER_BENCH_PASS <n> end {json}` line.

## 2. What each measurement method sees (Android)

| Method | What it measures | Use it for |
| --- | --- | --- |
| **SurfaceFlinger `--latency`** on the app's `SurfaceView[…MainActivity](BLAST)` layer | The actual present time of every frame of Flutter's surface. In **both** platform-view modes Flutter composites the map into this surface, so these are the frames the user sees. | **The criterion-2 number.** `bin/measure.dart` collects it. |
| Flutter `FrameTiming` (in the app, `flutter_frames` / `flutter_raster`) | Frames of Flutter's raster thread, including compositing the map texture. Does not see MapLibre's own GL thread. | Cross-check; shows whether the Flutter side (raster time) is the bottleneck. |
| `dumpsys gfxinfo <pkg> framestats` | HWUI (the Android View renderer) only. | GLSurfaceView mode: always 0 frames, because neither Flutter nor MapLibre draws through HWUI. TextureView mode: it counts HWUI's compositing of the map's `TextureView`, which is the map's frame rate but not what reaches the screen. Captured anyway in `gfxinfo.txt`; do not use it for criterion 2. |
| MapLibre's own frame callback | `MapView.addOnDidFinishRenderingFrameListener` exists in MapLibre Native, but **`maplibre_gl` 0.27.1 does not expose it** to Dart. | Would need a plugin fork; not needed while SurfaceFlinger works. |
| Perfetto | Everything (SurfaceFlinger frame timeline, per-thread CPU, GPU completion). | Diagnosis of a failed run, by hand (section 5). |

## 3. One-time setup (Windows dev box)

1. Flutter 3.47.7. **JDK 21**: `maplibre_gl` 0.27.1 compiles its Android module for Java 21, so JDK 17 fails with `invalid source release: 21`. Point `JAVA_HOME` at a JDK 21 for the build only, e.g. a Temurin 21 unzipped to `D:\software\jdk-21.0.12.1+1`.
2. `android/gradle.properties` already sets `kotlin.incremental=false`: with the pub cache on `C:` and the repo on `D:`, Kotlin's incremental cache fails with `Could not close incremental caches`.
3. If Gradle cannot download from Maven Central behind a local proxy, prefetch once through it: `cd android && ./gradlew :app:mergeProfileAssets -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=<port>`.
4. Under Git Bash, prefix `adb` commands that contain `/sdcard/...` paths with `MSYS_NO_PATHCONV=1`.

## 4. Android: run it

**One command (W2 onwards).** From the repo root, with the device connected and unlocked, `dart spike/device_run/run_android.dart --only render --serial <serial> [--out DIR]` does all of the below: it builds the profile APK for the device's ABI (JDK 21 from `RB_JAVA_HOME`, `JAVA_HOME` if it is a 21, or `D:/software/jdk-21.0.12.1+1`), installs it, pushes `spike/out/dataset.segcells.bin` (skipped when the device already has the same size), runs the matrix, and writes `runs.md`, `criterion2.md` and `step.json` into `<out>/render/`. The matrix: z10 (a) holes on VD, (b) inverse on VD and (a) holes on TextureView, all layout B, 3 runs each, interleaved; then once each: z10 (a) holes VD on layout **A**, and the spot runs z5, z14 and z18 ((a) holes, VD, layout B). About 35 minutes, plus the one-time DB builds. For a manual re-run, `dart spike/device_run/render.dart --serial S --out DIR --dataset spike/out --device-json DIR/device.json [--no-build] [--runs N]`. If Gradle cannot reach Maven Central, set `GRADLE_OPTS=-Dhttps.proxyHost=… -Dhttps.proxyPort=…` (§3).

By hand, from `spike/render_bench`:

```bash
# Build and install the profile APK (never debug for numbers).
JAVA_HOME="D:/software/jdk-21.0.12.1+1" flutter build apk --profile
adb -s <serial> install -r build/app/outputs/flutter-apk/app-profile.apk

# Data: S01-10's seed-42 dump (cd spike/tracegen && dart run tracegen --seed 42 --years 5 --out ../out).
MSYS_NO_PATHCONV=1 adb -s <serial> shell mkdir -p /sdcard/Android/data/com.example.footnoted.spike.render_bench/files
MSYS_NO_PATHCONV=1 adb -s <serial> push ../out/dataset.segcells.bin \
  /sdcard/Android/data/com.example.footnoted.spike.render_bench/files/dataset.segcells.bin
# (memory control only: push ../out/dataset.cells.bin as dataset.cells.bin; without it the app uses the stand-in)

# One run = warm-up + 3 measured passes, about 2 minutes (the first run per layout also builds the DB).
# Keep the screen on and the phone untouched.
dart run bin/measure.dart --serial <serial> --label "<model, Android version>" --strategy holes   --texture false
dart run bin/measure.dart --serial <serial> --label "<model, Android version>" --strategy inverse --texture false
dart run bin/measure.dart --serial <serial> --label "<model, Android version>" --strategy holes   --texture true
dart run bin/measure.dart --serial <serial> --label "<…>" --strategy holes --texture false --layout A
dart run bin/measure.dart --serial <serial> --label "<…>" --strategy holes --texture false --zoom 5    # also 14, 18
# Baselines without fog (the base map's own cost):
dart run bin/measure.dart --serial <serial> --label "<…>" --texture false --no-fog

dart run bin/summarize.dart                  # markdown table of every run under out/runs
dart run bin/criterion2.dart --runs out/runs --device-json <device.json>   # the criterion-2 table
```

Options: `--zoom <n>` (default 10), `--layout A|B` (default B), `--source db|memory` (default db), `--detail <n>` (cell level = tile zoom + n, default 6), `--passes <n>` (default 3), `--out DIR` (default `out/runs`). Without a host, the same options are `--dart-define`s: `RB_ZOOM`, `RB_LAYOUT`, `RB_SOURCE`, `RB_REBUILD=true` (rebuild the DB), plus the ones in §6.

`--texture false` is `MapLibreMap.useHybridComposition = false` (the plugin default): MapLibre renders into a `GLSurfaceView`, which Flutter can only embed through **Virtual Display**. `--texture true` makes MapLibre use a `TextureView`, which Flutter embeds as a **texture layer** (TLHC). Despite the plugin's flag name, neither is Flutter's "Hybrid Composition"; both go through `PlatformViewsService.initAndroidView`.

What `measure.dart` does: `am start -S` (fresh process) with the options as intent extras; reads the app's log by its pid (`logcat -d --pid`; it never clears the shared log buffer); waits for `RENDER_BENCH_DATA` (up to 30 min, for a first-launch DB build), then polls `dumpsys SurfaceFlinger --list` / `--latency <layer>` every ~0.5 s (SurfaceFlinger keeps only the last 127 frames per layer); resets `gfxinfo` when pass 1 starts; waits for `RENDER_BENCH_DONE`; cuts the present timestamps to each pass window that the app reports (`window_monotonic_us`, the same `CLOCK_MONOTONIC` as SurfaceFlinger); writes `out/runs/<utc>_z<zoom>_<strategy>_<vd|tex>_<A|B|mem>[_nofog]/` with:

- `summary.json`: per pass, per layer: `frames`, `median_fps`, `pct_over_32ms`, `p50/p90/p99/max_ms`, plus the Flutter frame stats;
- `app_result.json`: the app's own result (data and DB info with `cipher_version`, pan zoom and path share, fog query-wait/build/set times, FrameTiming stats);
- `sf_presents.json`, `gfxinfo.txt`, `logcat.txt` (the run log, including `RENDER_BENCH_DB`): raw captures.

A `RENDER_BENCH_ERROR` line (for example no `dataset.segcells.bin`, or SQLCipher not linked) ends the run with exit 1 and an `ERROR` file.

**Reading it.** Criterion 2 uses the `(BLAST)` layer of each measured pass: `median_fps ≥ 55` and `pct_over_32ms ≤ 5`, on all three passes. Report the worst pass, not the best (`bin/criterion2.dart` does).

**Shared device.** If another app takes the foreground during a run, the pan stops; `measure.dart` notices, writes `PREEMPTED` in the run directory and exits with code 3. Re-run it.

Without a host: launch the app, wait for the cell count to appear, press ▶. The result JSON lands in `/sdcard/Android/data/com.example.footnoted.spike.render_bench/files/results/`.

## 5. Android: Perfetto (diagnosis only)

```bash
adb shell perfetto -o /data/misc/perfetto-traces/rb.pftrace -t 30s sched freq gfx view
# start the run within the 30 s, then:
adb pull /data/misc/perfetto-traces/rb.pftrace
```

Open it at https://ui.perfetto.dev (the file is loaded locally in the browser). Look at the app's `1.raster` (Flutter raster), MapLibre's render thread, and the SurfaceFlinger frame timeline for the BLAST layer.

## 6. iOS (owner, on the Mac)

The agents never run iOS (D-009). CI only checks that the app compiles (`spike-ios`).

1. `cd spike/render_bench && flutter build ios --profile`, then open `ios/Runner.xcworkspace` in Xcode, choose your team under *Signing & Capabilities*, and select your iPhone.
2. Data: run the app once, then in Finder → your iPhone → *Files* → *Render Bench*, drop `dataset.segcells.bin` (S01-10's seed-42 dump, `spike/out/dataset.segcells.bin`; regenerate it with `cd spike/tracegen && dart run tracegen --seed 42 --years 5 --out ../out`). Relaunch the app: the first launch builds the SQLCipher coverage DB (a minute or more) before the cell count appears; the status line then shows the SQLCipher `cipher_version`. Without the file the app shows an error; for the old in-memory path use `--dart-define=RB_SOURCE=memory` with `dataset.cells.bin` (or nothing, for the stand-in).
3. Profile: Xcode → *Product → Profile* (⌘I) builds in the profile/release configuration and opens Instruments. Choose the **Animation Hitches** template (if your Xcode still offers the **Core Animation FPS** instrument, add it too). Start recording.
4. In the app, wait for the cell count, then press ▶. The run is a warm-up plus 3 passes of 20 s (about 1 min 40 s). Stop recording after `done →` appears.
   - Or autorun without touching the phone: `flutter run --profile --dart-define=RB_AUTORUN=true --dart-define=RB_STRATEGY=holes` (also `RB_DETAIL`, `RB_PASSES`, `RB_FOG=false`, `RB_LABEL`, `RB_ZOOM` for the z5 / z14 / z18 spot runs, `RB_LAYOUT=A`, `RB_SOURCE=memory`, `RB_REBUILD=true`).
5. Record, per measured pass (the 20 s windows after each 2 s pause): the frame rate and hitch-time ratio from Animation Hitches, plus the number of frames over 32 ms if the Display track shows frame durations. Also copy the app's `RENDER_BENCH_PASS … end {…}` lines from the Xcode console (they carry Flutter's own frame stats) and the `results/*.json` file from Finder → *Files*.
6. Write down the iPhone model, iOS version, Xcode version and "profile". Do both strategies (`holes`, `inverse`). iOS has no platform-view mode switch.

Note: the Info.plist sets `CADisableMinimumFrameDurationOnPhone`, so a ProMotion iPhone may run at 120 Hz; on such a phone report the fps against 120 Hz as well.
