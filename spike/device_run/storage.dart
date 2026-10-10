// M0 spike (W2 seam): the storage step of run_android.dart, owned by S01-20a1.
// Contract: README.md. Builds the storage_bench release APK, installs it,
// pushes dataset.segcells.bin, runs the bench N times (a fresh process each
// time), pulls each result JSON and the BENCH logcat lines, and writes
// summary.md (medians across runs).
//
//   dart spike/device_run/storage.dart --serial S --out DIR --dataset DIR
//       --device-json FILE [--runs 3] [--no-build] [--timeout-min 120]
//
// JAVA_HOME is passed through to Gradle unchanged; set it if the default JDK
// cannot build the APK.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const _pkg = 'com.example.footnoted.spike.storage_bench';
const _ext = '/sdcard/Android/data/$_pkg/files';
const _result = 'storage_bench_result.json';
const _error = 'storage_bench_error.txt';

late final String _serial;

Future<void> main(List<String> argv) async {
  final args = _parse(argv);
  final root = File.fromUri(Platform.script).parent.parent.parent.path;
  final bench = '$root/spike/storage_bench';
  _serial = args['serial'] ?? _fail('--serial is required');
  final out = Directory(args['out'] ?? _fail('--out is required'))
    ..createSync(recursive: true);
  final dataset = File(
    '${args['dataset'] ?? '$root/spike/out'}/'
    'dataset.segcells.bin',
  );
  if (!dataset.existsSync()) _fail('missing ${dataset.path}');
  final device = args['device-json'] == null
      ? await _deviceInfo()
      : jsonDecode(File(args['device-json']!).readAsStringSync())
            as Map<String, Object?>;
  final runs = int.parse(args['runs'] ?? '3');
  final timeout = Duration(minutes: int.parse(args['timeout-min'] ?? '120'));
  final meta = jsonDecode(
    File(dataset.path.replaceFirst(RegExp(r'\.bin$'), '.json'))
        .readAsStringSync(),
  ) as Map<String, Object?>;

  final apk = '$bench/build/app/outputs/flutter-apk/app-release.apk';
  if (args['no-build'] == null) {
    _say(
      'building the release APK (JAVA_HOME=${Platform.environment['JAVA_HOME']})',
    );
    await _exec('flutter', ['build', 'apk', '--release'], cwd: bench);
  }
  if (!File(apk).existsSync()) _fail('no APK at $apk');
  await _adb(['install', '-r', apk]);

  _say('pushing ${dataset.path}');
  await _adb(['shell', 'mkdir', '-p', _ext]);
  await _adb(['push', dataset.path, '$_ext/dataset.segcells.bin']);
  final onDevice = (await _adb([
    'shell',
    'sha256sum',
    '$_ext/dataset.segcells.bin',
  ])).split(RegExp(r'\s+')).first;
  if (onDevice != meta['sha256']) {
    _fail('dataset sha256 on the device $onDevice != ${meta['sha256']}');
  }

  final pulled = <String>[];
  for (var i = 1; i <= runs; i++) {
    _say('run $i/$runs');
    final f = '${out.path}/result-run$i.json';
    await _runOnce(f, '${out.path}/logcat-run$i.txt', timeout);
    final r = jsonDecode(File(f).readAsStringSync()) as Map<String, Object?>;
    final rows = (r['results'] as List).length;
    _say('run $i: $rows configurations, sqlite ${jsonEncode(r['sqlite'])}');
    if ((r['sqlite'] as Map)['cipher_available'] != true || rows != 8) {
      _fail('run $i: expected SQLCipher and 8 configurations, got $rows');
    }
    pulled.add(f);
  }

  final tables = await _exec(
    Platform.resolvedExecutable,
    ['run', 'tool/summarize.dart', ...pulled],
    cwd: bench,
    capture: true,
  );
  final emulator = device['emulator'] == true;
  final summary = StringBuffer()
    ..writeln(
      '# storage_bench on ${device['manufacturer']} ${device['model']}, '
      'release${emulator ? ' (*emulator — no pass/fail*)' : ''}',
    )
    ..writeln()
    ..writeln(
      '- **Device:** ${device['manufacturer']} ${device['model']}, Android '
      '${device['android']} (SDK ${device['sdk']}), ${device['abi']}, serial '
      '`${device['serial']}`${emulator ? ' — **emulator — no pass/fail**' : ''}',
    )
    ..writeln(
      '- **Build:** release APK (`flutter build apk --release`), '
      'SQLCipher via the root `hooks.user_defines` (D-011)',
    )
    ..writeln(
      '- **Method:** $runs launch${runs == 1 ? '' : 'es'}, each a fresh process '
      '(`am force-stop` + `am start`); every number is the median across '
      'launches. Per configuration: a fresh database, leg insert, full insert '
      'in one transaction, VACUUM + size, `cell_rollups` build, tile queries '
      '(one checked warm-up + median of 5), leg delete.',
    )
    ..writeln(
      '- **Dataset:** `${meta['source_trace']}` → `dataset.segcells.bin` '
      'sha256 `${meta['sha256']}` (verified on the device)',
    )
    ..writeln('- **Collected:** ${DateTime.now().toUtc().toIso8601String()}')
    ..writeln()
    ..write(tables);
  File('${out.path}/summary.md').writeAsStringSync(summary.toString());
  _say('wrote ${out.path}/summary.md');
}

Future<void> _runOnce(
  String resultPath,
  String logPath,
  Duration timeout,
) async {
  await _adb(['shell', 'am', 'force-stop', _pkg]);
  await _adb([
    'shell',
    'rm',
    '-f',
    '$_ext/$_result',
    '$_ext/$_result.tmp',
    '$_ext/$_error',
  ]);
  await _adb(['shell', 'am', 'start', '-W', '-n', '$_pkg/.MainActivity']);
  var pid = '';
  for (var i = 0; i < 20 && pid.isEmpty; i++) {
    pid = (await _adb(['shell', 'pidof', _pkg], check: false)).trim();
    if (pid.isEmpty) await Future<void>.delayed(const Duration(seconds: 1));
  }
  if (pid.isEmpty) _fail('$_pkg did not start');

  final log = File(logPath).openWrite();
  final logcat = await Process.start('adb', [
    '-s',
    _serial,
    'logcat',
    '-v',
    'threadtime',
    '--pid=$pid',
  ]);
  final done = Completer<void>();
  logcat.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((
    l,
  ) {
    if (l.contains('BENCH_RESULT ')) return;
    log.writeln(l);
    if (l.contains('BENCH ')) {
      final i = l.indexOf('BENCH ');
      stdout.writeln('  ${l.substring(i, math.min(l.length, i + 160))}');
    }
  }, onDone: done.complete);

  final sw = Stopwatch()..start();
  try {
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 5));
      final ls = await _adb(['shell', 'ls', _ext], check: false);
      if (ls.contains(_error)) {
        await _adb(['pull', '$_ext/$_error', '$resultPath.error.txt']);
        _fail(
          'the app failed: ${File('$resultPath.error.txt').readAsStringSync()}',
        );
      }
      if (LineSplitter.split(ls).any((f) => f.trim() == _result)) break;
      if ((await _adb(['shell', 'pidof', _pkg], check: false)).trim() != pid) {
        _fail('$_pkg (pid $pid) died before writing $_result; see $logPath');
      }
      if (sw.elapsed > timeout) _fail('timed out after $timeout');
    }
    await _adb(['pull', '$_ext/$_result', resultPath]);
  } finally {
    logcat.kill();
    await done.future.timeout(const Duration(seconds: 10), onTimeout: () {});
    await log.close();
  }
  _say('pulled $resultPath after ${sw.elapsed.inSeconds} s');
}

// The same fields as run_android.dart's device.json, for direct runs.
Future<Map<String, Object?>> _deviceInfo() async {
  Future<String> prop(String name) async =>
      (await _adb(['shell', 'getprop', name])).trim();
  return {
    'serial': _serial,
    'manufacturer': await prop('ro.product.manufacturer'),
    'model': await prop('ro.product.model'),
    'android': await prop('ro.build.version.release'),
    'sdk': await prop('ro.build.version.sdk'),
    'abi': await prop('ro.product.cpu.abi'),
    'emulator': await prop('ro.kernel.qemu') == '1',
  };
}

Future<String> _adb(List<String> args, {bool check = true}) =>
    _exec('adb', ['-s', _serial, ...args], capture: true, check: check);

Future<String> _exec(
  String exe,
  List<String> args, {
  String? cwd,
  bool capture = false,
  bool check = true,
}) async {
  if (!capture) {
    final p = await Process.start(
      exe,
      args,
      workingDirectory: cwd,
      runInShell: Platform.isWindows,
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await p.exitCode;
    if (check && code != 0) _fail('$exe ${args.join(' ')} exited with $code');
    return '';
  }
  final r = await Process.run(
    exe,
    args,
    workingDirectory: cwd,
    runInShell: Platform.isWindows && exe == 'flutter',
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (check && r.exitCode != 0) {
    _fail('$exe ${args.join(' ')} exited with ${r.exitCode}: ${r.stderr}');
  }
  return r.stdout as String;
}

Map<String, String> _parse(List<String> argv) {
  const valued = {
    'serial',
    'out',
    'dataset',
    'device-json',
    'runs',
    'timeout-min',
  };
  const flags = {'no-build'};
  final m = <String, String>{};
  for (var i = 0; i < argv.length; i++) {
    final k = argv[i].replaceFirst(RegExp('^--'), '');
    if (flags.contains(k)) {
      m[k] = 'true';
    } else if (valued.contains(k) && i + 1 < argv.length) {
      m[k] = argv[++i];
    } else {
      _fail('unknown or incomplete option ${argv[i]}');
    }
  }
  return m;
}

void _say(String s) => stdout.writeln('storage: $s');

Never _fail(String message) {
  stderr.writeln('storage: $message');
  exit(1);
}
