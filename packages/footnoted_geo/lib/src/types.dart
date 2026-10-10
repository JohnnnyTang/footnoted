// Frozen W3 seam (Stage 1 W3 kickoff). Changes go through the orchestrator.
import 'tile_math.dart';

class LatLng {
  const LatLng(this.lat, this.lon);

  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) =>
      other is LatLng && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'LatLng($lat, $lon)';
}

/// A level-20 cell ID (F01.1). Other levels use the functions in tile_math.
extension type const CellId(int value) {
  CellId.fromTile(int x, int y) : value = packCell(x, y);

  CellId.fromLatLng(LatLng p)
    : value = packCell(
        lonToTileX(p.lon, cellLevel),
        latToTileY(p.lat, cellLevel),
      );

  int get x => cellX(value);
  int get y => cellY(value);

  /// The ancestor at [level], packed with shift [level].
  int parentAt(int level) => parentCell(value, level);

  LatLng get center => tileToLatLng(x + 0.5, y + 0.5, cellLevel);

  double get widthMeters => rowWidthMeters(y, cellLevel);
}

/// A Web Mercator tile; [z] is also the cell level of `packCell(x, y, z)`.
class TileId {
  TileId(this.z, this.x, this.y) {
    final n = tilesPerAxis(z);
    RangeError.checkValueInInterval(x, 0, n - 1, 'x');
    RangeError.checkValueInInterval(y, 0, n - 1, 'y');
  }

  final int z;
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is TileId && other.z == z && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(z, x, y);

  @override
  String toString() => 'TileId($z/$x/$y)';
}

/// `segments.connection_mode`; [dbValue] is the stored text.
enum ConnectionMode {
  straight('straight'),
  greatCircle('great_circle'),
  road('road'),
  none('none');

  const ConnectionMode(this.dbValue);

  final String dbValue;

  static ConnectionMode fromDb(String value) =>
      values.firstWhere((m) => m.dbValue == value);
}

/// `segments.kind`; [dbValue] is the stored text.
enum SegmentKind {
  local('local'),
  transit('transit');

  const SegmentKind(this.dbValue);

  final String dbValue;

  static SegmentKind fromDb(String value) =>
      values.firstWhere((k) => k.dbValue == value);
}

/// D-018: the default buffer of a `local` segment, and the user range.
/// A `transit` leg reveals its endpoints only (finalised in Stage 4).
const double defaultLocalBufferMeters = 100;
const double minBufferMeters = 25;
const double maxBufferMeters = 2000;
