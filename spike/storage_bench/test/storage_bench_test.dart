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
  });

  testWidgets('app shell builds without autorun', (tester) async {
    await tester.pumpWidget(const SpikeApp(autorun: false));
    expect(find.text('storage_bench'), findsWidgets);
  });
}
