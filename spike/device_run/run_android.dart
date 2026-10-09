// M0 spike (W2 seam): one-command Android device run. Throwaway; removed at G1-B.
// Contract: README.md. Steps storage.dart (S01-20a1) and render.dart (S01-20a2).
import 'dart:convert';
import 'dart:io';

const _steps = ['storage', 'render'];

Future<void> main(List<String> argv) async {
  final args = _parse(argv);
  final root = File.fromUri(Platform.script).parent.parent.parent.path;
  final serial = args['serial'] ?? await _onlyDevice();
  final out = Directory(
    _abs(root, args['out'] ?? 'stages/01-foundation/evidence/S01-20b'),
  )..createSync(recursive: true);
  final dataset = Directory(_abs(root, args['dataset'] ?? 'spike/out'));
  final only = args['only'];
  if (only != null && !_steps.contains(only)) {
    _fail('--only must be one of $_steps');
  }

  await _ensureDataset(root, dataset);
  final deviceJson = File('${out.path}/device.json');
  deviceJson.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(await _deviceInfo(serial)),
  );
  stdout.writeln('device_run: ${deviceJson.readAsStringSync()}');

  for (final step in _steps) {
    if (only != null && only != step) continue;
    stdout.writeln('device_run: step $step');
    final p = await Process.start(
      Platform.resolvedExecutable,
      [
        '$root/spike/device_run/$step.dart',
        '--serial',
        serial,
        '--out',
        '${out.path}/$step',
        '--dataset',
        dataset.path,
        '--device-json',
        deviceJson.path,
      ],
      workingDirectory: root,
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await p.exitCode;
    if (code != 0) _fail('step $step exited with $code', code);
  }

  final c2 = File('${out.path}/render/criterion2.md');
  if (c2.existsSync()) stdout.writeln(c2.readAsStringSync());
  stdout.writeln('device_run: done → ${out.path}');
}

Map<String, String> _parse(List<String> argv) {
  const known = {'serial', 'out', 'dataset', 'only'};
  final m = <String, String>{};
  for (var i = 0; i < argv.length; i++) {
    final k = argv[i].replaceFirst(RegExp('^--'), '');
    if (!known.contains(k) || i + 1 >= argv.length) {
      _fail(
        'usage: run_android.dart [--serial S] [--out DIR] '
        '[--dataset DIR] [--only storage|render]',
      );
    }
    m[k] = argv[++i];
  }
  return m;
}

String _abs(String root, String p) => File(p).isAbsolute ? p : '$root/$p';

Future<String> _onlyDevice() async {
  final r = await Process.run('adb', ['devices']);
  final serials = LineSplitter.split(r.stdout as String)
      .skip(1)
      .map((l) => l.split(RegExp(r'\s+')))
      .where((f) => f.length >= 2 && f[1] == 'device')
      .map((f) => f[0])
      .toList();
  if (serials.length != 1) {
    _fail('expected exactly one adb device, found $serials; pass --serial');
  }
  return serials.single;
}

Future<void> _ensureDataset(String root, Directory dataset) async {
  const files = ['dataset.cells.bin', 'dataset.segcells.bin'];
  if (files.every((f) => File('${dataset.path}/$f').existsSync())) return;
  stdout.writeln('device_run: generating seed-42 dataset in ${dataset.path}');
  final r = await Process.start(
    Platform.resolvedExecutable,
    ['run', 'tracegen', '--seed', '42', '--years', '5', '--out', dataset.path],
    workingDirectory: '$root/spike/tracegen',
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await r.exitCode;
  if (code != 0) _fail('tracegen exited with $code', code);
}

Future<Map<String, Object?>> _deviceInfo(String serial) async {
  Future<String> prop(String name) async {
    final r = await Process.run('adb', [
      '-s',
      serial,
      'shell',
      'getprop',
      name,
    ]);
    return (r.stdout as String).trim();
  }

  return {
    'serial': serial,
    'manufacturer': await prop('ro.product.manufacturer'),
    'model': await prop('ro.product.model'),
    'android': await prop('ro.build.version.release'),
    'sdk': await prop('ro.build.version.sdk'),
    'abi': await prop('ro.product.cpu.abi'),
    'emulator': await prop('ro.kernel.qemu') == '1',
    'utc': DateTime.now().toUtc().toIso8601String(),
  };
}

Never _fail(String message, [int code = 64]) {
  stderr.writeln('device_run: $message');
  exit(code);
}
