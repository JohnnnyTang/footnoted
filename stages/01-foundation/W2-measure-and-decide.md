# Stage 1 · W2 — On-device measurement and gate G1

**Opens after:** W1 merged. **Sessions:** S01-20, then S01-21 (S01-21 needs S01-20's build). *S01-22 only if criterion 2 fails.* **Closes into:** gate G1, then W3.
**Purpose:** turn emulator and desktop numbers into **device** numbers, and give the owner what they need to rule G1.

**Amended 2026-10-09 (D-012):** W2 now runs only **S01-20a** (no device) and closes into **G1-A**. The device sessions S01-20b and S01-21 move to **W2b**, between W3 and W4, closing into **G1-B**. See [the amendment](#amendment-2026-10-09-d-012) at the end; it overrides this file where they differ.

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

---

## Amendment 2026-10-09 (D-012)

The owner's Android phone is not yet connected (`S01-E1`). Gate G1 is ruled in two parts so that W3 does not wait for hardware. Where this amendment and the text above differ, the amendment wins.

### New order

```
W2: S01-20a (no device) ─▶ G1-A (a, b, c, d) ─▶ W3 ─▶ W2b: S01-20b (Android) + S01-21 (iOS owner) ─▶ G1-B (e + criterion 2) ─▶ W4
```

- **W2 kickoff, part 2** (the next session): rebase, run the suite, then dispatch **S01-20a alone**. Prerequisites `S01-E1` and `S01-E2` move to the W2b kickoff.
- **W2 close → G1-A.** The orchestrator writes `notes/<date>-G1A.md` with decision tables for (a)–(d), using W1 and S01-20a numbers, and the owner rules. Then:
  - append the decisions to `docs/decisions.md` (the next free D-numbers);
  - mark **F01.1, F01.2, F01.3, F01.5, F01.6** as **FROZEN** in the stage README. F01.4 (`CoverageReader`) stays a proposal until G1-B;
  - **keep `spike/`** and its CI jobs;
  - the optional checkpoint PR moves to after G1-B.
- **W2b** opens after W3 merges and needs `S01-E1` (and `S01-E2` for S01-21). It contains S01-20b, then S01-21, and conditionally S01-22.
- **W2b close → G1-B:** (e) the fog strategy, zoom → level mapping and rollup levels; criterion 2 MET/MISSED per platform. Then F01.4 is frozen, `m0-spike` is tagged, `spike/` and its CI jobs (`spike tests`, `spike-ios`) are deleted, and the workspace list is trimmed. W4 opens only after this.

### S01-20a — Integrated spike on the real dataset (no device)

**Wave:** W2 · **Branch:** `s01/20a-integrate` · **Size:** M · **Depends on:** W1 merged, D-011 in place

**Goal.** Make the spike measure the real five-year dataset end to end, through the SQLCipher database, on desktop and emulator. Also make the later device run a single scripted step, so that S01-20b is mostly the owner plugging in the phone.

**Owns:** `spike/storage_bench/**`, `spike/render_bench/**`, `spike/tracegen/**` (bug fixes only, and no change to the output bytes for a given seed), a new `spike/device_run/**` (or scripts under `spike/`), `stages/01-foundation/evidence/S01-20a/**`, and its own note.
**Reads:** `spike/FORMAT.md`, the W1 session notes (S01-10…13), `spike/render_bench/MEASURE.md`, the W2 kickoff note.

**Deliverables.**
1. **Real dataset.**
   - Generate `dataset.*` with `dart run tracegen --seed 42 --years 5`, and record the hashes against S01-10's.
   - `storage_bench` takes `dataset.segcells.bin` for every metric (S01-V004, S01-V007 desktop half).
   - `render_bench` takes `dataset.cells.bin`.
2. **DB-backed fog.**
   - `render_bench` reads coverage from a **SQLCipher** database through the tile query ("covered cells in tile at level L"), not from memory, so frame timing includes I/O.
   - Both layouts A and B are still open. Use B by default; A is a switch.
3. **Pan path.** Re-point `panWaypoints` from the Berlin stand-in to S01-10's home city (Mexico City) and its road corridor. The fixed z10 path and the z5 / z14 / z18 spot runs are from the S01-20 brief.
4. **Desktop and emulator runs on the real data**, each labelled with device and build mode:
   - storage: every S01-11 metric, desktop AOT plus emulator release;
   - render: emulator profile, strategy (a) d6 on VD, plus (b) and TextureView as controls, 3 runs each;
   - the emulator is **not** representative and gives no pass/fail.
5. **One-command device run**:
   - a script, say `spike/device_run/run_android.sh` or `.dart`, that builds profile/release, installs both apps, pushes the dataset, runs the storage bench and the pan script, pulls the JSON and SurfaceFlinger captures into `evidence/S01-20b/`, and prints the criterion 2 summary;
   - dry-run it end to end on the emulator.
6. **G1-A inputs** in the note: one table per decision (a)–(d), using W1 numbers plus the real-dataset numbers.

**Acceptance.**
- [ ] The tracegen hashes for seed 42 match S01-10's recorded hashes.
- [ ] `render_bench` coverage comes from the SQLCipher database: show the `cipher_version` from the same connection in the run log.
- [ ] Storage and render tables are produced on the real dataset, labelled desktop/emulator.
- [ ] The device-run script completes against the emulator with no manual steps beyond starting it.
- [ ] `dart analyze --fatal-infos`, `dart format`, all spike tests and `check_deps` are green.

**Owner steps:** none.
**Out of scope:** pass/fail on criterion 2; optimisation (S01-22); any production code.
**Traps:**
- JDK 21 is needed for `render_bench` (S01-V013): set `JAVA_HOME=D:/software/jdk-21.0.12.1+1` per command.
- Set `kotlin.incremental=false` (S01-V015).
- Gradle needs `-Dhttps.proxyHost` for its first downloads on this machine.

### S01-20b — Android device measurement (W2b)

**Wave:** W2b · **Branch:** `s01/20b-android-measure` · **Size:** S · **Depends on:** S01-20a merged, W3 merged, `S01-E1`

This is the original S01-20 deliverables 2–4 and acceptance, run with S01-20a's script on the owner's phone.

- If W3's workspace changes broke the spike build, the session fixes it inside `spike/**`.
- Output: criterion 2 (Android) MET/MISSED with figures; storage metrics on the phone (S01-V007); the profile build state handed to S01-21.

**S01-21** keeps its brief above, in W2b, after S01-20b. **S01-22** stays conditional, in W2b.
