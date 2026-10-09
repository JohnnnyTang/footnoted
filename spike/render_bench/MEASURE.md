# render_bench — how to measure fog pan performance

Reproduces the S01-12 numbers, and the W2 numbers for exit criterion 2 (median ≥ 55 fps and ≤ 5 % of frames over 32 ms during a scripted 20 s pan at z10, with about 1 M revealed z20 cells, in a profile or release build). You do not need to read the code.

Always write down the **device model, OS version, build mode (profile), the platform-view mode and the fog strategy** next to every number. Numbers from an emulator are labelled *emulator* and never decide pass or fail.

## 1. What the app does

- Shows the OpenFreeMap **dark** style (`https://tiles.openfreemap.org/styles/dark`; style, tiles, glyphs and sprites all come from `tiles.openfreemap.org`, nothing else). The credits are always visible at the bottom left.
- Loads a cell dump (FORMAT.md §3) from the app's files directory as `dataset.cells.bin`. If there is none, it generates the deterministic stand-in (≈1.03 M z20 cells: Berlin plus a Berlin → Florence corridor), which takes a while on a phone.
- Draws the fog as one GeoJSON source + one fill layer. Two strategies:
  - **(a) `holes`**: per visible tile, one polygon = the tile with the scanline-merged covered rectangles as holes.
  - **(b) `inverse`**: per visible tile, a MultiPolygon of the merged **uncovered** rectangles (no holes).
  The cell level is `tile zoom + detail` (default detail 6: at z10, z16 cells of 8 logical px). Tiles are the visible ones plus one tile of padding; the fog is rebuilt only when the viewport leaves that padded set.
- **Scripted pan** (▶ button, or autorun): z10, north-up, 20 s along a fixed path (west → east across Berlin, then south-west along the corridor to Leipzig). Each pass first jumps to the start, waits 2 s, then moves the camera once per vsync with `moveCamera` (if the previous move has not been acknowledged yet, that frame's move is skipped and counted). By default there is one unmeasured warm-up pass (pass 0, it also fills the tile cache) and then 3 measured passes.
- At the end it writes `results/rb_<strategy>_<vd|tex>_<epoch>.json` into its files directory and logs `RENDER_BENCH_DONE <path>`. Each pass also logs one `RENDER_BENCH_PASS <n> end {json}` line.

## 2. What each measurement method sees (Android)

| Method | What it measures | Use it for |
| --- | --- | --- |
| **SurfaceFlinger `--latency`** on the app's `SurfaceView[…MainActivity](BLAST)` layer | The actual present time of every frame of Flutter's surface. In **both** platform-view modes Flutter composites the map into this surface, so these are the frames the user sees. | **The criterion-2 number.** `bin/measure.dart` collects it. |
| Flutter `FrameTiming` (in the app, `flutter_frames` / `flutter_raster`) | Frames of Flutter's raster thread, including compositing the map texture. Does not see MapLibre's own GL thread. | Cross-check; shows whether the Flutter side (raster time) is the bottleneck. |
| `dumpsys gfxinfo <pkg> framestats` | HWUI (the Android View renderer) only. | Not useful here: Flutter and MapLibre do not draw through HWUI; it reports 0 frames in the GLSurfaceView mode. Captured anyway in `gfxinfo.txt`. |
| MapLibre's own frame callback | `MapView.addOnDidFinishRenderingFrameListener` exists in MapLibre Native, but **`maplibre_gl` 0.27.1 does not expose it** to Dart. | Would need a plugin fork; not needed while SurfaceFlinger works. |
| Perfetto | Everything (SurfaceFlinger frame timeline, per-thread CPU, GPU completion). | Diagnosis of a failed run, by hand (section 5). |

## 3. One-time setup (Windows dev box)

1. Flutter 3.47.7. **JDK 21**: `maplibre_gl` 0.27.1 compiles its Android module for Java 21, so JDK 17 fails with `invalid source release: 21`. Point `JAVA_HOME` at a JDK 21 for the build only, e.g. a Temurin 21 unzipped to `D:\software\jdk-21.0.12.1+1`.
2. `android/gradle.properties` already sets `kotlin.incremental=false`: with the pub cache on `C:` and the repo on `D:`, Kotlin's incremental cache fails with `Could not close incremental caches`.
3. If Gradle cannot download from Maven Central behind a local proxy, prefetch once through it: `cd android && ./gradlew :app:mergeProfileAssets -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=<port>`.
4. Under Git Bash, prefix `adb` commands that contain `/sdcard/...` paths with `MSYS_NO_PATHCONV=1`.

## 4. Android: run it

From `spike/render_bench`:

```bash
# Build and install the profile APK (never debug for numbers).
JAVA_HOME="D:/software/jdk-21.0.12.1+1" flutter build apk --profile
adb -s <serial> install -r build/app/outputs/flutter-apk/app-profile.apk

# Data: the stand-in, or S01-10's dataset.cells.bin when it exists.
dart run bin/standin.dart --out out          # writes out/standin.cells.bin (+ .json with sha256)
MSYS_NO_PATHCONV=1 adb -s <serial> shell mkdir -p /sdcard/Android/data/com.example.footnoted.spike.render_bench/files
MSYS_NO_PATHCONV=1 adb -s <serial> push out/standin.cells.bin \
  /sdcard/Android/data/com.example.footnoted.spike.render_bench/files/dataset.cells.bin

# One run = warm-up + 3 measured passes, about 2 minutes. Keep the screen on and the phone untouched.
dart run bin/measure.dart --serial <serial> --label "<model, Android version>" --strategy holes   --texture false
dart run bin/measure.dart --serial <serial> --label "<model, Android version>" --strategy inverse --texture false
dart run bin/measure.dart --serial <serial> --label "<model, Android version>" --strategy holes   --texture true
dart run bin/measure.dart --serial <serial> --label "<model, Android version>" --strategy inverse --texture true
# Baselines without fog (the base map's own cost):
dart run bin/measure.dart --serial <serial> --label "<…>" --texture false --no-fog
dart run bin/measure.dart --serial <serial> --label "<…>" --texture true  --no-fog

dart run bin/summarize.dart                  # markdown table of every run under out/runs
```

Options: `--detail <n>` (cell level = tile zoom + n, default 6), `--passes <n>` (default 3).

`--texture false` is `MapLibreMap.useHybridComposition = false` (the plugin default): MapLibre renders into a `GLSurfaceView`, which Flutter can only embed through **Virtual Display**. `--texture true` makes MapLibre use a `TextureView`, which Flutter embeds as a **texture layer** (TLHC). Despite the plugin's flag name, neither is Flutter's "Hybrid Composition"; both go through `PlatformViewsService.initAndroidView`.

What `measure.dart` does: `am start -S` (fresh process) with the options as intent extras; polls `dumpsys SurfaceFlinger --list` / `--latency <layer>` every ~0.5 s (SurfaceFlinger keeps only the last 127 frames per layer); resets `gfxinfo` when pass 1 starts; waits for `RENDER_BENCH_DONE`; cuts the present timestamps to each pass window that the app reports (`window_monotonic_us`, the same `CLOCK_MONOTONIC` as SurfaceFlinger); writes `out/runs/<utc>_<strategy>_<vd|tex>[_nofog]/` with:

- `summary.json`: per pass, per layer: `frames`, `median_fps`, `pct_over_32ms`, `p50/p90/p99/max_ms`, plus the Flutter frame stats;
- `app_result.json`: the app's own result (data info, fog build/set times, FrameTiming stats);
- `sf_presents.json`, `gfxinfo.txt`, `logcat.txt`: raw captures.

**Reading it.** Criterion 2 uses the `(BLAST)` layer of each measured pass: `median_fps ≥ 55` and `pct_over_32ms ≤ 5`, on all three passes. Report the worst pass, not the best.

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
2. Data: run the app once, then in Finder → your iPhone → *Files* → *Render Bench*, drop `dataset.cells.bin` (from `out/standin.cells.bin`, or S01-10's dataset). Without it the app generates the stand-in itself.
3. Profile: Xcode → *Product → Profile* (⌘I) builds in the profile/release configuration and opens Instruments. Choose the **Animation Hitches** template (if your Xcode still offers the **Core Animation FPS** instrument, add it too). Start recording.
4. In the app, wait for the cell count, then press ▶. The run is a warm-up plus 3 passes of 20 s (about 1 min 40 s). Stop recording after `done →` appears.
   - Or autorun without touching the phone: `flutter run --profile --dart-define=RB_AUTORUN=true --dart-define=RB_STRATEGY=holes` (also `RB_DETAIL`, `RB_PASSES`, `RB_FOG=false`, `RB_LABEL`).
5. Record, per measured pass (the 20 s windows after each 2 s pause): the frame rate and hitch-time ratio from Animation Hitches, plus the number of frames over 32 ms if the Display track shows frame durations. Also copy the app's `RENDER_BENCH_PASS … end {…}` lines from the Xcode console (they carry Flutter's own frame stats) and the `results/*.json` file from Finder → *Files*.
6. Write down the iPhone model, iOS version, Xcode version and "profile". Do both strategies (`holes`, `inverse`). iOS has no platform-view mode switch.

Note: the Info.plist sets `CADisableMinimumFrameDurationOnPhone`, so a ProMotion iPhone may run at 120 Hz; on such a phone report the fps against 120 Hz as well.
