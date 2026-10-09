# FootNoted — Agent Instructions

> The rulebook for every coding agent (Claude Code reads it via `CLAUDE.md`). It holds **rules and the map only**: no stage status, dates or blockers. Those live in `stages/`.

## 1. Start here, every session

Read in this order; stop when you have what the request needs.

1. This file.
2. **`stages/README.md`**: find the `ACTIVE` stage, then that stage's `README.md` → **Current status** and **Blockers that still bind**. (The SessionStart hook prints the active row for you.)
3. **`docs/HANDOFF.md`**: the product brief. The **10 non-negotiable invariants** and the **Compliance requirements** bind every change.
4. **`docs/decisions.md`**: decisions taken after the handoff. A decision row beats the handoff text it settles.
5. The source of the package you touch.

## 2. Repo map

Dart pub workspace (D-008); one root `pubspec.lock`. Run `flutter pub get` at the repo root.

| Path | What |
| --- | --- |
| `app/` | The Flutter app (`package:footnoted`), Android + iOS. Temporary IDs `com.example.footnoted` (D-006). |
| `packages/footnoted_geo/` | Pure-Dart cell-grid math. **No Flutter imports.** Tests: `dart test`. |
| `packages/footnoted_data/` | Drift + SQLCipher database, schema, migrations, reveal pipeline. **No Flutter imports** (platform pieces such as the keystore live in `app/lib/src/data/`). |
| `tool/` | Repo scripts (`check_deps.dart`, …) and Claude Code hooks (`tool/hooks/`). Used by CI. |
| `spike/` | M0 throwaway harness (exists only during Stage 1 W1–W2; tag `m0-spike` afterwards). |
| `docs/` | `HANDOFF.md` (brief), `decisions.md` (D-log), `README.md` (doc index), `network-hosts.md`. |
| `stages/` | Stage → wave → session plans, session notes, backlogs. |
| `.claude/` | Project settings (hooks, permissions, plugins) and skills. `.claude-plugin/marketplace.json` makes this repo a plugin marketplace (`dart-lsp`). |

## 3. How work is organised

- **Stage → wave → session.** Conventions, IDs and branch names are in `stages/README.md`. Templates are in `stages/TEMPLATE.md`.
- **Orchestrator vs session agent.** The orchestrator (foreground) opens and closes waves with the **`orchestrate-wave`** skill. Session agents execute one brief each with the **`run-session`** skill, in their own worktree. A new stage is planned with **`plan-stage`**. Every diff is checked with **`invariant-review`**.
- **Out of contract → stop and raise.** A session that needs a file outside its "Owns" list, a seam change, an undeclared dependency or an undeclared migration stops and records the need in its note.
- **Status lives in two places only:** the stage README's *Current status* and its row in `stages/README.md`.
- **Records are append-only.** Correct with a dated `**Correction of record (YYYY-MM-DD):**`.

## 4. Code rules

- **Toolchain:** Flutter 3.47.7 / Dart 3.13.5 (D-010). Do not upgrade mid-wave.
- **Invariants are hard constraints** (handoff §Non-negotiable invariants). The common traps are:
  - never `UPDATE` coordinates in `points`/`media` (corrections are new rows);
  - never write coverage without its `segment_id`;
  - never store inferred geometry as recorded;
  - no network host outside `docs/network-hosts.md`;
  - nothing logs coordinates, notes or the DB key.
- **Dependencies:** open-source licences only. `tool/check_deps.dart` and the post-edit hook block denylisted packages (Google/Mapbox map SDKs, Firebase, analytics/ads, `flutter_background_geolocation`, FFmpegKit). Check current versions with the Dart MCP `pub_dev_search` or context7, not from memory.
- **Strings:** every user-visible string comes from `app/lib/l10n/*.arb` (D-005). The exceptions are legal credit text (`map_credits.dart`) and the brand name.
- **Name:** "FootNoted" with a capital N, never with an asterisk.
- **Permissions:** a rationale screen before every prompt; **no `ACCESS_BACKGROUND_LOCATION`** outside the passive-mode build flag (M7).
- **Monetisation hooks:** UI asks `Entitlements.isAvailable(...)`; nothing tests purchase state; nothing free is ever gated.
- **Comments:** write none unless the *why* is non-obvious. No multi-line doc-block boilerplate.
- **Formatting:** `dart format` (the post-edit hook runs it). `dart analyze` must be clean.
- **Generated code** (Drift `*.g.dart`): committed, regenerated with `dart run build_runner build` (S01-32 records the final rule).
- **Line endings:** LF everywhere except `*.bat`/`*.cmd`/`*.ps1` (`.gitattributes`).

## 5. Verify before claiming

Run these from the repo root before saying something works:

```
flutter pub get
dart analyze
dart format --output=none --set-exit-if-changed .
(cd packages/footnoted_geo && dart test)
(cd packages/footnoted_data && dart test)
(cd tool && dart test)
(cd app && flutter test)
dart tool/check_deps.dart
```

- **Android SDK components:** install with `sdkmanager "ndk/<ver>"` (slash form). The `;` form is broken in cmdline-tools 23, and Gradle's NDK auto-install fails because of it.
- **Devices.** The Android emulator AVD is `fn_api36`. The owner's phone appears in `adb devices` when connected. Label every number with its device and build mode (profile/release for performance).
- **iOS (D-009).** Agents run on Windows. iOS is compiled in CI (`macos-latest`, `--no-codesign`) and run on device **only by the owner** on their Mac. Never report an iOS on-device result you did not receive from the owner.

## 6. Git

- `main` is always green. Each stage has a branch `stage/NN-slug`; each session has a branch `sNN/<wn>-<slug>` in its own worktree.
- Commit messages: `S01-31: <what>` for session work, `W1 kickoff: <what>` / `W1 close: <what>` for orchestration, a plain imperative sentence otherwise.
- No force-push (denied in settings). Rebase session branches before merging them; merge with `--no-ff`.
- Licence: MPL-2.0 (D-001). New source files need no per-file header.

## 7. Maintaining this file

Keep it under about 200 lines. Change it in the same commit as the convention it describes. Dates, statuses and blockers go to `stages/`, never here.
