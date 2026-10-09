# Stage 4 — Trips and places (M4) · KICKOFF

**State:** `KICKOFF`. Planned after the previous stage exits. It depends functionally on Stage 2 only (imported data is enough to group), so it may be re-ordered before Stage 3 if device availability blocks M3. That is an owner ruling.
**Milestone:** M4, per [`HANDOFF.md`](../../docs/HANDOFF.md#segmentation-and-trips).

## Objective

Turn a flat history into **trips → places → segments**, as suggestions the user confirms ("Looks like a trip to Kyoto, 6–14 March. Group these 47 photos?"), with local vs transit segments revealed differently and trips collapsing to a pin at low zoom.

## Scope

**In:**
- **Stay-point detection:** points within a radius spanning more than a few hours → `places`.
- **Trip suggestion:** a cluster of places in a time window joined by transit legs; stored as `status = 'suggested'` until the user confirms; `origin = 'auto' | 'user'`.
- Segment kinds `local` / `transit`, with **per-kind buffers**; the transit reveal default (handoff Open; D-007 already proposes endpoints-only).
- **Return-leg pairing** (`return_of`), drawn as one line with a two-way marker.
- Trip UI: a list, confirm/rename/merge/split, creating empty trips in advance, reassigning segments, tags for day trips.
- Map behaviour: zoom-to-fit a trip; a trip collapses to one pin at low zoom and expands into places as the user zooms in; repeated trips to the same city are clustered.
- Batch regeneration skips `is_user_edited = 1` segments (invariant 8).

**Out:** place **names** need a reverse-geocoding source. That is handoff Open (M4) and is likely its own session or gate: public Nominatim forbids bulk use, so the options are an offline boundary dataset or a self-hosted Photon/Nominatim.

## Open questions to settle at planning

- Transit reveal default: nothing, or a thin line?
- The place-naming source (above), which affects the offline footprint and invariant 7 (nothing leaves the device unless opted in).
- Clustering thresholds for "the same city".

## Likely shape

- **W1:** stay-point + trip suggestion algorithms with fixtures (two unrelated trips on consecutive days, overnight gaps) ‖ trip/place repositories ‖ the place-naming spike.
- **W2:** trip UI + confirm prompts ‖ low-zoom clustering ‖ return-leg pairing.
- **W3:** verification on the owner's real imported library.
