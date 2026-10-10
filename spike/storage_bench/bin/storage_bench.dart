import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:storage_bench/storage_bench.dart';

const _usage = '''
Usage: dart run bin/storage_bench.dart [options]

  --out <dir>        Work dir for databases, dumps and results (default: out)
  --segcells <path>  Use a FORMAT.md *.segcells.bin instead of the stand-in
  --leg <id>         Segment used as the long leg (default: the largest)
  --tiny             Tiny stand-in dataset (smoke test)
  --dumps            Also write the stand-in as stand-in.{cells,segcells}.bin
  --probe            Only print the SQLite/SQLCipher probe and exit
  --stats            Only print the dataset counts and exit
  --label <text>     Free-text label stored in the result (machine, build)
  --layout A|B       Only this layout (default: both)
  --driver <name>    Only this driver: raw, drift or driftsql (default: raw + drift)
  --cipher on|off    Only this cipher mode (default: both)
  --cache-mb <n>     PRAGMA cache_size of n MiB (default: SQLite's 2,000 KiB)
  --rollups <list>   cell_rollups levels, finest first (default: 16,12,8)
''';

Future<void> main(List<String> args) async {
  String opt(String name, String fallback) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  if (args.contains('--help')) {
    stdout.write(_usage);
    return;
  }
  final out = opt('--out', 'out');
  Directory(out).createSync(recursive: true);
  if (args.contains('--probe')) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(probe(out)));
    return;
  }

  final sw = Stopwatch()..start();
  final segPath = opt('--segcells', '');
  final Dataset ds;
  if (segPath.isNotEmpty) {
    final leg = opt('--leg', '');
    ds = readSegcells(segPath, longLegId: leg.isEmpty ? null : int.parse(leg));
  } else {
    ds = buildStandIn(
      args.contains('--tiny') ? const StandInSpec.tiny() : const StandInSpec(),
    );
    if (args.contains('--dumps')) writeDumps(ds, out, 'stand-in');
  }
  stdout.writeln(
    'dataset ready in ${sw.elapsedMilliseconds} ms: ${ds.segments.length} '
    'segments, ${ds.rows} rows, ${ds.union().length} unique cells, '
    '${ds.spanCount} spans, long leg ${ds.longLeg.cells.length} rows',
  );
  if (args.contains('--stats')) return;

  final layout = opt('--layout', '');
  final driver = opt('--driver', '');
  final cipher = opt('--cipher', '');
  final cacheMb = opt('--cache-mb', '');
  final result = await runBench(
    ds,
    p.join(out, 'db'),
    opts: BenchOptions(
      layouts: [
        for (final l in Layout.values)
          if (layout.isEmpty || l.label == layout) l,
      ],
      drivers: [
        for (final d in driver.isEmpty ? defaultDrivers : Driver.values)
          if (driver.isEmpty || d.name == driver) d,
      ],
      cipherModes: [if (cipher != 'off') true, if (cipher != 'on') false],
      cacheKib: cacheMb.isEmpty ? null : int.parse(cacheMb) * 1024,
      rollupLevels: [
        for (final l in opt('--rollups', '16,12,8').split(',')) int.parse(l),
      ],
    ),
    env: {
      'runner': 'desktop-cli',
      'label': opt('--label', ''),
      'build': const bool.fromEnvironment('dart.vm.product') ? 'aot' : 'jit',
    },
  );
  final json = const JsonEncoder.withIndent('  ').convert(result);
  final file = File(p.join(out, 'result-desktop.json'))
    ..writeAsStringSync(json);
  stdout.writeln('result written to ${file.path}');
}
