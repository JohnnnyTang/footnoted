# render_bench runs — unknown Android SDK built for x86_64, Android 16 (emulator), profile — emulator — no pass/fail

Edited 2026-10-10T02:14Z: run 013205 (z10 holes VD B) overlapped a sibling session's CPU load (01:31:40–01:32:52Z), so it was moved to `../../contended/` and repeated as run 021129 (rows at the end). `criterion2.md` was regenerated with `bin/criterion2.dart` over the same `runs/`.

| run | zoom | view | fog | coverage | pass | SF median fps | SF % >32 ms | SF frames | Flutter median fps | Flutter % >32 ms | raster p50/p90 ms | fog updates | tiles queried | query p50/max ms | set p50/max ms |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 013425 | 10 | GLSurfaceView/VD | inverse | SQLCipher B (4.19.0 community) | 1 | 53.27 | 17.92 | 921 | 49.4 | 11.94 | 12.95/25.83 | 9 | 87 | 51.58/5065.27 | 24.63/51.38 |
| 013425 | 10 | GLSurfaceView/VD | inverse | SQLCipher B (4.19.0 community) | 2 | 52.17 | 21.61 | 893 | 48.1 | 14.33 | 12.65/25.0 | 9 | 89 | 52.58/5124.17 | 25.89/60.96 |
| 013425 | 10 | GLSurfaceView/VD | inverse | SQLCipher B (4.19.0 community) | 3 | 52.65 | 18.98 | 901 | 48.56 | 12.32 | 13.26/24.07 | 9 | 89 | 54.99/6187.49 | 18.76/46.96 |
| 013642 | 10 | TextureView | holes | SQLCipher B (4.19.0 community) | 1 | 53.24 | 20.91 | 875 | 47.15 | 12.79 | 11.13/19.92 | 9 | 87 | 60.89/5013.77 | 23.56/39.29 |
| 013642 | 10 | TextureView | holes | SQLCipher B (4.19.0 community) | 2 | 54.68 | 19.56 | 910 | 50.47 | 11.86 | 10.84/18.73 | 9 | 87 | 55.59/4787.63 | 20.83/56.9 |
| 013642 | 10 | TextureView | holes | SQLCipher B (4.19.0 community) | 3 | 54.1 | 22.07 | 879 | 46.77 | 13.18 | 10.91/19.72 | 9 | 91 | 49.13/5562.36 | 18.31/50.74 |
| 013858 | 10 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 1 | 54.38 | 15.82 | 948 | 50.59 | 10.34 | 13.08/24.3 | 9 | 87 | 50.04/5076.96 | 30.51/49.74 |
| 013858 | 10 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 2 | 54.71 | 15.38 | 956 | 50.66 | 9.51 | 12.5/23.51 | 9 | 85 | 57.19/5364.91 | 21.79/32.95 |
| 013858 | 10 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 3 | 54.58 | 16.79 | 941 | 50.51 | 11.04 | 12.38/24.4 | 9 | 85 | 60.47/5390.59 | 21.2/31.34 |
| 014112 | 10 | GLSurfaceView/VD | inverse | SQLCipher B (4.19.0 community) | 1 | 53.84 | 17.49 | 932 | 50.22 | 11.58 | 13.49/25.04 | 9 | 91 | 74.34/5441.81 | 27.32/108.58 |
| 014112 | 10 | GLSurfaceView/VD | inverse | SQLCipher B (4.19.0 community) | 2 | 54.01 | 15.15 | 944 | 50.72 | 10.15 | 13.3/23.5 | 9 | 93 | 58.05/5629.96 | 20.6/48.97 |
| 014112 | 10 | GLSurfaceView/VD | inverse | SQLCipher B (4.19.0 community) | 3 | 53.54 | 17.72 | 920 | 49.56 | 11.62 | 13.15/25.24 | 9 | 93 | 43.03/5430.75 | 19.72/47.44 |
| 014327 | 10 | TextureView | holes | SQLCipher B (4.19.0 community) | 1 | 52.79 | 25.09 | 857 | 46.48 | 13.77 | 10.92/20.67 | 9 | 93 | 54.39/5445.42 | 19.0/40.1 |
| 014327 | 10 | TextureView | holes | SQLCipher B (4.19.0 community) | 2 | 53.95 | 21.23 | 881 | 47.06 | 12.81 | 11.4/20.39 | 9 | 93 | 53.19/5650.59 | 26.05/48.86 |
| 014327 | 10 | TextureView | holes | SQLCipher B (4.19.0 community) | 3 | 52.77 | 24.7 | 838 | 45.14 | 15.87 | 11.59/20.82 | 9 | 91 | 52.28/5436.42 | 22.45/48.93 |
| 014545 | 10 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 1 | 54.41 | 15.6 | 936 | 50.68 | 11.21 | 13.08/24.89 | 9 | 93 | 60.63/5473.03 | 15.96/40.79 |
| 014545 | 10 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 2 | 52.85 | 18.92 | 909 | 49.26 | 13.08 | 13.57/25.4 | 9 | 93 | 72.47/5930.3 | 14.93/31.79 |
| 014545 | 10 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 3 | 52.45 | 19.13 | 920 | 48.44 | 12.61 | 13.57/25.08 | 9 | 91 | 47.4/5498.26 | 14.01/33.69 |
| 014759 | 10 | GLSurfaceView/VD | inverse | SQLCipher B (4.19.0 community) | 1 | 51.34 | 19.31 | 901 | 48.41 | 14.52 | 12.93/24.73 | 9 | 85 | 58.41/5351.52 | 22.91/63.66 |
| 014759 | 10 | GLSurfaceView/VD | inverse | SQLCipher B (4.19.0 community) | 2 | 52.54 | 19.16 | 908 | 49.07 | 14.3 | 13.2/24.71 | 9 | 93 | 57.39/5507.29 | 15.94/40.91 |
| 014759 | 10 | GLSurfaceView/VD | inverse | SQLCipher B (4.19.0 community) | 3 | 53.64 | 19.65 | 911 | 49.43 | 13.05 | 13.06/24.39 | 9 | 93 | 62.47/5779.13 | 20.05/30.92 |
| 015015 | 10 | TextureView | holes | SQLCipher B (4.19.0 community) | 1 | 53.22 | 23.03 | 864 | 46.41 | 14.0 | 10.43/20.24 | 9 | 85 | 42.25/5298.73 | 27.35/61.28 |
| 015015 | 10 | TextureView | holes | SQLCipher B (4.19.0 community) | 2 | 52.23 | 22.16 | 871 | 45.54 | 12.27 | 10.42/19.71 | 9 | 91 | 66.57/5471.92 | 17.23/35.17 |
| 015015 | 10 | TextureView | holes | SQLCipher B (4.19.0 community) | 3 | 53.63 | 22.1 | 878 | 47.15 | 12.97 | 10.63/20.45 | 9 | 91 | 57.78/5947.86 | 17.57/70.57 |
| 015230 | 10 | GLSurfaceView/VD | holes | SQLCipher A (4.19.0 community) | 1 | 52.6 | 20.56 | 890 | 48.09 | 14.48 | 13.59/25.4 | 11 | 104 | 913.83/1512.13 | 18.39/23.81 |
| 015230 | 10 | GLSurfaceView/VD | holes | SQLCipher A (4.19.0 community) | 2 | 52.57 | 20.31 | 896 | 47.65 | 14.27 | 13.68/25.85 | 11 | 106 | 815.21/1540.03 | 14.62/42.61 |
| 015230 | 10 | GLSurfaceView/VD | holes | SQLCipher A (4.19.0 community) | 3 | 50.82 | 22.06 | 866 | 46.57 | 16.26 | 13.71/27.48 | 11 | 106 | 971.71/1650.3 | 15.33/34.17 |
| 015527 | 5 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 1 | 54.72 | 13.79 | 972 | 50.98 | 8.63 | 13.43/24.2 | 0 | 0 | -1.0/0.0 | -1.0/0.0 |
| 015527 | 5 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 2 | 52.71 | 14.23 | 963 | 50.12 | 9.44 | 13.34/24.18 | 0 | 0 | -1.0/0.0 | -1.0/0.0 |
| 015527 | 5 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 3 | 53.7 | 15.2 | 954 | 50.53 | 9.95 | 13.85/26.44 | 0 | 0 | -1.0/0.0 | -1.0/0.0 |
| 015747 | 14 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 1 | 45.93 | 28.73 | 790 | 41.94 | 23.16 | 14.43/28.22 | 8 | 95 | 17.57/6244.75 | 28.83/90.69 |
| 015747 | 14 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 2 | 49.4 | 24.34 | 834 | 44.22 | 17.72 | 13.76/26.75 | 9 | 102 | 21.7/5736.38 | 25.91/65.02 |
| 015747 | 14 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 3 | 48.81 | 24.61 | 841 | 45.39 | 19.19 | 13.84/28.02 | 9 | 99 | 28.21/5310.72 | 24.42/60.73 |
| 015959 | 18 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 1 | 42.23 | 29.98 | 814 | 42.09 | 23.44 | 15.59/31.76 | 11 | 112 | 587.91/740.47 | 5.43/17.35 |
| 015959 | 18 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 2 | 45.21 | 27.92 | 838 | 44.1 | 23.63 | 15.29/32.11 | 11 | 112 | 587.53/704.1 | 5.24/13.98 |
| 015959 | 18 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 3 | 42.88 | 26.85 | 838 | 43.39 | 23.21 | 15.47/31.38 | 11 | 112 | 546.62/857.93 | 9.59/16.2 |
| 021129 | 10 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 1 | 49.35 | 20.88 | 867 | 45.73 | 15.09 | 13.7/25.21 | 9 | 85 | 58.91/5356.57 | 18.4/71.72 |
| 021129 | 10 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 2 | 50.98 | 21.25 | 880 | 46.9 | 14.89 | 13.93/26.79 | 9 | 91 | 55.76/5740.49 | 17.71/35.14 |
| 021129 | 10 | GLSurfaceView/VD | holes | SQLCipher B (4.19.0 community) | 3 | 51.75 | 20.18 | 887 | 47.93 | 14.99 | 13.28/25.89 | 9 | 93 | 83.21/5876.46 | 18.83/34.63 |
