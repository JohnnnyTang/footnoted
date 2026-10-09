// M0 spike (W2): the render step of run_android.dart, owned by S01-20a2.
// Contract: README.md. Throwaway; removed at G1-B.
//
// Builds the render_bench profile APK (JDK 21), installs it, pushes
// dataset.segcells.bin, runs the configuration matrix below through
// spike/render_bench/bin/measure.dart (the app builds its keyed SQLCipher
// coverage DB on the first launch of each layout, before any pass), then
// writes runs.md and criterion2.md into --out.
//
// Extra options for manual use (the driver passes none): --no-build (reuse the
// installed APK), --runs N (z10 runs per configuration, default 3).
import 'dart:convert';
import 'dart:io';

const _pkg = 'com.example.footnoted.spike.render_bench';
const _remote = '/sdcard/Android/data/$_pkg/files';
const _defaultJdk = 'D:/software/jdk-21.0.12.1+1';

typedef Config = ({
  int zoom,
  String strategy,
  bool texture,
  String layout,
  bool spot,
});

// z10: (a) holes d6 on VD is the candidate; (b) inverse and TextureView are
// controls; layout A is the G1(c) alternative. Spot runs catch level-mapping
// cliffs (cell level = tile zoom + 6).
const _z10 = <Config>[
  (zoom: 10, strategy: 'holes', texture: false, layout: 'B', spot: false),
  (zoom: 10, strategy: 'inverse', texture: false, layout: 'B', spot: false),
  (zoom: 10, strategy: 'holes', texture: true, layout: 'B', spot: false),
];
const _once = <Config>[
  (zoom: 10, strategy: 'holes', texture: false, layout: 'A', spot: false),
  (zoom: 5, strategy: 'holes', texture: false, layout: 'B', spot: true),
  (zoom: 14, strategy: 'holes', texture: false, layout: 'B', spot: true),
  (zoom: 18, strategy: 'holes', texture: false, layout: 'B', spot: true),
];

late final String _root;
late final String _serial;

Future<void> main(List<String> argv) async {
  final args = _parse(argv);
  _root = Directory.current.path;
  _serial = args['serial'] ?? _fail('--serial is required');
  final out = Directory(args['out'] ?? _fail('--out is required'))
    ..createSync(recursive: true);
  final dataset = args['dataset'] ?? '$_root/spike/out';
  final device = jsonDecode(
    File(args['device-json'] ?? _fail('--device-json is required'))
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  final runsPerConfig = int.parse(args['runs'] ?? '3');
  final emulator = device['emulator'] == true;
  final label =
      '${device['manufacturer']} ${device['model']}, '
      'Android ${device['android']}${emulator ? ' (emulator)' : ''}';
  final bench = '$_root/spike/render_bench';
  final log = <String, Object?>{
    'device': device,
    'label': label,
    'build_mode': 'profile',
    'started_utc': DateTime.now().toUtc().toIso8601String(),
    'git_head': (await _run('git', ['rev-parse', 'HEAD'])).trim(),
  };

  if (!argv.contains('--no-build')) {
    final jdk = _jdk21();
    final abi = '${device['abi']}';
    final target = switch (abi) {
      'x86_64' => 'android-x64',
      'arm64-v8a' => 'android-arm64',
      'armeabi-v7a' => 'android-arm',
      _ => _fail('unsupported ABI $abi'),
    };
    _say('building the profile APK for $target (JAVA_HOME=$jdk)');
    final sw = Stopwatch()..start();
    await _stream(
      'flutter',
      ['build', 'apk', '--profile', '--target-platform', target],
      dir: bench,
      env: {'JAVA_HOME': jdk},
    );
    log['build'] = {
      'java_home': jdk,
      'target_platform': target,
      'seconds': sw.elapsed.inSeconds,
    };
  }
  final apk = File('$bench/build/app/outputs/flutter-apk/app-profile.apk');
  if (!apk.existsSync()) _fail('no ${apk.path}; build it or drop --no-build');
  log['apk_bytes'] = apk.lengthSync();
  _say('installing ${apk.path}');
  await _stream('adb', ['-s', _serial, 'install', '-r', apk.path]);

  await _push(dataset, 'dataset.segcells.bin');
  await _push(dataset, 'dataset.segcells.json', optional: true);

  final plan = <Config>[
    for (var r = 0; r < runsPerConfig; r++) ..._z10,
    ..._once,
  ];
  final runsDir = '${out.path}/runs';
  final done = <Map<String, Object>>[];
  for (final (i, c) in plan.indexed) {
    _say(
      'run ${i + 1}/${plan.length}: z${c.zoom} ${c.strategy} '
      '${c.texture ? 'TextureView' : 'VD'} layout ${c.layout}',
    );
    var attempt = 0;
    while (true) {
      attempt++;
      final code = await _stream(
        Platform.resolvedExecutable,
        [
          'run',
          'bin/measure.dart',
          '--serial',
          _serial,
          '--label',
          label,
          '--strategy',
          c.strategy,
          '--texture',
          '${c.texture}',
          '--zoom',
          '${c.zoom}',
          '--layout',
          c.layout,
          '--source',
          'db',
          '--out',
          runsDir,
        ],
        dir: bench,
        check: false,
      );
      if (code == 0) break;
      if (code == 3 && attempt < 3) {
        _say('preempted; retrying');
        continue;
      }
      _fail('measure.dart exited with $code (attempt $attempt)', code);
    }
    done.add({
      'zoom': c.zoom,
      'strategy': c.strategy,
      'texture': c.texture,
      'layout': c.layout,
      'spot': c.spot,
      'attempts': attempt,
    });
  }
  log['runs'] = done;
  log['finished_utc'] = DateTime.now().toUtc().toIso8601String();

  final table = await _run(Platform.resolvedExecutable, [
    'run',
    'bin/summarize.dart',
    runsDir,
  ], dir: bench);
  File('${out.path}/runs.md').writeAsStringSync(
    '# render_bench runs — $label, profile'
    '${emulator ? ' — emulator — no pass/fail' : ''}\n\n$table',
  );
  await _run(Platform.resolvedExecutable, [
    'run',
    'bin/criterion2.dart',
    '--runs',
    runsDir,
    '--device-json',
    args['device-json']!,
    '--out',
    '${out.path}/criterion2.md',
  ], dir: bench);
  File('${out.path}/step.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(log));
  // The driver prints <out>/render/criterion2.md; this step's --out is that
  // directory.
  _say('done → ${out.path}');
}

String _jdk21() {
  bool is21(String home) {
    final rel = File('$home/release');
    return rel.existsSync() &&
        rel.readAsStringSync().contains('JAVA_VERSION="21');
  }

  for (final home in [
    Platform.environment['RB_JAVA_HOME'],
    Platform.environment['JAVA_HOME'],
    _defaultJdk,
  ]) {
    if (home != null && home.isNotEmpty && is21(home)) return home;
  }
  _fail(
    'no JDK 21 found: set RB_JAVA_HOME (maplibre_gl 0.27.1 needs JDK 21, '
    'MEASURE.md §3)',
  );
}

Future<void> _push(String dir, String name, {bool optional = false}) async {
  final local = File('$dir/$name');
  if (!local.existsSync()) {
    if (optional) return;
    _fail('missing ${local.path}');
  }
  await _run('adb', ['-s', _serial, 'shell', 'mkdir', '-p', _remote]);
  final remote = '$_remote/$name';
  final size = (await _run('adb', [
    '-s',
    _serial,
    'shell',
    'stat -c %s $remote 2>/dev/null || echo -1',
  ], check: false)).trim();
  if (size == '${local.lengthSync()}') {
    _say('$name already on the device ($size bytes)');
    return;
  }
  _say('pushing $name (${local.lengthSync()} bytes)');
  await _stream('adb', ['-s', _serial, 'push', local.path, remote]);
}

Future<String> _run(
  String exe,
  List<String> args, {
  String? dir,
  bool check = true,
}) async {
  final r = await Process.run(
    exe,
    args,
    workingDirectory: dir,
    runInShell: Platform.isWindows && exe == 'flutter',
    environment: const {'MSYS_NO_PATHCONV': '1'},
  );
  if (check && r.exitCode != 0) {
    stderr.write(r.stderr);
    _fail('$exe ${args.join(' ')} exited with ${r.exitCode}', r.exitCode);
  }
  return r.stdout as String;
}

Future<int> _stream(
  String exe,
  List<String> args, {
  String? dir,
  Map<String, String> env = const {},
  bool check = true,
}) async {
  final p = await Process.start(
    exe,
    args,
    workingDirectory: dir,
    runInShell: Platform.isWindows && exe == 'flutter',
    environment: {'MSYS_NO_PATHCONV': '1', ...env},
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await p.exitCode;
  if (check && code != 0) {
    _fail('$exe ${args.join(' ')} exited with $code', code);
  }
  return code;
}

Map<String, String> _parse(List<String> argv) {
  const valued = {'serial', 'out', 'dataset', 'device-json', 'runs'};
  const flags = {'no-build'};
  final m = <String, String>{};
  for (var i = 0; i < argv.length; i++) {
    final k = argv[i].replaceFirst(RegExp('^--'), '');
    if (flags.contains(k)) continue;
    if (!valued.contains(k) || i + 1 >= argv.length) {
      _fail(
        'usage: render.dart --serial S --out DIR --dataset DIR '
        '--device-json F [--no-build] [--runs N]',
      );
    }
    m[k] = argv[++i];
  }
  return m;
}

void _say(String s) => stdout.writeln('render: $s');

Never _fail(String message, [int code = 1]) {
  stderr.writeln('render: $message');
  exit(code == 0 ? 1 : code);
}
