# S01-12 emulator runs: all numbers are *emulator*

Device: AVD `fn_api36` (Android 16 / API 36, x86_64, 1080 × 2400 px at 420 dpi, dpr 2.625), host GPU Intel Arc 140V through the emulator's GLES translator. Build: `flutter build apk --profile`. Data: stand-in, 1,033,958 z20 cells. Pan: z10, 20 s, warm-up pass 0 excluded. Times are UTC on 2026-10-09.

Each table comes from `dart run bin/summarize.dart <dir>`. Raw `summary.json` and `app_result.json` files are in the matching subdirectories.

- **SF** columns: SurfaceFlinger present timestamps of the app's Flutter `SurfaceView (BLAST)` layer. These are the frames that reach the screen.
- **Flutter** columns: `FrameTiming` from the raster thread.
- **set**: how long `await setGeoJsonSource` took, which includes the plugin's JSON encode and the channel hop.

The emulator is shared with three sibling sessions, and the host with their builds. It switches between a "fast" state (VD at about 58 fps, about 3 % of frames over 32 ms) and a "slow" state (VD at about 52 fps, about 16 % over 32 ms), and that switch has nothing to do with the fog. Only rows from the same batch should be compared.

## Batch 1: `runs/` (07:34–07:44, slow state for most of it)

| run | view | fog | pass | SF median fps | SF % >32 ms | SF frames | Flutter median fps | Flutter % >32 ms | raster p50/p90 ms | fog updates | set p50/max ms |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 073447 | GLSurfaceView/VD | holes | 1 | 52.96 | 16.56 | 936 | 48.36 | 7.47 | 12.08/21.79 | 4 | 38.15/40.13 |
| 073447 | GLSurfaceView/VD | holes | 2 | 50.09 | 18.82 | 898 | 45.84 | 10.57 | 12.73/22.26 | 4 | 32.44/33.08 |
| 073447 | GLSurfaceView/VD | holes | 3 | 51.76 | 15.63 | 928 | 48.07 | 7.75 | 12.42/21.62 | 4 | 21.33/37.25 |
| 073630 | GLSurfaceView/VD | inverse | 1 | 55.19 | 14.21 | 964 | 50.42 | 7.36 | 12.51/21.32 | 4 | 36.47/37.5 |
| 073630 | GLSurfaceView/VD | inverse | 2 | 54.69 | 13.13 | 975 | 50.24 | 5.95 | 11.98/21.59 | 4 | 33.84/44.32 |
| 073630 | GLSurfaceView/VD | inverse | 3 | 54.56 | 13.87 | 952 | 50.11 | 7.14 | 12.97/21.79 | 4 | 34.25/38.6 |
| 073814 | TextureView | holes | 1 | 51.21 | 31.57 | 814 | 42.31 | 15.23 | 8.42/17.51 | 4 | 34.62/45.3 |
| 073814 | TextureView | holes | 2 | 54.5 | 28.35 | 850 | 44.49 | 10.24 | 8.62/16.9 | 4 | 30.77/31.6 |
| 073814 | TextureView | holes | 3 | 50.57 | 32.01 | 809 | 41.95 | 15.56 | 8.17/17.18 | 4 | 26.85/48.28 |
| 073958 | TextureView | inverse | 1 | 57.03 | 20.81 | 942 | 50.01 | 6.57 | 8.27/16.7 | 4 | 26.57/54.66 |
| 073958 | TextureView | inverse | 2 | 57.61 | 21.48 | 945 | 50.4 | 6.77 | 9.21/16.77 | 4 | 21.55/28.05 |
| 073958 | TextureView | inverse | 3 | 57.36 | 18.68 | 958 | 51.33 | 5.74 | 9.45/17.02 | 4 | 24.96/42.08 |
| 074141 | GLSurfaceView/VD | off | 1 | 58.02 | 3.33 | 1142 | 58.26 | 1.14 | 14.06/21.04 | 0 | – |
| 074141 | GLSurfaceView/VD | off | 2 | 58.52 | 3.52 | 1135 | 58.0 | 1.14 | 12.56/20.81 | 0 | – |
| 074141 | GLSurfaceView/VD | off | 3 | 57.44 | 4.66 | 1095 | 56.22 | 1.28 | 13.01/20.71 | 0 | – |
| 074323 | TextureView | off | 1 | 56.24 | 23.39 | 902 | 47.74 | 8.86 | 7.82/15.55 | 0 | – |
| 074323 | TextureView | off | 2 | 57.75 | 18.58 | 969 | 51.57 | 5.57 | 10.35/17.58 | 0 | – |
| 074323 | TextureView | off | 3 | 56.82 | 19.62 | 943 | 50.1 | 6.79 | 9.07/17.17 | 0 | – |

## Batch 2: `runs_d8/` (07:45–07:52, detail 8, so z18 cells at z10 and up to 1,698 rectangles per update)

| run | view | fog | pass | SF median fps | SF % >32 ms | SF frames | Flutter median fps | Flutter % >32 ms | raster p50/p90 ms | fog updates | set p50/max ms |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 074523 | GLSurfaceView/VD | holes | 1 | 58.62 | 3.08 | 1135 | 58.69 | 1.23 | 13.38/20.41 | 4 | 61.21/92.8 |
| 074523 | GLSurfaceView/VD | holes | 2 | 57.75 | 3.73 | 1126 | 57.36 | 1.15 | 11.47/20.35 | 4 | 42.88/71.88 |
| 074523 | GLSurfaceView/VD | holes | 3 | 57.85 | 5.35 | 1102 | 56.68 | 1.99 | 12.3/20.34 | 4 | 50.7/97.15 |
| 074705 | GLSurfaceView/VD | inverse | 1 | 57.84 | 5.12 | 1094 | 57.07 | 2.28 | 13.29/20.89 | 4 | 99.09/111.06 |
| 074705 | GLSurfaceView/VD | inverse | 2 | 58.21 | 4.22 | 1113 | 58.38 | 2.6 | 13.57/20.8 | 4 | 59.13/72.53 |
| 074705 | GLSurfaceView/VD | inverse | 3 | 58.21 | 5.05 | 1108 | 57.89 | 2.43 | 13.14/20.85 | 4 | 76.75/89.64 |
| 074847 | TextureView | holes | 1 | 57.26 | 19.43 | 947 | 51.0 | 7.92 | 9.57/17.2 | 4 | 43.52/61.65 |
| 074847 | TextureView | holes | 2 | 56.56 | 22.51 | 924 | 49.52 | 8.0 | 9.07/16.92 | 4 | 63.18/66.87 |
| 074847 | TextureView | holes | 3 | 56.93 | 23.64 | 922 | 49.55 | 8.46 | 8.58/16.67 | 4 | 71.08/97.31 |
| 075029 | TextureView | inverse | 1 | 57.2 | 22.1 | 923 | 50.03 | 8.77 | 8.95/16.79 | 4 | 71.37/78.35 |
| 075029 | TextureView | inverse | 2 | 57.06 | 20.02 | 939 | 50.02 | 7.88 | 9.68/17.62 | 4 | 61.78/110.5 |
| 075029 | TextureView | inverse | 3 | 56.36 | 22.19 | 924 | 49.18 | 8.12 | 8.96/17.53 | 4 | 61.41/73.5 |

## Batch 3: `runs_repeat/` (07:52, detail 6)

| run | view | fog | pass | SF median fps | SF % >32 ms | SF frames | Flutter median fps | Flutter % >32 ms | raster p50/p90 ms | fog updates | set p50/max ms |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 075211 | GLSurfaceView/VD | holes | 1 | 59.05 | 2.98 | 1140 | 58.29 | 0.79 | 13.55/20.34 | 4 | 25.68/26.86 |
| 075211 | GLSurfaceView/VD | holes | 2 | 58.19 | 3.35 | 1133 | 57.81 | 1.32 | 13.77/20.28 | 4 | 26.04/27.37 |
| 075211 | GLSurfaceView/VD | holes | 3 | 57.73 | 3.01 | 1131 | 57.89 | 1.15 | 12.85/20.37 | 4 | 19.0/20.88 |

## Batch 4: `runs_r2/` (07:54–08:04, detail 6; fast state until about 08:01, then slow)

| run | view | fog | pass | SF median fps | SF % >32 ms | SF frames | Flutter median fps | Flutter % >32 ms | raster p50/p90 ms | fog updates | set p50/max ms |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 075435 | GLSurfaceView/VD | holes | 1 | 58.61 | 3.35 | 1136 | 58.76 | 1.85 | 13.31/20.5 | 4 | 32.57/36.1 |
| 075435 | GLSurfaceView/VD | holes | 2 | 59.01 | 3.04 | 1150 | 58.57 | 1.39 | 12.66/20.41 | 4 | 26.57/29.12 |
| 075435 | GLSurfaceView/VD | holes | 3 | 58.72 | 3.32 | 1145 | 57.8 | 1.31 | 12.74/20.04 | 4 | 22.61/24.53 |
| 075616 | GLSurfaceView/VD | inverse | 1 | 57.37 | 3.55 | 1099 | 57.67 | 1.16 | 12.56/20.42 | 4 | 22.75/30.47 |
| 075616 | GLSurfaceView/VD | inverse | 2 | 58.26 | 2.64 | 1135 | 58.8 | 1.85 | 13.44/20.8 | 4 | 23.2/25.4 |
| 075616 | GLSurfaceView/VD | inverse | 3 | 58.15 | 3.19 | 1130 | 57.58 | 1.15 | 12.56/20.94 | 4 | 21.95/26.54 |
| 075758 | TextureView | holes | 1 | 56.87 | 20.47 | 943 | 50.49 | 6.89 | 9.38/16.68 | 4 | 28.29/31.13 |
| 075758 | TextureView | holes | 2 | 56.74 | 21.97 | 933 | 49.65 | 7.71 | 9.44/17.04 | 4 | 34.76/37.39 |
| 075758 | TextureView | holes | 3 | 57.63 | 20.19 | 951 | 50.5 | 7.14 | 9.25/17.03 | 4 | 24.27/24.92 |
| 075940 | TextureView | inverse | 1 | 57.2 | 19.26 | 945 | 50.12 | 7.2 | 9.16/17.12 | 4 | 25.92/40.67 |
| 075940 | TextureView | inverse | 2 | 56.7 | 19.83 | 933 | 50.77 | 9.1 | 10.21/17.87 | 4 | 30.75/38.87 |
| 075940 | TextureView | inverse | 3 | 56.1 | 22.42 | 919 | 48.72 | 8.71 | 9.09/17.11 | 4 | 26.32/26.39 |
| 080121 | GLSurfaceView/VD | off | 1 | 52.52 | 16.44 | 943 | 48.52 | 7.42 | 12.9/22.91 | 0 | – |
| 080121 | GLSurfaceView/VD | off | 2 | 51.78 | 15.78 | 944 | 48.67 | 7.51 | 12.9/22.48 | 0 | – |
| 080121 | GLSurfaceView/VD | off | 3 | 54.41 | 15.5 | 961 | 50.13 | 6.65 | 12.88/22.44 | 0 | – |
| 080303 | TextureView | off | 1 | 49.61 | 30.18 | 815 | 42.73 | 17.3 | 8.82/18.51 | 0 | – |
| 080303 | TextureView | off | 2 | 38.12 | 36.92 | 772 | 40.9 | 21.09 | 7.97/17.28 | 0 | – |
| 080303 | TextureView | off | 3 | 51.58 | 30.41 | 822 | 42.61 | 13.87 | 8.07/17.54 | 0 | – |

## Batch 5: `runs_ab/` (08:05–08:16, interleaved A/B on GLSurfaceView/VD, slow state throughout)

| run | view | fog | pass | SF median fps | SF % >32 ms | SF frames | Flutter median fps | Flutter % >32 ms | raster p50/p90 ms | fog updates | set p50/max ms |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 080547 | GLSurfaceView/VD | off | 1 | 53.11 | 16.28 | 952 | 49.15 | 7.77 | 12.88/23.31 | 0 | – |
| 080547 | GLSurfaceView/VD | off | 2 | 52.48 | 13.46 | 966 | 49.5 | 6.31 | 12.83/21.85 | 0 | – |
| 080547 | GLSurfaceView/VD | off | 3 | 50.8 | 18.65 | 917 | 47.02 | 9.48 | 13.31/22.93 | 0 | – |
| 080730 | GLSurfaceView/VD | holes | 1 | 52.11 | 15.8 | 937 | 48.37 | 8.64 | 13.27/22.69 | 4 | 40.9/42.05 |
| 080730 | GLSurfaceView/VD | holes | 2 | 51.54 | 17.42 | 930 | 48.11 | 8.8 | 12.53/22.78 | 4 | 27.75/30.4 |
| 080730 | GLSurfaceView/VD | holes | 3 | 53.11 | 16.54 | 949 | 48.73 | 7.06 | 13.18/22.47 | 4 | 23.99/27.29 |
| 080913 | GLSurfaceView/VD | inverse | 1 | 53.31 | 15.88 | 951 | 49.34 | 6.83 | 13.27/22.33 | 4 | 34.3/35.22 |
| 080913 | GLSurfaceView/VD | inverse | 2 | 50.95 | 20.35 | 904 | 45.95 | 11.16 | 13.04/22.36 | 4 | 32.02/34.86 |
| 080913 | GLSurfaceView/VD | inverse | 3 | 52.31 | 15.71 | 942 | 48.93 | 8.49 | 12.7/22.46 | 4 | 31.99/40.67 |
| 081056 | GLSurfaceView/VD | off | 1 | 52.39 | 17.65 | 935 | 47.68 | 7.69 | 12.55/22.45 | 0 | – |
| 081056 | GLSurfaceView/VD | off | 2 | 51.92 | 16.1 | 944 | 48.48 | 7.94 | 12.56/22.42 | 0 | – |
| 081056 | GLSurfaceView/VD | off | 3 | 52.67 | 14.02 | 963 | 49.63 | 6.74 | 12.83/22.16 | 0 | – |
| 081238 | GLSurfaceView/VD | holes | 1 | 51.96 | 17.33 | 923 | 47.52 | 9.2 | 13.9/23.38 | 4 | 28.1/46.87 |
| 081238 | GLSurfaceView/VD | holes | 2 | 52.01 | 16.49 | 946 | 48.25 | 8.45 | 12.39/22.19 | 4 | 21.28/37.67 |
| 081238 | GLSurfaceView/VD | holes | 3 | 52.61 | 17.93 | 937 | 48.9 | 9.07 | 12.42/21.94 | 4 | 24.98/38.28 |
| 081421 | GLSurfaceView/VD | inverse | 1 | 53.85 | 17.63 | 936 | 48.78 | 7.8 | 12.53/22.26 | 4 | 34.64/37.2 |
| 081421 | GLSurfaceView/VD | inverse | 2 | 54.54 | 14.13 | 984 | 50.9 | 5.79 | 12.89/22.11 | 4 | 30.22/39.45 |
| 081421 | GLSurfaceView/VD | inverse | 3 | 53.37 | 14.2 | 958 | 49.93 | 7.72 | 13.11/22.18 | 4 | 25.93/28.29 |

## `dumpsys gfxinfo` (runs_r2)

- GLSurfaceView/VD: `Total frames rendered: 0`. HWUI draws nothing in this mode.
- TextureView: `Total frames rendered: 2668`, `Janky frames: 1218 (45.65%)`. In this mode HWUI composites the map's `TextureView`, so gfxinfo counts the map's frames, though not the frames that reach the screen.
