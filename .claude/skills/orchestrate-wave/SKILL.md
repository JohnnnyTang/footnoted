---
name: orchestrate-wave
description: Open, dispatch, and close a FootNoted wave (stage → wave → session). Use when the user says "start/kick off/open W<n>", "dispatch the wave", "merge/close W<n>", or "run the next wave" for the ACTIVE stage under stages/. Runs in the foreground as the orchestrator; sessions run as parallel background agents.
---

# Orchestrate a wave

You are the **orchestrator**. You own the stage branch, the seams, the merges and the stage status. Session agents own only the files their brief gives them.

Read first: `AGENTS.md`, `stages/README.md` (conventions), the active stage `README.md` (exit criteria, F-contract, current status), and the wave file `stages/NN-slug/W<n>-*.md`.

## A. Kickoff (foreground; nothing dispatches until every step is done)

1. **Branch.** In the first wave of a stage, cut `stage/NN-slug` from an up-to-date `main` and push it. Otherwise `git fetch` and rebase the stage branch on `origin/main` if `main` moved.
2. **Baseline, with commands recorded.** Run each of these and keep the counts (not adjectives):
   - `flutter pub get` (root)
   - `dart analyze`
   - `dart format --output=none --set-exit-if-changed .`
   - `dart test` in each `packages/*` and `tool/`
   - `flutter test` in `app/`
   - `dart tool/check_deps.dart`

   If anything is red, fix it or record it before dispatching. Never dispatch onto a red baseline without a written reason.
3. **Owner rulings.** Every item the wave file lists under owner rulings / prerequisites is resolved with the user (use AskUserQuestion) or recorded as a blocker. Log new decisions in `docs/decisions.md` (append-only, D-NNN).
4. **Seams.** Implement every item under "Kickoff obligations → Seams" yourself: shared interfaces, frozen types, fixtures, pre-added dependencies, directory skeletons. Commit them on the stage branch **before** dispatch, so every worktree starts with them. Seams are read-only to sessions.
5. **Ownership and order.** Re-check the ownership table against the actual tree, because paths drift. Any change is written into the kickoff note. Confirm the merge order. Sessions that depend on a sibling's unmerged code go in a later sub-wave (`W<n>b`), never in the same dispatch.
6. **Kickoff note.** Write `stages/NN-slug/notes/<YYYY-MM-DD>-W<n>-kickoff.md` (template C in `stages/TEMPLATE.md`). Commit it.

## B. Dispatch

For each session in the wave, start **one background agent** with `isolation: "worktree"`, all in a single message so they run in parallel. Use this prompt shape (fill in the brackets):

```
You are session agent S<NN>-<wn> for FootNoted. Follow the `run-session` skill exactly.
Branch: s<NN>/<wn>-<slug>, created from stage/NN-slug @ <sha> (your worktree is already on that commit; create the branch).
Your brief: stages/NN-slug/W<n>-<file>.md → section "S<NN>-<wn>".
Wave kickoff note: stages/NN-slug/notes/<date>-W<n>-kickoff.md.
Owner context: <any ruling or device info the session needs>.
Do not edit files outside your "Owns" list. Out of contract → stop and record it in your session note.
Finish with: tests green for your package(s), your session note committed on your branch, and a final message listing the branch, the head SHA, and any acceptance items NOT met.
```

Never fabricate or predict a session's result. Wait for each completion notification.

## C. Close (after every session reports)

1. **Review each session branch** before merging: the diff stays inside its owned files; the acceptance checklist in the note is evidenced by commands; the invariant check is present. Bounce it back (SendMessage to that agent) when something is missing, rather than fixing it silently.
2. **Merge in the declared order.** For each branch: rebase it onto the current stage branch, then `git merge --no-ff`, and re-run that package's tests.
3. **Whole suite on the merged tree** (the same commands as A.2). Check the test arithmetic: the sum of new tests per session matches the observed count delta.
4. **Backlog.** Append every `## Backlog rows` entry from the session notes to `VERIFICATION_BACKLOG.md`.
5. **Status.** Update the stage README's **Current status** (one line per session plus a wave line) and **Blockers that still bind**, and the stage row in `stages/README.md`. Status lives only in those two places.
6. **Close note** `notes/<date>-W<n>-close.md`. Push the stage branch. Remove the merged session worktrees and branches.
7. **Gates.** If the wave ends at a gate (for example G1), prepare the decision tables and ask the owner. Nothing in the next wave dispatches before the ruling is logged.

## Rules

- Do not do a session's work in the foreground "to save time". If a seam is missing, add it as a seam (commit + note).
- Never claim a device or iOS result that nobody observed (D-009). Missing evidence → a backlog row.
- Records are append-only; correct with `**Correction of record (date):**`.
