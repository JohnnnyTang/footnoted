// The two coverage layouts under test. Both drivers create them from this DDL
// so the on-disk schema is identical whichever driver writes it.

enum Layout {
  /// A: one row per (cell, segment).
  cells('A'),

  /// B: run-length spans per (segment, row) plus derived per-cell counts.
  spans('B');

  const Layout(this.label);
  final String label;
}

const ddlA = [
  'CREATE TABLE cell_coverage (cell_id INTEGER NOT NULL, '
      'segment_id INTEGER NOT NULL, PRIMARY KEY (cell_id, segment_id)) '
      'WITHOUT ROWID',
  'CREATE INDEX cell_coverage_segment ON cell_coverage (segment_id)',
];

// The brief names coverage_spans(segment_id, y, x_start, x_end) +
// INDEX(y, x_start). Deleting a segment needs a segment lookup; the spike
// gets it from a (segment_id, y, x_start) primary key on a WITHOUT ROWID
// table instead of a second index, mirroring layout A's PK + one index.
const ddlB = [
  'CREATE TABLE coverage_spans (segment_id INTEGER NOT NULL, '
      'y INTEGER NOT NULL, x_start INTEGER NOT NULL, x_end INTEGER NOT NULL, '
      'PRIMARY KEY (segment_id, y, x_start)) WITHOUT ROWID',
  'CREATE INDEX coverage_spans_yx ON coverage_spans (y, x_start)',
  'CREATE TABLE cell_stats (cell_id INTEGER NOT NULL PRIMARY KEY, '
      'n INTEGER NOT NULL) WITHOUT ROWID',
];

List<String> ddlFor(Layout l) => l == Layout.cells ? ddlA : ddlB;

const int _mask20 = (1 << 20) - 1;

/// Distinct level-L cells in a z20 ID range, rolled up in SQL. Used for A
/// (`cell_coverage`) and for B's `cell_stats` path.
String rollupSql(String table) =>
    'SELECT DISTINCT (cell_id >> 20) >> ?1 AS x, (cell_id & $_mask20) >> ?1 '
    'AS y FROM $table WHERE cell_id BETWEEN ?2 AND ?3 '
    'AND (cell_id & $_mask20) BETWEEN ?4 AND ?5';

const spansInTileSql =
    'SELECT y, x_start, x_end FROM coverage_spans '
    'WHERE y BETWEEN ?1 AND ?2 AND x_end >= ?3 AND x_start <= ?4';

const insertCellSql =
    'INSERT INTO cell_coverage (cell_id, segment_id) VALUES (?, ?)';
const insertSpanSql =
    'INSERT INTO coverage_spans (segment_id, y, x_start, x_end) '
    'VALUES (?, ?, ?, ?)';
const upsertStatSql =
    'INSERT INTO cell_stats (cell_id, n) VALUES (?, ?) '
    'ON CONFLICT (cell_id) DO UPDATE SET n = n + excluded.n';
const decStatSql = 'UPDATE cell_stats SET n = n - 1 WHERE cell_id = ?';
const dropStatSql = 'DELETE FROM cell_stats WHERE cell_id = ? AND n <= 0';

// F01.3 rollups, a rebuildable cache. `n` counts the covered z20 cells under
// the level-`level` cell, which is packed `(x << level) | y`.
const ddlRollups =
    'CREATE TABLE cell_rollups (level INTEGER NOT NULL, '
    'cell_id INTEGER NOT NULL, n INTEGER NOT NULL, '
    'PRIMARY KEY (level, cell_id)) WITHOUT ROWID';

/// Level [l] from the z20 covered cells: A's distinct `cell_coverage` cells,
/// or B's `cell_stats`.
String rollupFromLeavesSql(Layout layout, int l) {
  final sh = 20 - l;
  final src = layout == Layout.cells
      ? '(SELECT DISTINCT cell_id FROM cell_coverage)'
      : 'cell_stats';
  return 'INSERT INTO cell_rollups (level, cell_id, n) '
      'SELECT $l, (((cell_id >> 20) >> $sh) << $l) | '
      '((cell_id & $_mask20) >> $sh) AS p, count(*) FROM $src GROUP BY p';
}

/// Level [l] from the finer level [from], which must already be built.
String rollupFromLevelSql(int from, int l) {
  final sh = from - l;
  final mask = (1 << from) - 1;
  return 'INSERT INTO cell_rollups (level, cell_id, n) '
      'SELECT $l, (((cell_id >> $from) >> $sh) << $l) | '
      '((cell_id & $mask) >> $sh) AS p, sum(n) FROM cell_rollups '
      'WHERE level = $from GROUP BY p';
}

/// Level-`?1` cells with x in a packed-ID range `?2..?3` and y
/// (`cell_id & ?4`) in `?5..?6`.
const rollupTileSql =
    'SELECT cell_id, n FROM cell_rollups WHERE level = ?1 '
    'AND cell_id BETWEEN ?2 AND ?3 AND (cell_id & ?4) BETWEEN ?5 AND ?6';
