import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'cells.dart';
import 'coverage_db.dart';

/// One tile query: covered level-[level] cells in the tile (z, x, y).
typedef TileQuery = ({int z, int x, int y, int level});

/// Where the fog gets its coverage from.
abstract class CoverageSource {
  /// Per query, the tile's covered cells as `CoverageIndex.tileColumns` shapes
  /// them, plus the source-side time spent in the queries.
  Future<({List<List<Int32List>> columns, double queryMs})> columns(
    List<TileQuery> queries,
  );

  Future<void> close();
}

/// The W1 in-memory rollups (control; no I/O).
class MemorySource implements CoverageSource {
  MemorySource(this.index);
  final CoverageIndex index;

  @override
  Future<({List<List<Int32List>> columns, double queryMs})> columns(
    List<TileQuery> queries,
  ) async {
    final sw = Stopwatch()..start();
    final cols = [
      for (final q in queries) index.tileColumns(q.z, q.x, q.y, q.level),
    ];
    return (columns: cols, queryMs: sw.elapsedMicroseconds / 1000);
  }

  @override
  Future<void> close() async {}
}

/// The SQLCipher database, queried on a worker isolate that owns the
/// connection, as a production reader (Drift's background isolate) would.
class DbSource implements CoverageSource {
  DbSource._(this._isolate, this._send, this._replies, this.info);

  final Isolate _isolate;
  final SendPort _send;
  final ReceivePort _replies;
  final _pending = <int, Completer<Object?>>{};
  var _next = 0;

  /// `CoverageDb.info()` from the worker's connection.
  final Map<String, Object> info;

  static Future<DbSource> open(String path, Layout layout) async {
    final replies = ReceivePort();
    final first = Completer<List<Object?>>();
    late final StreamSubscription<Object?> sub;
    final isolate = await Isolate.spawn(_worker, (
      replies.sendPort,
      path,
      layout.label,
    ), debugName: 'coverage-db');
    DbSource? source;
    sub = replies.listen((msg) {
      if (source == null) {
        first.complete(msg as List<Object?>);
        return;
      }
      final (id, result) = msg as (int, Object?);
      source._pending.remove(id)?.complete(result);
    });
    final hello = await first.future;
    if (hello[0] is String) {
      await sub.cancel();
      replies.close();
      isolate.kill();
      throw StateError('coverage db: ${hello[0]}');
    }
    source = DbSource._(
      isolate,
      hello[0]! as SendPort,
      replies,
      (hello[1]! as Map).cast<String, Object>(),
    );
    return source;
  }

  @override
  Future<({List<List<Int32List>> columns, double queryMs})> columns(
    List<TileQuery> queries,
  ) async {
    final id = _next++;
    final done = Completer<Object?>();
    _pending[id] = done;
    _send.send((id, [for (final q in queries) (q.z, q.x, q.y, q.level)]));
    final result = await done.future;
    if (result is String) throw StateError('coverage db: $result');
    final (cols, ms) = result! as (List<List<Int32List>>, double);
    return (columns: cols, queryMs: ms);
  }

  @override
  Future<void> close() async {
    _send.send(null);
    _replies.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _isolate.kill();
  }
}

void _worker((SendPort, String, String) init) {
  final (reply, path, layoutLabel) = init;
  final CoverageDb db;
  try {
    db = CoverageDb.open(path, Layout.parse(layoutLabel));
  } catch (e) {
    reply.send(['$e']);
    return;
  }
  final inbox = ReceivePort();
  reply.send([inbox.sendPort, db.info()]);
  inbox.listen((msg) {
    if (msg == null) {
      db.close();
      inbox.close();
      return;
    }
    final (id, qs) = msg as (int, List<(int, int, int, int)>);
    try {
      final sw = Stopwatch()..start();
      final cols = [for (final (z, x, y, l) in qs) db.tileColumns(z, x, y, l)];
      reply.send((id, (cols, sw.elapsedMicroseconds / 1000)));
    } catch (e) {
      reply.send((id, '$e'));
    }
  });
}
