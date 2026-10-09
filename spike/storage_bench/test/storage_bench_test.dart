import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:storage_bench/main.dart';
import 'package:storage_bench/storage_bench.dart';

void main() {
  test('spansOf merges consecutive x per row', () {
    final cells = Int64List.fromList(
      [
        packCell(5, 1),
        packCell(6, 1),
        packCell(7, 1),
        packCell(9, 1),
        packCell(5, 2),
      ]..sort(),
    );
    final spans = spansOf(cells);
    expect(
      [for (final s in spans) (s.y, s.xStart, s.xEnd)],
      [(1, 5, 7), (1, 9, 9), (2, 5, 5)],
    );
  });

  test('a point reveals a disk of about pi r^2 cells', () {
    final cells = rasterise([const LatLon(0, 0)], 500);
    final r = 500 / cellWidthM(0);
    expect(cells.length, closeTo(3.14159 * r * r, 0.1 * 3.14159 * r * r));
    expect(cells, orderedEquals([...cells]..sort()));
  });

  test('stand-in is deterministic and dumps round-trip', () {
    final a = buildStandIn(const StandInSpec.tiny());
    final b = buildStandIn(const StandInSpec.tiny());
    expect(a.rows, b.rows);
    expect(a.union(), b.union());
    final dir = Directory.systemTemp.createTempSync('sb_dumps');
    addTearDown(() => dir.deleteSync(recursive: true));
    writeDumps(a, dir.path, 'x');
    final back = readSegcells(
      p.join(dir.path, 'x.segcells.bin'),
      longLegId: a.longLegId,
    );
    expect(back.rows, a.rows);
    expect(back.union(), a.union());
    expect(
      File(p.join(dir.path, 'x.cells.bin')).lengthSync(),
      a.union().length * 8,
    );
  });

  test('every layout x driver agrees on a tiny dataset', () async {
    final dir = Directory.systemTemp.createTempSync('sb_bench');
    addTearDown(() => dir.deleteSync(recursive: true));
    final r = await runBench(
      buildStandIn(const StandInSpec.tiny()),
      dir.path,
      opts: const BenchOptions(queryReps: 1),
      log: (_) {},
    );
    final results = r['results']! as List;
    final cipher = (r['sqlite']! as Map)['cipher_available'] == true;
    expect(results, hasLength(cipher ? 8 : 4));
    final rtree = (r['sqlite']! as Map)['rtree_query_ids'];
    expect(rtree, [1]);
    for (final row in results.cast<Map<String, Object?>>()) {
      final on = row['cipher'] == true;
      expect(row['file_header_is_plain_sqlite'], !on);
      if (on) expect(row['cipher_version'], isNotEmpty);
      final rollups = row['rollups']! as Map;
      expect((rollups['levels'] as Map).keys, ['16', '12', '8']);
      expect(rollups['bytes'] as int, greaterThan(0));
      final q = row['tile_query']! as Map;
      expect(q.keys, containsAll(['densest/cell_rollups', 'long_leg']));
      expect((q['densest'] as Map).keys, ['8', '12', '16', '20']);
    }
  });

  test('rollups cascade and the rollup tile query match by hand', () async {
    final dir = Directory.systemTemp.createTempSync('sb_roll');
    addTearDown(() => dir.deleteSync(recursive: true));
    // Two z20 cells under one z16 parent, a third under a neighbouring z16
    // parent; all three share one z12 and one z8 parent. Tile z10 (0x3A5,
    // 0x1C7) contains them.
    final x = 0x3A5 << 10, y = 0x1C7 << 10;
    final cells = Int64List.fromList(
      [packCell(x, y), packCell(x + 1, y), packCell(x + 16, y + 3)]..sort(),
    );
    final st = await Store.open(
      Driver.raw,
      Layout.spans,
      p.join(dir.path, 'r.db'),
      cipher: false,
    );
    await st.insert([Segment(1, cells), Segment(2, cells.sublist(0, 1))]);
    await st.exec(ddlRollups);
    await st.exec(rollupFromLeavesSql(Layout.spans, 16));
    await st.exec(rollupFromLevelSql(16, 12));
    await st.exec(rollupFromLevelSql(12, 8));
    Future<List<int>> level(int l) async => [
      await st.scalar('SELECT count(*) FROM cell_rollups WHERE level = $l'),
      await st.scalar('SELECT sum(n) FROM cell_rollups WHERE level = $l'),
    ];
    expect(await level(16), [2, 3]);
    expect(await level(12), [1, 3]);
    expect(await level(8), [1, 3]);
    final tile = TileRange.z10(0x3A5, 0x1C7);
    expect(await st.rollupTileCells(tile, 16), 2);
    expect(await st.rollupTileCells(tile, 8), 1);
    expect(await st.rollupTileCells(TileRange.z10(0x3A6, 0x1C7), 16), 0);
    await st.close();
  });

  testWidgets('app shell builds without autorun', (tester) async {
    await tester.pumpWidget(const SpikeApp(autorun: false));
    expect(find.text('storage_bench'), findsWidgets);
  });
}
