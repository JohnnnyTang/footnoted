runs: 3; env: {"runner":"desktop-cli","label":"win11 desktop, dart build cli AOT, run1","build":"aot","os":"windows","os_version":"\"Windows 11 家庭版 中文版\" 10.0 (Build 26300)","dart":"3.13.5 (stable) (Tue Sep 29 01:00:52 2026 -0700) on \"windows_x64\"","cpus":8,"utc":"2026-10-09T14:31:43.217350Z"}

sqlite (probe): {"sqlite_version":"3.53.4","cipher_version":"4.19.0 community","rtree_compile_option":true,"cipher_available":true,"cipher_provider":"openssl","cipher_provider_version":"OpenSSL 4.0.3 29 Sep 2026","rtree_query_ids":[1],"journal_mode":"wal","synchronous":1,"file_header_is_plain_sqlite":false,"file_header_hex":"7994c5618dc3466947f2f277f6e9bd4c"}

dataset: dataset.segcells.bin; 2982 segments; 9714696 (cell, segment) rows; 1169242 unique cells; 458360 spans; long leg {"id":564,"label":"","rows":899508,"spans":25599}; z10 tiles {"densest":[229,455],"long_leg":[225,442]}

cipher_version read on each cipher-on store connection: 4.19.0 community

| Layout | Driver | Cipher | Leg insert ms | Full insert ms | Delete leg ms | VACUUM ms | Size MiB | Plain header |
|---|---|---|---:|---:|---:|---:|---:|---|
| A | raw | on | 1031 | 95151 | 1134 | 3526 | 265.4 | false |
| A | drift | on | 2284 | 110843 | 1114 | 4085 | 265.4 | false |
| B | raw | on | 637 | 2430 | 1341 | 370 | 30.0 | false |
| B | drift | on | 2922 | 6462 | 3547 | 382 | 30.0 | false |
| A | raw | off | 918 | 50830 | 857 | 2331 | 260.0 | true |
| A | drift | off | 2215 | 64868 | 835 | 2354 | 260.0 | true |
| B | raw | off | 621 | 2428 | 1240 | 261 | 29.4 | true |
| B | drift | off | 2906 | 6047 | 3629 | 247 | 29.4 | true |

F01.3 `cell_rollups`: build ms (rows) per level, total build ms, table size MiB

| Layout | Driver | Cipher | L16 | L12 | L8 | Total ms | Size MiB |
|---|---|---|---:|---:|---:|---:|---:|
| A | raw | on | 711 (7610) | 1 (199) | 0 (18) | 712 | 0.13 |
| A | drift | on | 757 (7610) | 1 (199) | 0 (18) | 758 | 0.13 |
| B | raw | on | 300 (7610) | 1 (199) | 0 (18) | 302 | 0.13 |
| B | drift | on | 294 (7610) | 1 (199) | 0 (18) | 295 | 0.13 |
| A | raw | off | 589 (7610) | 2 (199) | 0 (18) | 591 | 0.12 |
| A | drift | off | 595 (7610) | 1 (199) | 0 (18) | 596 | 0.12 |
| B | raw | off | 268 (7610) | 2 (199) | 0 (18) | 269 | 0.12 |
| B | drift | off | 280 (7610) | 1 (199) | 0 (18) | 281 | 0.12 |

z10 tile `densest`, median ms per level (cells: L8 1, L12 7, L16 606, L20 112296)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| A | raw | on | 453 | 477 | 638 | 521 |
| A | drift | on | 472 | 466 | 626 | 584 |
| B | raw | on | 1653 | 1489 | 1491 | 1693 |
| B | drift | on | 1767 | 1754 | 1888 | 1852 |
| A | raw | off | 399 | 407 | 547 | 421 |
| A | drift | off | 399 | 402 | 542 | 469 |
| B | raw | off | 758 | 732 | 786 | 796 |
| B | drift | off | 1015 | 1092 | 1120 | 1072 |

z10 tile `densest/cell_rollups`, median ms per level (cells: L8 1, L12 7, L16 606)

| Layout | Driver | Cipher | L8 | L12 | L16 |
|---|---|---|---:|---:|---:|
| A | raw | on | 0.009 | 0.023 | 0.149 |
| A | drift | on | 0.004 | 0.006 | 0.200 |
| B | raw | on | 0.007 | 0.009 | 0.155 |
| B | drift | on | 0.004 | 0.007 | 0.250 |
| A | raw | off | 0.006 | 0.007 | 0.141 |
| A | drift | off | 0.005 | 0.007 | 0.231 |
| B | raw | off | 0.006 | 0.008 | 0.135 |
| B | drift | off | 0.004 | 0.007 | 0.241 |

z10 tile `long_leg`, median ms per level (cells: L8 1, L12 4, L16 200, L20 32747)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| A | raw | on | 126 | 127 | 135 | 139 |
| A | drift | on | 128 | 134 | 137 | 147 |
| B | raw | on | 3.85 | 4.25 | 3.73 | 8.29 |
| B | drift | on | 7.33 | 7.56 | 7.54 | 12.0 |
| A | raw | off | 96.9 | 100 | 103 | 117 |
| A | drift | off | 103 | 102 | 105 | 119 |
| B | raw | off | 3.86 | 4.02 | 4.26 | 9.11 |
| B | drift | off | 7.21 | 7.02 | 7.10 | 12.4 |

z10 tile `long_leg/cell_rollups`, median ms per level (cells: L8 1, L12 4, L16 200)

| Layout | Driver | Cipher | L8 | L12 | L16 |
|---|---|---|---:|---:|---:|
| A | raw | on | 0.006 | 0.009 | 0.119 |
| A | drift | on | 0.005 | 0.009 | 0.159 |
| B | raw | on | 0.006 | 0.008 | 0.102 |
| B | drift | on | 0.005 | 0.008 | 0.151 |
| A | raw | off | 0.006 | 0.009 | 0.132 |
| A | drift | off | 0.004 | 0.007 | 0.144 |
| B | raw | off | 0.006 | 0.009 | 0.106 |
| B | drift | off | 0.005 | 0.008 | 0.141 |

z10 tile `densest/cell_stats`, median ms per level (cells: L8 1, L12 7, L16 606, L20 112296)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| B | raw | on | 7.66 | 8.10 | 11.9 | 40.6 |
| B | drift | on | 8.57 | 8.47 | 12.2 | 94.5 |
| B | raw | off | 8.05 | 8.49 | 13.2 | 39.4 |
| B | drift | off | 7.99 | 8.67 | 12.4 | 95.6 |

z10 tile `long_leg/cell_stats`, median ms per level (cells: L8 1, L12 4, L16 200, L20 32747)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| B | raw | on | 19.9 | 21.0 | 22.6 | 29.3 |
| B | drift | on | 21.8 | 23.0 | 21.7 | 38.9 |
| B | raw | off | 16.8 | 17.9 | 17.7 | 25.7 |
| B | drift | off | 17.5 | 18.2 | 17.6 | 35.7 |

Spread, full insert ms per run: A/raw/true 88459/95599/95151; A/drift/true 110843/108666/111491; B/raw/true 2430/2402/2554; B/drift/true 6462/6368/6610; A/raw/false 47144/50830/51916; A/drift/false 61274/65438/64868; B/raw/false 2556/2207/2428; B/drift/false 6047/5991/6480
