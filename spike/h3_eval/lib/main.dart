import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/evaluation.dart';

void main() => runApp(const SpikeApp());

String get _buildMode =>
    kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug');

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key, this.autoRun = false});

  /// When true the evaluation starts on launch (the on-device run); tests
  /// leave it off because the H3 native library is not present on the host.
  final bool autoRun;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'h3_eval',
      home: EvalPage(autoRun: autoRun || kReleaseMode || kProfileMode),
    );
  }
}

class EvalPage extends StatefulWidget {
  const EvalPage({super.key, required this.autoRun});
  final bool autoRun;

  @override
  State<EvalPage> createState() => _EvalPageState();
}

class _EvalPageState extends State<EvalPage> {
  final _lines = <String>[];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoRun) _start();
  }

  Future<void> _start() async {
    setState(() => _running = true);
    final port = ReceivePort();
    final mode = _buildMode;
    await Isolate.spawn(_worker, (port.sendPort, mode));
    await for (final msg in port) {
      final line = msg as String;
      // ignore: avoid_print
      print('H3EVAL $line');
      if (!mounted) break;
      setState(() => _lines.add(line));
      if (line.startsWith('{"kind":"done"') ||
          line.startsWith('{"kind":"error"')) {
        port.close();
      }
    }
    if (mounted) setState(() => _running = false);
  }

  static Future<void> _worker((SendPort, String) args) async {
    final (send, mode) = args;
    void emit(String kind, Map<String, Object?> data) =>
        send.send(jsonEncode({'kind': kind, ...data}));
    try {
      await runEvaluation(emit, buildMode: mode);
    } catch (e, st) {
      emit('error', {'error': '$e', 'stack': '$st'});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('h3_eval (S01-13)')),
      floatingActionButton: _running
          ? null
          : FloatingActionButton(onPressed: _start, child: const Text('Run')),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          for (final l in _lines) Text(l, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
