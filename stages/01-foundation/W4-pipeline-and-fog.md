# Stage 1 · W4 — Reveal pipeline, fog, guards

**Opens after:** W3 merged. **Parallel sessions:** S01-40, S01-41, S01-42 (one dispatch). **Closes into:** W5.
**Purpose:** compose the W3 blocks into the derived-data pipeline (raw → geometry → coverage → rollups/stats) and the fog renderer that reads it, and harden CI around the invariants.

## Kickoff obligations

1. Rebase; re-run the suite; record it.
2. **Seams (frozen for W4):**
   - `packages/footnoted_data/lib/src/coverage/coverage_reader.dart`: **F01.4** exactly — `CoverageReader.coveredCells(TileId, int level)` and `Stream<CoverageChange> changes` (`CoverageChange` carries the affected tiles at the coarsest rollup level).
   - `packages/footnoted_data/lib/src/reveal/reveal_service.dart`: the interface only — `revealSegment(id)`, `deleteSegment(id)`, `setConnectionMode(id, mode)`, `rebuildAll()`, `derivedStateHash()`.
   - `packages/footnoted_data/lib/src/dev/fixtures.dart`: the three hard-coded segments used by the M1 exit. (1) A city walk of about 40 points at 150–300 m spacing, in a real city. (2) A 1,000 km drive at a 400 m spacing (`straight`, 500 m buffer). (3) A flight Tokyo → Honolulu (`great_circle`, crosses the antimeridian, endpoints-only reveal). The fixture is used by tests **and** by the S01-50 dev harness.
   - `app/lib/src/features/fog/` directory created (S01-41's).
3. Dispatch all three.

## File ownership

| Path | Owner |
| --- | --- |
| `coverage_reader.dart`, `reveal_service.dart` (interface), `dev/fixtures.dart` | **kickoff (frozen)** |
| `packages/footnoted_data/lib/src/reveal/**` (implementation), `packages/footnoted_data/lib/src/coverage/**` (implementation), `packages/footnoted_data/test/reveal/**` | S01-40 |
| `app/lib/src/features/fog/**`, `app/test/fog/**` | S01-41 |
| `tool/**`, `.github/**`, `docs/network-hosts.md` (enforcement only; content changes need a row) | S01-42 |

**Merge order:** S01-40 → S01-41 → S01-42 (the guards go last, so they run against the final W4 dependency set).

---

### S01-40 — Reveal pipeline, provenance, rebuild

**Branch:** `s01/40-reveal-pipeline` · **Size:** L

**Goal.** Implement invariants 2, 4, 5 and 6 as running code: everything derived is rebuilt from raw data plus edits, every covered cell knows which segment revealed it, and deleting or editing a segment moves the map and the stats back exactly.

**Deliverables.**
1. `GeometryBuilder`: member points ordered by `seq`, with corrections applied (latest wins, originals untouched), plus vias in `(after_seq, ord)` order → vertices for `straight` / `great_circle` / `none`. `road` falls back per F01.5, and `inferred` is set per F01.5.
2. `RevealServiceImpl`. `revealSegment` runs **in one transaction**: clear the segment's old derived rows → write `segment_geometry` → rasterise + dilate (`footnoted_geo`, effective buffer per F01.6/D-007) → write coverage in the F01.2 layout → apply rollup and `cell_stats` deltas → emit `CoverageChange`. `deleteSegment` removes the derived rows and memberships but **never** `points`. `setConnectionMode` keeps the vias and re-reveals. `rebuildAll` drops every derived table and replays all segments.
3. `CoverageReaderImpl` over rollups (coarse levels) and coverage (level 20).
4. `derivedStateHash()`: a stable hash over the sorted contents of `segment_geometry`, coverage, `cell_stats` and `cell_rollups`.
5. A recorded time budget: reveal of the 1,000 km × 500 m leg on desktop, and on the Android emulator, in the note.

**Acceptance (these are the handoff's required tests).**
- [ ] **Provenance:** reveal A; reveal B (overlapping A); delete A → `cell_stats` equals "B alone" exactly. Edit A's member points → the stats move by exactly the delta.
- [ ] **Rebuild idempotency:** the hash before `rebuildAll` == the hash after, on the dev fixtures plus a random 50-segment set.
- [ ] **Connection modes:** switching straight ↔ great_circle on a segment with vias keeps the vias; "reset to automatic" (clear vias + corrections, `is_user_edited = 0`) clears them.
- [ ] **Corrections:** after a correction and a re-reveal, the `points` row is byte-identical.
- [ ] **Antimeridian:** the flight fixture's coverage contains no cells across the far side of the world.
- [ ] `dart test packages/footnoted_data` is green.

**Owner steps:** none. **Out of scope:** segmentation (M2), trips (M4), UI.

---

### S01-41 — Blocky fog renderer

**Branch:** `s01/41-fog-renderer` · **Size:** L

**Goal.** Production fog following the G1 strategy: for the visible tiles, fetch covered cells at the level mapped from the zoom, merge them into rectangles, and draw "tile minus rectangles" as a dark fill in the `fn-fog` slot. It must stay correct at z0–z20 and smooth at z10.

**Deliverables.**
1. `FogController(CoverageReader, FootMapController)`: the visible tile set on camera idle (plus a throttled update during long moves if G1 found it necessary); the zoom → level table from G1; an LRU cache keyed by `(tile, level)` with invalidation driven by `CoverageChange`; a fully dark world when there is no coverage; correct behaviour at the antimeridian and with world copies.
2. `FogGeometry`: a pure function from `(tile, level, rectangles)` to GeoJSON, unit-testable without a map.
3. Fog style properties (colour/opacity tuned to the dark style), with the labels left above the fog.

**Acceptance.**
- [ ] Unit tests with a fake `CoverageReader`: an empty coverage → one full-tile polygon per tile; a known cell set → the expected holes (golden JSON); invalidation refetches only the affected tiles.
- [ ] A widget/integration test on the Android emulator: fog is drawn, the camera moves, the fog updates.
- [ ] A profile-build pan at z10 on the **emulator**, with the S01-12 method, is recorded as indicative. The device number belongs to S01-51.

**Owner steps:** none. **Out of scope:** soft edges (Later), route lines (M2).

---

### S01-42 — Invariant guards + CI hardening

**Branch:** `s01/42-guards-ci` · **Size:** M

**Goal.** Make the invariants that can be checked mechanically fail CI: open-source-only dependencies, no background location, no unlisted network hosts, and no location-seeing SDKs. Bring CI to its Stage 1 final shape.

**Deliverables.**
1. `tool/check_deps.dart` (extending the W0 denylist version): walk `pubspec.lock` (including transitive dependencies), resolve each package's licence from the pub cache, and fail on any licence outside the allowlist (MIT, BSD-2/3-Clause, Apache-2.0, MPL-2.0, Zlib, ISC, Unlicense, public domain) or any denylisted name (Google/Mapbox map SDKs, Firebase Analytics/Crashlytics, any `*analytics*`, `flutter_background_geolocation`, `ffmpeg_kit*`). Print a licence table artifact.
2. `tool/check_manifest.dart`: fail if `ACCESS_BACKGROUND_LOCATION` is in any Android manifest, or if an iOS location/photo usage key exists without a specific purpose string (the handoff's wording rule).
3. `tool/check_hosts.dart`: every `http(s)://` host in `app/lib/**` and `app/assets/**` must be listed in `docs/network-hosts.md`.
4. CI (`.github/workflows/ci.yml`): analyze + format check; the `footnoted_geo` tests; the `footnoted_data` tests including migration tests; the `app` tests; the three checks above; `flutter build apk`; `flutter build ios --no-codesign` on `macos-latest`. Caching; the Flutter version pinned per D-010. Add `dependabot.yml` for pub + actions, and a PR template with the 10-invariant checklist.
5. **Prove each guard fires**: add a denylisted dependency / background permission / unlisted host on a scratch branch, show CI red, and record the run URLs in the note. Do not merge the scratch branch.

**Acceptance.**
- [ ] CI is green on the merged W4 tree, and red on each negative control (run links in the note).
- [ ] The licence table artifact lists every resolved package.

**Owner steps:** none.
