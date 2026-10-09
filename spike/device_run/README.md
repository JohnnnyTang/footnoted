# device_run

M0 spike (W2 seam, S01-20a split): one command that runs the storage and render benchmarks on an Android device and collects the evidence. Throwaway; removed with `spike/` at G1-B.

```sh
# From the repo root, with one device in `adb devices` (or pass --serial):
dart spike/device_run/run_android.dart
dart spike/device_run/run_android.dart --serial emulator-5554 --out stages/01-foundation/evidence/S01-20a2/dry-run
dart spike/device_run/run_android.dart --only storage
```

| Option | Default |
| --- | --- |
| `--serial S` | the only device listed by `adb devices` |
| `--out DIR` | `stages/01-foundation/evidence/S01-20b` |
| `--dataset DIR` | `spike/out` (generated with `tracegen --seed 42 --years 5` if `dataset.cells.bin` or `dataset.segcells.bin` is missing) |
| `--only storage\|render` | both, storage first |

Relative paths resolve against the repo root.

## Contract between the driver and the steps

`run_android.dart` (orchestrator seam, read-only to sessions) writes `<out>/device.json` (serial, manufacturer, model, Android version, SDK, ABI, `emulator` flag, UTC time), then runs each step as

```
dart spike/device_run/<step>.dart --serial S --out <out>/<step> --dataset DIR --device-json <out>/device.json
```

with the repo root as the working directory. A step:

- builds what it needs itself (release for storage, profile for render; never debug), installs it, pushes the dataset, runs, and pulls the raw captures and result JSON into its `--out` directory;
- labels every number it writes with the device fields from `device.json` and the build mode, and marks emulator runs as *emulator — no pass/fail*;
- needs no manual step beyond a connected, unlocked device;
- exits 0 on success and non-zero on any failure (the driver stops there).

The render step also writes `<out>/render/criterion2.md`: the exit criterion 2 table (worst measured pass per configuration, `median_fps ≥ 55` and `pct_over_32ms ≤ 5`), which the driver prints at the end.

| File | Owner |
| --- | --- |
| `run_android.dart`, this README | orchestrator (seam) |
| `storage.dart`, `storage_*.dart` | S01-20a1 |
| `render.dart`, `render_*.dart` | S01-20a2 |

Step details (environment such as `JAVA_HOME`, proxy flags) are documented in `spike/storage_bench/README.md` and `spike/render_bench/MEASURE.md`.
