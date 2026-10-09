# Stage 1 — Verification backlog

Rows are appended by the orchestrator at merge, from each session note's `## Backlog rows`. Sessions never edit this file. Close a row by striking it through and adding a line of evidence (a date, a command or link, the result).

## Environment / owner-action rows (`S01-E#`)

| ID | Row | Needed by | State |
| --- | --- | --- | --- |
| S01-E1 | The owner's **mid-range Android phone** connected over USB with debugging on. Record the model, Android version and RAM. | W2 (S01-20), W5 (S01-51) | open |
| S01-E2 | The owner's **Mac with Xcode + an older iPhone** (record the model and iOS version) for the iOS runbooks. Apple personal team signing is enough. | W2 (S01-21), W5 (S01-51) | open |
| S01-E3 | Owner confirmation of **D-007** (default buffer 100 m local, range 25 m – 2 km). | W3 kickoff | open |

## Verification rows (`S01-V###`)

| ID | Row | Raised by | Blocks | State |
| --- | --- | --- | --- | --- |
| S01-V001 | Cross-platform determinism of tracegen is unguarded (platform libm transcendental functions). Windows = Linux CI for seed 7 / 1 year; macOS unchecked. If hashes ever differ, round intermediates or use pure-Dart sin/cos. (was S01-V10a) | S01-10 | none today | open |
| S01-V002 | Dilation radius `ceil(buffer / w)` reveals up to one cell beyond the buffer (100 m → 108 m CDMX, 124 m Tokyo) and steps discontinuously with latitude. Rule at G1 (F01.6): ceil, round, or exact real-valued radius. Same decision as S01-V018. (was S01-V10b) | S01-10 | F01 freeze (G1) | open |
| S01-V003 | Near the poles the per-row disk uses the source row's width only; negligible below about 80°. S01-31 may use the target row's width. (was S01-V10c) | S01-10 | none | open |
| S01-V004 | Commute repetition dominates per-cell rows (4.9 M rows over 148 k home cells). Storage must be measured with the real `dataset.segcells.bin`, not single legs. (was S01-V10d) | S01-10 | G1(c) | open |
| ~~S01-V005~~ | ~~SQLCipher selection is workspace-wide: add `hooks: user_defines: sqlite3: source: sqlcipher` to the **root** `pubspec.yaml`, pin `sqlite3 ≥ 3.7.0`, record in the D-log. Owner ruling pending (W2 kickoff or G1). (was S01-V11a)~~ | S01-11 | in-repo cipher runs in S01-20; S01-32 | **closed 2026-10-09**: owner ruled; D-011; root `pubspec.yaml` set; in-workspace desktop probe `cipher_version` 4.19.0 community (W2 kickoff note) |
| S01-V006 | iOS SQLCipher: CI compile once S01-V005 lands, then the owner's on-device `cipher_version` / R\*Tree / header check (S01-21 runbook). (was S01-V11b) | S01-11 | G1(d) iOS evidence | open: **CI compile done 2026-10-09** (run 37933622249, `sqlcipher.framework` bundled, asserted in CI); the owner's on-device check remains |
| S01-V007 | Re-run `storage_bench` on S01-10's real dataset (`--segcells`) on the owner's Android phone, release mode. (was S01-V11c) | S01-11 | G1(c), G1(d) | open |
| S01-V008 | SQLCipher (BSD-3, binary attribution) and OpenSSL (Apache-2.0) notices on About/Licences; Flutter's `LicenseRegistry` does not list native libs. (was S01-V11d) | S01-11 | store submission | open |
| S01-V009 | Production logs must never include tile/cell indices of user coverage (a densest tile is a coarse home location). (was S01-V11e) | S01-11 | — | open |
| S01-V010 | Build-time network: the `sqlite3` hook downloads prebuilt binaries from `github.com` (sha256-pinned). Accept, mirror (`url_pattern`) or build from source; list it as a build-time host in `docs/network-hosts.md`. (was S01-V11f) | S01-11 | — | open |
| S01-V011 | Exit criterion 2 on the owner's Android phone per `spike/render_bench/MEASURE.md` §4 with S01-10's `dataset.cells.bin`: (a) holes d6 on GLSurfaceView/VD, plus (b) and TextureView controls. Re-point `panWaypoints` at S01-10's home city (Mexico City) and corridor first. (was S01-V12a) | S01-12 | G1(e), exit 2 | open |
| S01-V012 | Invariant 1: `maplibre_gl`'s Android module pulls `play-services-base`/`-location`. Exclude `com.google.android.gms` in `app/android` (S01-33) and add a CI guard on the release runtime classpath (S01-42); `check_deps` only sees Dart. (was S01-V12b) | S01-12 | exit 12 | open |
| S01-V013 | CI Android job needs Java 21 once `app/` depends on `maplibre_gl` ≥ 0.27.1; record JDK 21 next to D-010. (was S01-V12c) | S01-12 | exit 5 | open |
| S01-V014 | MapLibre merges `ACCESS_FINE/COARSE_LOCATION` into the manifest: declare deliberately or `tools:node="remove"` until recording; the rationale rule applies. (was S01-V12d) | S01-12 | — | open |
| S01-V015 | Windows dev box: `kotlin.incremental=false` in `app/android/gradle.properties` (pub cache on C:, repo on D:), or move the pub cache. (was S01-V12e) | S01-12 | — | open |
| S01-V016 | iOS exit criterion 2: the owner runs `MEASURE.md` §6 (Instruments → Animation Hitches) on the older iPhone, both strategies. (was S01-V12f) | S01-12 | exit 2 | open |
| S01-V017 | Fog design inputs for S01-41: level = tile zoom + 6, +1 tile padding, rebuild only when leaving the padded set, per-tile cache, persisted rollups (on-the-fly rollup of 1 M cells = 3 s on the emulator). (was S01-V12g) | S01-12 | — | open |
| S01-V018 | F01.6 / handoff "Revealing cells" step 3: replace the `ceil` radius with the exact radius (S01-13 boundary-error table). Same decision as S01-V002. (was S01-V13a) | S01-13 | F01 freeze (G1) | open |
| S01-V019 | Quadkey area statistics must weight each row by cell area (∝ cos² lat); raw cell counts are not comparable across latitudes. (was S01-V13b) | S01-13 | none | open |
| S01-V020 | Optional: H3 compute timings on real hardware (`spike/h3_eval` release on the owner's phone, nothing else in the foreground). Drop if G1 rules quadkey. (was S01-V13c) | S01-13 | none | open |
| S01-V021 | iOS H3 is CI-compile only. If H3 is ever adopted: on-device run, linked size, SwiftPM support. (was S01-V13d) | S01-13 | none unless H3 | open |
