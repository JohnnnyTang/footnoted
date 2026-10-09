# Stage 1 · W2 — On-device measurement and gate G1

**Opens after:** W1 merged. **Sessions:** S01-20, then S01-21 (S01-21 needs S01-20's build). *S01-22 only if criterion 2 fails.* **Closes into:** gate G1, then W3.
**Purpose:** turn emulator and desktop numbers into **device** numbers, and give the owner what they need to rule G1.

W2 is deliberately small and serial: it is gated by real hardware, not by agent throughput.

## Kickoff obligations

1. Rebase `stage/01-foundation`; re-run the suite; record it.
2. **Owner prerequisites (S01-E1 / S01-E2):** the Android phone's model, Android version and RAM, with USB debugging on and `adb devices` listing it on the dev machine. The owner confirms that a Mac with Xcode and the older iPhone are available for S01-21, and records the model and iOS version.
3. Pick the fog strategy from S01-12's recommendation and the storage layouts that are still in contention from S01-11's.

## File ownership

| Path | Owner |
| --- | --- |
| `spike/**` (integration glue only: asset wiring, a combined runner) | S01-20 |
| `spike/render_bench/MEASURE.md` (the iOS section), `spike/RUNBOOK-ios.md` | S01-21 |
| `stages/01-foundation/evidence/S01-2n/**`, own notes | each session |
| `docs/decisions.md` (G1 rows), the F01 table in `README.md` | **orchestrator at G1** |

---

### S01-20 — Integrated spike + Android measurement

**Branch:** `s01/20-android-measure` · **Size:** M · **Depends on:** W1 merged, S01-E1

**Goal.** Run the real five-year dataset through the chosen storage layout(s) and fog strategy **on the owner's Android phone**, and produce the numbers behind exit criteria 2 and 3.

**Deliverables.**
1. Wire S01-10's dumps into `storage_bench` and `render_bench`. The render bench reads coverage **from the SQLCipher database** through the tile query, not from memory, so the measurement includes I/O.
2. Device runs, release/profile builds only:
   - storage: every metric from S01-11 on the phone;
   - render: the pan script at z10, 3 runs per strategy (and per composition mode, if both are still open), plus one run each at z5, z14 and z18 to catch level-mapping cliffs.
3. Raw captures saved under `evidence/S01-20/` (gfxinfo/Perfetto output, JSON results), plus a summary table in the note.
4. Pass/fail against exit criterion 2 for Android, stated plainly.

**Acceptance.**
- [ ] Every number names the device, OS, build mode and method.
- [ ] Criterion 2 (Android) is MET or MISSED, with the figures.
- [ ] A profile-mode `.apk`/`.ipa`-ready branch state is handed to S01-21 (the iOS build is done on the Mac by the owner).

**Owner steps:** keep the phone connected and unlocked during the runs, and confirm the model.
**Out of scope:** optimisation work. If the criterion is missed, record it and stop: S01-22 is a separate decision.

---

### S01-21 — iOS measurement (owner runs it)

**Branch:** `s01/21-ios-runbook` · **Size:** S · **Depends on:** S01-20's branch state, S01-E2

**Goal.** Get the iOS half of criteria 2 and 3 **measured by the owner on their Mac + older iPhone**, with an agent-written runbook that makes the run mechanical (D-009).

**Deliverables.**
1. `spike/RUNBOOK-ios.md`: the exact steps — `flutter build ios --profile`, open in Xcode, sign with a personal team, install on the device, run the storage bench and copy the JSON out, then run the pan script under Instruments (Animation Hitches / Core Animation FPS) — plus what to screenshot and where to paste the results.
2. When the owner returns the results, the session (or the orchestrator) records them under `evidence/S01-21/` and in the note, tagged **owner-measured**.

**Acceptance.**
- [ ] The runbook is complete enough that the owner needs no other document.
- [ ] Criterion 2 (iOS) is recorded as MET / MISSED / NOT RUN (backlog row) from the owner's numbers only.

**Owner steps:** the whole device run on the Mac (about 1 hour).

---

### S01-22 — *(conditional)* Performance remediation

Dispatched **only** if S01-20 or S01-21 misses criterion 2. Options, in order of cost: coarser rollup levels at z10 with bigger merged rectangles; precomputed per-tile fog geometry cached in the database; vector-tile/raster fog served from an in-app source (pulls the "soft fog" path forward). The session re-measures and reports. If it still misses, G1 asks the owner to accept a lower bar or re-scope.

---

## Gate G1 (orchestrator + owner)

At W2 close the orchestrator writes `notes/<date>-G1.md` with one table per decision (the options, the numbers, a recommendation) and asks the owner to rule:

- **(a)** grid type: quadkey vs H3;
- **(b)** cell size: z20 vs z21;
- **(c)** coverage storage: per-cell rows vs spans;
- **(d)** driver: confirm Drift (D-003) or switch to raw `sqlite3`;
- **(e)** fog strategy and the zoom → level mapping, including the rollup levels.

Then the orchestrator:

1. appends the decisions D-011… to `docs/decisions.md` and settles the matching `HANDOFF.md` open questions;
2. rewrites the F01 table in `README.md` as **FROZEN**;
3. tags `m0-spike`, deletes `spike/` from the tree, and removes it from the workspace;
4. optionally opens a checkpoint PR `stage/01-foundation → main` (decisions + the `footnoted_geo` math), so `main` carries the decisions before M1 starts.
