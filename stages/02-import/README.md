# Stage 2 — Import mode (M2) · KICKOFF

**State:** `KICKOFF`. This is a scope document; it is **planned into waves and sessions only after Stage 1 exits** (`plan-stage` skill).
**Milestone:** M2, per [`HANDOFF.md`](../../docs/HANDOFF.md#import-mode).
**Entry conditions:** Stage 1 `EXITED` (or `EXITED WITH CAVEATS` with no caveat touching reveal/fog); F01 frozen; `footnoted_data` at schema v1 with the migration harness.

## Objective

A user picks photos and videos (or a date range), and FootNoted reads where and when each was taken, groups them into segments, connects them as straight lines or great-circle arcs, and reveals the map. **Exit (handoff): importing a real camera roll produces a sensible map with flights drawn as arcs.**

## Scope

**In:**
- A photo/video picker with multi-select, plus an optional date-range scan of the library.
- Metadata extraction:
  - **Android:** `ACCESS_MEDIA_LOCATION`, or MediaStore strips the coordinates.
  - **iOS:** PhotoKit asset location, read explicitly.
  - **Video:** `AVAsset` (iOS) and `MediaMetadataRetriever.METADATA_KEY_LOCATION` (Android) via platform channels. **No FFmpegKit.**
  - Photo EXIF: choose `native_exif` vs `exif` here (handoff: decide during M2).
- One `media` row and one `points` row (`source = 'media'`) per item; **dedupe on the platform asset ID** on re-import.
- Items without a location: listed separately, to be pinned manually (a manual point) or skipped.
- **Segmentation v1:** a time-gap break (~6 h, Proposed) plus implied-speed plausibility; great-circle as the default above ~150 km/h; `none` when a gap is too large to infer anything.
- Inferred-segment styling (dashed / lower opacity) vs recorded segments; the route line layer in the `fn-routes` slot.
- Thumbnails (cached derived data, rebuildable) and photo markers on the map.
- Permission rationale screens before each prompt (`RationaleScreen` from Stage 1). iOS purpose strings that name the feature.
- Import progress, cancellation, and resumability for large libraries (thousands of items).

**Out:** trips/places grouping (Stage 4), editing vias and anchors (Stage 6), road mode (M8), live recording (Stage 3).

## Open questions to settle at planning

- **Segment break thresholds** (handoff Open, M2): the time-gap and speed values. Propose a fixture-driven calibration session.
- The EXIF library choice (`native_exif` vs `exif`), with licence and maintenance checked.
- Whether a "date range scan" reads the whole library metadata up front (cost on a 50 k-photo library) or pages through it.
- Thumbnail storage location and size budget; cache eviction.

## Likely shape (to be confirmed at planning)

- **W1:** platform metadata channels (Android, iOS; the iOS work is owner-verified) ‖ the import pipeline + dedupe in `footnoted_data` ‖ segmentation v1 with fixtures ‖ the picker UI + rationale.
- **W2:** route rendering + inferred styling ‖ markers/thumbnails ‖ large-library performance.
- **W3 (verification):** real camera rolls on the owner's devices, including photos with stripped location and videos from several phone makers (handoff device testing).

## Risks

- Platform variance in video location metadata (OEM formats, ISO-6709 strings).
- Very large libraries: memory use and time.
- Missing `ACCESS_MEDIA_LOCATION` silently yields zero coordinates. A test must catch "all imported items lack location" as a warning state.

## Compliance carried

Rationale before every prompt; purpose strings name the feature; nothing leaves the device; any later share strips EXIF by default.
