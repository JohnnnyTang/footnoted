import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'stores.dart';

/// What the loaded SQLite library is, and whether encryption and R*Tree work
/// on this platform. Runs against a real file so the header can be checked.
Map<String, Object?> probe(String dir) {
  final out = <String, Object?>{};
  final mem = sqlite3.openInMemory();
  out['sqlite_version'] = mem.select('SELECT sqlite_version() AS v').first['v'];
  final cv = mem.select('PRAGMA cipher_version');
  out['cipher_version'] = cv.isEmpty ? '' : '${cv.first.values.first}';
  final opts = [
    for (final r in mem.select('PRAGMA compile_options')) '${r.values.first}',
  ];
  out['rtree_compile_option'] = opts.contains('ENABLE_RTREE');
  mem.close();
  final cipher = (out['cipher_version'] as String).isNotEmpty;
  out['cipher_available'] = cipher;

  final path = '$dir${Platform.pathSeparator}probe.db';
  for (final f in [path, '$path-wal', '$path-shm']) {
    if (File(f).existsSync()) File(f).deleteSync();
  }
  final db = sqlite3.open(path);
  applyPragmas(db, cipher: cipher);
  if (cipher) {
    final prov = db.select('PRAGMA cipher_provider');
    out['cipher_provider'] = prov.isEmpty ? '' : '${prov.first.values.first}';
    final prv = db.select('PRAGMA cipher_provider_version');
    out['cipher_provider_version'] = prv.isEmpty
        ? ''
        : '${prv.first.values.first}';
  }
  db.execute(
    'CREATE VIRTUAL TABLE rt USING rtree(id, min_x, max_x, min_y, max_y)',
  );
  db.execute('INSERT INTO rt VALUES (1, 0, 10, 0, 10), (2, 20, 30, 20, 30)');
  final hit = db.select(
    'SELECT id FROM rt WHERE max_x >= 5 AND min_x <= 6 '
    'AND max_y >= 5 AND min_y <= 6',
  );
  out['rtree_query_ids'] = [for (final r in hit) r['id']];
  out['journal_mode'] = db.select('PRAGMA journal_mode').first.values.first;
  out['synchronous'] = db.select('PRAGMA synchronous').first.values.first;
  db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  db.close();
  final head = File(path).openSync()..setPositionSync(0);
  final bytes = head.readSync(16);
  head.closeSync();
  out['file_header_is_plain_sqlite'] =
      latin1.decode(bytes, allowInvalid: true) == 'SQLite format 3\u0000';
  out['file_header_hex'] = [
    for (final b in bytes) b.toRadixString(16).padLeft(2, '0'),
  ].join();
  File(path).deleteSync();
  return out;
}
