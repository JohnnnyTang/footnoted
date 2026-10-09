# Stage 1 · W5 — Integrate and verify (the M1 exit)

**Opens after:** W4 merged. **Sessions:** S01-50, then S01-51 (serial: S01-51 verifies what S01-50 wires). **Closes into:** stage exit.
**Purpose:** wire the real caller path end to end, then verify every exit criterion on real devices and leave the docs true. Verification is a wave of its own, not a step at the end of an implementation session.

## Kickoff obligations

1. Rebase; re-run the full suite and CI; record it.
2. Owner prerequisites: the Android phone connected (S01-E1), and an iOS slot booked on the Mac (S01-E2).

## File ownership

| Path | Owner |
| --- | --- |
| `app/lib/main.dart`, `app/lib/src/app/bootstrap.dart`, `app/lib/src/features/dev/**`, `app/integration_test/**` | S01-50 |
| `docs/**`, `stages/01-foundation/README.md` (status), `evidence/S01-51/**`, `RUNBOOK-ios-M1.md` | S01-51 |

---

### S01-50 — End-to-end wiring + dev harness (**wiring owner**)

**Branch:** `s01/50-e2e-wiring` · **Size:** M

**Goal.** The app boots into the real stack: the encrypted database opened with the keystore key → `AppMetaStore` over the database (first use recorded) → `RevealService` → `CoverageReader` → `FogController` on the home map. A debug-only harness drives the M1 exit scenario through the **real caller path**.

**Deliverables.**
1. `bootstrap.dart`: open the database (`SecureKeyProvider`), run migrations, build the providers, record first use, and handle failure visibly (an error screen; never a silent empty map, per invariant 9).
2. `/dev` harness (debug or `FN_DEV` only): insert the dev fixtures (raw points + segments), reveal, delete one or all, rebuild, show cell counts and `derivedStateHash`, and jump the camera to zoom presets z2/z5/z10/z14/z18/z20 over each fixture.
3. `integration_test/m1_exit_test.dart`, run on the emulator or a device. Capture the baseline (`derivedStateHash`, the fog geometry of a set of probe tiles at z3/z10/z16/z20) → insert + reveal the three fixtures → assert coverage > 0 and the probe-tile fog has holes along each fixture (and none on the far side of the antimeridian) → delete all → assert **hash == baseline and probe fog == baseline**. The assertions go through the same providers the UI uses, not test-supplied fakes.

**Acceptance.**
- [ ] `flutter test integration_test` passes on the Android emulator (the command and output are recorded).
- [ ] A cold start on the emulator: the first-use timestamp is written once, and the key persists across restarts (the database reopens).
- [ ] CI is green.

**Owner steps:** none (the device run is S01-51's).

---

### S01-51 — Exit verification + docs

**Branch:** `s01/51-exit-verify` · **Size:** M

**Goal.** Walk every exit criterion (1–13) with evidence, run the device checks, and leave `HANDOFF.md`, `decisions.md`, `docs/README.md` and this stage's README true. Unmet criteria are recorded as MISSED with backlog rows, never softened.

**Deliverables.**
1. `m1_exit_test` on the **owner's Android phone**, plus a z10 pan fps run on the production fog path (the S01-12 method), with screenshot pairs (before reveal / revealed / after delete) at 3 zooms.
2. `RUNBOOK-ios-M1.md` for the owner: build and run on the iPhone, run `m1_exit_test` from Xcode or `flutter test integration_test -d <iphone>`, the Instruments pan, and the screenshots. Record the owner's results as **owner-measured**.
3. An exit table in the stage README: each criterion → MET / MET IN PART / MISSED, with an evidence link.
4. Docs: update `HANDOFF.md` wherever the build diverged (the grid, the storage layout, levels, packaging), refresh `docs/README.md` freshness, and close or carry every `S01-V` row.
5. A draft of the stage PR description (`stage/01-foundation → main`).

**Acceptance.**
- [ ] Every criterion has a verdict and evidence; every non-MET criterion has a backlog row.
- [ ] No iOS result is claimed unless the owner reported it.

**Owner steps:** keep the Android phone connected; run the iOS runbook (about 45 minutes).

---

## Stage exit (orchestrator)

1. The exit table is complete, and the owner reviews it.
2. Open the PR `stage/01-foundation → main` (attribution per the repo convention), get CI green, and merge.
3. The stage row becomes `EXITED` / `EXITED WITH CAVEATS`.
4. **Plan Stage 2 in detail** from [`../02-import/README.md`](../02-import/README.md) with the `plan-stage` skill.
