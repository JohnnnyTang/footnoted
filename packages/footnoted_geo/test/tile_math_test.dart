import 'dart:math' as math;

import 'package:footnoted_geo/footnoted_geo.dart';
import 'package:test/test.dart';

void main() {
  group('projection', () {
    test('equator and prime meridian sit on the world centre', () {
      expect(lonToTileX(0, 1), 1);
      expect(latToTileY(0, 1), 1);
      expect(lonToPixelX(0, 20), 1 << 27);
      expect(latToPixelY(0, 20), 1 << 27);
    });

    test('Paris is the well-known z10 tile (518, 352)', () {
      expect(lonToTileX(2.3522219, 10), 518);
      expect(latToTileY(48.856614, 10), 352);
    });

    test('lon/lat round-trips through tile coordinates', () {
      final rnd = math.Random(1);
      for (var i = 0; i < 1000; i++) {
        final lat = (rnd.nextDouble() * 2 - 1) * 85;
        final lon = (rnd.nextDouble() * 2 - 1) * 180;
        final x = lonToTileX(lon, 20);
        final y = latToTileY(lat, 20);
        final nw = tileToLatLng(x, y, 20);
        final se = tileToLatLng(x + 1, y + 1, 20);
        expect(lon, inInclusiveRange(nw.lon, se.lon));
        expect(lat, inInclusiveRange(se.lat, nw.lat));
      }
    });

    test('latitude is clamped to ±85.05112878°', () {
      final n = tilesPerAxis(20);
      expect(latToTileY(85.0511287, 20), 0);
      expect(latToTileY(89.9, 20), 0);
      expect(latToTileY(90, 20), 0);
      expect(latToTileY(-89.9, 20), n - 1);
      expect(latToTileY(-90, 20), n - 1);
      expect(latToTileY(84.5, 20), greaterThan(0));
      expect(tileToLatLng(0, 0, 20).lat, closeTo(maxMercatorLatitude, 1e-7));
    });

    test('longitude 180 wraps onto -180', () {
      expect(lonToTileX(180, 20), 0);
      expect(lonToTileX(-180, 20), 0);
      expect(lonToTileX(179.9999999, 20), tilesPerAxis(20) - 1);
      expect(normalizeLongitude(190), closeTo(-170, 1e-9));
      expect(normalizeLongitude(-190), closeTo(170, 1e-9));
    });

    test('levels outside 0..22 are rejected', () {
      expect(() => tilesPerAxis(23), throwsRangeError);
      expect(() => tilesPerAxis(-1), throwsRangeError);
    });
  });

  group('cell ground width', () {
    test('about 38.2 m at the equator, 19.1 m at 60°, 27 m at 45°', () {
      expect(groundResolutionMeters(0, 20), closeTo(38.2185, 1e-3));
      expect(groundResolutionMeters(60, 20), closeTo(19.1093, 1e-3));
      expect(groundResolutionMeters(45, 20), closeTo(27.0247, 1e-3));
      expect(groundResolutionMeters(0, 21), closeTo(19.1093, 1e-3));
    });

    test('a row width uses the row centre latitude', () {
      final y = latToTileY(60, 20);
      expect(rowWidthMeters(y, 20), closeTo(19.11, 0.01));
      expect(
        CellId.fromLatLng(const LatLng(60, 10)).widthMeters,
        closeTo(19.11, 0.01),
      );
    });
  });

  group('cell IDs (F01.1)', () {
    test('pack and unpack round-trip at z20 and z21', () {
      final rnd = math.Random(2);
      for (final level in [20, 21]) {
        final n = tilesPerAxis(level);
        for (var i = 0; i < 1000; i++) {
          final x = rnd.nextInt(n);
          final y = rnd.nextInt(n);
          final id = packCell(x, y, level);
          expect(cellX(id, level), x);
          expect(cellY(id, level), y);
        }
      }
    });

    test('z20 packing is (x << 20) | y', () {
      final id = CellId.fromTile(5, 7);
      expect(id.value, (5 << 20) | 7);
      expect(id.x, 5);
      expect(id.y, 7);
      expect(() => packCell(1 << 20, 0), throwsRangeError);
      expect(() => packCell(0, -1), throwsRangeError);
    });

    test('parent at level L shifts both axes', () {
      final paris = CellId.fromLatLng(const LatLng(48.856614, 2.3522219));
      expect(paris.parentAt(10), packCell(518, 352, 10));
      expect(paris.parentAt(20), paris.value);
      expect(paris.parentAt(0), 0);
      final z21 = packCell(2 * paris.x + 1, 2 * paris.y + 1, 21);
      expect(parentCell(z21, 20, 21), paris.value);
    });

    test('cell centre lies inside the cell', () {
      final id = CellId.fromLatLng(const LatLng(-33.8688, 151.2093));
      expect(CellId.fromLatLng(id.center), id);
    });
  });
}
