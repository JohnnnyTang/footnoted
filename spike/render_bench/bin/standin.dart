// Writes the stand-in dump in FORMAT.md §3 form:
//   dart run bin/standin.dart [--out out]
// produces <out>/standin.cells.bin and <out>/standin.cells.json.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:render_bench/src/cells.dart';
import 'package:render_bench/src/standin.dart';

void main(List<String> args) {
  final i = args.indexOf('--out');
  final out = Directory(i >= 0 ? args[i + 1] : 'out')
    ..createSync(recursive: true);
  final sw = Stopwatch()..start();
  final cells = generateStandIn();
  final ms = sw.elapsedMilliseconds;
  final bytes = encodeCellsBin(cells);
  File('${out.path}/standin.cells.bin').writeAsBytesSync(bytes);
  final meta = {
    'count': cells.length,
    'level': maxLevel,
    'buffer_m': null,
    'source_trace': null,
    'sha256': sha256.convert(bytes).toString(),
  };
  File('${out.path}/standin.cells.json').writeAsStringSync(jsonEncode(meta));
  stdout.writeln('${jsonEncode(meta)} generated in $ms ms');
}
