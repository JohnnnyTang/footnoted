import 'dart:math' as math;

import 'types.dart';

/// Latitude limit of the square Web Mercator world.
const double maxMercatorLatitude = 85.05112878;

/// The cell level of F01.1.
const int cellLevel = 20;

/// Highest level whose integer pixel math fits in an int64 (2^(2·(L+8)) < 2^63).
const int maxCellLevel = 22;

/// Pixels per tile edge; pixel coordinates at level L span `256 << L`.
const int tilePixelShift = 8;

const double earthRadiusMeters = 6378137.0;
const double earthCircumferenceMeters = 2 * math.pi * earthRadiusMeters;

double clampLatitude(double lat) =>
    lat.clamp(-maxMercatorLatitude, maxMercatorLatitude).toDouble();

/// Wraps a longitude into [-180, 180).
double normalizeLongitude(double lon) {
  if (lon >= -180 && lon < 180) return lon;
  final wrapped = (lon + 180) % 360;
  return wrapped - 180;
}

/// Normalised Mercator x in [0, 1) (0 at -180°, growing east).
double lonToMercatorX(double lon) => (normalizeLongitude(lon) + 180) / 360;

/// Normalised Mercator y in [0, 1] (0 at the north edge, growing south).
double latToMercatorY(double lat) {
  final phi = clampLatitude(lat) * math.pi / 180;
  final y = 0.5 - math.log(math.tan(math.pi / 4 + phi / 2)) / (2 * math.pi);
  return y.clamp(0.0, 1.0).toDouble();
}

double mercatorXToLon(double x) => x * 360 - 180;

double mercatorYToLat(double y) {
  final n = math.pi * (1 - 2 * y);
  return math.atan((math.exp(n) - math.exp(-n)) / 2) * 180 / math.pi;
}

void _checkLevel(int level) =>
    RangeError.checkValueInInterval(level, 0, maxCellLevel, 'level');

/// Number of tiles along one axis at [level].
int tilesPerAxis(int level) {
  _checkLevel(level);
  return 1 << level;
}

/// Number of pixels along one axis at [level] (256-px tiles).
int worldPixels(int level) => tilesPerAxis(level) << tilePixelShift;

int _toInt(double unit, int size) {
  final v = (unit * size).floor();
  if (v < 0) return 0;
  if (v >= size) return size - 1;
  return v;
}

/// Integer pixel x at [level]; longitude 180 wraps to pixel 0.
int lonToPixelX(double lon, int level) {
  final size = worldPixels(level);
  return (lonToMercatorX(lon) * size).floor() % size;
}

/// Integer pixel y at [level], clamped to the world.
int latToPixelY(double lat, int level) =>
    _toInt(latToMercatorY(lat), worldPixels(level));

int lonToTileX(double lon, int level) =>
    lonToPixelX(lon, level) >> tilePixelShift;

int latToTileY(double lat, int level) =>
    latToPixelY(lat, level) >> tilePixelShift;

/// The north-west corner of tile `(x, y)`; fractional tile coordinates give
/// points inside the tile (for example `x + 0.5, y + 0.5` is the centre).
LatLng tileToLatLng(num x, num y, int level) {
  final n = tilesPerAxis(level);
  return LatLng(mercatorYToLat(y / n), mercatorXToLon(x / n));
}

/// Ground width (and height: Mercator is conformal) of a tile at [lat].
double groundResolutionMeters(double lat, int level) =>
    earthCircumferenceMeters *
    math.cos(clampLatitude(lat) * math.pi / 180) /
    tilesPerAxis(level);

/// Ground width of the cells in row [y] at [level], measured at the row's
/// centre latitude.
double rowWidthMeters(int y, int level) => groundResolutionMeters(
  mercatorYToLat((y + 0.5) / tilesPerAxis(level)),
  level,
);

/// Packs tile `(x, y)` at [level] as `(x << level) | y` (F01.1 at level 20).
int packCell(int x, int y, [int level = cellLevel]) {
  final n = tilesPerAxis(level);
  RangeError.checkValueInInterval(x, 0, n - 1, 'x');
  RangeError.checkValueInInterval(y, 0, n - 1, 'y');
  return (x << level) | y;
}

int cellX(int id, [int level = cellLevel]) => id >> level;

int cellY(int id, [int level = cellLevel]) => id & ((1 << level) - 1);

/// The ancestor of [id] (at [level]) at [parentLevel], packed at [parentLevel].
int parentCell(int id, int parentLevel, [int level = cellLevel]) {
  RangeError.checkValueInInterval(parentLevel, 0, level, 'parentLevel');
  final shift = level - parentLevel;
  return ((cellX(id, level) >> shift) << parentLevel) |
      (cellY(id, level) >> shift);
}
