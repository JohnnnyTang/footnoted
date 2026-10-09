// Host-side runner for one benchmark run on an Android device (MEASURE.md):
//   dart run bin/measure.dart --serial emulator-5554 --strategy holes \
//       --texture false --label emulator [--detail 6] [--passes 3] [--no-fog]
//
// It launches the installed profile build with autorun extras, polls
// SurfaceFlinger's per-layer present timestamps while the passes run, then
// cuts them to each pass window the app reports and writes
// out/runs/<stamp>/summary.json next to the raw captures.
import 'dart:convert';
import 'dart:io';

import 'package:render_bench/src/stats.dart';

const pkg = 'com.example.footnoted.spike.render_bench';

late String serial;

Future<String> adb(List<String> args) async {
  final r = await Process.run('adb', ['-s', serial, ...args]);
  return r.stdout as String;
}

String opt(List<String> args, String name, String fallback) {
  final i = args.indexOf('--$name');
  return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
}

Future<void> main(List<String> args) async {
  serial = opt(args, 'serial', 'emulator-5554');
  final strategy = opt(args, 'strategy', 'holes');
  final texture = opt(args, 'texture', 'false') == 'true';
  final label = opt(args, 'label', '');
  final detail = opt(args, 'detail', '6');
  final passes = opt(args, 'passes', '3');
  final fog = !args.contains('--no-fog');
  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '');
  final dir = Directory(
    '${opt(args, 'out', 'out/runs')}/${stamp}_${strategy}_${texture ? 'tex' : 'vd'}${fog ? '' : '_nofog'}',
  )..createSync(recursive: true);

  await adb(['logcat', '-c']);
  await adb([
    'shell',
    'am',
    'start',
    '-S',
    '-W',
    '-n',
    '$pkg/.MainActivity',
    '--ez',
    'autorun',
    'true',
    '--es',
    'strategy',
    strategy,
    '--ez',
    'texture',
    '$texture',
    '--ei',
    'detail',
    detail,
    '--ei',
    'passes',
    passes,
    '--ez',
    'fog',
    '$fog',
    '--es',
    'label',
    label,
  ]);
  stdout.writeln('started $strategy texture=$texture fog=$fog → ${dir.path}');

  final presents = <String, Set<int>>{};
  final refresh = <String, int>{};
  var gfxReset = false;
  String? donePath;
  final passWindows = <int, List<int>>{};
  final appPasses = <int, Map<String, Object?>>{};
  final deadline = DateTime.now().add(const Duration(minutes: 6));

  while (donePath == null && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final layers = (await adb(['shell', 'dumpsys', 'SurfaceFlinger', '--list']))
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.contains(pkg) || l.contains('flutter-vd'))
        .toSet();
    for (final layer in layers) {
      final out = await adb([
        'shell',
        'dumpsys',
        'SurfaceFlinger',
        '--latency',
        "'$layer'",
      ]);
      final lines = out.trim().split('\n');
      if (lines.isEmpty) continue;
      final period = int.tryParse(lines.first.trim());
      if (period != null) refresh[layer] = period;
      final set = presents.putIfAbsent(layer, () => <int>{});
      for (final l in lines.skip(1)) {
        final parts = l.trim().split(RegExp(r'\s+'));
        if (parts.length < 3) continue;
        final actual = int.tryParse(parts[1]) ?? 0;
        if (actual > 0 && actual < 0x7fffffffffffffff) set.add(actual);
      }
    }
    final log = await adb(['logcat', '-d', '-s', 'flutter:I']);
    for (final line in log.split('\n')) {
      final start = RegExp(r'RENDER_BENCH_PASS (\d+) start').firstMatch(line);
      if (start != null && !gfxReset) {
        await adb(['shell', 'dumpsys', 'gfxinfo', pkg, 'reset']);
        gfxReset = true;
      }
      final end = RegExp(r'RENDER_BENCH_PASS (\d+) end (\{.*\})$')
          .firstMatch(line.trim());
      if (end != null) {
        final n = int.parse(end.group(1)!);
        final json = jsonDecode(end.group(2)!) as Map<String, Object?>;
        appPasses[n] = json;
        passWindows[n] = (json['window_monotonic_us'] as List).cast<int>();
      }
      final done = RegExp(r'RENDER_BENCH_DONE (\S+)').firstMatch(line);
      if (done != null) donePath = done.group(1);
    }
  }
  if (donePath == null) {
    stderr.writeln('timed out waiting for RENDER_BENCH_DONE');
    exit(1);
  }

  final gfx = await adb(['shell', 'dumpsys', 'gfxinfo', pkg, 'framestats']);
  File('${dir.path}/gfxinfo.txt').writeAsStringSync(gfx);
  File('${dir.path}/logcat.txt')
      .writeAsStringSync(await adb(['logcat', '-d', '-s', 'flutter:I']));
  await Process.run(
    'adb',
    ['-s', serial, 'pull', donePath!, '${dir.path}/app_result.json'],
    environment: {'MSYS_NO_PATHCONV': '1'},
  );

  final perPass = <String, Object>{};
  for (final MapEntry(key: n, value: w) in passWindows.entries) {
    if (n == 0) continue;
    final startNs = w[0] * 1000, endNs = w[1] * 1000;
    final layersOut = <String, Object>{};
    presents.forEach((layer, set) {
      final ts = set.where((t) => t >= startNs && t <= endNs).toList()..sort();
      if (ts.length < 2) return;
      layersOut[layer] = intervalStats([
        for (var i = 1; i < ts.length; i++) (ts[i] - ts[i - 1]) / 1e6,
      ]);
    });
    perPass['$n'] = {
      'surfaceflinger': layersOut,
      'flutter_frames': appPasses[n]?['flutter_frames'],
    };
  }
  final summary = {
    'serial': serial,
    'label': label,
    'strategy': strategy,
    'texture': texture,
    'fog': fog,
    'refresh_period_ns': refresh,
    'gfxinfo_summary': gfx
        .split('\n')
        .where(
          (l) =>
              l.startsWith('Total frames') ||
              l.startsWith('Janky') ||
              l.contains('percentile') ||
              l.startsWith('Number '),
        )
        .map((l) => l.trim())
        .toList(),
    'passes': perPass,
  };
  File('${dir.path}/summary.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(summary));
  File('${dir.path}/sf_presents.json').writeAsStringSync(
    jsonEncode({
      for (final e in presents.entries) e.key: (e.value.toList()..sort()),
    }),
  );
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(summary));
}
