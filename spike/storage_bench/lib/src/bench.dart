import 'dart:io';

import 'package:path/path.dart' as p;

import 'dataset.dart';
import 'probe.dart';
import 'schema.dart';
import 'stores.dart';

class BenchOptions {
  const BenchOptions({
    this.layouts = Layout.values,
    this.drivers = defaultDrivers,
    this.cipherModes = const [true, false],
    this.levels = const [8, 12, 16, 20],
    this.rollupLevels = const [16, 12, 8],
    this.queryReps = 5,
    this.cacheKib,
  });

  final List<Layout> layouts;
  final List<Driver> drivers;

  /// Ignored modes: `true` is skipped when the loaded library has no cipher.
  final List<bool> cipherModes;

  /// Levels of the on-the-fly tile query (rolled up from z20 in the query).
  final List<int> levels;

  /// F01.3 `cell_rollups` levels, finest first: the first is built from the
  /// z20 cells, each later one from the level before it.
  final List<int> rollupLevels;
  final int queryReps;

  /// `PRAGMA cache_size` in KiB; null keeps the SQLite default (2,000 KiB).
  final int? cacheKib;
}

typedef Log = void Function(String line);

int _ms(Stopwatch sw) => sw.elapsedMicroseconds ~/ 1000;

double _median(List<int> us) {
  final s = [...us]..sort();
  return s[s.length ~/ 2] / 1000;
}

void _rm(String path) {
  for (final f in [path, '$path-wal', '$path-shm', '$path-journal']) {
    final file = File(f);
    if (file.existsSync()) file.deleteSync();
  }
}

/// The z10 tile with the most covered cells, and the z10 tile at the long
/// leg's middle cell.
Map<String, (int, int)> pickTiles(Dataset ds, List<int> union) {
  final hist = <int, int>{};
  for (final c in union) {
    final k = ((cellX(c) >> 10) << 10) | (cellY(c) >> 10);
    hist[k] = (hist[k] ?? 0) + 1;
  }
  final dense = hist.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  final mid = ds.longLeg.cells[ds.longLeg.cells.length ~/ 2];
  return {
    'densest': (dense >> 10, dense & 1023),
    'long_leg': (cellX(mid) >> 10, cellY(mid) >> 10),
  };
}

int expectedTileCells(List<int> union, TileRange t, int l) {
  final sh = 20 - l;
  final out = <int>{};
  for (final c in union) {
    final x = cellX(c), y = cellY(c);
    if (x < t.x0 || x > t.x1 || y < t.y0 || y > t.y1) continue;
    out.add(((x >> sh) << l) | (y >> sh));
  }
  return out.length;
}

/// Distinct level-[l] parents of [union]: the `cell_rollups` row count.
int expectedRollupRows(List<int> union, int l) {
  final sh = 20 - l;
  return {for (final c in union) ((cellX(c) >> sh) << l) | (cellY(c) >> sh)}
      .length;
}

/// True when the file starts with the plain SQLite header.
bool plainSqliteHeader(String path) {
  final f = File(path).openSync();
  try {
    return String.fromCharCodes(f.readSync(16)) == 'SQLite format 3\u0000';
  } finally {
    f.closeSync();
  }
}

Future<Map<String, Object?>> _timedQuery(
  Future<int> Function() run,
  int want,
  String what,
  int reps,
) async {
  final got = await run();
  if (got != want) throw StateError('$what: $got cells, want $want');
  final us = <int>[];
  for (var i = 0; i < reps; i++) {
    final sw = Stopwatch()..start();
    await run();
    us.add(sw.elapsedMicroseconds);
  }
  return {'median_ms': _median(us), 'cells': got};
}

/// Runs every configuration and returns the JSON-ready result. [workDir]
/// holds the throwaway database files.
Future<Map<String, Object?>> runBench(
  Dataset ds,
  String workDir, {
  BenchOptions opts = const BenchOptions(),
  Log log = print,
  Map<String, Object?> env = const {},
}) async {
  Directory(workDir).createSync(recursive: true);
  final info = probe(workDir);
  log('probe: $info');
  final cipherOk = info['cipher_available'] == true;

  final union = ds.union();
  final leg = ds.longLeg;
  final withoutLeg = Dataset(
    [
      for (final s in ds.segments)
        if (s.id != leg.id) s,
    ],
    longLegId: -1,
    source: '',
  ).union().length;
  final tiles = {
    for (final e in pickTiles(ds, union).entries)
      e.key: TileRange.z10(e.value.$1, e.value.$2),
  };
  final allLevels = {...opts.levels, ...opts.rollupLevels};
  final expected = {
    for (final e in tiles.entries)
      e.key: {
        for (final l in allLevels) '$l': expectedTileCells(union, e.value, l),
      },
  };
  final rollupRows = {
    for (final l in opts.rollupLevels) '$l': expectedRollupRows(union, l),
  };
  final dsInfo = {
    'source': ds.source,
    'segments': ds.segments.length,
    'rows_cell_segment': ds.rows,
    'unique_cells': union.length,
    'spans': ds.spanCount,
    'long_leg': {
      'id': leg.id,
      'label': leg.label,
      'rows': leg.cells.length,
      'spans': leg.spans().length,
    },
    'tiles_z10': {
      for (final e in pickTiles(ds, union).entries)
        e.key: [e.value.$1, e.value.$2],
    },
    'expected_tile_cells': expected,
    'expected_rollup_rows': rollupRows,
  };
  log('dataset: $dsInfo');

  final results = <Map<String, Object?>>[];
  for (final cipher in opts.cipherModes) {
    if (cipher && !cipherOk) {
      log('skip cipher=on: no SQLCipher in the loaded library');
      continue;
    }
    for (final layout in opts.layouts) {
      for (final driver in opts.drivers) {
        final tag = '${layout.label}/${driver.name}/cipher=$cipher';
        log('run $tag');
        final r = <String, Object?>{
          'layout': layout.label,
          'driver': driver.name,
          'cipher': cipher,
        };
        final legPath = p.join(workDir, 'leg.db');
        _rm(legPath);
        var st = await Store.open(
          driver,
          layout,
          legPath,
          cipher: cipher,
          cacheKib: opts.cacheKib,
        );
        var sw = Stopwatch()..start();
        await st.insert([leg]);
        r['leg_insert_ms'] = _ms(sw);
        await st.close();
        _rm(legPath);

        final path = p.join(workDir, 'full.db');
        _rm(path);
        st = await Store.open(
          driver,
          layout,
          path,
          cipher: cipher,
          cacheKib: opts.cacheKib,
        );
        sw = Stopwatch()..start();
        await st.insert(ds.segments);
        r['full_insert_ms'] = _ms(sw);
        r['cipher_version'] = await st.cipherVersion();
        if (cipher && (r['cipher_version'] as String).isEmpty) {
          throw StateError('$tag: no cipher_version on the store connection');
        }
        final rows = await st.count();
        final want = layout == Layout.cells ? ds.rows : ds.spanCount;
        if (rows != want) throw StateError('$tag: $rows rows, want $want');
        if (layout == Layout.spans && await st.statsCount() != union.length) {
          throw StateError('$tag: cell_stats count mismatch');
        }

        sw = Stopwatch()..start();
        await st.vacuum();
        r['vacuum_ms'] = _ms(sw);
        r['size_bytes'] = File(path).lengthSync();
        final wal = File('$path-wal');
        r['wal_bytes_after_checkpoint'] = wal.existsSync()
            ? wal.lengthSync()
            : 0;

        Future<int> pageBytes() async =>
            await st.scalar('PRAGMA page_count') *
            await st.scalar('PRAGMA page_size');
        if (opts.rollupLevels.isNotEmpty) {
          final before = await pageBytes();
          await st.exec(ddlRollups);
          final built = <String, Object?>{};
          int? finer;
          var total = 0;
          for (final l in opts.rollupLevels) {
            sw = Stopwatch()..start();
            await st.exec(
              finer == null
                  ? rollupFromLeavesSql(layout, l)
                  : rollupFromLevelSql(finer, l),
            );
            final ms = _ms(sw);
            total += ms;
            final n = await st.scalar(
              'SELECT count(*) FROM cell_rollups WHERE level = $l',
            );
            if (n != rollupRows['$l']) {
              throw StateError(
                '$tag rollup L$l: $n rows, want ${rollupRows['$l']}',
              );
            }
            built['$l'] = {'build_ms': ms, 'rows': n, 'from': finer ?? 20};
            finer = l;
          }
          r['rollups'] = {
            'levels': built,
            'build_ms_total': total,
            'bytes': await pageBytes() - before,
          };
        }

        final q = <String, Object?>{};
        for (final te in tiles.entries) {
          for (final viaStats
              in layout == Layout.spans ? [false, true] : [false]) {
            final key = viaStats ? '${te.key}/cell_stats' : te.key;
            q[key] = {
              for (final l in opts.levels)
                '$l': await _timedQuery(
                  () => st.tileCells(te.value, l, viaStats: viaStats),
                  expected[te.key]!['$l']!,
                  '$tag $key L$l',
                  opts.queryReps,
                ),
            };
          }
          if (opts.rollupLevels.isNotEmpty) {
            q['${te.key}/cell_rollups'] = {
              for (final l in opts.rollupLevels)
                '$l': await _timedQuery(
                  () => st.rollupTileCells(te.value, l),
                  expected[te.key]!['$l']!,
                  '$tag ${te.key}/cell_rollups L$l',
                  opts.queryReps,
                ),
            };
          }
        }
        r['tile_query'] = q;

        sw = Stopwatch()..start();
        await st.deleteSegment(leg.id);
        r['delete_leg_ms'] = _ms(sw);
        final after = await st.count();
        final wantAfter =
            want -
            (layout == Layout.cells ? leg.cells.length : leg.spans().length);
        if (after != wantAfter) {
          throw StateError('$tag: $after rows after delete, want $wantAfter');
        }
        if (layout == Layout.spans && await st.statsCount() != withoutLeg) {
          throw StateError('$tag: cell_stats wrong after delete');
        }
        await st.close();
        r['file_header_is_plain_sqlite'] = plainSqliteHeader(path);
        if (r['file_header_is_plain_sqlite'] == cipher) {
          throw StateError('$tag: file header does not match cipher=$cipher');
        }
        _rm(path);
        log('done $tag: $r');
        results.add(r);
      }
    }
  }
  return {
    'env': {
      ...env,
      'os': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'dart': Platform.version,
      'cpus': Platform.numberOfProcessors,
      'utc': DateTime.now().toUtc().toIso8601String(),
    },
    'sqlite': info,
    'pragmas': {
      'journal_mode': 'wal',
      'synchronous': 'NORMAL',
      'cache_size_kib': opts.cacheKib ?? 'default',
    },
    'dataset': dsInfo,
    'results': results,
  };
}
