# Stage 1 · W3 — M1 building blocks

**Opens after:** G1-A is ruled and F01.1–F01.3, F01.5 and F01.6 are frozen (D-012). **Parallel sessions:** S01-30, S01-31, S01-32, S01-33 (one dispatch). **Closes into:** W4.
**Purpose:** build the four independent foundations (app shell, cell-grid library, encrypted database, map + style) against frozen seams, so that W4 only composes them.

## Kickoff obligations (orchestrator, foreground)

1. Rebase; re-run the suite; record it. **Amended 2026-10-09 (D-012):** `spike/` stays until G1-B. Confirm instead that G1-A is ruled and F01.1–F01.3, F01.5 and F01.6 are frozen. W3 adds dependencies to `app/` and `packages/`; check that the spike packages still resolve and their tests still pass.
2. **Owner ruling:** confirm or amend **D-007** (default buffer of 100 m local, range 25 m – 2 km).
3. **Seams (implement once; frozen for W3):**
   - **All W3 dependencies added up front** to `app/pubspec.yaml` and `packages/*/pubspec.yaml`, with `pubspec.lock` committed. This stops four sessions fighting over the lockfile. Expected: `maplibre_gl`, `url_launcher`, `flutter_riverpod` + `go_router` (state/routing, **Proposed**: record a D-row), `flutter_secure_storage`, `drift` + `drift_dev` + `build_runner`, the SQLCipher packaging chosen at G1, and `intl` / `flutter_localizations`. Run `tool/check_deps.dart` on the result.
   - `packages/footnoted_geo/lib/src/types.dart`: `LatLng`, `CellId` (extension type over `int`), `TileId(z, x, y)`, `ConnectionMode`, `SegmentKind`. Exported, and **frozen**.
   - `app/lib/src/` skeleton: `app/` (S01-30), `features/map/foot_map_view.dart` as a placeholder widget (S01-33 replaces its body, keeping the constructor), `features/about/` (S01-30), `core/` (S01-30), `data/` (S01-32).
   - `app/lib/src/core/map_credits.dart`: the exact credit strings and URLs from the handoff's Compliance section, read by both the map overlay (S01-33) and the About screen (S01-30).
   - `app/lib/src/core/app_meta_store.dart`: `abstract interface class AppMetaStore { Future<String?> read(String key); Future<void> write(String key, String value); }`. S01-30 uses an in-memory implementation; S01-50 wires the database implementation.
   - `app/l10n.yaml` + `app/lib/l10n/app_en.arb`, **owned by S01-30**. Other sessions list the strings they need in their note, and the orchestrator adds them at merge. (Map credit strings are legal text and are not localised.)
4. Dispatch all four.

## File ownership

| Path | Owner |
| --- | --- |
| `pubspec.yaml` files, `pubspec.lock`, `footnoted_geo/lib/src/types.dart`, `core/map_credits.dart`, `core/app_meta_store.dart` | **kickoff (frozen)** |
| `app/lib/main.dart`, `app/lib/src/app/**`, `app/lib/src/core/**` (except the frozen files), `app/lib/src/features/about/**`, `app/lib/l10n/**`, `app/test/app/**`, `app/test/about/**`, `app/android/app/src/main/AndroidManifest.xml`, `app/ios/Runner/Info.plist` | S01-30 |
| `packages/footnoted_geo/**` (except `types.dart`) | S01-31 |
| `packages/footnoted_data/**`, `app/lib/src/data/**`, `app/test/data/**` | S01-32 |
| `app/lib/src/features/map/**`, `app/assets/map/**`, `app/test/map/**`, the `flutter: assets:` entry for `assets/map/` | S01-33 (the asset entry is pre-added by the kickoff) |

**Merge order:** S01-31 → S01-32 → S01-30 → S01-33.

---

### S01-30 — App shell

**Branch:** `s01/30-app-shell` · **Size:** M

**Goal.** Turn the template app into the FootNoted shell: structure, routing, a dark theme, localisation plumbing, the About/Licences screen, the `Entitlements` service, first-use recording and the reusable permission-rationale screen. No location or media permissions yet.

**Deliverables.**
1. `FootNotedApp` with `go_router` routes `/` (home, embedding `FootMapView`), `/about` and `/dev` (placeholder; S01-50 fills it, and it is reachable only in debug or with `--dart-define=FN_DEV=true`).
2. A dark Material 3 theme matching the map's identity. App name **FootNoted** (capital N, never an asterisk) on the Android label and the iOS `CFBundleDisplayName`.
3. `gen-l10n` wired up (`l10n.yaml`, `app_en.arb`), with **every** visible string coming from it (D-005).
4. The About/Licences screen: the app version, map credits from `map_credits.dart` with links, and Flutter's licence page. `LicenseRegistry.addLicense` entries for map data (ODbL), OpenMapTiles (CC-BY 4.0) and the forked style's licence. The text is taken from the actual upstream files, never paraphrased.
5. `Entitlements` (`core/entitlements.dart`): `bool isAvailable(Feature f)`, returning true for everything. The `Feature` enum lists the future gated items (cloud sync, road routing, offline packs, detailed stats, posters, …). Nothing in the UI may test purchase state directly.
6. `FirstUseRecorder`: on first launch, writes `first_use_at` (epoch ms UTC) to `AppMetaStore` if absent, and never overwrites it.
7. `RationaleScreen`, a reusable "why we need this" screen (title, the feature it serves, Continue / Not now), ready for M2/M3 permission prompts.
8. The Android manifest has `INTERNET` only. The iOS `Info.plist` has no location or photo keys yet.

**Acceptance.**
- [ ] `flutter analyze` is clean, and `flutter test app` is green with widget tests for About (both credit lines present and tappable), the Entitlements unit test, and the first-use test (idempotent across two launches).
- [ ] A grep finds no user-visible string literals outside ARB files and `map_credits.dart` (the command is recorded).
- [ ] `flutter build apk --debug` is green.

**Owner steps:** none. **Out of scope:** the database, the map internals, real permissions.

---

### S01-31 — Cell-grid library (production)

**Branch:** `s01/31-cell-grid` · **Size:** L

**Goal.** Make `footnoted_geo` the complete, tested and benchmarked implementation of F01.1, F01.3 and F01.6: the S01-10 math hardened, plus rollups, rectangle merge and (if G1 chose spans) the span codec.

**Deliverables.**
1. Hardened `tile_math`, `rasterize` and `dilate` from S01-10, with the API surface documented by its types.
2. `rollup.dart`: parents at F01.3's levels, per-parent child counts from a sorted cell list, and incremental add/remove deltas (for use by the reveal pipeline).
3. `rect_merge.dart`: covered cells inside one tile at level L become a minimal-ish set of axis-aligned rectangles (a scanline over rows into maximal runs, merging vertically identical runs). Output is in cell coordinates plus a lon/lat conversion helper.
4. `spans.dart` (only if G1(c) chose spans): cells ↔ `(y, x_start, x_end)` runs.
5. Helpers: the area of a cell at its latitude (for M5); the bounding box of a cell set; `CellSet` ops (union, difference, contains) on sorted `Int64List`/`Uint64`-backed lists.
6. Benchmarks for the 1,000 km × 500 m leg: rasterise + dilate time, and rect-merge time for a dense z10 view. If they miss the budget the reveal pipeline needs (S01-40 records the budget), write a note on the **Rust FFI** option (handoff: Proposed) rather than adding it.

**Acceptance.**
- [ ] `dart test packages/footnoted_geo` is green, including the handoff's required geographies (**equator, 60°, antimeridian, near the poles**), the rollup round-trip (sum of child counts = cell count), rect-merge exactness (the union of the rectangles == the input set, with no overlaps), and a zero-length segment.
- [ ] `dart analyze` is clean; coverage ≥ 90% of lines in `lib/` (reported).
- [ ] Benchmark numbers are in the note.

**Owner steps:** none. **Out of scope:** the database and Flutter.

---

### S01-32 — Encrypted database, full schema, migrations

**Branch:** `s01/32-encrypted-db` · **Size:** L

**Goal.** `footnoted_data` ships the **full** v1 schema (handoff "Data model", plus F01's derived tables) on SQLCipher via Drift, with the key in the platform keystore and a migration test harness that every later stage extends.

**Deliverables.**
1. A Drift database `FootDatabase`, schema **v1**:
   - **Source:** `points` (+ `points_rtree`, maintained by triggers), `media` (a **unique** platform asset ID for dedupe; the original EXIF lat/lon kept as captured; kind; capture ts; tz offset; thumbnail path; imported_at), `notes`, `note_media`, `recording_sessions`.
   - **Edits:** `anchor_corrections` (latest row wins), `segment_vias`.
   - **Structure:** `trips`, `places`, `segments` (every handoff column), `segment_points`, `tags` + link tables for trips/places/segments.
   - **Derived (rebuildable):** `segment_geometry`, coverage per F01.2, `cell_stats`, `cell_rollups`.
   - **Meta:** `app_meta(key PRIMARY KEY, value)`.
   - `PRAGMA foreign_keys = ON`. The `ON DELETE` rules are written down: deleting a segment cascades to its derived rows and its membership rows, and **never** to `points` or `media`.
2. Opening: `openFootDatabase(File, DbKeyProvider)`. The key is applied before any other statement; WAL on; it fails loudly if the cipher is not active.
3. `DbKeyProvider` (a package interface) + `app/lib/src/data/secure_key_provider.dart` (`flutter_secure_storage`): generates a 256-bit random key on first launch, stores it in Keychain/Keystore, and never logs it.
4. `AppMetaStore` implemented over `app_meta` (the class lives in `app/lib/src/data/`; S01-50 wires it).
5. Migrations: the Drift `make-migrations` workflow, with schema snapshots under `packages/footnoted_data/drift_schemas/`, generated migration tests, and a short doc in `packages/footnoted_data/README.md` on how a later stage adds v2.
6. Thin repositories needed by W4/W5: insert/get points, segments with members and vias, and corrections (an insert-only API; there is no update path for `points`).

**Acceptance.**
- [ ] `dart test packages/footnoted_data` is green. It includes: the **plaintext check** (the first 16 bytes of the file ≠ `SQLite format 3\0`), opening with the wrong key fails, R\*Tree insert + range query under SQLCipher, an FK cascade test, a test that a correction leaves the `points` row byte-identical, and the v1 schema-snapshot test.
- [ ] `dart run drift_dev schema validate` (or the current equivalent) is clean.
- [ ] The key provider is unit-tested with a fake secure store. On-device keystore behaviour becomes a W5 check (backlog row if not run).

**Owner steps:** none. **Out of scope:** the reveal logic (S01-40). **Traps:** Drift's generated code must be committed or generated in CI (pick one and record it); keep the package **Flutter-free**.

---

### S01-33 — Map widget, dark style, attribution

**Branch:** `s01/33-map-style` · **Size:** M

**Goal.** The product's identity: a stripped-down dark style forked from OpenFreeMap dark, a `FootMapView` widget with a small controller API that the fog and routes will use, and attribution that is always visible.

**Deliverables.**
1. `app/assets/map/footnoted-dark.json`: forked from the OpenFreeMap dark style (record the upstream URL and commit/date and its licence). Strip POI clutter, keep place and road labels legible on a dark background, and **define the layer order contract**: base → `fn-fog` → `fn-routes` / `fn-markers` → labels. Document the insertion layer IDs in `features/map/README.md`.
2. `FootMapView` + `FootMapController`: loads the style from the asset; `setFogGeoJson(...)` / `addRouteLayer(...)` hooks that insert at the contracted slots; camera helpers (`flyTo`, `fitBounds`, `currentZoom`, visible bounds); `renderWorldCopies` behaviour decided and recorded.
3. An **always-visible attribution overlay** (not just MapLibre's "i" button): "© OpenStreetMap contributors" (linked to `https://www.openstreetmap.org/copyright`) and "OpenFreeMap © OpenMapTiles Data from OpenStreetMap", read from `map_credits.dart`, opened with `url_launcher`.
4. `docs/network-hosts.md`: every host the app contacts (tiles, style, glyphs, sprites) and why. S01-42's egress check enforces it.

**Acceptance.**
- [ ] A style test: valid JSON, the `fn-fog` slot exists below the first label layer, and every URL host is in `docs/network-hosts.md`.
- [ ] A widget test: both attribution lines are present and remain visible (not clipped) on a 360×640 surface.
- [ ] An Android emulator screenshot of the dark map is saved to `evidence/S01-33/`. iOS: CI compile only, with the visual check deferred to S01-51 (owner).

**Owner steps:** none. **Out of scope:** the fog logic (S01-41).
