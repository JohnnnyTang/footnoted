# Stages

**Status:** current · **Last verified:** 2026-10-08 · **Owner:** orchestrator

Work is organised in three layers:

- **Stage.** One milestone-sized outcome with exit criteria (normally one handoff milestone; Stage 1 = M0 + M1, see D-002). Lives in `stages/NN-slug/`.
- **Wave.** A set of sessions that can run **in parallel** because their file ownership does not overlap. Waves run strictly in order, and a wave opens only after the previous one has merged and its suite is green.
- **Session.** One agent's balanced unit of work: one brief, one worktree, one branch, one session note. Sized to finish in a single agent session, roughly 1–4 hours of agent work, touching one package or feature slice.

## Stage index

Status lives in exactly two places: this table and the stage README's **Current status**.

| # | Stage | Milestone | State | What still binds |
| --- | --- | --- | --- | --- |
| 01 | [Foundation](01-foundation/README.md) | M0 spike + M1 foundation | `ACTIVE`: W0 done, **W1 dispatched** (S01-10…13 running) | W1 close; owner's Android device for W2 |
| 02 | [Import mode](02-import/README.md) | M2 | `KICKOFF`: scope only | Stage 1 exit |
| 03 | [Live recording](03-live-recording/README.md) | M3 | `KICKOFF`: scope only | Stage 2 exit; real OEM devices |
| 04 | [Trips and places](04-trips-places/README.md) | M4 | `KICKOFF`: scope only | Stage 2 exit (Stage 3 not required) |
| 05 | [Statistics](05-statistics/README.md) | M5 | `KICKOFF`: scope only | Stage 4 exit |
| 06 | [Route editing](06-route-editing/README.md) | M6 | `KICKOFF`: scope only | Stage 2 exit |
| — | Passive mode | M7 | not opened | Play background-location declaration |
| — | Road routing (opt-in) | M8 | not opened | Self-hosted Valhalla |
| — | Later | soft fog, PMTiles packs, E2E backup, paid tiers, posters | not opened | — |

**States:** `KICKOFF` (a scope document only, not yet planned into waves) · `ACTIVE` (planned and in progress) · `MERGED, NOT EXITED` (the PR is merged but some exit criteria are still open) · `EXITED WITH CAVEATS` (every criterion is met or carried as a named backlog row) · `EXITED`.

A `KICKOFF` stage is planned into waves and sessions **only after the previous stage exits**, using the `plan-stage` skill. Plans written before then go stale.

## Conventions

### IDs

- **Session `S<stage>-<wave><n>`**: `S01-10` is Stage 1, Wave 1, session 0. Wave 0 (bootstrap/planning) is `S01-0x`. A suffix letter (`S01-31b`) marks a split decided at kickoff.
- **Backlog rows `S<stage>-V###`** live in the stage's `VERIFICATION_BACKLOG.md`. **Environment/owner-action rows `S<stage>-E#`.**
- **Gates `G<n>`**: decision points inside a stage where the owner rules before work continues (for example Stage 1 G1: grid and storage decisions from the spike).

### Branches and worktrees

- `main` is always green. One stage branch, `stage/NN-slug`, is cut from `main` by the stage's first wave kickoff.
- Each session works in its own worktree on branch `sNN/<wave><n>-<slug>`, for example `s01/10-trace-generator`, cut from the stage branch at wave open.
- The orchestrator merges sessions into the stage branch **in the declared merge order**, rebasing each one before it merges. A stage reaches `main` through one PR when it exits (or at an agreed checkpoint, such as Stage 1 after G1).

### How a wave runs

1. **Kickoff (foreground orchestrator, `orchestrate-wave` skill).** Rebase the stage branch. Re-run the full suite and record the baseline **with the commands**. Implement every cross-session **seam** once (shared interfaces, fixtures, file skeletons), read-only to sessions. Confirm file ownership and the merge order. Resolve or escalate any owner questions the wave needs. Write `notes/<date>-W<n>-kickoff.md`.
2. **Dispatch.** Start one background agent per session (worktree isolation), each told to follow the `run-session` skill against its brief. Sessions that depend on a sibling's code go in a later sub-wave (`W3b`), never in the same dispatch.
3. **Session.** The agent stays inside its owned files, writes tests, runs the whole package suite, and writes a session note (`stages/NN-slug/notes/<date>-S<id>-<slug>.md`, skeleton in [`TEMPLATE.md`](TEMPLATE.md)). Backlog rows go in the note, never straight into `VERIFICATION_BACKLOG.md`.
4. **Close (orchestrator).** Merge in order. Re-run the **whole** suite on the merged tree. Append backlog rows. Update the stage README **Current status** and the row above. Write `notes/<date>-W<n>-close.md`.

### Rules every session follows

- **Out of contract → stop and raise.** A session that needs to edit a file it does not own, change a frozen seam, or add an undeclared migration stops and records the need in its note. It does not work around it.
- **Never claim what you did not observe.** A device-only or iOS-only check that was not run is a backlog row, not a pass. An agent never reports an iOS result (D-009).
- **Records are append-only.** Correct the past with a dated `**Correction of record (YYYY-MM-DD):**` line.
- **Invariants first.** Every session checks its diff against the 10 invariants in [`docs/HANDOFF.md`](../docs/HANDOFF.md#non-negotiable-invariants) (`invariant-review` skill) before it finishes.
