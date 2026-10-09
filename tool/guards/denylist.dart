// Invariants 1 and 10 (docs/HANDOFF.md): no proprietary map/location SDKs, no
// ads or analytics that can see location, no retired FFmpegKit.
// Dependency-free on purpose: the Claude Code hook imports it by relative path.

final List<(RegExp, String)> deniedPackages = [
  (
    RegExp(r'^google_maps_flutter'),
    'proprietary Google Maps SDK (invariant 1)',
  ),
  (RegExp(r'^(mapbox|flutter_mapbox)'), 'proprietary Mapbox SDK (invariant 1)'),
  (
    RegExp(r'^apple_maps_flutter$'),
    'proprietary Apple MapKit wrapper (invariant 1)',
  ),
  (
    RegExp(r'^(here_sdk|huawei_map|huawei_location)'),
    'proprietary map/location SDK (invariant 1)',
  ),
  (
    RegExp(r'^flutter_background_geolocation$'),
    'paid plugin, rejected in the handoff (invariant 1)',
  ),
  (
    RegExp(r'^ffmpeg_kit'),
    'FFmpegKit was retired in 2025; use platform channels',
  ),
  (
    RegExp(r'^firebase_'),
    'Google SDK that can see app data (invariants 1, 10)',
  ),
  (RegExp(r'analytics'), 'analytics SDK (invariant 10)'),
  (RegExp(r'^(google_mobile_ads|.*_ads)$'), 'ads SDK (invariant 10)'),
  (
    RegExp(r'^(mixpanel|amplitude|appsflyer|posthog|segment|branch|adjust)'),
    'tracking SDK (invariant 10)',
  ),
  (RegExp(r'^facebook_'), 'tracking SDK (invariant 10)'),
];

/// Returns the reason [package] is denied, or null if it is allowed.
String? denialReason(String package) {
  for (final (pattern, reason) in deniedPackages) {
    if (pattern.hasMatch(package)) return reason;
  }
  return null;
}

/// Direct dependency names declared in a pubspec.yaml, by line scan (no YAML
/// package needed). Covers dependencies, dev_dependencies, dependency_overrides.
List<String> declaredDependencies(String pubspecText) {
  final names = <String>[];
  var inDeps = false;
  for (final line in pubspecText.split(RegExp(r'\r?\n'))) {
    if (RegExp(r'^\S').hasMatch(line)) {
      inDeps = RegExp(r'^(dependencies|dev_dependencies|dependency_overrides):')
          .hasMatch(line);
      continue;
    }
    if (!inDeps) continue;
    final m = RegExp(r'^  ([A-Za-z0-9_]+):').firstMatch(line);
    if (m != null) names.add(m.group(1)!);
  }
  return names;
}
