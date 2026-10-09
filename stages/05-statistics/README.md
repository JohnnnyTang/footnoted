# Stage 5 — Statistics (M5) · KICKOFF

**State:** `KICKOFF`. Planned after Stage 4 exits (the trip/place counts depend on it).
**Milestone:** M5, per [`HANDOFF.md`](../../docs/HANDOFF.md#statistics).

## Objective

Show how much of the world the user has explored and how often they return, computed entirely on device from derived (rebuildable) data.

## Scope

**In:**
- Total explored area: covered cells × the cell area at their latitude (`footnoted_geo` already provides the area helper).
- Repeat visits per cell and per place, using the definition chosen at planning (handoff Open: a distinct segment, a distinct day, or a distinct trip). `cell_stats` already carries per-cell segment counts from Stage 1. A day- or trip-based definition needs a derived table, and `tz_offset_min` matters for day boundaries.
- Counts: trips, places, countries, cities.
- **Coverage percentage** of a city or country: admin boundaries from **Natural Earth** (public domain, Proposed). Bundled or downloaded? It must stay offline-capable.
- A stats screen, and an exploration heatmap of revisit intensity (note: "heatmaps" and "detailed stats" are earmarked for the future lifetime tier. Build them behind `Entitlements` checks that return true; never test purchase state).
- A **rebuild check** extended to the stats (the handoff's most important test).

**Out:** year-in-review, posters, sharing (Later; sharing needs the EXIF-strip and location-warning rules).

## Open questions to settle at planning

- The definition of a repeat visit.
- The Natural Earth resolution (10 m vs 50 m) vs app size; city boundaries (Natural Earth has populated places, not city polygons — another source may be needed, and it must be open).

## Likely shape

- **W1:** the admin-boundary dataset + point-in-polygon/cell attribution ‖ the stats derivation tables + rebuild tests ‖ the visit definition.
- **W2:** the stats UI ‖ the heatmap layer.
- **W3:** verification.
