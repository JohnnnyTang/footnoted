import 'package:test/test.dart';

import '../guards/denylist.dart';

void main() {
  test('denies proprietary, analytics and retired SDKs', () {
    for (final name in [
      'google_maps_flutter',
      'mapbox_maps_flutter',
      'firebase_analytics',
      'flutter_background_geolocation',
      'ffmpeg_kit_flutter_min',
      'google_mobile_ads',
    ]) {
      expect(denialReason(name), isNotNull, reason: name);
    }
  });

  test('allows the planned open-source stack', () {
    for (final name in [
      'maplibre_gl',
      'drift',
      'sqlite3',
      'geolocator',
      'flutter_foreground_task',
      'flutter_secure_storage',
      'native_exif',
    ]) {
      expect(denialReason(name), isNull, reason: name);
    }
  });

  test('reads declared dependencies from a pubspec', () {
    const pubspec = '''
name: x
dependencies:
  flutter:
    sdk: flutter
  maplibre_gl: ^0.22.0
dev_dependencies:
  firebase_analytics: any
flutter:
  uses-material-design: true
''';
    expect(declaredDependencies(pubspec), [
      'flutter',
      'maplibre_gl',
      'firebase_analytics',
    ]);
  });
}
