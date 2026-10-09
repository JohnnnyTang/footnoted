# M0 spike data formats

**Status:** frozen for W1 (kickoff seam) · **Owner:** orchestrator · **Lifetime:** removed with `spike/` at G1 (tag `m0-spike`).

Every W1 session reads and writes these formats. A session that needs a change stops and raises it in its note; it does not change this file.

General rules for every file below:

- Encoding UTF-8, LF line endings, binary integers **little-endian**.
- Output must be **deterministic**: the same generator seed gives byte-identical files.
- Generated files are not committed (`.gitignore` covers `*.trace.ndjson`, `*.cells.bin`, `*.segcells.bin` and `spike/**/out/`). Regenerate them from the seed. Small hand-made fixtures that a test needs may be committed under the owning package with a `.gitignore` exception.

## 1. Cell IDs

A cell is a Web Mercator tile `(x, y)` at level `L` (256 px tiles, latitude clamped to ±85.05112878°, `x` grows east, `y` grows south).

```
id = (x << L) | y          // int64; at L = 20 this is F01.1
x  = id >> L
y  = id & ((1 << L) - 1)
parent at level P < L:  (x >> (L - P), y >> (L - P)), packed with shift P
```

The level is never encoded in the ID; it is carried by the file's metadata. G1 freezes the production packing (F01.1).

## 2. Trace file `*.trace.ndjson`

One JSON object per line. Two line types, told apart by their keys.

**Segment header**, written immediately before the segment's first point:

```json
{"segment":12,"kind":"local","mode":"straight","buffer_m":100,"reveal":"line","label":"home: commute 2023-04-11"}
```

| Key | Type | Meaning |
| --- | --- | --- |
| `segment` | int ≥ 0 | Ground-truth segment ID, unique in the file. |
| `kind` | `"local"` \| `"transit"` | Handoff segment kind. |
| `mode` | `"straight"` \| `"great_circle"` | How consecutive points are joined. |
| `buffer_m` | number | Effective buffer in metres (D-007; F01.6). |
| `reveal` | `"line"` \| `"endpoints"` | `line`: dilate the whole joined line by `buffer_m`. `endpoints`: dilate only the first and last point (flights). |
| `label` | string | Human-readable; for logs only. |

Defaults the generator uses: home-city and foreign-stay segments `local / straight / 100 / line`; road-trip legs `transit / straight / 500 / line` (the spike's worst case, "transit reveal on"); flights `transit / great_circle / 500 / endpoints`.

**Point**:

```json
{"ts":1681200000000,"lat":48.8566140,"lon":2.3522219,"acc":12.5,"src":"gps","seg":12}
```

| Key | Type | Meaning |
| --- | --- | --- |
| `ts` | int | Epoch milliseconds, UTC. |
| `lat`, `lon` | number | Degrees, WGS84. `lon` in [-180, 180]. |
| `acc` | number \| null | Horizontal accuracy in metres. |
| `src` | `"gps"` \| `"media"` | Fix source. |
| `seg` | int | The segment this point belongs to. |

Points are sorted by `ts` (ties keep generation order). Segments do not overlap in time, so every segment's points are contiguous and follow its header.

## 3. Cell dump `*.cells.bin` + `*.cells.json`

`*.cells.bin`: a flat array of int64 cell IDs (section 1), **sorted ascending, no duplicates**, no header. `count = file size / 8`.

`*.cells.json`, same basename:

```json
{"count":1003211,"level":20,"buffer_m":null,"source_trace":"dataset.trace.ndjson","sha256":"<lowercase hex of the .bin bytes>"}
```

`buffer_m` is a number when one buffer was applied to every segment, or `null` when each segment used its own header `buffer_m`. `source_trace` is a file name (no directory), or `null` for stand-in dumps that were not built from a trace.

## 4. Per-segment cell dump `*.segcells.bin` + `*.segcells.json`

Repeated records, no file header:

```
[int64 segment_id][int64 n][n × int64 cell_id]
```

Records are ordered by `segment_id` ascending. Cells inside a record are sorted ascending with no duplicates. Every segment in the source trace has a record, with `n = 0` allowed. The union of all records equals the matching `*.cells.bin`.

`*.segcells.json`, same basename:

```json
{"segments":4120,"rows":1650332,"level":20,"source_trace":"dataset.trace.ndjson","sha256":"<lowercase hex of the .bin bytes>"}
```

`rows` is the total of all `n`, i.e. the number of (cell, segment) rows the per-cell layout (F01.2) would store.

## 5. Where files live

- The generator writes to the `--out` directory it is given; the convention is `spike/out/` (ignored by git).
- Before S01-10 merges, sibling spikes may build **stand-in** dumps in their own `out/` directory, in exactly these formats with `source_trace: null`. W2 swaps in the real dataset.
