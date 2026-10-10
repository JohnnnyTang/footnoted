# storage_bench on unknown Android SDK built for x86_64, release (*emulator — no pass/fail*)

- **Device:** unknown Android SDK built for x86_64, Android 16 (SDK 36), x86_64, serial `emulator-5554` — **emulator — no pass/fail**
- **Build:** release APK (`flutter build apk --release`), SQLCipher via the root `hooks.user_defines` (D-011)
- **Method:** 3 launches, each a fresh process (`am force-stop` + `am start`); every number is the median across launches. Per configuration: a fresh database, leg insert, full insert in one transaction, VACUUM + size, `cell_rollups` build, tile queries (one checked warm-up + median of 5), leg delete.
- **Dataset:** `dataset.trace.ndjson` → `dataset.segcells.bin` sha256 `22739288fc0633530a2436c0f1573de9d931984e27daceb1e0119fb09419b7c2` (verified on the device)
- **Collected:** 2026-10-09T15:43:22.012996Z

runs: 3; env: {"runner":"flutter-app","build":"release","os":"android","os_version":"sdk_phone64_x86_64-userdebug 16 BE2A.250530.026.D1 13818094 test-keys","dart":"3.13.5 (stable) (Tue Sep 29 01:00:52 2026 -0700) on \"android_x64\"","cpus":4,"utc":"2026-10-09T15:26:23.288452Z"}

sqlite (probe): {"sqlite_version":"3.53.4","cipher_version":"4.19.0 community","rtree_compile_option":true,"cipher_available":true,"cipher_provider":"openssl","cipher_provider_version":"OpenSSL 4.0.3 29 Sep 2026","rtree_query_ids":[1],"journal_mode":"wal","synchronous":1,"file_header_is_plain_sqlite":false,"file_header_hex":"8dc0133ae6208f31e2eb2ded9369e13d"}

dataset: dataset.segcells.bin; 2982 segments; 9714696 (cell, segment) rows; 1169242 unique cells; 458360 spans; long leg {"id":564,"label":"","rows":899508,"spans":25599}; z10 tiles {"densest":[229,455],"long_leg":[225,442]}

cipher_version read on each cipher-on store connection: 4.19.0 community

| Layout | Driver | Cipher | Leg insert ms | Full insert ms | Delete leg ms | VACUUM ms | Size MiB | Plain header |
|---|---|---|---:|---:|---:|---:|---:|---|
| A | raw | on | 1011 | 70544 | 922 | 3332 | 265.4 | false |
| A | drift | on | 2819 | 94474 | 818 | 3258 | 265.4 | false |
| B | raw | on | 817 | 3392 | 1302 | 403 | 30.0 | false |
| B | drift | on | 4282 | 9035 | 4575 | 336 | 30.0 | false |
| A | raw | off | 870 | 23847 | 613 | 1938 | 260.0 | true |
| A | drift | off | 3018 | 45822 | 561 | 1697 | 260.0 | true |
| B | raw | off | 802 | 3193 | 1188 | 225 | 29.4 | true |
| B | drift | off | 4089 | 8953 | 4483 | 223 | 29.4 | true |

F01.3 `cell_rollups`: build ms (rows) per level, total build ms, table size MiB

| Layout | Driver | Cipher | L16 | L12 | L8 | Total ms | Size MiB |
|---|---|---|---:|---:|---:|---:|---:|
| A | raw | on | 792 (7610) | 8 (199) | 0 (18) | 808 | 0.13 |
| A | drift | on | 840 (7610) | 12 (199) | 0 (18) | 852 | 0.13 |
| B | raw | on | 388 (7610) | 2 (199) | 0 (18) | 389 | 0.13 |
| B | drift | on | 399 (7610) | 1 (199) | 0 (18) | 402 | 0.13 |
| A | raw | off | 680 (7610) | 9 (199) | 0 (18) | 691 | 0.12 |
| A | drift | off | 598 (7610) | 8 (199) | 0 (18) | 599 | 0.12 |
| B | raw | off | 464 (7610) | 2 (199) | 0 (18) | 466 | 0.12 |
| B | drift | off | 350 (7610) | 1 (199) | 0 (18) | 351 | 0.12 |

z10 tile `densest`, median ms per level (cells: L8 1, L12 7, L16 606, L20 112296)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| A | raw | on | 389 | 414 | 545 | 473 |
| A | drift | on | 401 | 415 | 555 | 551 |
| B | raw | on | 1226 | 1206 | 1211 | 1455 |
| B | drift | on | 1606 | 1532 | 1620 | 1833 |
| A | raw | off | 339 | 358 | 480 | 381 |
| A | drift | off | 335 | 351 | 496 | 487 |
| B | raw | off | 432 | 432 | 504 | 683 |
| B | drift | off | 820 | 796 | 838 | 1174 |

z10 tile `densest/cell_rollups`, median ms per level (cells: L8 1, L12 7, L16 606)

| Layout | Driver | Cipher | L8 | L12 | L16 |
|---|---|---|---:|---:|---:|
| A | raw | on | 0.007 | 0.009 | 0.148 |
| A | drift | on | 0.004 | 0.008 | 0.329 |
| B | raw | on | 0.011 | 0.013 | 0.171 |
| B | drift | on | 0.003 | 0.006 | 0.211 |
| A | raw | off | 0.006 | 0.007 | 0.143 |
| A | drift | off | 0.006 | 0.008 | 0.451 |
| B | raw | off | 0.006 | 0.007 | 0.132 |
| B | drift | off | 0.004 | 0.006 | 0.238 |

z10 tile `long_leg`, median ms per level (cells: L8 1, L12 4, L16 200, L20 32747)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| A | raw | on | 120 | 118 | 120 | 130 |
| A | drift | on | 119 | 120 | 131 | 153 |
| B | raw | on | 4.49 | 5.31 | 4.76 | 17.1 |
| B | drift | on | 8.13 | 7.73 | 7.75 | 20.8 |
| A | raw | off | 77.2 | 80.6 | 84.5 | 88.1 |
| A | drift | off | 78.9 | 79.9 | 85.4 | 101 |
| B | raw | off | 4.08 | 4.13 | 4.87 | 16.8 |
| B | drift | off | 7.76 | 8.48 | 8.27 | 21.3 |

z10 tile `long_leg/cell_rollups`, median ms per level (cells: L8 1, L12 4, L16 200)

| Layout | Driver | Cipher | L8 | L12 | L16 |
|---|---|---|---:|---:|---:|
| A | raw | on | 0.008 | 0.008 | 0.102 |
| A | drift | on | 0.003 | 0.006 | 0.132 |
| B | raw | on | 0.006 | 0.008 | 0.113 |
| B | drift | on | 0.004 | 0.006 | 0.129 |
| A | raw | off | 0.006 | 0.008 | 0.098 |
| A | drift | off | 0.005 | 0.008 | 0.161 |
| B | raw | off | 0.006 | 0.008 | 0.136 |
| B | drift | off | 0.004 | 0.007 | 0.127 |

z10 tile `densest/cell_stats`, median ms per level (cells: L8 1, L12 7, L16 606, L20 112296)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| B | raw | on | 7.65 | 8.32 | 12.0 | 51.5 |
| B | drift | on | 7.35 | 8.54 | 12.5 | 123 |
| B | raw | off | 7.45 | 7.79 | 12.9 | 52.8 |
| B | drift | off | 7.04 | 8.40 | 12.7 | 129 |

z10 tile `long_leg/cell_stats`, median ms per level (cells: L8 1, L12 4, L16 200, L20 32747)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| B | raw | on | 19.8 | 20.1 | 19.3 | 29.1 |
| B | drift | on | 19.6 | 20.4 | 19.6 | 40.5 |
| B | raw | off | 13.4 | 12.7 | 15.6 | 22.8 |
| B | drift | off | 13.0 | 12.8 | 14.2 | 33.2 |

Spread, full insert ms per run: A/raw/true 77797/67003/70544; A/drift/true 94474/95459/89874; B/raw/true 3627/3341/3392; B/drift/true 9035/8822/9483; A/raw/false 24142/23847/23198; A/drift/false 45822/44254/47290; B/raw/false 3223/3193/3060; B/drift/false 8953/8412/9011
