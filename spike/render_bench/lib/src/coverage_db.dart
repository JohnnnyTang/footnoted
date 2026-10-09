import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'cells.dart';

// The fog's coverage store (S01-20a2): a keyed SQLCipher database built once
// from `dataset.segcells.bin` (FORMAT.md §4). The DDL and the tile-query SQL
// are copied from spike/storage_bench/lib/src/schema.dart at 3473a2d, so the
// fog reads exactly what S01-11/S01-20a1 measure; the package is not imported.

enum Layout {
  /// A: one row per (cell, segment).
  cells('A'),

  /// B: run-length spans per (segment, row) plus derived per-cell counts.
  spans('B');

  const Layout(this.label);
  final String label;

  static Layout parse(String? s) =>
      s?.toUpperCase() == 'A' ? Layout.cells : Layout.spans;
}

const ddlA = [
  'CREATE TABLE cell_coverage (cell_id INTEGER NOT NULL, '
      'segment_id INTEGER NOT NULL, PRIMARY KEY (cell_id, segment_id)) '
      'WITHOUT ROWID',
  'CREATE INDEX cell_coverage_segment ON cell_coverage (segment_id)',
];

const ddlB = [
  'CREATE TABLE coverage_spans (segment_id INTEGER NOT NULL, '
      'y INTEGER NOT NULL, x_start INTEGER NOT NULL, x_end INTEGER NOT NULL, '
      'PRIMARY KEY (segment_id, y, x_start)) WITHOUT ROWID',
  'CREATE INDEX coverage_spans_yx ON coverage_spans (y, x_start)',
  'CREATE TABLE cell_stats (cell_id INTEGER NOT NULL PRIMARY KEY, '
      'n INTEGER NOT NULL) WITHOUT ROWID',
];

const int _mask20 = (1 << 20) - 1;

/// Distinct level-L cells in a z20 ID range, rolled up in SQL (layout A).
const rollupSqlA =
    'SELECT DISTINCT (cell_id >> 20) >> ?1 AS x, (cell_id & $_mask20) >> ?1 '
    'AS y FROM cell_coverage WHERE cell_id BETWEEN ?2 AND ?3 '
    'AND (cell_id & $_mask20) BETWEEN ?4 AND ?5';

/// Spans crossing a z20 rectangle (layout B's reader path).
const spansInTileSql =
    'SELECT y, x_start, x_end FROM coverage_spans '
    'WHERE y BETWEEN ?1 AND ?2 AND x_end >= ?3 AND x_start <= ?4';

const _insertCellSql =
    'INSERT INTO cell_coverage (cell_id, segment_id) VALUES (?, ?)';
const _insertSpanSql =
    'INSERT INTO coverage_spans (segment_id, y, x_start, x_end) '
    'VALUES (?, ?, ?, ?)';
const _insertStatSql = 'INSERT INTO cell_stats (cell_id, n) VALUES (?, ?)';

/// A fixed 256-bit test key applied as a raw key (no PBKDF2), as a
/// keystore-held key is in production. Never logged.
const _testKeyHex =
    '2b7e151628aed2a6abf7158809cf4f3c762e7151f4a7c5c6b1a0dbe3b1e6c1f0';

Database _open(String path) {
  final db = sqlite3.open(path);
  db.execute("PRAGMA key = \"x'$_testKeyHex'\"");
  final v = db.select('PRAGMA cipher_version');
  if (v.isEmpty || '${v.first.values.first}'.isEmpty) {
    db.close();
    throw StateError('SQLCipher is not linked: cipher_version is empty');
  }
  final jm = db.select('PRAGMA journal_mode = WAL').first.values.first;
  if ('$jm'.toLowerCase() != 'wal') {
    db.close();
    throw StateError('journal_mode is $jm, expected wal');
  }
  db.execute('PRAGMA synchronous = NORMAL');
  return db;
}

/// One FORMAT.md §4 record: segment id and its sorted, unique z20 cells.
typedef SegRecord = ({int id, Int64List cells});

List<SegRecord> readSegcellsBin(Uint8List bytes) {
  final b = ByteData.sublistView(bytes);
  final out = <SegRecord>[];
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
    out.add((id: id, cells: cells));
  }
  return out;
}

Uint8List encodeSegcellsBin(List<SegRecord> records) {
  final n = records.fold<int>(0, (a, r) => a + 2 + r.cells.length);
  final b = ByteData(n * 8);
  var o = 0;
  void put(int v) {
    b.setInt64(o, v, Endian.little);
    o += 8;
  }

  for (final r in records) {
    put(r.id);
    put(r.cells.length);
    r.cells.forEach(put);
  }
  return b.buffer.asUint8List();
}

/// Row runs `(y, x_start, x_end)` (inclusive) of one segment's z20 cells,
/// ordered by (y, x_start): the order of layout B's primary key.
List<(int, int, int)> spansOf(Int64List cells) {
  final byRow = Int64List(cells.length);
  for (var i = 0; i < cells.length; i++) {
    final id = cells[i];
    byRow[i] = (cellY(id, maxLevel) << maxLevel) | cellX(id, maxLevel);
  }
  byRow.sort();
  final out = <(int, int, int)>[];
  var i = 0;
  while (i < byRow.length) {
    final y = byRow[i] >> maxLevel;
    final x0 = byRow[i] & _mask20;
    var x1 = x0;
    var j = i + 1;
    while (j < byRow.length &&
        byRow[j] >> maxLevel == y &&
        (byRow[j] & _mask20) == x1 + 1) {
      x1++;
      j++;
    }
    out.add((y, x0, x1));
    i = j;
  }
  return out;
}

void _tx(Database db, void Function() body) {
  db.execute('BEGIN');
  try {
    body();
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

void _deleteDb(String path) {
  for (final s in ['', '-wal', '-shm', '-journal']) {
    final f = File('$path$s');
    if (f.existsSync()) f.deleteSync();
  }
}

/// Builds a fresh keyed database at [dbPath] in [layout] from the
/// `*.segcells.bin` at [segcellsPath]. Rows go in primary-key order and the
/// secondary indexes are created after the bulk insert, so the final schema is
/// storage_bench's while the one-time build stays fast. Returns build stats.
Map<String, Object> buildCoverageDb({
  required String segcellsPath,
  required String dbPath,
  required Layout layout,
}) {
  final sw = Stopwatch()..start();
  final records = readSegcellsBin(File(segcellsPath).readAsBytesSync());
  final readMs = sw.elapsedMilliseconds;
  _deleteDb(dbPath);
  final db = _open(dbPath);
  final stats = <String, Object>{'layout': layout.label};
  try {
    final rows = records.fold<int>(0, (a, r) => a + r.cells.length);
    if (layout == Layout.cells) {
      // (cell, segment) packed as cell << 20 | segment sorts in PK order.
      final packed = Int64List(rows);
      var k = 0;
      for (final r in records) {
        if (r.id < 0 || r.id > _mask20) {
          throw RangeError('segment id ${r.id} does not fit in 20 bits');
        }
        for (final c in r.cells) {
          packed[k++] = (c << 20) | r.id;
        }
      }
      packed.sort();
      db.execute(ddlA[0]);
      var distinct = 0, last = -1;
      _tx(db, () {
        final st = db.prepare(_insertCellSql);
        for (final p in packed) {
          final cell = p >> 20;
          if (cell != last) distinct++;
          last = cell;
          st.execute([cell, p & _mask20]);
        }
        st.close();
      });
      db.execute(ddlA[1]);
      stats['cell_coverage_rows'] = rows;
      stats['z20_cells'] = distinct;
    } else {
      db
        ..execute(ddlB[0])
        ..execute(ddlB[2]);
      var spans = 0;
      _tx(db, () {
        final st = db.prepare(_insertSpanSql);
        for (final r in records) {
          for (final (y, a, b) in spansOf(r.cells)) {
            st.execute([r.id, y, a, b]);
            spans++;
          }
        }
        st.close();
      });
      db.execute(ddlB[1]);
      final all = Int64List(rows);
      var k = 0;
      for (final r in records) {
        all.setAll(k, r.cells);
        k += r.cells.length;
      }
      all.sort();
      var distinct = 0;
      _tx(db, () {
        final st = db.prepare(_insertStatSql);
        var i = 0;
        while (i < all.length) {
          var j = i + 1;
          while (j < all.length && all[j] == all[i]) {
            j++;
          }
          st.execute([all[i], j - i]);
          distinct++;
          i = j;
        }
        st.close();
      });
      stats['coverage_spans_rows'] = spans;
      stats['cell_stats_rows'] = distinct;
      stats['z20_cells'] = distinct;
    }
    db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    stats.addAll({
      'segments': records.length,
      'source_rows': rows,
      'read_ms': readMs,
      'build_ms': sw.elapsedMilliseconds,
    });
  } catch (_) {
    db.close();
    _deleteDb(dbPath);
    rethrow;
  }
  db.close();
  stats['db_bytes'] = File(dbPath).lengthSync();
  return stats;
}

/// Opens (building it first if needed) the coverage database for [layout]
/// next to the segcells file. A sidecar JSON records the source's size and
/// modification time; a mismatch, or [rebuild], builds it again.
Map<String, Object> ensureCoverageDb({
  required String segcellsPath,
  required String dbPath,
  required Layout layout,
  bool rebuild = false,
}) {
  final src = File(segcellsPath);
  final stamp = {
    'segcells_bytes': src.lengthSync(),
    'segcells_mtime_ms': src.lastModifiedSync().millisecondsSinceEpoch,
    'layout': layout.label,
  };
  final side = File('$dbPath.json');
  if (!rebuild && side.existsSync() && File(dbPath).existsSync()) {
    try {
      final old = jsonDecode(side.readAsStringSync()) as Map<String, dynamic>;
      final same = stamp.entries.every((e) => old[e.key] == e.value);
      if (same) {
        return {
          'reused': true,
          ...(old['build'] as Map<String, dynamic>).cast<String, Object>(),
        };
      }
    } on FormatException {
      // A torn sidecar means a torn build: rebuild.
    }
  }
  if (side.existsSync()) side.deleteSync();
  final build = buildCoverageDb(
    segcellsPath: segcellsPath,
    dbPath: dbPath,
    layout: layout,
  );
  side.writeAsStringSync(jsonEncode({...stamp, 'build': build}));
  return {'reused': false, ...build};
}

/// Read side of the coverage database: the fog's tile query.
class CoverageDb {
  CoverageDb.open(String path, this.layout) : _db = _open(path) {
    _stmt = _db.prepare(
      layout == Layout.cells ? rollupSqlA : spansInTileSql,
      persistent: true,
    );
  }

  final Layout layout;
  final Database _db;
  late final PreparedStatement _stmt;

  /// Read back from this connection: proves the coverage comes from SQLCipher.
  Map<String, Object> info() {
    String one(String sql) => '${_db.select(sql).first.values.first}';
    final table = layout == Layout.cells ? 'cell_coverage' : 'coverage_spans';
    return {
      'layout': layout.label,
      'cipher_version': one('PRAGMA cipher_version'),
      'cipher_provider': one('PRAGMA cipher_provider'),
      'sqlite_version': one('SELECT sqlite_version()'),
      'journal_mode': one('PRAGMA journal_mode'),
      'rows': int.parse(one('SELECT count(*) FROM $table')),
    };
  }

  /// Covered level-[level] cells in the tile (tz, tx, ty), as per-column
  /// sorted row indices local to the tile: the shape `mergeColumns` takes.
  List<Int32List> tileColumns(int tz, int tx, int ty, int level) {
    final d = level - tz;
    final side = 1 << d;
    final x0 = tx << d, y0 = ty << d;
    final sh = maxLevel - level;
    final zx0 = tx << (maxLevel - tz), zy0 = ty << (maxLevel - tz);
    final zx1 = ((tx + 1) << (maxLevel - tz)) - 1;
    final zy1 = ((ty + 1) << (maxLevel - tz)) - 1;
    final buckets = List<List<int>?>.filled(side, null);
    void add(int x, int y) => (buckets[x - x0] ??= <int>[]).add(y - y0);

    if (layout == Layout.cells) {
      final rs = _stmt.select([
        sh,
        zx0 << maxLevel,
        (zx1 << maxLevel) | _mask20,
        zy0,
        zy1,
      ]);
      for (final r in rs) {
        add(r.columnAt(0) as int, r.columnAt(1) as int);
      }
    } else {
      final rs = _stmt.select([zy0, zy1, zx0, zx1]);
      for (final r in rs) {
        final y = (r.columnAt(0) as int) >> sh;
        final a = r.columnAt(1) as int, b = r.columnAt(2) as int;
        final xa = (a < zx0 ? zx0 : a) >> sh;
        final xb = (b > zx1 ? zx1 : b) >> sh;
        for (var x = xa; x <= xb; x++) {
          add(x, y);
        }
      }
    }
    return [
      for (final b in buckets) b == null ? Int32List(0) : _sortedUnique(b),
    ];
  }

  void close() {
    _stmt.close();
    _db.close();
  }
}

Int32List _sortedUnique(List<int> v) {
  v.sort();
  var w = 1;
  for (var r = 1; r < v.length; r++) {
    if (v[r] != v[w - 1]) v[w++] = v[r];
  }
  return Int32List.fromList(v.sublist(0, w));
}
