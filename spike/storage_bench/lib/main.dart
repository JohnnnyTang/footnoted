import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'storage_bench.dart';

// App runner: same code path as bin/storage_bench.dart. Runs once on launch
// (unless --dart-define=AUTORUN=false), prints the result between
// BENCH_RESULT_BEGIN / BENCH_RESULT_END in chunks (logcat truncates long
// lines), and saves it to the documents dir and, on Android, to the app's
// external files dir for `adb pull`.

const _autorun = bool.fromEnvironment('AUTORUN', defaultValue: true);
const _tiny = bool.fromEnvironment('TINY');

void main() => runApp(const SpikeApp());

class SpikeApp extends StatefulWidget {
  const SpikeApp({super.key, this.autorun = _autorun});

  final bool autorun;

  @override
  State<SpikeApp> createState() => _SpikeAppState();
}

class _SpikeAppState extends State<SpikeApp> {
  final _lines = <String>['storage_bench'];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    if (widget.autorun) _run();
  }

  void _log(String l) {
    debugPrint('BENCH $l');
    if (mounted) setState(() => _lines.add(l));
  }

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      final docs = (await getApplicationDocumentsDirectory()).path;
      final ext = Platform.isAndroid
          ? (await getExternalStorageDirectory())?.path
          : null;
      final input = ext == null ? null : p.join(ext, 'dataset.segcells.bin');
      final work = p.join(
        (await getApplicationSupportDirectory()).path,
        'bench',
      );
      _log('work dir $work');
      final json = await Isolate.run(() async {
        final ds = input != null && File(input).existsSync()
            ? readSegcells(input)
            : buildStandIn(
                _tiny ? const StandInSpec.tiny() : const StandInSpec(),
              );
        final r = await runBench(
          ds,
          work,
          log: (l) => debugPrint('BENCH $l'),
          env: {
            'runner': 'flutter-app',
            'build': kReleaseMode
                ? 'release'
                : (kProfileMode ? 'profile' : 'debug'),
          },
        );
        return const JsonEncoder.withIndent('  ').convert(r);
      });
      for (final dir in [docs, ?ext]) {
        File(p.join(dir, 'storage_bench_result.json')).writeAsStringSync(json);
      }
      debugPrint('BENCH_RESULT_BEGIN');
      for (final line in const LineSplitter().convert(json)) {
        debugPrint('BENCH_RESULT $line');
      }
      debugPrint('BENCH_RESULT_END');
      _log('done; saved to $docs${ext == null ? '' : ' and $ext'}');
    } catch (e, st) {
      _log('FAILED: $e');
      debugPrint('$st');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'storage_bench',
      home: Scaffold(
        appBar: AppBar(title: const Text('storage_bench')),
        floatingActionButton: FloatingActionButton(
          onPressed: _running ? null : _run,
          child: Icon(_running ? Icons.hourglass_top : Icons.play_arrow),
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [for (final l in _lines) Text(l)],
        ),
      ),
    );
  }
}
