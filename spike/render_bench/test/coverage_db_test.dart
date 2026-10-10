import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:render_bench/src/cells.dart';
import 'package:render_bench/src/coverage_db.dart';
import 'package:render_bench/src/coverage_source.dart';
import 'package:render_bench/src/fog.dart';
import 'package:sqlite3/sqlite3.dart';

/// Overlapping segments of short horizontal runs around the z10 tile
/// (229, 455), including its bottom row and the next tiles over.
List<SegRecord> _segments() {
  final rnd = math.Random(42);
  const x0 = (229 << 10) - 40, y0 = (455 << 10) - 40, span = 1024 + 80;
  final out = <SegRecord>[];
  List<int>? previous;
  for (var s = 0; s < 6; s++) {
    final cells = <int>{
      // Segment 3 re-traverses half of segment 2, as a commute would.
      if (s == 3) ...previous!.take(previous.length ~/ 2),
      // The bottom row of the tile and the first row below it.
      if (s == 0)
        for (var x = 229 << 10; x < (229 << 10) + 64; x++) ...[
          packCell(x, (456 << 10) - 1, 20),
          packCell(x, 456 << 10, 20),
        ],
    };
    for (var r = 0; r < 300; r++) {
      final x = x0 + rnd.nextInt(span), y = y0 + rnd.nextInt(span);
      for (var k = 0; k < 1 + rnd.nextInt(12); k++) {
        cells.add(packCell(x + k, y, 20));
      }
    }
    final sorted = cells.toList()..sort();
    previous = sorted;
    out.add((id: s * 7, cells: Int64List.fromList(sorted)));
  }
  out.add((id: 99, cells: Int64List(0)));
  return out;
}

Int64List _union(List<SegRecord> segs) {
  final all = <int>{for (final s in segs) ...s.cells}.toList()..sort();
  return Int64List.fromList(all);
}

const _tiles = [
  (z: 10, x: 229, y: 455, level: 16),
  (z: 10, x: 229, y: 455, level: 20),
  (z: 10, x: 228, y: 455, level: 16),
  (z: 10, x: 229, y: 456, level: 17),
  (z: 12, x: 229 * 4 + 3, y: 455 * 4 + 3, level: 18),
  (z: 8, x: 57, y: 113, level: 14),
  (z: 5, x: 7, y: 14, level: 11),
  (z: 10, x: 0, y: 0, level: 16),
];

void main() {
  late Directory dir;
  late String segPath;
  late List<SegRecord> segs;
  late CoverageIndex index;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('rb_db');
    segs = _segments();
    segPath = '${dir.path}/t.segcells.bin';
    File(segPath).writeAsBytesSync(encodeSegcellsBin(segs));
    index = CoverageIndex.fromZ20(_union(segs));
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('segcells round-trip and spans cover exactly the cells', () {
    final back = readSegcellsBin(File(segPath).readAsBytesSync());
    expect([for (final r in back) r.id], [for (final r in segs) r.id]);
    for (var i = 0; i < segs.length; i++) {
      expect(back[i].cells, segs[i].cells);
      final fromSpans = <int>{
        for (final (y, a, b) in spansOf(segs[i].cells))
          for (var x = a; x <= b; x++) packCell(x, y, 20),
      };
      expect(fromSpans, segs[i].cells.toSet());
    }
  });

  for (final layout in Layout.values) {
    test('layout ${layout.label}: the tile query equals the in-memory '
        'rollup, through SQLCipher', () async {
      final path = '${dir.path}/c_${layout.label}.db';
      final build = buildCoverageDb(
        segcellsPath: segPath,
        dbPath: path,
        layout: layout,
      );
      expect(build['z20_cells'], index.count(20));
      final header = File(path).openSync()..setPositionSync(0);
      final magic = header.readSync(16);
      header.closeSync();
      expect(
        utf8.decode(magic, allowMalformed: true),
        isNot(startsWith('SQLite format 3')),
      );

      final db = CoverageDb.open(path, layout);
      final info = db.info();
      expect(info['cipher_version'], isNotEmpty);
      expect(info['journal_mode'], 'wal');
      final rows = segs.fold<int>(0, (a, s) => a + s.cells.length);
      expect(
        info['rows'],
        layout == Layout.cells ? rows : build['coverage_spans_rows'],
      );
      for (final t in _tiles) {
        expect(
          db.tileColumns(t.z, t.x, t.y, t.level),
          index.tileColumns(t.z, t.x, t.y, t.level),
          reason: '$t',
        );
      }
      db.close();

      // The worker-isolate source returns the same columns.
      final source = await DbSource.open(path, layout);
      expect(source.info['cipher_version'], info['cipher_version']);
      final got = await source.columns(_tiles);
      for (var i = 0; i < _tiles.length; i++) {
        final t = _tiles[i];
        expect(got.columns[i], index.tileColumns(t.z, t.x, t.y, t.level));
      }
      expect(got.queryMs, greaterThanOrEqualTo(0));

      // And the fog built from it is the in-memory fog.
      const tiles = [(z: 10, x: 229, y: 455), (z: 10, x: 228, y: 456)];
      for (final s in FogStrategy.values) {
        final a = await FogBuilder(source).build(s, tiles, FogStats());
        final b = await FogBuilder(MemorySource(index))
            .build(s, tiles, FogStats());
        expect(jsonEncode(a), jsonEncode(b));
      }
      await source.close();
    });
  }

  test('ensureCoverageDb reuses a matching build and rebuilds on change', () {
    final path = '${dir.path}/e.db';
    final first = ensureCoverageDb(
      segcellsPath: segPath,
      dbPath: path,
      layout: Layout.spans,
    );
    expect(first['reused'], false);
    final again = ensureCoverageDb(
      segcellsPath: segPath,
      dbPath: path,
      layout: Layout.spans,
    );
    expect(again['reused'], true);
    expect(again['z20_cells'], first['z20_cells']);
    final forced = ensureCoverageDb(
      segcellsPath: segPath,
      dbPath: path,
      layout: Layout.spans,
      rebuild: true,
    );
    expect(forced['reused'], false);
    File(segPath).setLastModifiedSync(DateTime(2020));
    final changed = ensureCoverageDb(
      segcellsPath: segPath,
      dbPath: path,
      layout: Layout.spans,
    );
    expect(changed['reused'], false);
  });

  test('a missing SQLCipher key is not silently a plain database', () {
    final path = '${dir.path}/k.db';
    buildCoverageDb(segcellsPath: segPath, dbPath: path, layout: Layout.spans);
    final plain = sqlite3.open(path);
    expect(
      () => plain.select('SELECT count(*) FROM coverage_spans'),
      throwsA(anything),
    );
    plain.close();
  });
}
