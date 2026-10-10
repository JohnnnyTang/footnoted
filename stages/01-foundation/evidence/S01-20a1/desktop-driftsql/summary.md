runs: 3; env: {"runner":"desktop-cli","label":"win11 desktop AOT, driftsql, cipher on, run1","build":"aot","os":"windows","os_version":"\"Windows 11 家庭版 中文版\" 10.0 (Build 26300)","dart":"3.13.5 (stable) (Tue Sep 29 01:00:52 2026 -0700) on \"windows_x64\"","cpus":8,"utc":"2026-10-10T01:25:22.065656Z"}

sqlite (probe): {"sqlite_version":"3.53.4","cipher_version":"4.19.0 community","rtree_compile_option":true,"cipher_available":true,"cipher_provider":"openssl","cipher_provider_version":"OpenSSL 4.0.3 29 Sep 2026","rtree_query_ids":[1],"journal_mode":"wal","synchronous":1,"file_header_is_plain_sqlite":false,"file_header_hex":"a3fed82c70c49a9340fa74b78f3ce9d7"}

dataset: dataset.segcells.bin; 2982 segments; 9714696 (cell, segment) rows; 1169242 unique cells; 458360 spans; long leg {"id":564,"label":"","rows":899508,"spans":25599}; z10 tiles {"densest":[229,455],"long_leg":[225,442]}

cipher_version read on each cipher-on store connection: 4.19.0 community

| Layout | Driver | Cipher | Leg insert ms | Full insert ms | Delete leg ms | VACUUM ms | Size MiB | Plain header |
|---|---|---|---:|---:|---:|---:|---:|---|
| A | driftsql | on | 1110 | 85884 | 1017 | 3237 | 265.4 | false |
| B | driftsql | on | 775 | 2579 | 1959 | 355 | 30.0 | false |

F01.3 `cell_rollups`: build ms (rows) per level, total build ms, table size MiB

| Layout | Driver | Cipher | L16 | L12 | L8 | Total ms | Size MiB |
|---|---|---|---:|---:|---:|---:|---:|
| A | driftsql | on | 683 (7610) | 1 (199) | 0 (18) | 684 | 0.13 |
| B | driftsql | on | 289 (7610) | 1 (199) | 0 (18) | 291 | 0.13 |

z10 tile `densest`, median ms per level (cells: L8 1, L12 7, L16 606, L20 112296)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| A | driftsql | on | 452 | 473 | 617 | 548 |
| B | driftsql | on | 1603 | 1638 | 1646 | 1675 |

z10 tile `densest/cell_rollups`, median ms per level (cells: L8 1, L12 7, L16 606)

| Layout | Driver | Cipher | L8 | L12 | L16 |
|---|---|---|---:|---:|---:|
| A | driftsql | on | 0.004 | 0.008 | 0.323 |
| B | driftsql | on | 0.004 | 0.007 | 0.324 |

z10 tile `long_leg`, median ms per level (cells: L8 1, L12 4, L16 200, L20 32747)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| A | driftsql | on | 122 | 126 | 132 | 152 |
| B | driftsql | on | 5.82 | 5.17 | 5.09 | 9.60 |

z10 tile `long_leg/cell_rollups`, median ms per level (cells: L8 1, L12 4, L16 200)

| Layout | Driver | Cipher | L8 | L12 | L16 |
|---|---|---|---:|---:|---:|
| A | driftsql | on | 0.004 | 0.007 | 0.130 |
| B | driftsql | on | 0.005 | 0.009 | 0.169 |

z10 tile `densest/cell_stats`, median ms per level (cells: L8 1, L12 7, L16 606, L20 112296)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| B | driftsql | on | 8.25 | 8.39 | 12.2 | 95.6 |

z10 tile `long_leg/cell_stats`, median ms per level (cells: L8 1, L12 4, L16 200, L20 32747)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| B | driftsql | on | 20.4 | 19.8 | 22.7 | 39.4 |

Spread, full insert ms per run: A/driftsql/true 84089/85884/87017; B/driftsql/true 2588/2553/2579
