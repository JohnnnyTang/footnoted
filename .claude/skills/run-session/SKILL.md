---
name: run-session
description: Execute one FootNoted session brief (S<NN>-<wn>) as a session agent inside its own worktree - stay inside owned files, meet the acceptance checklist with evidence, write the session note. Use when dispatched as a session agent, or when the user says "run session S01-xx" / "do S01-xx".
---

# Run a session

You are a **session agent**. You own exactly the files listed under **Owns** in your brief, and nothing else.

## 1. Orient (in order, stop when you have enough)

1. `AGENTS.md`: the rules and the repo map.
2. Your brief: `stages/NN-slug/W<n>-*.md`, the section for your session ID. Read the whole wave file once, because sibling briefs tell you what *not* to build.
3. The wave kickoff note in `stages/NN-slug/notes/`: the baseline, the seams, any ownership changes, owner rulings.
4. The stage README: the exit criteria your session feeds, and the F-contract.
5. The relevant `docs/HANDOFF.md` sections. Your brief names them.

## 2. Set up

- Create your branch `s<NN>/<wn>-<slug>` at the commit you were given. Run `flutter pub get` at the repo root.
- Run the baseline for your package(s) and note the counts.

## 3. Work

- **Stay inside "Owns".** If you need to touch any other file, change a seam, add an undeclared dependency, or add a schema migration that is not in your brief, **stop that line of work** and record it under *Out-of-contract findings* in your note. Do not work around it.
- Library questions: use the context7 tools or the Dart MCP `pub_dev_search` for **current** package APIs and versions; do not trust memory for package versions. Verify licences are open (invariant 1). `tool/check_deps.dart` must stay green.
- Tests first where practical. Every acceptance item needs a command that proves it.
- Device work: on Android, use `flutter devices` / `adb devices`. If no device is attached, run on the emulator and **label the numbers "emulator"**. Never report an iOS on-device result; make it an owner step or a backlog row (D-009).
- Commit in small, meaningful commits on your branch. Message format: `S<NN>-<wn>: <what>`.

## 4. Finish

1. Whole-package suite green: `dart analyze`, `dart format --output=none --set-exit-if-changed .`, and the tests for each package you touched. Also `flutter test` in `app/` if you touched the app.
2. Run the `invariant-review` skill on your diff.
3. Write your session note `stages/NN-slug/notes/<YYYY-MM-DD>-S<NN>-<wn>-<slug>.md` from template B in `stages/TEMPLATE.md`. Include:
   - an acceptance checklist with ✅ / ❌ and evidence;
   - measurements with the device, build mode and method;
   - backlog rows (`S<NN>-V###` placeholders: use `S<NN>-V<wn>a`, `…b`; the orchestrator renumbers);
   - a handover.
   Lead the summary with anything that did **not** land.
4. Commit the note. Final message to the orchestrator: the branch, the head SHA, the acceptance items not met, and the out-of-contract findings.

Do **not** edit `VERIFICATION_BACKLOG.md`, the stage README status, `stages/README.md`, or `docs/decisions.md`. Those belong to the orchestrator.
