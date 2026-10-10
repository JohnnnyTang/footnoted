import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:footnoted_geo/footnoted_geo.dart' hide SegmentKind;
import 'package:test/test.dart';
import 'package:tracegen/tracegen.dart';

Int64List _readInt64s(File f) {
  final bytes = f.readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  return Int64List.fromList([
    for (var i = 0; i < bytes.length; i += 8) data.getInt64(i, Endian.little),
  ]);
}

void main() {
  group('Rng', () {
    test('is deterministic per seed', () {
      final a = Rng(42), b = Rng(42), c = Rng(43);
      final sa = [for (var i = 0; i < 5; i++) a.nextInt64()];
      expect([for (var i = 0; i < 5; i++) b.nextInt64()], sa);
      expect([for (var i = 0; i < 5; i++) c.nextInt64()], isNot(sa));
      for (var i = 0; i < 1000; i++) {
        expect(a.nextDouble(), inInclusiveRange(0, 1));
      }
    });
  });

  group('five-year scenario', () {
    final segments = Scenario(seed: 42, years: 5).generate();

    test('segments are numbered and ordered in time without overlap', () {
      var lastTs = -1;
      for (var i = 0; i < segments.length; i++) {
        final s = segments[i];
        expect(s.id, i);
        expect(s.startTs, greaterThan(lastTs));
        for (final p in s.points) {
          expect(p.ts, greaterThanOrEqualTo(lastTs));
          expect(p.lon, inInclusiveRange(-180, 180));
          lastTs = p.ts;
        }
      }
      expect(
        segments.last.endTs,
        lessThan(DateTime.utc(2026).millisecondsSinceEpoch + 86400000),
      );
    });

    test('has three road trips with a single leg of 1,000 km or more', () {
      final road = segments.where((s) => s.category == 'road').toList();
      double length(Segment s) {
        var d = 0.0;
        for (var i = 1; i < s.points.length; i++) {
          d += greatCircleMeters(s.points[i - 1].latLng, s.points[i].latLng);
        }
        return d;
      }

      final perTrip = <String, double>{};
      for (final s in road) {
        final year = s.label.split(' ').last.substring(0, 4);
        perTrip[year] = (perTrip[year] ?? 0) + length(s);
      }
      expect(perTrip, hasLength(3));
      for (final km in perTrip.values) {
        expect(km, greaterThan(1000e3));
      }
      expect(
        road.map(length).reduce((a, b) => a > b ? a : b),
        greaterThan(1e6),
      );
      for (final s in road) {
        expect(s.kind, SegmentKind.transit);
        expect(s.bufferM, 500);
        expect(s.reveal, Reveal.line);
      }
    });

    test('has at least ten flights, one across the antimeridian', () {
      final flights = segments.where((s) => s.category == 'flight').toList();
      expect(flights.length, greaterThanOrEqualTo(10));
      for (final f in flights) {
        expect(f.mode, JoinMode.greatCircle);
        expect(f.reveal, Reveal.endpoints);
      }
      final pacific = flights.singleWhere((f) => f.label.contains('HND → HNL'));
      final lons = pacific.points.map((p) => p.lon);
      expect(lons.any((l) => l > 170), isTrue);
      expect(lons.any((l) => l < -170), isTrue);
      expect(lons.every((l) => l > 139 || l < -157), isTrue);
    });

    test('has stays in three foreign cities', () {
      for (final city in ['Madrid', 'Tokyo', 'Helsinki']) {
        expect(
          segments.where((s) => s.label.startsWith('$city: walk')).length,
          greaterThanOrEqualTo(5),
          reason: city,
        );
      }
    });

    test('home points are sampled every 150-400 m', () {
      final gaps = <double>[];
      for (final s in segments.where((s) => s.category == 'home')) {
        for (var i = 1; i < s.points.length - 1; i++) {
          gaps.add(
            greatCircleMeters(s.points[i - 1].latLng, s.points[i].latLng),
          );
        }
      }
      gaps.sort();
      expect(gaps[gaps.length ~/ 2], inInclusiveRange(200, 350));
      expect(gaps[gaps.length ~/ 10], greaterThan(120));
      expect(gaps[gaps.length * 9 ~/ 10], lessThan(450));
    });
  });

  group('files (one year, z20 and z21)', () {
    late Directory dir;
    setUpAll(() {
      dir = Directory.systemTemp.createTempSync('tracegen_test');
    });
    tearDownAll(() => dir.deleteSync(recursive: true));

    test('match spike/FORMAT.md and are byte-identical across runs', () {
      final a = generate(
        seed: 7,
        years: 1,
        outDir: '${dir.path}/a',
        levels: [20, 21],
      );
      final b = generate(
        seed: 7,
        years: 1,
        outDir: '${dir.path}/b',
        levels: [20, 21],
      );
      expect(
        a.replaceAll(RegExp(r'\(\d+ ms.*\)'), ''),
        b.replaceAll(RegExp(r'\(\d+ ms.*\)'), ''),
      );
      for (final name in [
        'dataset.trace.ndjson',
        'dataset.cells.bin',
        'dataset.segcells.bin',
        'dataset.z21.cells.bin',
        'dataset.z21.segcells.bin',
      ]) {
        final x = File('${dir.path}/a/$name').readAsBytesSync();
        final y = File('${dir.path}/b/$name').readAsBytesSync();
        expect(sha256.convert(x), sha256.convert(y), reason: name);
      }
      // Printed so that CI (Linux) can be compared with the Windows run.
      print('seed 7, 1 year: $a');

      // Trace: headers before their points, points sorted by ts.
      final lines = File('${dir.path}/a/dataset.trace.ndjson')
          .readAsLinesSync();
      var current = -1;
      var lastTs = -1;
      final headers = <int>[];
      for (final line in lines) {
        final j = jsonDecode(line) as Map<String, Object?>;
        if (j.containsKey('segment')) {
          current = j['segment'] as int;
          headers.add(current);
          expect(j.keys, [
            'segment',
            'kind',
            'mode',
            'buffer_m',
            'reveal',
            'label',
          ]);
        } else {
          expect(j.keys, ['ts', 'lat', 'lon', 'acc', 'src', 'seg']);
          expect(j['seg'], current);
          expect(j['ts'] as int, greaterThanOrEqualTo(lastTs));
          lastTs = j['ts'] as int;
        }
      }
      expect(headers, List.generate(headers.length, (i) => i));

      for (final (base, level) in [('dataset', 20), ('dataset.z21', 21)]) {
        final cellsFile = File('${dir.path}/a/$base.cells.bin');
        final cells = _readInt64s(cellsFile);
        for (var i = 1; i < cells.length; i++) {
          expect(cells[i], greaterThan(cells[i - 1]));
        }
        final meta = jsonDecode(
          File('${dir.path}/a/$base.cells.json').readAsStringSync(),
        ) as Map;
        expect(meta['count'], cells.length);
        expect(meta['level'], level);
        expect(meta['source_trace'], 'dataset.trace.ndjson');
        expect(
          meta['sha256'],
          sha256.convert(cellsFile.readAsBytesSync()).toString(),
        );

        // Segcells: every segment in order; union equals the cells dump.
        final seg = _readInt64s(File('${dir.path}/a/$base.segcells.bin'));
        final union = <int>{};
        var i = 0, expectedId = 0, rows = 0;
        while (i < seg.length) {
          expect(seg[i], expectedId++);
          final n = seg[i + 1];
          final record = seg.sublist(i + 2, i + 2 + n);
          for (var k = 1; k < record.length; k++) {
            expect(record[k], greaterThan(record[k - 1]));
          }
          union.addAll(record);
          rows += n;
          i += 2 + n;
        }
        expect(expectedId, headers.length);
        expect(union.length, cells.length);
        expect(union.containsAll(cells), isTrue);
        final segMeta = jsonDecode(
          File('${dir.path}/a/$base.segcells.json').readAsStringSync(),
        ) as Map;
        expect(segMeta['rows'], rows);
        expect(segMeta['segments'], headers.length);
      }
    });
  });

  test('countSpans counts horizontal runs', () {
    final ids = [
      packCell(1, 5),
      packCell(2, 5),
      packCell(3, 5),
      packCell(5, 5),
      packCell(2, 6),
    ]..sort();
    expect(countSpans(ids, 20), 3);
    expect(countSpans([], 20), 0);
  });

  test('CLI rejects a missing --out', () {
    run(['--seed', '1']);
    expect(exitCode, 64);
    exitCode = 0;
  });
}
