// Prints Markdown tables from one or more result JSON files. With several
// files (repeat runs) every number is the median across runs.
//
// Usage: dart run tool/summarize.dart <result.json>...
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final runs = [
    for (final a in args)
      jsonDecode(File(a).readAsStringSync()) as Map<String, dynamic>,
  ];
  if (runs.isEmpty) {
    stderr.writeln('usage: summarize.dart <result.json>...');
    exit(64);
  }
  num med(List<num> v) => (v..sort())[v.length ~/ 2];
  String mb(num b) => (b / 1048576).toStringAsFixed(1);

  final first = runs.first;
  stdout.writeln('runs: ${runs.length}; env: ${jsonEncode(first['env'])}');
  stdout.writeln('sqlite: ${jsonEncode(first['sqlite'])}');
  stdout.writeln('dataset: ${jsonEncode(first['dataset'])}\n');

  final keys = [
    for (final r in first['results'] as List)
      '${r['layout']}|${r['driver']}|${r['cipher']}',
  ];
  Map<String, dynamic> find(Map<String, dynamic> run, String k) =>
      (run['results'] as List).cast<Map<String, dynamic>>().firstWhere(
        (r) => '${r['layout']}|${r['driver']}|${r['cipher']}' == k,
      );
  num m(String k, String field) =>
      med([for (final run in runs) find(run, k)[field] as num]);
  num q(String k, String tile, String l) => med([
    for (final run in runs)
      ((find(run, k)['tile_query'] as Map)[tile] as Map?)?[l]?['median_ms']
              as num? ??
          -1,
  ]);

  stdout.writeln(
    '| Layout | Driver | Cipher | Leg insert ms | Full insert ms | '
    'Delete leg ms | VACUUM ms | Size MB |',
  );
  stdout.writeln('|---|---|---|---:|---:|---:|---:|---:|');
  for (final k in keys) {
    final [l, d, c] = k.split('|');
    stdout.writeln(
      '| $l | $d | ${c == 'true' ? 'on' : 'off'} | ${m(k, 'leg_insert_ms')} | '
      '${m(k, 'full_insert_ms')} | ${m(k, 'delete_leg_ms')} | '
      '${m(k, 'vacuum_ms')} | ${mb(m(k, 'size_bytes'))} |',
    );
  }

  final tiles = <String>{
    for (final r in first['results'] as List)
      ...(r['tile_query'] as Map).keys.cast<String>(),
  };
  stdout.writeln(
    '\nz10 tile query, median ms (L12 / L16 / L20); "-" = not applicable\n',
  );
  stdout.writeln('| Layout | Driver | Cipher | ${tiles.join(' | ')} |');
  stdout.writeln('|---|---|---|${[for (final _ in tiles) '---:'].join('|')}|');
  for (final k in keys) {
    final [l, d, c] = k.split('|');
    final cells = [
      for (final t in tiles)
        q(k, t, '12') < 0
            ? '-'
            : [
                for (final lv in ['12', '16', '20']) q(k, t, lv),
              ].join(' / '),
    ];
    stdout.writeln(
      '| $l | $d | ${c == 'true' ? 'on' : 'off'} | ${cells.join(' | ')} |',
    );
  }
}
