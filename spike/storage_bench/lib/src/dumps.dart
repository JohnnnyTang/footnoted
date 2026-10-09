import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'dataset.dart';

// Reads and writes the FORMAT.md section 3 and 4 dumps.

Uint8List _int64Bytes(List<int> values) {
  final b = ByteData(values.length * 8);
  for (var i = 0; i < values.length; i++) {
    b.setInt64(i * 8, values[i], Endian.little);
  }
  return b.buffer.asUint8List();
}

void writeDumps(Dataset ds, String dir, String basename) {
  Directory(dir).createSync(recursive: true);
  final seg = BytesBuilder(copy: false);
  final sorted = [...ds.segments]..sort((a, b) => a.id.compareTo(b.id));
  for (final s in sorted) {
    seg.add(_int64Bytes([s.id, s.cells.length]));
    seg.add(_int64Bytes(s.cells));
  }
  final segBytes = seg.takeBytes();
  File(p.join(dir, '$basename.segcells.bin')).writeAsBytesSync(segBytes);
  File(p.join(dir, '$basename.segcells.json')).writeAsStringSync(
    jsonEncode({
      'segments': sorted.length,
      'rows': ds.rows,
      'level': level,
      'source_trace': null,
      'sha256': sha256.convert(segBytes).toString(),
    }),
  );
  final cellBytes = _int64Bytes(ds.union());
  File(p.join(dir, '$basename.cells.bin')).writeAsBytesSync(cellBytes);
  File(p.join(dir, '$basename.cells.json')).writeAsStringSync(
    jsonEncode({
      'count': cellBytes.length ~/ 8,
      'level': level,
      'buffer_m': null,
      'source_trace': null,
      'sha256': sha256.convert(cellBytes).toString(),
    }),
  );
}

/// Loads a `*.segcells.bin`. The long leg is the segment with the most rows
/// unless [longLegId] is given.
Dataset readSegcells(String path, {int? longLegId}) {
  final bytes = File(path).readAsBytesSync();
  final b = ByteData.sublistView(bytes);
  final segs = <Segment>[];
  var o = 0;
  while (o < bytes.length) {
    final id = b.getInt64(o, Endian.little);
    final n = b.getInt64(o + 8, Endian.little);
    o += 16;
    final cells = Int64List(n);
    for (var i = 0; i < n; i++) {
      cells[i] = b.getInt64(o + i * 8, Endian.little);
    }
    o += n * 8;
    segs.add(Segment(id, cells));
  }
  final leg =
      longLegId ??
      segs.reduce((a, c) => c.cells.length > a.cells.length ? c : a).id;
  return Dataset(segs, longLegId: leg, source: p.basename(path));
}
