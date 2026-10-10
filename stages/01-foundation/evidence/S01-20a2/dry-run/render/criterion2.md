# Exit criterion 2 — Android render step

- **Device:** unknown Android SDK built for x86_64, Android 16 (SDK 36, x86_64), serial emulator-5554 — **emulator — no pass/fail**
- **Build:** profile
- **Coverage:** z20 cells 1169242; SQLCipher `cipher_version` from the fog's own connection: 4.19.0 community
- **Method:** SurfaceFlinger `--latency` on the Flutter `SurfaceView (BLAST)` layer, cut to each measured pass (20 s); the worst pass of every run of a configuration.
- **Bar:** median ≥ 55 fps and ≤ 5 % of frames over 32 ms on every measured pass, at z10. z5 / z14 / z18 rows are spot runs for level-mapping cliffs.

| configuration | runs | passes | worst median fps | worst % > 32 ms | min frames | verdict |
|---|---|---|---|---|---|---|
| z10 · GLSurfaceView/VD · inverse d6 · SQLCipher layout B | 3 | 9 | 51.34 | 21.61 | 893 | emulator — no pass/fail |
| z10 · TextureView · holes d6 · SQLCipher layout B | 3 | 9 | 52.23 | 25.09 | 838 | emulator — no pass/fail |
| z10 · GLSurfaceView/VD · holes d6 · SQLCipher layout B | 3 | 9 | 49.35 | 21.25 | 867 | emulator — no pass/fail |
| z10 · GLSurfaceView/VD · holes d6 · SQLCipher layout A | 1 | 3 | 50.82 | 22.06 | 866 | emulator — no pass/fail |
| z5 · GLSurfaceView/VD · holes d6 · SQLCipher layout B | 1 | 3 | 52.71 | 15.2 | 954 | emulator — no pass/fail |
| z14 · GLSurfaceView/VD · holes d6 · SQLCipher layout B | 1 | 3 | 45.93 | 28.73 | 790 | emulator — no pass/fail |
| z18 · GLSurfaceView/VD · holes d6 · SQLCipher layout B | 1 | 3 | 42.23 | 29.98 | 814 | emulator — no pass/fail |
