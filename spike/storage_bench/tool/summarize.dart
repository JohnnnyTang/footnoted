// Prints Markdown tables from one or more result JSON files. With several
// files (repeat runs) every number is the median across runs.
//
// Usage: dart run tool/summarize.dart <result.json>...
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: summarize.dart <result.json>...');
    exit(64);
  }
  stdout.write(
    summarize([
      for (final a in args)
        jsonDecode(File(a).readAsStringSync()) as Map<String, dynamic>,
    ]),
  );
}

String summarize(List<Map<String, dynamic>> runs) {
  final out = StringBuffer();
  num med(List<num> v) => (v..sort())[v.length ~/ 2];
  String mb(num b) => (b / 1048576).toStringAsFixed(b < 10485760 ? 2 : 1);
  String fmt(num v) => v < 0
      ? '-'
      : v >= 100
      ? v.toStringAsFixed(0)
      : v >= 10
      ? v.toStringAsFixed(1)
      : v >= 1
      ? v.toStringAsFixed(2)
      : v.toStringAsFixed(3);

  final first = runs.first;
  final ds = first['dataset'] as Map<String, dynamic>;
  out.writeln('runs: ${runs.length}; env: ${jsonEncode(first['env'])}\n');
  out.writeln('sqlite (probe): ${jsonEncode(first['sqlite'])}\n');
  out.writeln(
    'dataset: ${ds['source']}; ${ds['segments']} segments; '
    '${ds['rows_cell_segment']} (cell, segment) rows; '
    '${ds['unique_cells']} unique cells; ${ds['spans']} spans; '
    'long leg ${jsonEncode(ds['long_leg'])}; z10 tiles '
    '${jsonEncode(ds['tiles_z10'])}\n',
  );

  String key(Map r) => '${r['layout']}|${r['driver']}|${r['cipher']}';
  final keys = [for (final r in first['results'] as List) key(r as Map)];
  Map<String, dynamic> find(Map<String, dynamic> run, String k) =>
      (run['results'] as List).cast<Map<String, dynamic>>().firstWhere(
        (r) => key(r) == k,
      );
  Object? at(Object? m, List<String> path) {
    for (final p in path) {
      if (m is! Map) return null;
      m = m[p];
    }
    return m;
  }

  num m(String k, List<String> path) =>
      med([for (final run in runs) (at(find(run, k), path) as num?) ?? -1]);
  String label(String k) {
    final [l, d, c] = k.split('|');
    return '| $l | $d | ${c == 'true' ? 'on' : 'off'} |';
  }

  final versions = {
    for (final run in runs)
      for (final r in run['results'] as List)
        if ((r as Map)['cipher'] == true) '${r['cipher_version']}',
  };
  out.writeln(
    'cipher_version read on each cipher-on store connection: '
    '${versions.isEmpty ? '(none)' : versions.join(', ')}\n',
  );

  out.writeln(
    '| Layout | Driver | Cipher | Leg insert ms | Full insert ms | '
    'Delete leg ms | VACUUM ms | Size MiB | Plain header |',
  );
  out.writeln('|---|---|---|---:|---:|---:|---:|---:|---|');
  for (final k in keys) {
    out.writeln(
      '${label(k)} ${m(k, ['leg_insert_ms'])} | '
      '${m(k, ['full_insert_ms'])} | ${m(k, ['delete_leg_ms'])} | '
      '${m(k, ['vacuum_ms'])} | ${mb(m(k, ['size_bytes']))} | '
      '${find(first, k)['file_header_is_plain_sqlite'] ?? '?'} |',
    );
  }

  final levels = [
    for (final l
        in (at(first, ['results']) as List).first['rollups']?['levels']?.keys ??
            const [])
      '$l',
  ];
  if (levels.isNotEmpty) {
    out.writeln(
      '\nF01.3 `cell_rollups`: build ms (rows) per level, total build ms, '
      'table size MiB\n',
    );
    out.writeln(
      '| Layout | Driver | Cipher | ${[for (final l in levels) 'L$l'].join(' | ')} '
      '| Total ms | Size MiB |',
    );
    out.writeln(
      '|---|---|---|${[for (final _ in levels) '---:'].join('|')}|---:|---:|',
    );
    for (final k in keys) {
      final cells = [
        for (final l in levels)
          '${m(k, ['rollups', 'levels', l, 'build_ms'])} '
              '(${m(k, ['rollups', 'levels', l, 'rows'])})',
      ];
      out.writeln(
        '${label(k)} ${cells.join(' | ')} | '
        '${m(k, ['rollups', 'build_ms_total'])} | '
        '${mb(m(k, ['rollups', 'bytes']))} |',
      );
    }
  }

  final tiles = <String>{
    for (final r in first['results'] as List)
      ...((r as Map)['tile_query'] as Map).keys.cast<String>(),
  };
  for (final t in tiles) {
    final ls = <String>{
      for (final r in first['results'] as List)
        ...(((r as Map)['tile_query'] as Map)[t] as Map? ?? {}).keys
            .cast<String>(),
    }.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    final cells = [
      for (final l in ls)
        at(first, ['dataset', 'expected_tile_cells', t.split('/').first, l]),
    ];
    out.writeln(
      '\nz10 tile `$t`, median ms per level (cells: '
      '${[for (var i = 0; i < ls.length; i++) 'L${ls[i]} ${cells[i]}'].join(', ')})\n',
    );
    out.writeln(
      '| Layout | Driver | Cipher | ${ls.map((l) => 'L$l').join(' | ')} |',
    );
    out.writeln('|---|---|---|${[for (final _ in ls) '---:'].join('|')}|');
    for (final k in keys) {
      if (at(find(first, k), ['tile_query', t]) == null) continue;
      out.writeln(
        '${label(k)} '
        '${[
          for (final l in ls) fmt(m(k, ['tile_query', t, l, 'median_ms'])),
        ].join(' | ')} |',
      );
    }
  }

  out.writeln(
    '\nSpread, full insert ms per run: '
    '${[
      for (final k in keys) '${k.replaceAll('|', '/')} ${[for (final run in runs) find(run, k)['full_insert_ms']].join('/')}',
    ].join('; ')}',
  );
  return out.toString();
}
