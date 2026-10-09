import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

import 'dataset.dart';
import 'drift_db.dart';
import 'schema.dart';

enum Driver { raw, drift }

/// A z10 tile in z20 cell coordinates (inclusive bounds).
class TileRange {
  TileRange.z10(int tx, int ty)
    : x0 = tx << 10,
      x1 = ((tx + 1) << 10) - 1,
      y0 = ty << 10,
      y1 = ((ty + 1) << 10) - 1;

  final int x0, x1, y0, y1;
}

/// A fixed 256-bit test key, applied as a raw key (no PBKDF2), which is how a
/// keystore-held key is applied in production. Never logged.
const _testKeyHex =
    '2b7e151628aed2a6abf7158809cf4f3c762e7151f4a7c5c6b1a0dbe3b1e6c1f0';

void applyPragmas(s3.Database db, {required bool cipher}) {
  if (cipher) {
    db.execute("PRAGMA key = \"x'$_testKeyHex'\"");
    final v = db.select('PRAGMA cipher_version');
    if (v.isEmpty || '${v.first.values.first}'.isEmpty) {
      throw StateError('SQLCipher requested but cipher_version is empty');
    }
  }
  final jm = db.select('PRAGMA journal_mode = WAL').first.values.first;
  if ('$jm'.toLowerCase() != 'wal') {
    throw StateError('journal_mode is $jm, expected wal');
  }
  db.execute('PRAGMA synchronous = NORMAL');
}

abstract class Store {
  static Future<Store> open(
    Driver d,
    Layout layout,
    String path, {
    required bool cipher,
  }) async {
    final s = d == Driver.raw
        ? RawStore(layout, path, cipher)
        : DriftStore(layout, path, cipher);
    await s.init();
    return s;
  }

  Future<void> init();
  Future<void> insert(List<Segment> segs);
  Future<void> deleteSegment(int id);

  /// Number of distinct level-[l] cells covered in [t].
  Future<int> tileCells(TileRange t, int l, {bool viaStats = false});
  Future<int> count();

  /// Rows in B's `cell_stats`.
  Future<int> statsCount();
  Future<void> vacuum();
  Future<void> close();

  /// `PRAGMA cipher_version` on this store's own connection ('' if none).
  Future<String> cipherVersion();

  /// Runs one statement (the rollup builds). Drift runs it through
  /// `customStatement`, as a Drift-based app would for set-based SQL.
  Future<void> exec(String sql);

  /// Number of level-[l] `cell_rollups` rows in [t].
  Future<int> rollupTileCells(TileRange t, int l);

  /// The first column of the first row of [sql], as an int.
  Future<int> scalar(String sql);
}

List<int> _rollupTileArgs(TileRange t, int l) {
  final sh = 20 - l;
  final mask = (1 << l) - 1;
  return [
    l,
    (t.x0 >> sh) << l,
    ((t.x1 >> sh) << l) | mask,
    mask,
    t.y0 >> sh,
    t.y1 >> sh,
  ];
}

Map<int, int> _cellCounts(List<Segment> segs) {
  final m = <int, int>{};
  for (final s in segs) {
    for (final c in s.cells) {
      m[c] = (m[c] ?? 0) + 1;
    }
  }
  return m;
}

List<int> _expand(Iterable<(int, int, int)> spans) => [
  for (final (y, a, b) in spans)
    for (var x = a; x <= b; x++) packCell(x, y),
];

int _rollupSpans(Iterable<(int, int, int)> rows, TileRange t, int l) {
  final sh = 20 - l;
  final out = <int>{};
  for (final (y, a, b) in rows) {
    final xa = (a < t.x0 ? t.x0 : a) >> sh;
    final xb = (b > t.x1 ? t.x1 : b) >> sh;
    for (var x = xa; x <= xb; x++) {
      out.add((x << l) | (y >> sh));
    }
  }
  return out.length;
}

List<int> _rollupArgs(TileRange t, int l) => [
  20 - l,
  t.x0 << 20,
  (t.x1 << 20) | ((1 << 20) - 1),
  t.y0,
  t.y1,
];

class RawStore implements Store {
  RawStore(this.layout, this.path, this.cipher);
  final Layout layout;
  final String path;
  final bool cipher;
  late final s3.Database db;

  @override
  Future<void> init() async {
    db = s3.sqlite3.open(path);
    applyPragmas(db, cipher: cipher);
    if (db.select('SELECT 1 FROM sqlite_master LIMIT 1').isEmpty) {
      for (final s in ddlFor(layout)) {
        db.execute(s);
      }
    }
  }

  void _tx(void Function() body) {
    db.execute('BEGIN');
    try {
      body();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<void> insert(List<Segment> segs) async {
    _tx(() {
      if (layout == Layout.cells) {
        final st = db.prepare(insertCellSql);
        for (final s in segs) {
          for (final c in s.cells) {
            st.execute([c, s.id]);
          }
        }
        st.close();
      } else {
        final sp = db.prepare(insertSpanSql);
        for (final s in segs) {
          for (final r in s.spans()) {
            sp.execute([s.id, r.y, r.xStart, r.xEnd]);
          }
        }
        sp.close();
        final up = db.prepare(upsertStatSql);
        _cellCounts(segs).forEach((c, n) => up.execute([c, n]));
        up.close();
      }
    });
  }

  @override
  Future<void> deleteSegment(int id) async {
    _tx(() {
      if (layout == Layout.cells) {
        db.execute('DELETE FROM cell_coverage WHERE segment_id = ?', [id]);
        return;
      }
      final rows = db.select(
        'SELECT y, x_start, x_end FROM coverage_spans WHERE segment_id = ?',
        [id],
      );
      final cells = _expand(
        rows.map(
          (r) => (r['y'] as int, r['x_start'] as int, r['x_end'] as int),
        ),
      );
      final dec = db.prepare(decStatSql);
      final drop = db.prepare(dropStatSql);
      for (final c in cells) {
        dec.execute([c]);
        drop.execute([c]);
      }
      dec.close();
      drop.close();
      db.execute('DELETE FROM coverage_spans WHERE segment_id = ?', [id]);
    });
  }

  @override
  Future<int> tileCells(TileRange t, int l, {bool viaStats = false}) async {
    if (layout == Layout.cells || viaStats) {
      final table = layout == Layout.cells ? 'cell_coverage' : 'cell_stats';
      return db.select(rollupSql(table), _rollupArgs(t, l)).length;
    }
    final rows = db.select(spansInTileSql, [t.y0, t.y1, t.x0, t.x1]);
    return _rollupSpans(
      rows.map((r) => (r['y'] as int, r['x_start'] as int, r['x_end'] as int)),
      t,
      l,
    );
  }

  @override
  Future<int> count() async {
    final table = layout == Layout.cells ? 'cell_coverage' : 'coverage_spans';
    return db.select('SELECT count(*) AS n FROM $table').first['n'] as int;
  }

  @override
  Future<int> statsCount() async =>
      db.select('SELECT count(*) AS n FROM cell_stats').first['n'] as int;

  @override
  Future<void> vacuum() async {
    db.execute('VACUUM');
    db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  @override
  Future<void> close() async => db.close();

  @override
  Future<String> cipherVersion() async {
    final v = db.select('PRAGMA cipher_version');
    return v.isEmpty ? '' : '${v.first.values.first}';
  }

  @override
  Future<void> exec(String sql) async => db.execute(sql);

  @override
  Future<int> rollupTileCells(TileRange t, int l) async =>
      db.select(rollupTileSql, _rollupTileArgs(t, l)).length;

  @override
  Future<int> scalar(String sql) async =>
      _asInt(db.select(sql).first.values.first);
}

// Some pragmas (page_count under SQLCipher) come back as text.
int _asInt(Object? v) => v is int ? v : int.parse('$v');

class DriftStore implements Store {
  DriftStore(this.layout, this.path, this.cipher);
  final Layout layout;
  final String path;
  final bool cipher;
  late final BenchDb db;

  static const _chunk = 20000;

  @override
  Future<void> init() async {
    db = BenchDb(
      NativeDatabase(
        File(path),
        setup: (raw) => applyPragmas(raw, cipher: cipher),
      ),
      ddlFor(layout),
    );
    await db.customSelect('SELECT 1').get();
  }

  @override
  Future<void> insert(List<Segment> segs) async {
    await db.transaction(() async {
      if (layout == Layout.cells) {
        var pending = <CellCoverageCompanion>[];
        Future<void> flush() async {
          final rows = pending;
          pending = [];
          await db.batch((b) => b.insertAll(db.cellCoverage, rows));
        }

        for (final s in segs) {
          for (final c in s.cells) {
            pending.add(
              CellCoverageCompanion.insert(cellId: c, segmentId: s.id),
            );
            if (pending.length >= _chunk) await flush();
          }
        }
        await flush();
        return;
      }
      var spans = <CoverageSpansCompanion>[];
      Future<void> flushSpans() async {
        final rows = spans;
        spans = [];
        await db.batch((b) => b.insertAll(db.coverageSpans, rows));
      }

      for (final s in segs) {
        for (final r in s.spans()) {
          spans.add(
            CoverageSpansCompanion.insert(
              segmentId: s.id,
              y: r.y,
              xStart: r.xStart,
              xEnd: r.xEnd,
            ),
          );
          if (spans.length >= _chunk) await flushSpans();
        }
      }
      await flushSpans();
      final counts = _cellCounts(segs).entries.toList();
      for (var i = 0; i < counts.length; i += _chunk) {
        final part = counts.skip(i).take(_chunk);
        await db.batch(
          (b) => b.insertAll(
            db.cellStats,
            [
              for (final e in part)
                CellStatsCompanion.insert(cellId: e.key, n: e.value),
            ],
            onConflict: DoUpdate<$CellStatsTable, CellStat>.withExcluded(
              (old, excluded) =>
                  CellStatsCompanion.custom(n: old.n + excluded.n),
            ),
          ),
        );
      }
    });
  }

  @override
  Future<void> deleteSegment(int id) async {
    await db.transaction(() async {
      if (layout == Layout.cells) {
        await (db.delete(
          db.cellCoverage,
        )..where((t) => t.segmentId.equals(id))).go();
        return;
      }
      final rows = await (db.select(
        db.coverageSpans,
      )..where((t) => t.segmentId.equals(id))).get();
      final cells = _expand(rows.map((r) => (r.y, r.xStart, r.xEnd)));
      final st = db.cellStats;
      for (var i = 0; i < cells.length; i += _chunk) {
        final part = cells.skip(i).take(_chunk);
        await db.batch((b) {
          for (final c in part) {
            b.update(
              st,
              CellStatsCompanion.custom(n: st.n - const Constant(1)),
              where: (t) => t.cellId.equals(c),
            );
            b.deleteWhere(
              st,
              (t) => t.cellId.equals(c) & t.n.isSmallerOrEqualValue(0),
            );
          }
        });
      }
      await (db.delete(
        db.coverageSpans,
      )..where((t) => t.segmentId.equals(id))).go();
    });
  }

  @override
  Future<int> tileCells(TileRange t, int l, {bool viaStats = false}) async {
    if (layout == Layout.cells || viaStats) {
      final TableInfo table = layout == Layout.cells
          ? db.cellCoverage
          : db.cellStats;
      final rows = await db
          .customSelect(
            rollupSql(table.actualTableName),
            variables: [for (final a in _rollupArgs(t, l)) Variable.withInt(a)],
            readsFrom: {table},
          )
          .get();
      return rows.length;
    }
    final sp = db.coverageSpans;
    final rows =
        await (db.select(sp)..where(
              (r) =>
                  r.y.isBetweenValues(t.y0, t.y1) &
                  r.xEnd.isBiggerOrEqualValue(t.x0) &
                  r.xStart.isSmallerOrEqualValue(t.x1),
            ))
            .get();
    return _rollupSpans(rows.map((r) => (r.y, r.xStart, r.xEnd)), t, l);
  }

  @override
  Future<int> count() async {
    final table = layout == Layout.cells
        ? db.cellCoverage
        : db.coverageSpans as TableInfo;
    final c = countAll();
    final q = db.selectOnly(table)..addColumns([c]);
    return (await q.getSingle()).read(c)!;
  }

  @override
  Future<int> statsCount() async {
    final c = countAll();
    final q = db.selectOnly(db.cellStats)..addColumns([c]);
    return (await q.getSingle()).read(c)!;
  }

  @override
  Future<void> vacuum() async {
    await db.customStatement('VACUUM');
    await db.customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
  }

  @override
  Future<void> close() => db.close();

  Future<List<Object?>> _first(String sql) async => [
    for (final r in await db.customSelect(sql).get()) r.data.values.first,
  ];

  @override
  Future<String> cipherVersion() async {
    final v = await _first('PRAGMA cipher_version');
    return v.isEmpty ? '' : '${v.first}';
  }

  @override
  Future<void> exec(String sql) => db.customStatement(sql);

  @override
  Future<int> rollupTileCells(TileRange t, int l) async {
    final rows = await db
        .customSelect(
          rollupTileSql,
          variables: [
            for (final a in _rollupTileArgs(t, l)) Variable.withInt(a),
          ],
        )
        .get();
    return rows.length;
  }

  @override
  Future<int> scalar(String sql) async => _asInt((await _first(sql)).first);
}
