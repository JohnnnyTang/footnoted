# FootNoted

FootNoted records a person's life footprints on a dark, misted world map. Every place you have been lights up, so using it feels like exploring the world and opening up new sights under your own feet.

- **Import mode:** pick photos and videos; their GPS and timestamps become routes that reveal the map.
- **Live recording:** record a walk or a trip, with photos and notes along the way.
- **Private by design:** everything stays on your device, in an encrypted database. No ads, no analytics, no data sales, ever.

> **Status:** early development. Stage 1 (performance spike + foundation) is planned and starting. See [`stages/`](stages/README.md).

## Stack

Flutter · MapLibre GL (`maplibre_gl`) · OpenFreeMap / Protomaps tiles · SQLite (Drift on SQLCipher) · a Web Mercator cell grid for explored area. Everything is open source, with no backend. The reasoning is in [`docs/HANDOFF.md`](docs/HANDOFF.md).

## Repository layout

```
app/                       Flutter app (Android + iOS)
packages/footnoted_geo/    pure-Dart cell-grid math
packages/footnoted_data/   encrypted database, schema, reveal pipeline
tool/                      invariant guards (CI) and Claude Code hooks
docs/                      product brief, decision log, doc index
stages/                    stage → wave → session plans and notes
```

## Getting started

Requirements: **Flutter 3.47.7** (Dart 3.13.5), the Android SDK (platform 36), and for iOS a Mac with Xcode.

```bash
flutter pub get                     # at the repo root (pub workspace)
dart analyze
(cd packages/footnoted_geo && dart test)
(cd packages/footnoted_data && dart test)
(cd app && flutter test)
(cd app && flutter run)             # emulator or device
dart tool/check_deps.dart           # open-source / no-tracking dependency guard
```

## Working with coding agents

The project is built with coding agents following a **stage → wave → session** process. Start with [`AGENTS.md`](AGENTS.md). Claude Code picks up the project hooks, skills, the Dart MCP server and the `dart-lsp` plugin from `.claude/`, `.mcp.json` and `.claude-plugin/` automatically.

## Map data attribution

Map data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), available under the ODbL. Tiles by [OpenFreeMap](https://openfreemap.org) © [OpenMapTiles](https://openmaptiles.org).

## Licence

[Mozilla Public License 2.0](LICENSE).
