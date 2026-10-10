# storage_bench on unknown Android SDK built for x86_64, release (*emulator — no pass/fail*)

- **Device:** unknown Android SDK built for x86_64, Android 16 (SDK 36), x86_64, serial `emulator-5554` — **emulator — no pass/fail**
- **Build:** release APK (`flutter build apk --release`), SQLCipher via the root `hooks.user_defines` (D-011)
- **Method:** 3 launches, each a fresh process (`am force-stop` + `am start`); every number is the median across launches. Per configuration: a fresh database, leg insert, full insert in one transaction, VACUUM + size, `cell_rollups` build, tile queries (one checked warm-up + median of 5), leg delete.
- **Dataset:** `dataset.trace.ndjson` → `dataset.segcells.bin` sha256 `22739288fc0633530a2436c0f1573de9d931984e27daceb1e0119fb09419b7c2` (verified on the device)
- **Collected:** 2026-10-10T02:54:28.730572Z

runs: 3; env: {"runner":"flutter-app","build":"release","os":"android","os_version":"sdk_phone64_x86_64-userdebug 16 BE2A.250530.026.D1 13818094 test-keys","dart":"3.13.5 (stable) (Tue Sep 29 01:00:52 2026 -0700) on \"android_x64\"","cpus":4,"utc":"2026-10-10T02:36:03.782863Z"}

sqlite (probe): {"sqlite_version":"3.53.4","cipher_version":"4.19.0 community","rtree_compile_option":true,"cipher_available":true,"cipher_provider":"openssl","cipher_provider_version":"OpenSSL 4.0.3 29 Sep 2026","rtree_query_ids":[1],"journal_mode":"wal","synchronous":1,"file_header_is_plain_sqlite":false,"file_header_hex":"2fd2bccc2ec29f441f6814635a70e363"}

dataset: dataset.segcells.bin; 2982 segments; 9714696 (cell, segment) rows; 1169242 unique cells; 458360 spans; long leg {"id":564,"label":"","rows":899508,"spans":25599}; z10 tiles {"densest":[229,455],"long_leg":[225,442]}

cipher_version read on each cipher-on store connection: 4.19.0 community

| Layout | Driver | Cipher | Leg insert ms | Full insert ms | Delete leg ms | VACUUM ms | Size MiB | Plain header |
|---|---|---|---:|---:|---:|---:|---:|---|
| A | raw | on | 1055 | 74331 | 962 | 3634 | 265.4 | false |
| A | drift | on | 3021 | 98803 | 867 | 3390 | 265.4 | false |
| B | raw | on | 1020 | 3760 | 1432 | 362 | 30.0 | false |
| B | drift | on | 4395 | 9925 | 5095 | 378 | 30.0 | false |
| A | raw | off | 929 | 25935 | 721 | 1863 | 260.0 | true |
| A | drift | off | 3210 | 49570 | 617 | 1816 | 260.0 | true |
| B | raw | off | 880 | 3469 | 1403 | 279 | 29.4 | true |
| B | drift | off | 4751 | 9606 | 5322 | 287 | 29.4 | true |

F01.3 `cell_rollups`: build ms (rows) per level, total build ms, table size MiB

| Layout | Driver | Cipher | L16 | L12 | L8 | Total ms | Size MiB |
|---|---|---|---:|---:|---:|---:|---:|
| A | raw | on | 900 (7610) | 10 (199) | 0 (18) | 908 | 0.13 |
| A | drift | on | 794 (7610) | 11 (199) | 0 (18) | 805 | 0.13 |
| B | raw | on | 377 (7610) | 2 (199) | 0 (18) | 379 | 0.13 |
| B | drift | on | 430 (7610) | 3 (199) | 0 (18) | 434 | 0.13 |
| A | raw | off | 710 (7610) | 10 (199) | 0 (18) | 718 | 0.12 |
| A | drift | off | 625 (7610) | 12 (199) | 0 (18) | 637 | 0.12 |
| B | raw | off | 457 (7610) | 2 (199) | 0 (18) | 459 | 0.12 |
| B | drift | off | 479 (7610) | 1 (199) | 0 (18) | 480 | 0.12 |

z10 tile `densest`, median ms per level (cells: L8 1, L12 7, L16 606, L20 112296)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| A | raw | on | 454 | 450 | 602 | 558 |
| A | drift | on | 433 | 423 | 594 | 629 |
| B | raw | on | 1351 | 1251 | 1291 | 1462 |
| B | drift | on | 1703 | 1762 | 1767 | 1897 |
| A | raw | off | 354 | 367 | 500 | 411 |
| A | drift | off | 344 | 372 | 521 | 492 |
| B | raw | off | 536 | 463 | 467 | 718 |
| B | drift | off | 855 | 846 | 1034 | 1175 |

z10 tile `densest/cell_rollups`, median ms per level (cells: L8 1, L12 7, L16 606)

| Layout | Driver | Cipher | L8 | L12 | L16 |
|---|---|---|---:|---:|---:|
| A | raw | on | 0.010 | 0.011 | 0.139 |
| A | drift | on | 0.004 | 0.007 | 0.333 |
| B | raw | on | 0.005 | 0.007 | 0.129 |
| B | drift | on | 0.006 | 0.009 | 0.260 |
| A | raw | off | 0.006 | 0.007 | 0.149 |
| A | drift | off | 0.003 | 0.007 | 0.678 |
| B | raw | off | 0.006 | 0.012 | 0.141 |
| B | drift | off | 0.004 | 0.008 | 0.298 |

z10 tile `long_leg`, median ms per level (cells: L8 1, L12 4, L16 200, L20 32747)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| A | raw | on | 115 | 118 | 123 | 137 |
| A | drift | on | 118 | 114 | 114 | 148 |
| B | raw | on | 4.36 | 5.39 | 5.09 | 18.0 |
| B | drift | on | 8.95 | 8.78 | 8.35 | 21.6 |
| A | raw | off | 79.6 | 83.6 | 88.1 | 89.0 |
| A | drift | off | 83.2 | 81.9 | 91.4 | 110 |
| B | raw | off | 4.42 | 4.49 | 5.31 | 18.2 |
| B | drift | off | 8.85 | 9.25 | 8.89 | 22.8 |

z10 tile `long_leg/cell_rollups`, median ms per level (cells: L8 1, L12 4, L16 200)

| Layout | Driver | Cipher | L8 | L12 | L16 |
|---|---|---|---:|---:|---:|
| A | raw | on | 0.005 | 0.007 | 0.104 |
| A | drift | on | 0.010 | 0.010 | 0.150 |
| B | raw | on | 0.005 | 0.007 | 0.136 |
| B | drift | on | 0.006 | 0.009 | 0.175 |
| A | raw | off | 0.006 | 0.009 | 0.105 |
| A | drift | off | 0.003 | 0.005 | 0.112 |
| B | raw | off | 0.006 | 0.008 | 0.100 |
| B | drift | off | 0.004 | 0.006 | 0.136 |

z10 tile `densest/cell_stats`, median ms per level (cells: L8 1, L12 7, L16 606, L20 112296)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| B | raw | on | 7.90 | 8.18 | 12.4 | 60.9 |
| B | drift | on | 6.83 | 8.19 | 12.9 | 151 |
| B | raw | off | 8.53 | 8.98 | 12.0 | 57.8 |
| B | drift | off | 7.43 | 8.53 | 12.8 | 153 |

z10 tile `long_leg/cell_stats`, median ms per level (cells: L8 1, L12 4, L16 200, L20 32747)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| B | raw | on | 20.3 | 20.6 | 21.8 | 34.1 |
| B | drift | on | 21.6 | 22.6 | 22.0 | 41.2 |
| B | raw | off | 13.7 | 15.2 | 14.5 | 24.6 |
| B | drift | off | 14.1 | 13.6 | 15.8 | 36.5 |

Spread, full insert ms per run: A/raw/true 78696/73299/74331; A/drift/true 98927/95911/98803; B/raw/true 3599/3820/3760; B/drift/true 9925/9330/10244; A/raw/false 25935/25318/26264; A/drift/false 48671/49570/51202; B/raw/false 4014/3469/3348; B/drift/false 9606/9621/9351
