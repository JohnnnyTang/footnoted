// Host-side runner for one benchmark run on an Android device (MEASURE.md):
//   dart run bin/measure.dart --serial emulator-5554 --strategy holes \
//       --texture false --label emulator [--zoom 10] [--layout B] \
//       [--source db|memory] [--detail 6] [--passes 3] [--no-fog] [--out DIR]
//
// It launches the installed profile build with autorun extras, polls
// SurfaceFlinger's per-layer present timestamps while the passes run, then
// cuts them to each pass window the app reports and writes
// <out>/<stamp>_.../summary.json next to the raw captures. The device log is
// read by the app's pid only; the shared log buffer is never cleared.
import 'dart:convert';
import 'dart:io';

import 'package:render_bench/src/stats.dart';

const pkg = 'com.example.footnoted.spike.render_bench';

late String serial;

Future<String> adb(List<String> args) async {
  final r = await Process.run('adb', ['-s', serial, ...args]);
  return r.stdout as String;
}

// Layers of this app that receive buffers. On Android 16 `--list` wraps each
// name as `RequestedLayerState{<name> parentId=…}`; `--latency` wants <name>.
// Container layers (bounds, background, input sink, splash, leashes) never get
// buffers, so they are skipped to keep each poll well inside the 127-frame
// history SurfaceFlinger keeps per layer.
Future<Set<String>> bufferLayers() async {
  final out = await adb(['shell', 'dumpsys', 'SurfaceFlinger', '--list']);
  final names = <String>{};
  for (var l in out.split('\n')) {
    l = l.trim();
    if (!l.contains('render_bench')) continue;
    l = l
        .replaceFirst(RegExp(r'^RequestedLayerState\{'), '')
        .replaceFirst(
          RegExp(r' (parentId|relativeParentId|z|layerStack)=.*$'),
          '',
        )
        .replaceFirst(RegExp(r'\}$'), '');
    if (RegExp(
      r'Background for|Bounds for|InputSink|Splash|leash|ActivityRecord',
    ).hasMatch(l)) {
      continue;
    }
    names.add(l);
  }
  return names;
}

String opt(List<String> args, String name, String fallback) {
  final i = args.indexOf('--$name');
  return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
}

Never fail(Directory dir, String file, String message, int code) {
  stderr.writeln(message);
  File('${dir.path}/$file').writeAsStringSync('$message\n');
  exit(code);
}

Future<void> main(List<String> args) async {
  serial = opt(args, 'serial', 'emulator-5554');
  final strategy = opt(args, 'strategy', 'holes');
  final texture = opt(args, 'texture', 'false') == 'true';
  final label = opt(args, 'label', '');
  final detail = opt(args, 'detail', '6');
  final passes = opt(args, 'passes', '3');
  final zoom = int.parse(opt(args, 'zoom', '10'));
  final layout = opt(args, 'layout', 'B').toUpperCase();
  final source = opt(args, 'source', 'db');
  final fog = !args.contains('--no-fog');
  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '');
  final name = [
    stamp,
    'z$zoom',
    strategy,
    texture ? 'tex' : 'vd',
    source == 'db' ? layout : 'mem',
    if (!fog) 'nofog',
  ].join('_');
  final dir = Directory('${opt(args, 'out', 'out/runs')}/$name')
    ..createSync(recursive: true);

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
    '--ei',
    'zoom',
    '$zoom',
    '--es',
    'layout',
    layout,
    '--es',
    'source',
    source,
    '--es',
    'label',
    // `adb shell` joins its arguments into one device shell command line, so
    // a label with spaces or parentheses must be quoted for that shell.
    "'${label.replaceAll("'", r"'\''")}'",
  ]);
  final pid = (await adb(['shell', 'pidof', pkg])).trim().split(' ').first;
  if (pid.isEmpty) fail(dir, 'ERROR', 'app did not start', 1);
  stdout.writeln(
    'started pid $pid z$zoom $strategy texture=$texture fog=$fog '
    'source=$source layout=$layout → ${dir.path}',
  );

  final presents = <String, Set<int>>{};
  final refresh = <String, int>{};
  final logLines = <String>{};
  var gfxReset = false, dataReady = false;
  String? donePath;
  final passWindows = <int, List<int>>{};
  final appPasses = <int, Map<String, Object?>>{};
  // The first launch on a device builds the coverage DB before any pass.
  var deadline = DateTime.now().add(const Duration(minutes: 30));

  var layers = <String>{};
  var polls = 0, ticks = 0;
  while (donePath == null && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (dataReady) {
      if (polls++ % 6 == 0) layers = await bufferLayers();
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
    }
    final log = await adb(['logcat', '-d', '--pid=$pid', '-s', 'flutter:I']);
    for (final line in log.split('\n')) {
      if (!logLines.add(line.trimRight())) continue;
      if (line.contains('RENDER_BENCH_ERROR')) {
        fail(dir, 'ERROR', line.trim(), 1);
      }
      if (!dataReady && line.contains('RENDER_BENCH_DATA')) {
        dataReady = true;
        deadline = DateTime.now().add(const Duration(minutes: 6));
        stdout.writeln('data ready');
      }
      final start = RegExp(r'RENDER_BENCH_PASS 1 start').firstMatch(line);
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
    // A shared device: another app taking the foreground stops the pan
    // ticker, so the run is void. Exit 3 lets the caller retry.
    final top = await adb(['shell', 'dumpsys', 'activity', 'activities']);
    final resumed = RegExp(r'topResumedActivity=\S+ \S+ (\S+)').firstMatch(top);
    if (resumed != null && !resumed.group(1)!.startsWith(pkg)) {
      fail(dir, 'PREEMPTED', 'preempted by ${resumed.group(1)}', 3);
    }
    if (++ticks % 20 == 0 && (await adb(['shell', 'pidof', pkg])).isEmpty) {
      File('${dir.path}/logcat.txt').writeAsStringSync(logLines.join('\n'));
      fail(dir, 'ERROR', 'app process $pid died', 1);
    }
  }
  File('${dir.path}/logcat.txt').writeAsStringSync(logLines.join('\n'));
  if (donePath == null) {
    fail(dir, 'ERROR', 'timed out waiting for RENDER_BENCH_DONE', 1);
  }

  final gfx = await adb(['shell', 'dumpsys', 'gfxinfo', pkg, 'framestats']);
  File('${dir.path}/gfxinfo.txt').writeAsStringSync(gfx);
  await Process.run(
    'adb',
    ['-s', serial, 'pull', donePath, '${dir.path}/app_result.json'],
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
    'zoom': zoom,
    'detail': int.parse(detail),
    'source': source,
    'layout': layout,
    'refresh_period_ns': refresh,
    'gfxinfo_summary': gfx
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('Total frames') || l.startsWith('Janky'))
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
