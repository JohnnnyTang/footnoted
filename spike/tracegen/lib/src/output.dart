import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:footnoted_geo/footnoted_geo.dart';

import 'model.dart';

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

/// Writes bytes to a file while hashing them.
class HashingWriter {
  HashingWriter(String path)
    : _file = File(path).openSync(mode: FileMode.write) {
    _hash = sha256.startChunkedConversion(_digest);
  }

  final RandomAccessFile _file;
  final _digest = _DigestSink();
  late final ByteConversionSink _hash;
  final _buf = ByteData(1 << 20);
  var _len = 0;
  int bytesWritten = 0;

  void _flush() {
    if (_len == 0) return;
    final view = _buf.buffer.asUint8List(0, _len);
    _file.writeFromSync(view);
    _hash.add(Uint8List.fromList(view));
    bytesWritten += _len;
    _len = 0;
  }

  void int64(int v) {
    if (_len + 8 > _buf.lengthInBytes) _flush();
    _buf.setInt64(_len, v, Endian.little);
    _len += 8;
  }

  void int64s(List<int> values) {
    for (final v in values) {
      int64(v);
    }
  }

  void bytes(List<int> data) {
    _flush();
    _file.writeFromSync(data);
    _hash.add(data);
    bytesWritten += data.length;
  }

  /// Closes the file and returns the lowercase hex SHA-256 of its bytes.
  String close() {
    _flush();
    _file.closeSync();
    _hash.close();
    return _digest.value.toString();
  }
}

num _jsonNumber(double v) => v == v.roundToDouble() ? v.round() : v;

/// Writes the trace (spike/FORMAT.md §2); returns its SHA-256.
String writeTrace(String path, List<Segment> segments) {
  final w = HashingWriter(path);
  final sb = StringBuffer();
  void flush() {
    w.bytes(utf8.encode(sb.toString()));
    sb.clear();
  }

  for (final s in segments) {
    sb.writeln(
      jsonEncode({
        'segment': s.id,
        'kind': s.kind.name,
        'mode': s.mode == JoinMode.greatCircle ? 'great_circle' : 'straight',
        'buffer_m': _jsonNumber(s.bufferM),
        'reveal': s.reveal.name,
        'label': s.label,
      }),
    );
    for (final p in s.points) {
      sb.writeln(
        jsonEncode({
          'ts': p.ts,
          'lat': p.lat,
          'lon': p.lon,
          'acc': p.acc,
          'src': p.media ? 'media' : 'gps',
          'seg': s.id,
        }),
      );
    }
    if (sb.length > 1 << 20) flush();
  }
  flush();
  return w.close();
}

void writeJson(String path, Map<String, Object?> json, {bool pretty = false}) {
  final text = pretty
      ? const JsonEncoder.withIndent('  ').convert(json)
      : jsonEncode(json);
  File(path).writeAsStringSync('$text\n');
}
