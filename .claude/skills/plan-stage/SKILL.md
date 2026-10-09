---
name: plan-stage
description: Turn a FootNoted KICKOFF stage document (stages/NN-slug/README.md) into a detailed stage plan with waves, balanced sessions, briefs, file ownership, seams and merge order - the same shape as stages/01-foundation. Use when the previous stage has exited and the user says "plan stage N" / "plan the next stage".
---

# Plan a stage

Input: `stages/NN-slug/README.md` in state `KICKOFF`. Output: the same directory, in the same shape as `stages/01-foundation/` (the reference plan; copy its structure, not its content):

- `README.md`: the header (state, branch, milestone, backlog link, wave links), **Objective**, numbered **Exit criteria** tagged `[auto] [device-A] [owner-iOS] [doc]`, the **F<NN> contract** table (the cross-package seams), **Waves at a glance**, the **Session index** (ID, title, size, wave, depends on), **Risks**, **Current status**, **Blockers that still bind**.
- `W<n>-<slug>.md` per wave: kickoff obligations (baseline, owner rulings, **seams to implement once**), a **file ownership table**, the **merge order**, then one brief per session in template A (`stages/TEMPLATE.md`).
- `VERIFICATION_BACKLOG.md`: empty, with headers.

## Procedure

1. **Re-ground.** Read `AGENTS.md`, `docs/HANDOFF.md` (the milestone section and the invariants), `docs/decisions.md`, the previous stage's exit table and its **open backlog rows** (they are inherited risks), and the actual code tree. The kickoff doc was written before the previous stage ran, so verify each assumption it makes against the code.
2. **Settle open questions.** List every `[Open]` item and every kickoff "open question" this stage needs. Ask the owner (AskUserQuestion: at most 4 per call, with a recommended option first) before writing briefs that depend on them. Log the answers as D-rows.
3. **Exit criteria first.** Derive them from the handoff milestone exit, the "definition of done" tests that apply, and compliance items. Each must be checkable, with a named method. Mark device/owner criteria honestly.
4. **Find the seams.** Identify the cross-package interfaces and shared files (pubspecs/lockfile, ARB, the router, schema migrations, fixtures). Each becomes either a frozen contract clause or a kickoff seam, so parallel sessions never edit the same file.
5. **Cut sessions.** Each session should:
   - own a disjoint file set;
   - be sized S/M/L, where L ≈ one full agent session (roughly 1–4 h of agent work, ~1–2 k changed lines including tests). Split anything bigger.
   - have 3–6 deliverables and an acceptance checklist where every item names a command;
   - name its owner steps (devices, iOS on the Mac) explicitly.

   Aim for **3–4 parallel sessions per implementation wave**, and put verification in its own final wave. Balance the sizes inside a wave so it does not wait on one straggler.
6. **Order waves** by dependency: a session needing unmerged sibling code goes in a later wave or a `b` sub-wave. Declare the merge order per wave.
7. **Write it**, update the `stages/README.md` row to `ACTIVE`, and present a summary to the owner: the waves table, the owner involvement, and any decisions still needed.
