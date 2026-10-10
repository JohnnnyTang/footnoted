# FootNoted — Engineering Handoff

Oct 8, 2026 · @Frankie Miller

## How to use this doc

This is the starting brief for the coding agent building FootNoted. Read it fully, then produce an implementation plan for Milestone 0 and Milestone 1 before writing product code.

> **In the repo:** M0 + M1 are planned as **Stage 1** in [`stages/01-foundation/`](../stages/01-foundation/README.md); later milestones map to later stages ([`stages/README.md`](../stages/README.md)). Decisions taken since this brief was written are logged in [`decisions.md`](decisions.md); where one settles an item below, the item is updated in place.

Every requirement is tagged so you know how firm it is:

- **\[Decided\]** — settled with the owner. Build it this way; raise a concern only if you find a concrete technical blocker.
- **\[Proposed\]** — the recommended direction, not yet confirmed. Build so it can change cheaply.
- **\[Open\]** — unresolved. Collected in the last section; ask the owner before it blocks you.

When this doc and the code disagree later, update this doc. It is meant to live in the repo (export to Markdown as `docs/HANDOFF.md`).

## Product summary

FootNoted is a cross-platform (iOS + Android) app that records a person's life footprints on a dark, "misted" world map. Every place they have been lights up, so using it should feel like exploring the world and opening up new sights under their own feet.

**Two ways footprints get in:**

1. **Import mode** — the user picks photos and videos. GPS and timestamps are read from their metadata, the locations are ordered by time and connected into segments, and the area around them is revealed.
2. **Live recording mode** — the app reads phone GPS during a recording session and draws the route as it happens. Photos taken along the way appear as thumbnails at their location. Text notes can be attached to a location on their own or together with photos.

**What users see and do:**

- A dark base map where explored area lights up within a user-set buffer distance of their routes.
- Footprints grouped into **trips** — tight clusters of places joined by one or two long transit legs.
- A choice of how points are connected (straight line, great-circle arc, road-snapped, or not connected), and the ability to hand-edit any connection.
- Statistics on repeat visits and how much of the world they have explored.

**Name:** FootNoted (internal capital N). Do not style it with an asterisk; an unrelated financial publication uses "footnoted\*".

**Positioning:** a personal, private record of a life's journeys — not a fitness tracker and not a precision logger. A few hundred metres between samples is acceptable.

## Non-negotiable invariants

These hold in every milestone. Any design that breaks one is wrong, even if it is faster. All are **\[Decided\]**.

1. **Open source only.** Every library, map engine, tile source and data set must be open source or openly licensed. No proprietary SDKs, no paid map APIs, no paid location plugins.
2. **Raw points are the only source of truth.** GPS fixes and media coordinates are stored as captured. All route geometry, revealed cells and statistics are derived and must be rebuildable from raw data.
3. **Original anchors are never overwritten.** A user correction to a photo's location is a separate row. EXIF values stay intact.
4. **Connection mode is a view, not data.** Never store inferred geometry as if it were recorded. Changing a segment's mode must be instant and reversible.
5. **Reveal along segments, not just at points.** Sparse sampling must still reveal the full corridor between points.
6. **Coverage has provenance.** Every revealed cell records which segment revealed it, so editing or deleting a segment updates the map and stats correctly.
7. **Local-first.** All user data lives on the device, encrypted at rest. Nothing leaves the device unless the user explicitly turns on a feature that needs it.
8. **The user decides.** Automatic grouping, segmentation and connection choices are suggestions with sensible defaults; the user can always override them.
9. **History is never held hostage.** No future paywall, lapse or error may hide or lock a user's existing map, photos or history.
10. **No ads, no analytics SDKs that see location, no data sales.** Ever.

## Tech stack

Flutter + MapLibre + SQLite, all on-device, with no backend until sync or road routing ships.

| Layer | Choice | Status | Notes |
| --- | --- | --- | --- |
| App framework | Flutter (Dart) | \[Decided\] | Chosen for native FFI and consistent rendering. React Native was the runner-up. |
| Map engine | MapLibre GL Native via `maplibre_gl` | \[Decided\] | Only serious open-source vector engine on mobile. Supports PMTiles and offline regions. |
| Base tiles (online) | OpenFreeMap public instance | \[Decided\] | No keys, no limits. Attribution required (see Compliance). |
| Base tiles (offline / self-host) | Protomaps PMTiles extracts | \[Decided\] | Region extracts via the `pmtiles` CLI, served from S3-compatible storage with byte-range reads. |
| Map style | Custom dark style forked from OpenFreeMap dark or Protomaps dark | \[Decided\] | The unexplored look is the product identity. Strip it down; keep labels legible under fog. |
| Local database | SQLite with R\*Tree index; SQLCipher for encryption | \[Decided\] | Driver: Drift \[Decided\], confirmed at G1-A; the coverage hot path uses prepared SQL through `customStatement` batches (D-016). |
| Explored-area model | Discrete cell grid | \[Decided\] | Grid type \[Decided\]: Web Mercator quadkey at z20 (D-013). See Core architecture. |
| Live location | `geolocator` + `flutter_foreground_task` | \[Decided\] | Free stack only. Tracelet (Apache 2.0) is the fallback if passive mode needs more. |
| Photo metadata | `native_exif` or `exif` | \[Decided\] | Pick one during M2. |
| Video metadata | Platform channels: `AVAsset` (iOS), `MediaMetadataRetriever` (Android) | \[Decided\] | Do not use FFmpegKit; it was retired in 2025. |
| Road routing / map matching | Self-hosted Valhalla | \[Decided\], later | Opt-in feature only. Straight line and great-circle are local and need no server. |
| Heavy geometry math | Dart first; Rust via FFI if profiling demands | \[Proposed\] | Candidates: cell rasterisation, scanline merge, polyline simplification. |
| Backend | None for now | \[Decided\] | Later: PocketBase for simple sync, or Postgres + PostGIS. |

**Rejected:** the commercial `flutter_background_geolocation` plugin (paid), any Google or Mapbox SDK (proprietary), FFmpegKit (retired), ad or analytics SDKs that can see location.

## Core architecture

Explored area is a set of grid cells, never a unioned buffer polygon. **\[Decided\]** A unioned polygon grows to hundreds of thousands of vertices within a few years of use and re-renders on every pan; integer cell IDs stay fast and make statistics trivial.

&#91;embedded content: data flow · 2 inputs, 1 source of truth, 4 derived layers\]

Raw points and user edits are the only stored truth; geometry, coverage, fog and statistics are rebuilt from them whenever a segment changes.

### Cell grid

- **\[Decided\]** (G1-A, D-013) Cells are Web Mercator tiles at **zoom 20**: about 38 m wide at the equator, 27 m at 45° latitude, 19 m at 60°. This aligns cells with map tiles and needs no dependency.
- Note: an earlier conversation mentioned z16–z18 for 25–50 m cells. That was wrong — a z17 tile is about 305 m. Use z20 (or z21 for \~19 m) to hit the intended size.
- Cell ID = `(x << 20) | y` packed into an int64.
- **Alternative (rejected at G1-A, D-013):** H3 hexagons via `h3_flutter`. Equal-area and prettier, but adds a native dependency, does not align with tiles, and has no run-length form or exact parents.

### Revealing cells

1. Build the segment's display geometry from its anchors, vias and connection mode.
2. Rasterise the geometry into z20 cells.
3. Dilate by the buffer: keep a cell at offset (dx, dy) cells when (dx² + dy²)·w² ≤ b², with b the buffer in metres and w the cell width at that row's latitude (the exact radius, per row; D-017 replaced `ceil(b ÷ w)`).
4. Write one coverage record per (cell, segment), stored physically as per-segment run-length spans plus a derived per-cell count (D-014). Never increment a bare counter that has no segment behind it.

Because reveal follows the line between points, sampling every few hundred metres reveals almost the same corridor as dense sampling.

### Rollups for low zoom

Maintain coarser rollup levels (**z16, z12, z8**, D-015) that store "any child covered" and a count. Low-zoom rendering and country-level stats read rollups, not raw cells. Rollups are a rebuildable cache.

### Fog rendering

- **\[Decided\] v1 is blocky.** For each visible tile, fetch covered cells at the matching level, merge them into rectangles with a scanline pass (no JTS, turf or GEOS needed), and render "tile minus rectangles" as a dark fill layer.
- **\[Proposed\] later polish:** soft edges by serving raster mask PNG tiles from a small in-app HTTP server, with blur applied, loaded by MapLibre as a raster source.

### Storage risk to measure in M0

A 1,000 km drive with a 500 m buffer touches roughly 700,000 z20 cells. One row per (cell, segment) may be too heavy for long legs. The spike must measure this. If it is too heavy, store coverage physically as run-length spans `(segment_id, y, x_start, x_end)` while keeping the logical (cell, segment) model and a derived per-cell stats table. **Settled at G1-A (D-014):** the real five-year dataset measured 265 MiB for per-cell rows against 30 MiB for spans, so coverage is stored as spans. The 1,033 km leg alone is 899,508 rows; the "~700,000" figure holds at the equator.

## Data model

Ship the full schema in M1, including tables whose UI comes much later (vias, corrections, trips). **\[Decided\]** Empty tables cost nothing; retrofitting a mutable-geometry model onto baked routes would cost a month.

### Source data (never rewritten)

- **points** — every location fix: GPS sample, photo/video coordinate, or manual pin. Timestamp, lat/lon, accuracy, speed, source, optional media link. R\*Tree index on lat/lon.
- **media** — photo or video reference (platform asset ID, not a copy), capture time, original EXIF/metadata coordinates, thumbnail path.
- **notes** — user text with time and location; can link to zero or more media.
- **recording\_sessions** — a live or passive recording run.

### User edits (separate from source)

- **anchor\_corrections** — a corrected location for a point. The original stays in `points`.
- **segment\_vias** — ordered user via-points inside a segment.
- **segments.connection\_mode**, **segments.is\_user\_edited**, per-segment buffer override.

### Structure

- **trips → places → segments**, shallow on purpose. A segment may belong to no trip (a daily commute). No nested sub-trips; use **tags** for day trips inside holidays.
- Trips can be created empty in advance; segments can be reassigned between trips.

### Derived (rebuildable cache)

- **segment\_geometry** — the display polyline for a segment's current mode.
- **coverage\_spans** + **cell\_stats** — which segment revealed which cell, as per-segment run-length spans, plus the per-cell segment count that fog and statistics read (D-014).
- **cell\_rollups** — coarse levels for low zoom and stats.

### Schema sketch

```sql
CREATE TABLE points (
  id INTEGER PRIMARY KEY,
  ts INTEGER NOT NULL,              -- epoch ms, UTC
  tz_offset_min INTEGER,            -- local offset at capture, for day-based stats
  lat REAL NOT NULL, lon REAL NOT NULL,
  accuracy_m REAL, speed_mps REAL,
  source TEXT NOT NULL,             -- 'gps' | 'media' | 'manual'
  session_id INTEGER REFERENCES recording_sessions(id),
  media_id INTEGER REFERENCES media(id)
);
CREATE VIRTUAL TABLE points_rtree USING rtree(id, min_lat, max_lat, min_lon, max_lon);

CREATE TABLE anchor_corrections (
  id INTEGER PRIMARY KEY,
  point_id INTEGER NOT NULL REFERENCES points(id),
  lat REAL NOT NULL, lon REAL NOT NULL,
  created_at INTEGER NOT NULL
);  -- latest row wins; delete rows to revert

CREATE TABLE trips (
  id INTEGER PRIMARY KEY, name TEXT,
  starts_at INTEGER, ends_at INTEGER,
  origin TEXT NOT NULL,             -- 'auto' | 'user'
  status TEXT NOT NULL              -- 'suggested' | 'confirmed'
);
CREATE TABLE places (
  id INTEGER PRIMARY KEY, trip_id INTEGER REFERENCES trips(id),
  name TEXT, lat REAL, lon REAL, radius_m REAL,
  starts_at INTEGER, ends_at INTEGER
);

CREATE TABLE segments (
  id INTEGER PRIMARY KEY,
  trip_id INTEGER REFERENCES trips(id),
  place_id INTEGER REFERENCES places(id),
  kind TEXT NOT NULL,               -- 'local' | 'transit'
  connection_mode TEXT NOT NULL,    -- 'straight' | 'great_circle' | 'road' | 'none'
  travel_mode TEXT,                 -- 'walk' | 'drive' | 'flight' | 'unknown'
  buffer_m REAL,                    -- NULL = use the default for this kind
  reveal INTEGER NOT NULL DEFAULT 1,
  return_of INTEGER REFERENCES segments(id),  -- pairs a return leg with its outbound
  is_user_edited INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE segment_points (
  segment_id INTEGER NOT NULL REFERENCES segments(id),
  seq INTEGER NOT NULL, point_id INTEGER NOT NULL REFERENCES points(id),
  PRIMARY KEY (segment_id, seq)
);
CREATE TABLE segment_vias (
  segment_id INTEGER NOT NULL REFERENCES segments(id),
  after_seq INTEGER NOT NULL,       -- via sits between member points after_seq and after_seq+1
  ord INTEGER NOT NULL,
  lat REAL NOT NULL, lon REAL NOT NULL,
  PRIMARY KEY (segment_id, after_seq, ord)
);

-- Coverage per D-014 (G1-A): logical (cell, segment), physical spans.
CREATE TABLE coverage_spans (
  segment_id INTEGER NOT NULL, y INTEGER NOT NULL,
  x_start INTEGER NOT NULL, x_end INTEGER NOT NULL,
  PRIMARY KEY (segment_id, y, x_start)
) WITHOUT ROWID;
CREATE TABLE cell_stats (
  cell_id INTEGER PRIMARY KEY, n INTEGER NOT NULL
) WITHOUT ROWID;
CREATE TABLE cell_rollups (
  level INTEGER NOT NULL, cell_id INTEGER NOT NULL, n INTEGER NOT NULL,
  PRIMARY KEY (level, cell_id)
) WITHOUT ROWID;
```

Every connection mode consumes the same input: member points with corrections applied, plus vias. That keeps user edits and mode independent — a user can add vias, then switch to road routing, and the route follows roads through their vias. Freehand drawing, if added, is a dense via list, not a new geometry type.

## Feature specs

### Import mode

- Multi-select photos and videos from the library; optionally scan a date range.
- Read capture time and coordinates; create one `media` row and one `points` row (source `media`) per item.
- Items without location are listed separately; the user can pin them manually or skip them.
- Re-importing the same asset must not duplicate it (dedupe on platform asset ID).
- After import, run segmentation and trip suggestion, then reveal.

### Live recording mode

- Explicit start / pause / stop of a recording session, with a persistent notification on Android and the system location indicator on iOS.
- Target sampling: one fix every few hundred metres or so. **\[Decided\]** Dense tracking is not a goal.
- Photos taken during a session appear as thumbnail markers at their location (in-app camera, or library photos matched by timestamp to the session).
- Text notes can be added at the current location, alone or with photos.

### Passive mode (later)

- Optional always-on background logging, off by default. Coarse and low-power: iOS significant-location-change; Android low-frequency fused provider with a large displacement filter.

### Connection modes

| Mode | How it draws | Runs | Default when |
| --- | --- | --- | --- |
| Straight line | Polyline through points and vias | On device | Default for everything not detected as a flight |
| Great-circle arc | Arcs between successive points and vias | On device | Implied speed above \~150 km/h (likely a flight) |
| Road-snapped | Valhalla route with vias as constraints | Server, opt-in | Never automatic; user chooses it |
| Not connected | No line; points revealed on their own | — | Gap too large to infer anything |

Mode is chosen **per segment**, not globally. Inferred segments must look different from recorded ones (for example dashed or lower opacity). For sparse photo points, road mode means routing between points, not HMM map matching — matching assumes points seconds apart.

### Segmentation and trips

- **Segment breaks** **\[Proposed\]**: start a new segment when the time gap exceeds a threshold (start at \~6 h) or implied speed is implausible for the previous mode. User can split and merge.
- **Places:** stay-point detection — points within a radius spanning more than a few hours form a place.
- **Trips:** a cluster of places in a time window, joined by transit legs. Usually one outbound leg, sometimes a return leg.
- **Segment kinds:** `local` (inside a place, full buffer) and `transit` (between places).
- **Transit defaults** **\[Proposed\]**: reveal little or nothing along a transit leg (a flight shows nothing below it); endpoints still reveal. User can turn transit reveal on.
- **Return legs:** when a return leg nearly duplicates its outbound leg, link them with `return_of` and draw one line with a two-way marker.
- **Ask, don't assume:** offer a suggestion such as "Looks like a trip to Kyoto, 6–14 March. Group these 47 photos?" Store as `suggested` until confirmed.
- **Map behaviour:** zoom-to-fit a trip; collapse a trip to one pin at low zoom and expand into places as the user zooms in; cluster repeated trips to the same city.

### Route editing

- Add, move and delete vias; drag an anchor to correct it (writes `anchor_corrections`).
- Recompute geometry and coverage on drag-end, limited to the affected segment's bounding box. Never per frame.
- Per-segment undo stack. Fat-fingered vias on phones are the common case.
- "Reset to automatic" per segment clears vias and corrections for it and drops `is_user_edited`.
- Batch regeneration skips segments with `is_user_edited = 1`.
- Live road-snapping while dragging is opt-in for the segment being edited only.

### Statistics

- Total explored area (covered cells × cell area at their latitude).
- Repeat visits per cell and per place. The exact definition of a "visit" is \[Open\].
- Counts: trips, places, countries, cities.
- Coverage percentage of a city or country needs admin boundaries; Natural Earth (public domain) is the \[Proposed\] source.

## Platform and permissions

Recording sessions use only foreground-grade permissions; "Always" location is requested only when the user turns on passive mode. **\[Decided\]**

### Location

|  | Recording session | Passive mode (later) |
| --- | --- | --- |
| Android | Foreground service of type `location`, started while the app is visible. Needs `ACCESS_FINE_LOCATION` + `FOREGROUND_SERVICE_LOCATION`. **No `ACCESS_BACKGROUND_LOCATION`.** | Needs `ACCESS_BACKGROUND_LOCATION`, requested in a second step after "while using" (Android 11+ forbids asking directly). Low-frequency fused provider, large displacement filter. |
| iOS | When-In-Use authorisation with `allowsBackgroundLocationUpdates` during the session; the blue indicator shows. | Always authorisation; significant-location-change plus region monitoring, which relaunch the app after termination. |

- No plugin can run Dart after the process is killed. Persist every fix to SQLite as it arrives; never buffer only in memory.
- Android OEM battery managers (Xiaomi, Huawei, Oppo, Samsung) kill services differently. Add a guided "allow background activity" screen for those brands and test on real devices.
- Show a rationale screen before every permission prompt, naming the feature it serves.

### Media location

- **Android:** request `ACCESS_MEDIA_LOCATION`, or MediaStore returns files with coordinates stripped and import finds nothing.
- **iOS:** use PhotoKit and read the asset's location explicitly; do not rely on exported image data.
- **Video:** read location via `AVAsset` metadata (iOS) and `MediaMetadataRetriever.METADATA_KEY_LOCATION` (Android) through platform channels.

### Identifiers

- The Android application ID is permanent after the first Play Store upload. The iOS bundle ID is effectively permanent too. Both are \[Open\] and must be confirmed with the owner before any store upload. Use a clearly temporary ID until then.

## Compliance requirements

These came out of a legal research pass and translate directly into code. They are requirements, not legal advice; the owner handles the non-code items (privacy policy, DPIA, trademark).

### Map attribution \[Decided\]

- Always visible on the map: "© OpenStreetMap contributors" linking to the ODbL copyright page.
- With OpenFreeMap tiles: "OpenFreeMap © OpenMapTiles Data from OpenStreetMap".
- With Protomaps tiles: "© OpenStreetMap" (Protomaps credit optional).
- Repeat all credits on an About / Licences screen, alongside open-source package licences.

### OpenStreetMap licence (ODbL) \[Decided\]

- Keep road-matched or routed geometry **per user and per segment**.
- Never aggregate OSM-derived geometry from many segments or users into a shared road-network database. That could make it a Derivative Database subject to share-alike.
- Raw GPS traces carry no OSM obligation; only routed geometry derives from OSM.

### Privacy \[Decided\]

- All data on device, in an encrypted SQLite database (SQLCipher), key held in the platform keystore.
- Any future cloud backup or sync is opt-in and end-to-end encrypted.
- No third-party SDK may receive location, media metadata or notes. Crash reporting, if added, must scrub coordinates.
- iOS purpose strings must name the specific feature, for example: "FootNoted uses your location during a recording to reveal the places you explore on your personal map."
- Google Play requires a background-location declaration with a demo video before passive mode can ship. Keep passive mode behind a build flag until that is ready.
- App Store privacy labels and the Play Data Safety form must match actual behaviour; update them whenever data flows change.
- Provide in-app deletion: delete a trip, a segment, a media item, or everything.

### Sharing and export \[Decided\]

- Strip GPS and EXIF from any image or video leaving the app by default, including embedded thumbnails. Keeping location is an explicit opt-in per share.
- Warn before sharing anything that reveals location (a route, a map screenshot, a poster).

## Monetization readiness

The app launches fully free with no paywall. **\[Decided\]** Build two small hooks now so paid tiers can be added later without a retrofit; do not build purchase flows yet.

### Build now

- **Entitlements layer:** a single `Entitlements` service the UI asks ("is cloud sync available?"). At launch every check returns true. Features never test purchase state directly.
- **First-use date:** record the first install / first launch timestamp locally, so early users can be grandfathered when monetization arrives.

### Planned tiers \[Proposed\]

| Tier | Includes | Why it sits there |
| --- | --- | --- |
| Free, forever | Recording, import, the fog map, trips, straight-line and great-circle connections, editing, basic stats | Retention comes from accumulated data, which takes months to build |
| Lifetime unlock (one-time) | Depth features: year-in-review, detailed stats, coverage percentages, heatmaps, advanced export | Runs on device, so near-zero ongoing cost |
| Subscription | Cloud backup and sync, road-snapped routing, offline map packs | Each has a real recurring server or bandwidth cost |
| One-off purchase | Printed posters of the explored map (print-on-demand) | Appeals to users who will never subscribe |

### Rules for later

- Paid features arrive as new additions; nothing free is ever taken away.
- A lapsed subscriber keeps their full map, photos and history; only the hosted services stop.
- Whether the app itself is open-sourced (client open, services paid) is \[Open\].

## Milestones

Start with a throwaway performance spike; if it passes, everything after it is ordinary app work. Each milestone lists its exit criteria.

1. **M0 — Performance spike (throwaway).** Generate five years of synthetic traces for a dense city plus a few long road trips and flights. Load them into the cell model.
   - Exit: panning at z10 with about 1 million revealed cells stays near 60 fps on a mid-range Android phone and an older iPhone.
   - Exit: measured database size for `cell_coverage` per-cell vs run-length spans; a written decision on quadkey vs H3 and on coverage storage.
2. **M1 — Foundation.** Flutter project for both platforms; MapLibre with the custom dark style on OpenFreeMap; attribution in place; the full encrypted schema with migrations; cell grid library (rasterise, dilate, rollups) with unit tests; blocky fog rendering.
   - Exit: a hard-coded segment reveals correctly at every zoom, and deleting it restores the fog exactly.
3. **M2 — Import mode.** Photo and video picker, metadata extraction on both platforms, dedupe, segmentation, straight-line and great-circle modes, reveal, inferred-segment styling.
   - Exit: importing a real camera roll produces a sensible map with flights drawn as arcs.
4. **M3 — Live recording.** Session start/pause/stop, foreground service and iOS background updates, crash-safe persistence, photo thumbnails on the route, text notes.
   - Exit: a two-hour walk on a real phone records fully with the screen off, on at least one aggressive OEM device.
5. **M4 — Trips and places.** Stay-point detection, trip suggestions with confirm prompts, local vs transit segments with per-kind buffers, return-leg pairing, trip clustering at low zoom.
6. **M5 — Statistics.** Explored area, repeat visits, trip/place/country counts, coverage percentage via admin boundaries.
7. **M6 — Route editing.** Vias, anchor dragging, per-segment undo, reset to automatic, bounded recompute on drag-end.
8. **M7 — Passive mode.** Coarse always-on logging behind a setting; Play background-location declaration prepared.
9. **M8 — Road routing (opt-in).** Self-hosted Valhalla; road mode honouring vias; ODbL rules respected.
10. **Later.** Soft-edged fog, offline PMTiles packs, encrypted cloud backup, paid tiers, posters.

## Testing and definition of done

The most important test is the rebuild check: deleting every derived table and regenerating from raw data must reproduce the same map and statistics.

### Automated tests

- **Cell math:** rasterising and dilating segments at the equator, 60° latitude, across the antimeridian and near the poles.
- **Coverage provenance:** add, edit and delete a segment; per-cell visit counts return exactly to their prior values.
- **Rebuild idempotency:** drop `segment_geometry`, the coverage tables (`coverage_spans`, `cell_stats`) and rollups, rebuild, and compare.
- **Segmentation:** fixtures for flights, long drives, overnight gaps, and two unrelated trips on consecutive days.
- **Connection modes:** switching modes on a segment with vias preserves the vias; reset clears them.
- **Corrections:** dragging an anchor never changes the original `points` row.
- **Migrations:** every schema version upgrades from the previous one with data intact.

### Device testing

- Live recording on physical devices only, including at least one Xiaomi or Huawei and one Samsung, plus a recent and an older iPhone.
- Test with the app swiped away, the screen off, low battery mode, and after a reboot.
- Import tests with real camera rolls, including photos with stripped location and videos from several phone makers.

### A milestone is done when

- Its exit criteria pass.
- No invariant in this doc is broken.
- Attribution and permission rationale screens are present for anything it adds.
- This doc is updated where the build diverged from it.

## Open questions

Raise these with the owner when the milestone in brackets needs them; none blocks M0.

- [x] **Grid type and cell size** (M0): quadkey z20 (\~38 m) or z21 (\~19 m), or H3? — **Quadkey z20** (G1-A, 2026-10-10). D-013.
- [x] **Coverage storage** (M0): one row per (cell, segment), or run-length spans? — **Run-length spans plus `cell_stats`; fog and stats read `cell_stats` and rollups only** (G1-A, 2026-10-10). D-014.
- [x] **SQLite driver** (M1): Drift or raw `sqlite3` FFI? — **Drift, confirmed at G1-A** (2026-10-10), with the coverage hot path as prepared SQL through `customStatement` batches. See [`decisions.md`](decisions.md) D-016 (supersedes D-003).
- [ ] **Default buffer distance** (M1): what the user sees before changing it, and the allowed range. — *Proposed in D-007, confirm at the Stage 1 W3 kickoff.*
- [x] **Minimum OS versions** (M1): lowest iOS and Android versions to support. — **Flutter stable template defaults** (owner, 2026-10-08), raised only where a dependency requires it. D-004.
- [ ] **App ID and bundle ID** (before first store upload): permanent once uploaded. — Temporary `com.example.footnoted` until then (D-006); the stores reject `com.example`, which makes an accidental upload impossible.
- [x] **Languages** (M1): which UI languages at launch. — **English only at launch, i18n-ready**: every UI string goes through `flutter gen-l10n` from the first screen (owner, 2026-10-08). D-005.
- [ ] **Segment break thresholds** (M2): the time-gap and speed values that start a new segment.
- [ ] **Place names** (M4): reverse-geocoding source. Public Nominatim forbids bulk use; options are an offline boundary dataset, or a self-hosted Photon or Nominatim.
- [ ] **Definition of a repeat visit** (M5): a distinct segment, a distinct day, or a distinct trip?
- [ ] **Transit reveal default** (M4): reveal nothing along transit legs, or a thin line?
- [x] **App licence** (before public repo): keep the client closed, or open-source it and charge for hosted services? — **Open-source client under MPL-2.0** in the public repo `JohnnnyTang/footnoted`; hosted services may be paid later (owner, 2026-10-08). D-001.
