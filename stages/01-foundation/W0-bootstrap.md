# Stage 1 · W0 — Planning and bootstrap

**Session:** S01-00 (foreground, orchestrator + owner) · **Date:** 2026-10-08 · **Branch:** `main` (no stage branch yet; the W1 kickoff cuts it).

W0 is this planning session. It is recorded here as the stage's first wave so the record stays complete.

## Owner rulings obtained (2026-10-08)

| Question | Ruling | Logged as |
| --- | --- | --- |
| What does Stage 1 cover? | M0 + M1 | D-002 |
| Repo visibility and name | **Public**, `JohnnnyTang/footnoted` | D-001 |
| App licence (now required, because the repo is public) | **MPL-2.0** | D-001 |
| iOS path | The owner has a Mac + iPhone; iOS steps are owner runbooks | D-009 |
| Toolchain | Install now on the dev machine | D-010 |
| SQLite driver | Drift, benchmarked in M0 | D-003 (Proposed) |
| Minimum OS versions | Flutter template defaults | D-004 |
| Languages | English only, i18n-ready | D-005 |

Proposed by the orchestrator and awaiting the owner: **D-007** (default buffer), to be confirmed at the W3 kickoff (S01-E3).

## What W0 produced

**Plan:**
- The Stage 1 README (exit criteria, the F01 proposal, waves, session index, risks).
- The wave files W1–W5 with 15 session briefs (+1 conditional).
- Kickoff docs for Stages 2–6.
- `stages/README.md` (process conventions) and `stages/TEMPLATE.md`.

**Docs:**
- `docs/HANDOFF.md`, moved from the repo root; the decided open questions were updated in place.
- `docs/decisions.md` (D-001…D-010) and `docs/README.md` (the index).
- `AGENTS.md` + `CLAUDE.md`, `README.md`, `LICENSE` (MPL-2.0).

**Toolchain (dev machine, Windows):**
- Flutter 3.47.7 at `D:\software\flutter`; the archive's SHA-256 matched the release manifest.
- Android SDK at `D:\software\android-sdk`: cmdline-tools, platform-tools, platform 36, build-tools 37, the emulator, and the AVD **`fn_api36`** (Android 36, x86_64, WHPX).
- User PATH: `flutter\bin`, `flutter\bin\cache\dart-sdk\bin` (so MCP/LSP servers can launch `dart.exe`), `platform-tools`, `cmdline-tools\latest\bin`. User env: `ANDROID_HOME`, and `NO_PROXY=localhost,127.0.0.1,::1` (an HTTP proxy is set on this machine).
- Flutter analytics disabled; web and Windows-desktop targets disabled.

**Scaffold:**
- A pub workspace with the members `app` (the `flutter create` template, Android + iOS, `com.example.footnoted`), `packages/footnoted_geo`, `packages/footnoted_data` and `tool`.

**Guards:**
- `tool/check_deps.dart` (a denylist over the resolved lockfile), `tool/guards/denylist.dart` and its tests.

**CI:**
- `.github/workflows/ci.yml`: analyze (`--fatal-infos`), format, dependency guard, all tests, Android debug build, iOS `--no-codesign` build on `macos-latest`.
- Dependabot and a PR template carrying the invariant checklist.

**Claude Code:**
- `.claude/settings.json`:
  - hooks: SessionStart → active stage; PostToolUse → `dart format` plus the pubspec denylist block;
  - permissions: an allowlist for read-only and test commands, force-push denied;
  - plugins: `dart-lsp@footnoted-tools`, `context7`, `commit-commands`, `pr-review-toolkit`.
- `.mcp.json`: the Dart MCP server.
- `.claude-plugin/marketplace.json`: this repo as the `footnoted-tools` marketplace, holding `dart-lsp`.
- Skills: `orchestrate-wave`, `run-session`, `plan-stage`, `invariant-review`.

## Verification (dev machine)

```
flutter doctor -v                       → Flutter ✓, Android toolchain ✓ (licences accepted); no device until the AVD booted
emulator -avd fn_api36 -no-window       → boot_completed=1 after ~95 s; `flutter devices` lists emulator-5554 (API 36)
flutter pub get (root)                  → workspace resolved
dart analyze                            → No issues found
dart format --set-exit-if-changed .     → 0 changed
dart test (geo, data, tool)             → +1, +1, +3 passed
flutter test (app)                      → +1 passed
dart tool/check_deps.dart               → 61 packages, none denylisted
post_edit hook, denylisted pubspec      → exit 2 with reason; .dart file → formatted
session_start hook                      → prints the Stage 01 row + Next line
claude plugin validate .                → Validation passed
claude mcp list                         → dart: pending approval (approve on the next `claude` start)
flutter build apk --debug               → first try FAILED: Gradle could not auto-install NDK 28.2.13676358, because the
                                          cmdline-tools 23 sdkmanager.bat splits "ndk;28.2…" at the semicolon
                                          ("Package ndk not found"). Installed it manually with sdkmanager "ndk/28.2.13676358";
                                          the rebuild is ✓ app-debug.apk (~8 min cold Gradle). AGP's own installer fetched
                                          build-tools 36 without trouble.
adb install + am start                  → com.example.footnoted/.MainActivity resumed on emulator-5554
```

**Known trap (dev machine):** pass Android SDK packages to `sdkmanager` in **slash form** (`platforms/android-36`, `ndk/<ver>`); the semicolon form is broken in cmdline-tools 23. When Gradle reports that sdkmanager "did not install" a component, install it by hand that way.

The first CI run is recorded in the stage README's *Current status*.

## Handover to the W1 kickoff

- Approve the `dart` MCP server and install the `dart-lsp` plugin when Claude Code prompts (the first `claude` start in this repo).
- No W1 seam exists yet: `spike/FORMAT.md` and the spike skeletons are the kickoff's to write.
