---
name: invariant-review
description: Check a FootNoted diff (a branch, a PR, or uncommitted changes) against the 10 non-negotiable invariants and the compliance rules in docs/HANDOFF.md. Use before finishing any session, before merging a session branch, before a stage PR, or when the user asks "does this break any invariant?".
---

# Invariant review

Get the diff, for example `git diff <base>...HEAD` (a session: base = the stage branch; a stage PR: base = `main`). Then answer **each** item below with `held`, `n/a`, or `BROKEN: <file:line, why>`. Never answer "looks fine" in aggregate.

| # | Invariant (docs/HANDOFF.md) | What to look for in the diff |
| --- | --- | --- |
| 1 | Open source only | New deps in any `pubspec.yaml`: licence open? `dart tool/check_deps.dart` green? Tile/style/font sources open and keyless? |
| 2 | Raw points are the only truth | Any code path that writes derived data **without** a way to rebuild it from `points` + edits? Derived tables populated only by the reveal/rebuild pipeline? |
| 3 | Anchors never overwritten | Any `UPDATE points` / `UPDATE media` of coordinates? Corrections must be new `anchor_corrections` rows. |
| 4 | Connection mode is a view | Inferred geometry stored as if it were recorded? Mode change must re-derive, keep vias, be reversible. |
| 5 | Reveal along segments | Reveal from points only, without rasterising the connecting geometry? |
| 6 | Coverage has provenance | Coverage written without a `segment_id`? A bare counter incremented instead of a (cell, segment) record? Delete paths that leave orphaned coverage? |
| 7 | Local-first, encrypted | A new network call (host in `docs/network-hosts.md`?); a plaintext DB or file holding user data; anything logged that contains coordinates or the DB key? |
| 8 | The user decides | Automatic grouping/segmentation that overwrites `is_user_edited = 1` work? Is there an override path? |
| 9 | History is never held hostage | An `Entitlements` check (or an error) that hides or locks **existing** data? An error path that shows an empty map instead of an error? |
| 10 | No ads/analytics/data sales | Any SDK or endpoint that can see location, media metadata or notes? Crash reporting without coordinate scrubbing? |

Also check, where the diff touches them:

- **Permissions:** no `ACCESS_BACKGROUND_LOCATION` outside the passive-mode flag; a rationale screen before every prompt; iOS purpose strings name the specific feature.
- **Attribution:** map credits are still visible on every map surface, and the About/Licences screen is updated for any new data source.
- **ODbL:** routed/matched geometry stays per user and per segment; nothing aggregates it into a shared road network.
- **Sharing/export:** GPS/EXIF stripped by default; a warning before sharing location.
- **Monetisation hooks:** UI asks `Entitlements`, never purchase state; nothing free is gated.

Output: the table filled in, then a one-line verdict (`PASS` / `FAIL: n items`). Any `BROKEN` or uncertain item becomes a backlog row in the session note. Never wave it through.
