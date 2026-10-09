import 'dart:io';

import 'package:args/args.dart';
import 'package:footnoted_geo/footnoted_geo.dart';

import 'src/model.dart';
import 'src/output.dart';
import 'src/paths.dart';
import 'src/reveal.dart';
import 'src/scenario.dart';

export 'src/model.dart';
export 'src/reveal.dart' show countSpans, revealSegment, UnionBuilder;
export 'src/rng.dart';
export 'src/scenario.dart' show Knobs, Scenario;

const traceName = 'dataset.trace.ndjson';

ArgParser _parser() => ArgParser()
  ..addOption('seed', defaultsTo: '42')
  ..addOption('years', defaultsTo: '5')
  ..addOption('out', help: 'Output directory (convention: spike/out).')
  ..addOption(
    'levels',
    defaultsTo: '20',
    help:
        'Comma-separated cell levels; level 20 writes dataset.*, others '
        'dataset.z<L>.*.',
  )
  ..addOption(
    'walk-scale',
    defaultsTo: '1.0',
    help: 'Dataset-size knob: multiplies every leisure-walk probability.',
  )
  ..addFlag('help', abbr: 'h', negatable: false);

void run(List<String> args) {
  final parser = _parser();
  final ArgResults opts;
  try {
    opts = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('tracegen: ${e.message}\n${parser.usage}');
    exitCode = 64;
    return;
  }
  final out = opts.option('out');
  if (opts.flag('help') || out == null) {
    stdout.writeln(
      'Usage: dart run tracegen --seed 42 --years 5 --out <dir>\n'
      '${parser.usage}',
    );
    exitCode = opts.flag('help') ? 0 : 64;
    return;
  }
  final summary = generate(
    seed: int.parse(opts.option('seed')!),
    years: int.parse(opts.option('years')!),
    outDir: out,
    levels: [for (final l in opts.option('levels')!.split(',')) int.parse(l)],
    knobs: Knobs(walkScale: double.parse(opts.option('walk-scale')!)),
  );
  stdout.writeln(summary);
}

String _base(int level) => level == cellLevel ? 'dataset' : 'dataset.z$level';

/// Generates the dataset into [outDir]; returns a human-readable summary.
/// Also writes `<base>.stats.json` per level (outside FORMAT.md; counts and
/// timings for the session note).
String generate({
  required int seed,
  required int years,
  required String outDir,
  List<int> levels = const [cellLevel],
  Knobs knobs = const Knobs(),
}) {
  Directory(outDir).createSync(recursive: true);
  final summary = StringBuffer();

  final genWatch = Stopwatch()..start();
  final segments = Scenario(seed: seed, years: years, knobs: knobs).generate();
  final genMs = genWatch.elapsedMilliseconds;
  final traceWatch = Stopwatch()..start();
  final traceSha = writeTrace('$outDir/$traceName', segments);
  final traceMs = traceWatch.elapsedMilliseconds;
  final points = segments.fold(0, (n, s) => n + s.points.length);
  summary.writeln(
    'trace: ${segments.length} segments, $points points, '
    'sha256 $traceSha (${genMs + traceMs} ms)',
  );

  for (final level in levels) {
    final base = _base(level);
    final watch = Stopwatch()..start();
    final union = UnionBuilder();
    final perCategory = <String, UnionBuilder>{};
    final catStats = <String, Map<String, int>>{};
    final seg = HashingWriter('$outDir/$base.segcells.bin');
    var rows = 0;
    var spans = 0;
    Map<String, Object?>? longestLeg;
    var revealMs = 0;
    for (final s in segments) {
      final t0 = watch.elapsedMilliseconds;
      final cells = revealSegment(s, level);
      revealMs += watch.elapsedMilliseconds - t0;
      final segSpans = countSpans(cells, level);
      seg
        ..int64(s.id)
        ..int64(cells.length)
        ..int64s(cells);
      rows += cells.length;
      spans += segSpans;
      union.add(cells);
      (perCategory[s.category] ??= UnionBuilder()).add(cells);
      final c = catStats[s.category] ??= {'segments': 0, 'rows': 0, 'spans': 0};
      c['segments'] = c['segments']! + 1;
      c['rows'] = c['rows']! + cells.length;
      c['spans'] = c['spans']! + segSpans;
      if (s.kind == SegmentKind.transit &&
          s.reveal == Reveal.line &&
          cells.length > ((longestLeg?['rows'] as int?) ?? 0)) {
        longestLeg = {
          'segment': s.id,
          'label': s.label,
          'km': (polylineMeters([for (final p in s.points) p.latLng]) / 1000)
              .round(),
          'buffer_m': s.bufferM,
          'rows': cells.length,
          'spans': segSpans,
        };
      }
    }
    final segSha = seg.close();
    final cells = union.build();
    final cellsWriter = HashingWriter('$outDir/$base.cells.bin')..int64s(cells);
    final cellsSha = cellsWriter.close();
    final totalMs = watch.elapsedMilliseconds;

    writeJson('$outDir/$base.cells.json', {
      'count': cells.length,
      'level': level,
      'buffer_m': null,
      'source_trace': traceName,
      'sha256': cellsSha,
    });
    writeJson('$outDir/$base.segcells.json', {
      'segments': segments.length,
      'rows': rows,
      'level': level,
      'source_trace': traceName,
      'sha256': segSha,
    });
    final unionSpans = countSpans(cells, level);
    writeJson('$outDir/$base.stats.json', {
      'seed': seed,
      'years': years,
      'walk_scale': knobs.walkScale,
      'level': level,
      'segments': segments.length,
      'points': points,
      'unique_cells': cells.length,
      'rows': rows,
      'segment_spans': spans,
      'union_spans': unionSpans,
      'by_category': {
        for (final e in catStats.entries)
          e.key: {
            ...e.value,
            'unique_cells': perCategory[e.key]!.build().length,
          },
      },
      'longest_line_leg': longestLeg,
      'sha256': {'trace': traceSha, 'cells': cellsSha, 'segcells': segSha},
      'ms': {
        'generate_trace': genMs,
        'write_trace': traceMs,
        'reveal': revealMs,
        'reveal_and_write': totalMs,
      },
    }, pretty: true);
    summary
      ..writeln(
        'z$level: ${cells.length} unique cells, $rows (cell, segment) rows, '
        '$spans segment spans, $unionSpans union spans ($totalMs ms, '
        'reveal $revealMs ms)',
      )
      ..writeln('  cells sha256 $cellsSha')
      ..writeln('  segcells sha256 $segSha');
  }
  return summary.toString().trimRight();
}
