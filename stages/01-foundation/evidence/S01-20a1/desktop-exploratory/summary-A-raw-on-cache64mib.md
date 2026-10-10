runs: 1; env: {"runner":"desktop-cli","label":"win11 desktop AOT, A/raw/on, cache_size 64 MiB","build":"aot","os":"windows","os_version":"\"Windows 11 家庭版 中文版\" 10.0 (Build 26300)","dart":"3.13.5 (stable) (Tue Sep 29 01:00:52 2026 -0700) on \"windows_x64\"","cpus":8,"utc":"2026-10-09T14:54:23.971448Z"}

sqlite (probe): {"sqlite_version":"3.53.4","cipher_version":"4.19.0 community","rtree_compile_option":true,"cipher_available":true,"cipher_provider":"openssl","cipher_provider_version":"OpenSSL 4.0.3 29 Sep 2026","rtree_query_ids":[1],"journal_mode":"wal","synchronous":1,"file_header_is_plain_sqlite":false,"file_header_hex":"75399a8f3fea5c04a53703dd4cbce6ec"}

dataset: dataset.segcells.bin; 2982 segments; 9714696 (cell, segment) rows; 1169242 unique cells; 458360 spans; long leg {"id":564,"label":"","rows":899508,"spans":25599}; z10 tiles {"densest":[229,455],"long_leg":[225,442]}

cipher_version read on each cipher-on store connection: 4.19.0 community

| Layout | Driver | Cipher | Leg insert ms | Full insert ms | Delete leg ms | VACUUM ms | Size MiB | Plain header |
|---|---|---|---:|---:|---:|---:|---:|---|
| A | raw | on | 1092 | 17389 | 963 | 3876 | 265.4 | false |

F01.3 `cell_rollups`: build ms (rows) per level, total build ms, table size MiB

| Layout | Driver | Cipher | L16 | L12 | L8 | Total ms | Size MiB |
|---|---|---|---:|---:|---:|---:|---:|
| A | raw | on | 747 (7610) | 2 (199) | 0 (18) | 749 | 0.13 |

z10 tile `densest`, median ms per level (cells: L8 1, L12 7, L16 606, L20 112296)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| A | raw | on | 465 | 473 | 649 | 541 |

z10 tile `densest/cell_rollups`, median ms per level (cells: L8 1, L12 7, L16 606)

| Layout | Driver | Cipher | L8 | L12 | L16 |
|---|---|---|---:|---:|---:|
| A | raw | on | 0.011 | 0.012 | 0.149 |

z10 tile `long_leg`, median ms per level (cells: L8 1, L12 4, L16 200, L20 32747)

| Layout | Driver | Cipher | L8 | L12 | L16 | L20 |
|---|---|---|---:|---:|---:|---:|
| A | raw | on | 76.8 | 79.3 | 81.3 | 85.0 |

z10 tile `long_leg/cell_rollups`, median ms per level (cells: L8 1, L12 4, L16 200)

| Layout | Driver | Cipher | L8 | L12 | L16 |
|---|---|---|---:|---:|---:|
| A | raw | on | 0.012 | 0.014 | 0.148 |

Spread, full insert ms per run: A/raw/true 17389
