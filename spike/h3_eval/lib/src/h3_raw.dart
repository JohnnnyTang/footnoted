import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'geo.dart';

// Minimal direct bindings to the libh3 that h3_flutter bundles, returning
// int64 lists. h3_flutter's public API returns BigInt per cell (it is
// web-compatible); measuring both separates the C cost from the wrapper cost.

final class _LatLngC extends Struct {
  @Double()
  external double lat;
  @Double()
  external double lng;
}

final class _GeoLoopC extends Struct {
  @Int()
  external int numVerts;
  external Pointer<_LatLngC> verts;
}

final class _GeoPolygonC extends Struct {
  external _GeoLoopC geoloop;
  @Int()
  external int numHoles;
  external Pointer<_GeoLoopC> holes;
}

typedef _MaxSizeC = Uint32 Function(
  Pointer<_GeoPolygonC>,
  Int,
  Uint32,
  Pointer<Int64>,
);
typedef _MaxSizeD = int Function(
  Pointer<_GeoPolygonC>,
  int,
  int,
  Pointer<Int64>,
);
typedef _PolyfillC = Uint32 Function(
  Pointer<_GeoPolygonC>,
  Int,
  Uint32,
  Pointer<Uint64>,
);
typedef _PolyfillD = int Function(
  Pointer<_GeoPolygonC>,
  int,
  int,
  Pointer<Uint64>,
);
typedef _CompactC = Uint32 Function(Pointer<Uint64>, Pointer<Uint64>, Int64);
typedef _CompactD = int Function(Pointer<Uint64>, Pointer<Uint64>, int);
typedef _ToCellC = Uint32 Function(Pointer<_LatLngC>, Int, Pointer<Uint64>);
typedef _ToCellD = int Function(Pointer<_LatLngC>, int, Pointer<Uint64>);

class H3Raw {
  H3Raw._(DynamicLibrary lib)
    : _maxSize = lib.lookupFunction<_MaxSizeC, _MaxSizeD>(
        'maxPolygonToCellsSize',
      ),
      _polyfill = lib.lookupFunction<_PolyfillC, _PolyfillD>('polygonToCells'),
      _compact = lib.lookupFunction<_CompactC, _CompactD>('compactCells'),
      _toCell = lib.lookupFunction<_ToCellC, _ToCellD>('latLngToCell');

  factory H3Raw.open() => H3Raw._(
    Platform.isWindows
        ? DynamicLibrary.open('h3.dll')
        : Platform.isAndroid || Platform.isLinux
        ? DynamicLibrary.open('libh3.so')
        : DynamicLibrary.process(),
  );

  final _MaxSizeD _maxSize;
  final _PolyfillD _polyfill;
  final _CompactD _compact;
  final _ToCellD _toCell;

  static double _rad(double d) => d * math.pi / 180;

  /// Cells whose centre lies inside [ring]; zeros removed, unsorted.
  Int64List polygonToCells(List<LatLng> ring, int res) {
    return using((arena) {
      final verts = arena<_LatLngC>(ring.length);
      for (var i = 0; i < ring.length; i++) {
        verts[i]
          ..lat = _rad(ring[i].lat)
          ..lng = _rad(ring[i].lon);
      }
      final poly = arena<_GeoPolygonC>();
      poly.ref.geoloop.numVerts = ring.length;
      poly.ref.geoloop.verts = verts;
      poly.ref.numHoles = 0;
      poly.ref.holes = nullptr;
      final size = arena<Int64>();
      _check(_maxSize(poly, res, 0, size), 'maxPolygonToCellsSize');
      final out = arena<Uint64>(size.value);
      for (var i = 0; i < size.value; i++) {
        out[i] = 0;
      }
      _check(_polyfill(poly, res, 0, out), 'polygonToCells');
      final view = out.cast<Int64>().asTypedList(size.value);
      var n = 0;
      for (var i = 0; i < view.length; i++) {
        if (view[i] != 0) n++;
      }
      final result = Int64List(n);
      var k = 0;
      for (var i = 0; i < view.length; i++) {
        if (view[i] != 0) result[k++] = view[i];
      }
      return result;
    });
  }

  Int64List compactCells(Int64List cells) {
    final input = calloc<Uint64>(cells.length);
    final out = calloc<Uint64>(cells.length);
    try {
      input.cast<Int64>().asTypedList(cells.length).setAll(0, cells);
      _check(_compact(input, out, cells.length), 'compactCells');
      final view = out.cast<Int64>().asTypedList(cells.length);
      return Int64List.fromList([
        for (final c in view)
          if (c != 0) c,
      ]);
    } finally {
      calloc
        ..free(input)
        ..free(out);
    }
  }

  int latLngToCell(LatLng p, int res) {
    return using((arena) {
      final ll = arena<_LatLngC>()
        ..ref.lat = _rad(p.lat)
        ..ref.lng = _rad(p.lon);
      final out = arena<Uint64>();
      _check(_toCell(ll, res, out), 'latLngToCell');
      return out.cast<Int64>().value;
    });
  }

  static void _check(int err, String fn) {
    if (err != 0) throw StateError('$fn: H3 error $err');
  }
}
