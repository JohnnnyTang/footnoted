# Stage 3 — Live recording (M3) · KICKOFF

**State:** `KICKOFF`. Planned into waves only after Stage 2 exits.
**Milestone:** M3, per [`HANDOFF.md`](../../docs/HANDOFF.md#live-recording-mode) and "Platform and permissions".
**Entry conditions:** Stage 2 exited (the route layer, segmentation and markers exist); **real OEM test devices available** (at least one Xiaomi or Huawei and one Samsung, plus a recent and an older iPhone, per the handoff).

## Objective

Explicit start / pause / stop recording that keeps working with the screen off and survives process death, sampling about every few hundred metres, with photos and text notes attached along the route. **Exit (handoff): a two-hour walk on a real phone records fully with the screen off, on at least one aggressive OEM device.**

## Scope

**In:**
- A `recording_sessions` lifecycle (start / pause / resume / stop) and its UI.
- **Android:** a foreground service of type `location` (`geolocator` + `flutter_foreground_task`) started while the app is visible; `ACCESS_FINE_LOCATION` + `FOREGROUND_SERVICE_LOCATION`; a persistent notification; **no `ACCESS_BACKGROUND_LOCATION`** (CI guard from Stage 1).
- **iOS:** When-In-Use + `allowsBackgroundLocationUpdates` during the session; the blue indicator.
- **Crash-safe persistence:** every fix is written to SQLite as it arrives, never buffered only in memory; a session survives an app kill / OS kill, and on relaunch it resumes or closes cleanly.
- Sampling policy: a displacement filter plus a time floor tuned to "a fix every few hundred metres" (dense tracking is explicitly **not** a goal).
- Live route drawing and live reveal (incremental, per new fix).
- Photos: the in-app camera, or library photos matched by timestamp to the session → thumbnail markers.
- Text notes at the current location, alone or with photos (`notes`, `note_media`).
- A guided "allow background activity" screen for Xiaomi/Huawei/Oppo/Samsung battery managers.
- **Fallback:** if the free stack fails the OEM test, evaluate Tracelet (Apache 2.0), per the handoff.

**Out:** passive/always-on mode (M7), and the `Always` authorisation.

## Open questions to settle at planning

- The exact sampling parameters per platform (displacement filter, accuracy, the iOS `activityType`).
- Session auto-pause on stillness?
- Notes UX: on-map only, or also a timeline?

## Likely shape

- **W1:** the Android foreground service + persistence ‖ iOS background updates (owner-verified) ‖ session UI + state machine ‖ notes data + UI.
- **W2:** camera + library time-matching ‖ live reveal performance ‖ the OEM guidance screens.
- **W3 (verification, device-heavy):** the two-hour walk matrix — screen off, app swiped away, low-battery mode, after a reboot — on the OEM devices.

## Risks

OEM process killers; the iOS background budget; battery drain; Play policy review of the foreground service type (needs a declaration even without background location).
