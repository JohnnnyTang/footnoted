// Exit criterion 2 from measure.dart run directories (summary.json +
// app_result.json): per configuration, the worst measured pass of the
// SurfaceFlinger BLAST layer against median_fps ≥ 55 and pct_over_32ms ≤ 5.
// Pure Dart, so the host scripts and the tests share it.

const minMedianFps = 55.0;
const maxPctOver32 = 5.0;

class PassFrames {
  const PassFrames(this.medianFps, this.pctOver32, this.frames);
  final double medianFps, pctOver32;
  final int frames;
}

class RunResult {
  RunResult({
    required this.config,
    required this.zoom,
    required this.passes,
    this.coverage = const {},
  });

  /// Parses one run directory's `summary.json` (and optionally its
  /// `app_result.json`). Passes without a BLAST layer are kept as `null`.
  factory RunResult.fromJson(
    Map<String, dynamic> summary, [
    Map<String, dynamic>? app,
  ]) {
    final passes = <PassFrames?>[];
    final byPass = (summary['passes'] as Map<String, dynamic>).entries.toList()
      ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
    for (final e in byPass) {
      final sf = (e.value['surfaceflinger'] as Map<String, dynamic>).entries
          .where((l) => l.key.contains('(BLAST)'))
          .map((l) => l.value as Map<String, dynamic>)
          .firstOrNull;
      passes.add(
        sf == null
            ? null
            : PassFrames(
                (sf['median_fps'] as num).toDouble(),
                (sf['pct_over_32ms'] as num).toDouble(),
                sf['frames'] as int,
              ),
      );
    }
    final zoom = (summary['zoom'] as num?)?.toDouble() ?? 10;
    final fog = summary['fog'] != false;
    final view = summary['texture'] == true
        ? 'TextureView'
        : 'GLSurfaceView/VD';
    final source = summary['source'] as String? ?? 'memory';
    final layout = summary['layout'] as String? ?? '';
    final config = [
      'z${_num(zoom)}',
      view,
      fog ? '${summary['strategy']} d${summary['detail'] ?? 6}' : 'fog off',
      if (fog) source == 'db' ? 'SQLCipher layout $layout' : source,
    ].join(' · ');
    final data = (app?['data'] as Map<String, dynamic>?) ?? const {};
    final db = (data['db'] as Map<String, dynamic>?) ?? const {};
    return RunResult(
      config: config,
      zoom: zoom,
      passes: passes,
      coverage: {
        if (db['cipher_version'] != null)
          'cipher_version': '${db['cipher_version']}',
        if (data['z20_cells'] != null) 'z20_cells': '${data['z20_cells']}',
      },
    );
  }

  final String config;
  final double zoom;
  final List<PassFrames?> passes;
  final Map<String, String> coverage;
}

class ConfigVerdict {
  ConfigVerdict(this.config, this.zoom);
  final String config;
  final double zoom;
  int runs = 0, passes = 0, missing = 0;
  double worstFps = double.infinity, worstOver32 = 0;
  int minFrames = 1 << 30;

  bool get hasData => passes > 0;
  bool get met =>
      hasData &&
      missing == 0 &&
      worstFps >= minMedianFps &&
      worstOver32 <= maxPctOver32;
}

List<ConfigVerdict> verdicts(List<RunResult> runs) {
  final out = <String, ConfigVerdict>{};
  for (final r in runs) {
    final v = out.putIfAbsent(r.config, () => ConfigVerdict(r.config, r.zoom));
    v.runs++;
    for (final p in r.passes) {
      if (p == null) {
        v.missing++;
        continue;
      }
      v.passes++;
      if (p.medianFps < v.worstFps) v.worstFps = p.medianFps;
      if (p.pctOver32 > v.worstOver32) v.worstOver32 = p.pctOver32;
      if (p.frames < v.minFrames) v.minFrames = p.frames;
    }
  }
  return out.values.toList();
}

/// The criterion-2 table. [device] is the driver's `device.json`.
String criterion2Markdown(
  List<RunResult> runs,
  Map<String, dynamic> device, {
  String buildMode = 'profile',
}) {
  final emulator = device['emulator'] == true;
  final label =
      '${device['manufacturer'] ?? '?'} ${device['model'] ?? '?'}, '
      'Android ${device['android'] ?? '?'} (SDK ${device['sdk'] ?? '?'}, '
      '${device['abi'] ?? '?'}), serial ${device['serial'] ?? '?'}';
  final ciphers = {
    for (final r in runs)
      if (r.coverage['cipher_version'] != null) r.coverage['cipher_version']!,
  };
  final cells = {
    for (final r in runs)
      if (r.coverage['z20_cells'] != null) r.coverage['z20_cells']!,
  };
  final b = StringBuffer()
    ..writeln('# Exit criterion 2 — Android render step')
    ..writeln()
    ..writeln(
      '- **Device:** $label${emulator ? ' — **emulator — no pass/fail**' : ''}',
    )
    ..writeln('- **Build:** $buildMode')
    ..writeln(
      '- **Coverage:** z20 cells ${cells.isEmpty ? '?' : cells.join(', ')}; '
      'SQLCipher `cipher_version` from the fog\'s own connection: '
      '${ciphers.isEmpty ? 'none (no DB-backed run)' : ciphers.join(', ')}',
    )
    ..writeln(
      '- **Method:** SurfaceFlinger `--latency` on the Flutter '
      '`SurfaceView (BLAST)` layer, cut to each measured pass (20 s); the '
      'worst pass of every run of a configuration.',
    )
    ..writeln(
      '- **Bar:** median ≥ ${_num(minMedianFps)} fps and '
      '≤ ${_num(maxPctOver32)} % of frames over 32 ms on every measured pass, '
      'at z10. z5 / z14 / z18 rows are spot runs for level-mapping cliffs.',
    )
    ..writeln()
    ..writeln(
      '| configuration | runs | passes | worst median fps | '
      'worst % > 32 ms | min frames | verdict |',
    )
    ..writeln('|---|---|---|---|---|---|---|');
  for (final v in verdicts(runs)) {
    final String verdict;
    if (!v.hasData || v.missing > 0) {
      verdict = 'NO DATA (${v.missing} pass(es) without a BLAST layer)';
    } else if (emulator) {
      verdict = 'emulator — no pass/fail';
    } else if (v.zoom != 10) {
      verdict = 'spot (${v.met ? 'within' : 'outside'} the bar)';
    } else {
      verdict = v.met ? 'MET' : 'MISSED';
    }
    b.writeln(
      '| ${v.config} | ${v.runs} | ${v.passes} '
      '| ${v.hasData ? _num(v.worstFps) : '–'} '
      '| ${v.hasData ? _num(v.worstOver32) : '–'} '
      '| ${v.hasData ? v.minFrames : '–'} | $verdict |',
    );
  }
  return b.toString();
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
