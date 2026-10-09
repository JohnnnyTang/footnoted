# Stage 6 — Route editing (M6) · KICKOFF

**State:** `KICKOFF`. Planned after the previous stage exits. It depends functionally on Stage 2 (routes exist) and on Stage 1's provenance pipeline. The data model (vias, corrections, `is_user_edited`) already ships in Stage 1's schema v1.
**Milestone:** M6, per [`HANDOFF.md`](../../docs/HANDOFF.md#route-editing).

## Objective

Let the user fix any connection by hand: add, move and delete vias; drag an anchor to correct a photo's location; undo per segment; reset to automatic. Every edit is reversible and **never** overwrites raw data (invariants 3, 4 and 8).

## Scope

**In:**
- Via editing on the map, plus anchor drag → an `anchor_corrections` row (the original EXIF/point is untouched; delete the rows to revert).
- **Recompute on drag-end only**, bounded to the affected segment's bounding box. Never per frame.
- A per-segment undo stack (fat-fingered vias are the common case).
- "Reset to automatic" per segment: clear vias + corrections, `is_user_edited = 0`.
- Switching the connection mode per segment while keeping vias (already tested at the data layer in Stage 1).
- Split and merge segments (from M2's "user can split and merge").
- Opt-in live road-snapping while dragging is **M8**, not here.

**Out:** road mode (M8), and freehand drawing (if ever: a dense via list, not a new geometry type).

## Open questions to settle at planning

- Undo persistence: in memory per editing session, or persisted?
- Touch targets and gestures for vias on small screens; a magnifier?

## Likely shape

- **W1:** editing interaction layer on the map ‖ the bounded recompute in the reveal pipeline + perf ‖ the undo/redo model.
- **W2:** split/merge ‖ reset + mode switch UI.
- **W3:** device verification (the drag-end latency budget on a mid-range Android).
