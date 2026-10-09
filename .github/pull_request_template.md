## What

<!-- Stage / wave / session ID, and what landed. Link the session note. -->

## Verification

<!-- Commands run and results. Device + build mode for anything measured. -->

## Invariants (docs/HANDOFF.md)

- [ ] 1 Open source only (`dart tool/check_deps.dart` green)
- [ ] 2 Raw points are the only source of truth (derived data rebuildable)
- [ ] 3 Original anchors never overwritten
- [ ] 4 Connection mode is a view, not data
- [ ] 5 Reveal along segments
- [ ] 6 Coverage has provenance
- [ ] 7 Local-first, encrypted; no new network host outside `docs/network-hosts.md`
- [ ] 8 The user decides (auto results overridable; user edits not regenerated)
- [ ] 9 History never held hostage
- [ ] 10 No ads / location-seeing analytics / data sales
- [ ] Attribution + permission rationale present for anything this adds
- [ ] `docs/HANDOFF.md` / `docs/decisions.md` updated where the build diverged
