import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path_provider/path_provider.dart';

import 'src/cells.dart';
import 'src/coverage_db.dart';
import 'src/coverage_source.dart';
import 'src/fog.dart';
import 'src/pan.dart';
import 'src/standin.dart';
import 'src/stats.dart';

const styleUrl = 'https://tiles.openfreemap.org/styles/dark';
const _launch = MethodChannel('render_bench/launch');

/// Launch options. On Android they come from `adb shell am start` extras (see
/// MEASURE.md); elsewhere the defaults apply.
class BenchArgs {
  BenchArgs(Map<Object?, Object?> m)
    : strategy = FogStrategy.values.firstWhere(
        (s) => s.name == m['strategy'],
        orElse: () => FogStrategy.holes,
      ),
      texture = m['texture'] == true,
      autorun = m['autorun'] == true,
      detail = (m['detail'] as int?) ?? 6,
      passes = (m['passes'] as int?) ?? 3,
      warmup = m['warmup'] != false,
      fog = m['fog'] != false,
      zoom = ((m['zoom'] as num?) ?? panZoom).toDouble(),
      source = m['source'] == 'memory' ? 'memory' : 'db',
      layout = Layout.parse(m['layout'] as String?),
      rebuild = m['rebuild'] == true,
      dataset = (m['dataset'] as String?) ?? 'dataset.cells.bin',
      segcells = (m['segcells'] as String?) ?? 'dataset.segcells.bin',
      label = (m['label'] as String?) ?? '';

  final FogStrategy strategy;
  final bool texture, autorun, warmup, fog, rebuild;
  final int detail, passes;
  final double zoom;

  /// `db`: the fog reads the SQLCipher database built from [segcells] in
  /// [layout] (the default). `memory`: W1's in-memory rollups of [dataset].
  final String source;
  final Layout layout;
  final String dataset, segcells, label;

  Map<String, Object> toJson() => {
    'zoom': zoom,
    'source': source,
    'layout': layout.label,
    'segcells': segcells,
    'strategy': strategy.name,
    'texture': texture,
    'platform_view': texture
        ? 'TextureView (Flutter texture layer)'
        : 'GLSurfaceView (Flutter virtual display)',
    'detail': detail,
    'passes': passes,
    'warmup': warmup,
    'fog': fog,
    'dataset': dataset,
    'label': label,
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // iOS (and any platform): `--dart-define=RB_AUTORUN=true` and friends.
  Map<Object?, Object?> raw = const {
    'autorun': bool.fromEnvironment('RB_AUTORUN'),
    'strategy': String.fromEnvironment('RB_STRATEGY', defaultValue: 'holes'),
    'detail': int.fromEnvironment('RB_DETAIL', defaultValue: 6),
    'passes': int.fromEnvironment('RB_PASSES', defaultValue: 3),
    'fog': bool.fromEnvironment('RB_FOG', defaultValue: true),
    'zoom': int.fromEnvironment('RB_ZOOM', defaultValue: 10),
    'source': String.fromEnvironment('RB_SOURCE', defaultValue: 'db'),
    'layout': String.fromEnvironment('RB_LAYOUT', defaultValue: 'B'),
    'rebuild': bool.fromEnvironment('RB_REBUILD'),
    'label': String.fromEnvironment('RB_LABEL'),
  };
  if (!kIsWeb && Platform.isAndroid) {
    final extras = await _launch.invokeMapMethod<Object?, Object?>('args');
    if (extras != null && extras.isNotEmpty) raw = extras;
  }
  final args = BenchArgs(raw);
  MapLibreMap.useHybridComposition = args.texture;
  runApp(SpikeApp(args: args));
}

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key, this.args, this.showMap = true});

  final BenchArgs? args;

  /// Widget tests run without the platform view.
  final bool showMap;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'render_bench',
      theme: ThemeData.dark(),
      home: BenchPage(args: args ?? BenchArgs(const {}), showMap: showMap),
    );
  }
}

class _Loaded {
  _Loaded(this.source, this.info);
  final CoverageSource source;
  final Map<String, Object> info;
}

class _Memory {
  _Memory(this.index, this.info);
  final CoverageIndex index;
  final Map<String, Object> info;
}

_Memory _load(String dir, String name) {
  final sw = Stopwatch()..start();
  final file = File('$dir/$name');
  final Int64List z20;
  final Map<String, Object> info;
  if (file.existsSync()) {
    z20 = readCellsBin(file);
    info = {'source': file.path};
  } else {
    const p = StandInParams();
    z20 = generateStandIn(p);
    info = {'source': 'stand-in (generated in app)', 'params': p.toJson()};
  }
  final readMs = sw.elapsedMilliseconds;
  final index = CoverageIndex.fromZ20(z20);
  info.addAll({
    'z20_cells': z20.length,
    'load_ms': readMs,
    'rollup_ms': sw.elapsedMilliseconds - readMs,
    'cells_by_level': {
      for (final l in [8, 10, 12, 14, 16, 18, 20]) '$l': index.count(l),
    },
  });
  return _Memory(index, info);
}

// Top-level so the closures capture only plain values, not a State.
Future<_Memory> _loadInIsolate(String dir, String name) =>
    Isolate.run(() => _load(dir, name));

Future<Map<String, Object>> _ensureDbInIsolate(
  String segcells,
  String db,
  String layout,
  bool rebuild,
) => Isolate.run(
  () => ensureCoverageDb(
    segcellsPath: segcells,
    dbPath: db,
    layout: Layout.parse(layout),
    rebuild: rebuild,
  ),
);

/// Opens the fog's coverage source. The DB build (first run, or a changed
/// dataset) happens here, before any pass.
Future<_Loaded> _openSource(String dir, BenchArgs args) async {
  if (args.source == 'memory') {
    final m = await _loadInIsolate(dir, args.dataset);
    return _Loaded(MemorySource(m.index), {...m.info, 'coverage': 'memory'});
  }
  final segcells = '$dir/${args.segcells}';
  if (!File(segcells).existsSync()) {
    throw StateError('no $segcells; push dataset.segcells.bin (MEASURE.md)');
  }
  final dbPath = '$dir/rb_coverage_${args.layout.label}.db';
  final sw = Stopwatch()..start();
  final build = await _ensureDbInIsolate(
    segcells,
    dbPath,
    args.layout.label,
    args.rebuild,
  );
  final ensureMs = sw.elapsedMilliseconds;
  final source = await DbSource.open(dbPath, args.layout);
  final db = {
    ...source.info,
    'path': dbPath,
    'bytes': File(dbPath).lengthSync(),
    'ensure_ms': ensureMs,
    'open_ms': sw.elapsedMilliseconds - ensureMs,
    'build': build,
  };
  final segJson = File('$dir/${args.segcells.replaceAll('.bin', '.json')}');
  return _Loaded(source, {
    'coverage': 'db',
    'source': segcells,
    'z20_cells': ?build['z20_cells'],
    if (segJson.existsSync())
      'segcells_meta': (jsonDecode(segJson.readAsStringSync()) as Map)
          .cast<String, Object>(),
    'db': db,
  });
}

Future<Directory> filesDir() async {
  if (Platform.isAndroid) {
    final ext = await getExternalStorageDirectory();
    if (ext != null) return ext;
  }
  return getApplicationDocumentsDirectory();
}

class BenchPage extends StatefulWidget {
  const BenchPage({super.key, required this.args, this.showMap = true});

  final BenchArgs args;
  final bool showMap;

  @override
  State<BenchPage> createState() => _BenchPageState();
}

class _FogUpdate {
  _FogUpdate(this.stats, this.setMs, {this.encodeMs, this.bytes});
  final FogStats stats;
  final double setMs;
  final double? encodeMs;
  final int? bytes;

  Map<String, Object> toJson() => {
    ...stats.toJson(),
    'set_ms': setMs,
    'encode_ms': ?encodeMs,
    'bytes': ?bytes,
  };
}

class _BenchPageState extends State<BenchPage>
    with SingleTickerProviderStateMixin {
  late FogStrategy _strategy = widget.args.strategy;
  late int _detail = widget.args.detail;
  MapLibreMapController? _map;
  bool _styleReady = false;
  _Loaded? _data;
  FogBuilder? _fog;
  String _status = 'loading cells…';

  late ({double lat, double lon, double zoom}) _camera = (
    lat: panWaypoints.first.lat,
    lon: panWaypoints.first.lon,
    zoom: widget.args.zoom,
  );
  Set<TileKey> _shown = {};
  bool _fogBusy = false;
  bool _fogPending = false;
  _FogUpdate? _lastUpdate;
  final List<_FogUpdate> _passUpdates = [];

  late final Ticker _ticker = createTicker(_onTick);
  Completer<void>? _passDone;
  int _passFirstVsyncUs = 0, _passLastVsyncUs = 0;
  int _moves = 0, _movesSkipped = 0;
  bool _moveInFlight = false;
  final List<FrameTiming> _timings = [];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    if (widget.showMap) unawaited(_loadCells());
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _ticker.dispose();
    unawaited(_data?.source.close());
    super.dispose();
  }

  void _onTimings(List<FrameTiming> t) {
    if (_running) _timings.addAll(t);
  }

  Future<void> _loadCells() async {
    final dir = (await filesDir()).path;
    final _Loaded loaded;
    try {
      loaded = await _openSource(dir, widget.args);
    } catch (e) {
      debugPrint('RENDER_BENCH_ERROR $e');
      if (mounted) setState(() => _status = 'error: $e');
      return;
    }
    // The run log's proof that coverage comes from SQLCipher: cipher_version
    // read back from the connection the fog queries.
    if (loaded.info['db'] case final Map<String, Object> db) {
      debugPrint('RENDER_BENCH_DB ${jsonEncode(db)}');
    }
    debugPrint('RENDER_BENCH_DATA ${jsonEncode(loaded.info)}');
    if (!mounted) {
      unawaited(loaded.source.close());
      return;
    }
    setState(() {
      _data = loaded;
      _fog = FogBuilder(loaded.source, detail: _detail);
      final db = loaded.info['db'] as Map<String, Object>?;
      _status =
          '${loaded.info['z20_cells'] ?? '?'} z20 cells · '
          '${db == null ? 'memory' : 'SQLCipher ${db['cipher_version']} layout ${db['layout']}'}';
    });
    await _refreshFog(force: true, measureEncode: true);
    _maybeAutorun();
  }

  Future<void> _onStyleLoaded() async {
    final map = _map!;
    await map.addGeoJsonSource('fog', {
      'type': 'FeatureCollection',
      'features': <Object>[],
    });
    await map.addFillLayer(
      'fog',
      'fog-fill',
      const FillLayerProperties(
        fillColor: '#04060c',
        fillOpacity: 0.88,
        fillAntialias: false,
      ),
      enableInteraction: false,
    );
    _styleReady = true;
    _shown = {};
    await _refreshFog(force: true, measureEncode: true);
    _maybeAutorun();
  }

  bool _autorunStarted = false;
  void _maybeAutorun() {
    if (!widget.args.autorun || _autorunStarted) return;
    if (!_styleReady || _data == null) return;
    _autorunStarted = true;
    unawaited(_runBenchmark());
  }

  Size get _viewport => MediaQuery.sizeOf(context);

  /// Rebuilds the fog when the visible tiles are not all on the map already.
  /// One update in flight at a time; a request during one is coalesced.
  Future<void> _refreshFog({
    bool force = false,
    bool measureEncode = false,
  }) async {
    final fog = _fog, map = _map;
    if (fog == null || map == null || !_styleReady || !widget.args.fog) {
      return;
    }
    final size = _viewport;
    final core = visibleTiles(
      lat: _camera.lat,
      lon: _camera.lon,
      zoom: _camera.zoom,
      width: size.width,
      height: size.height,
      pad: 0,
    );
    if (!force && _shown.containsAll(core)) return;
    if (_fogBusy) {
      _fogPending = true;
      return;
    }
    _fogBusy = true;
    final tiles = visibleTiles(
      lat: _camera.lat,
      lon: _camera.lon,
      zoom: _camera.zoom,
      width: size.width,
      height: size.height,
    );
    final stats = FogStats();
    final Map<String, Object> geojson;
    try {
      geojson = await fog.build(_strategy, tiles, stats);
    } catch (e) {
      // measure.dart fails the run on this line.
      debugPrint('RENDER_BENCH_ERROR fog: $e');
      _fogBusy = false;
      rethrow;
    }
    double? encodeMs;
    int? bytes;
    if (measureEncode) {
      final sw = Stopwatch()..start();
      bytes = utf8.encode(jsonEncode(geojson)).length;
      encodeMs = sw.elapsedMicroseconds / 1000;
    }
    final sw = Stopwatch()..start();
    await map.setGeoJsonSource('fog', geojson);
    final update = _FogUpdate(
      stats,
      sw.elapsedMicroseconds / 1000,
      encodeMs: encodeMs,
      bytes: bytes,
    );
    _shown = tiles.toSet();
    _lastUpdate = update;
    if (_running) _passUpdates.add(update);
    _fogBusy = false;
    if (mounted && !_running) setState(() {});
    if (_fogPending) {
      _fogPending = false;
      await _refreshFog();
    }
  }

  void _onCameraMove(CameraPosition p) {
    if (_running) return;
    _camera = (lat: p.target.latitude, lon: p.target.longitude, zoom: p.zoom);
    unawaited(_refreshFog());
  }

  void _onCameraIdle() {
    final p = _map?.cameraPosition;
    if (p == null || _running) return;
    _camera = (lat: p.target.latitude, lon: p.target.longitude, zoom: p.zoom);
    unawaited(_refreshFog(measureEncode: true));
  }

  void _onTick(Duration elapsed) {
    final stamp = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    if (_passFirstVsyncUs == 0) _passFirstVsyncUs = stamp.inMicroseconds;
    _passLastVsyncUs = stamp.inMicroseconds;
    final t = elapsed.inMicroseconds / panDuration.inMicroseconds;
    final w = panAt(t, zoom: widget.args.zoom);
    _camera = (lat: w.lat, lon: w.lon, zoom: widget.args.zoom);
    if (_moveInFlight) {
      _movesSkipped++;
    } else {
      _moveInFlight = true;
      _moves++;
      _map!
          .moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(w.lat, w.lon),
                zoom: widget.args.zoom,
              ),
            ),
          )
          .whenComplete(() => _moveInFlight = false);
    }
    unawaited(_refreshFog());
    if (t >= 1) {
      _ticker.stop();
      _passDone?.complete();
    }
  }

  Future<void> _goToStart() async {
    final w = panWaypoints.first;
    _camera = (lat: w.lat, lon: w.lon, zoom: widget.args.zoom);
    await _map!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(w.lat, w.lon), zoom: widget.args.zoom),
      ),
    );
    await _refreshFog(force: true);
  }

  Future<Map<String, Object>> _runPass(int n) async {
    await _goToStart();
    await Future<void>.delayed(const Duration(seconds: 2));
    _timings.clear();
    _passUpdates.clear();
    _moves = _movesSkipped = 0;
    _passFirstVsyncUs = _passLastVsyncUs = 0;
    _passDone = Completer<void>();
    final wall = Stopwatch()..start();
    debugPrint('RENDER_BENCH_PASS $n start');
    _ticker.start();
    await _passDone!.future;
    final wallMs = wall.elapsedMilliseconds;
    // FrameTiming is reported in batches; let the last batch arrive.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final frames = _timings
        .where((f) {
          final v = f.timestampInMicroseconds(FramePhase.vsyncStart);
          return v >= _passFirstVsyncUs && v <= _passLastVsyncUs;
        })
        .toList(growable: false);
    final rasterEnds = [
      for (final f in frames)
        f.timestampInMicroseconds(FramePhase.rasterFinish) / 1000,
    ]..sort();
    final intervals = [
      for (var i = 1; i < rasterEnds.length; i++)
        rasterEnds[i] - rasterEnds[i - 1],
    ];
    final result = <String, Object>{
      'pass': n,
      'wall_ms': wallMs,
      'window_monotonic_us': [_passFirstVsyncUs, _passLastVsyncUs],
      'camera_moves': _moves,
      'camera_moves_skipped_busy': _movesSkipped,
      'flutter_frames': intervalStats(intervals),
      'flutter_build': durationStats([
        for (final f in frames) f.buildDuration.inMicroseconds / 1000,
      ]),
      'flutter_raster': durationStats([
        for (final f in frames) f.rasterDuration.inMicroseconds / 1000,
      ]),
      'fog_updates': {
        'n': _passUpdates.length,
        'queried_tiles': _passUpdates.fold<int>(
          0,
          (a, u) => a + u.stats.queried,
        ),
        'query': durationStats([for (final u in _passUpdates) u.stats.queryMs]),
        'wait': durationStats([for (final u in _passUpdates) u.stats.waitMs]),
        'build': durationStats([for (final u in _passUpdates) u.stats.buildMs]),
        'set': durationStats([for (final u in _passUpdates) u.setMs]),
        'max_rects': _passUpdates.fold<int>(
          0,
          (a, u) => a > u.stats.rects ? a : u.stats.rects,
        ),
      },
    };
    debugPrint('RENDER_BENCH_PASS $n end ${jsonEncode(result)}');
    return result;
  }

  Future<void> _runBenchmark() async {
    if (_running || _map == null) return;
    final viewport = _viewport;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    setState(() {
      _running = true;
      _status = 'running…';
    });
    final passes = <Map<String, Object>>[];
    if (widget.args.warmup) await _runPass(0);
    for (var i = 1; i <= widget.args.passes; i++) {
      passes.add(await _runPass(i));
    }
    _running = false;
    final result = {
      'args': widget.args.toJson(),
      'strategy': _strategy.name,
      'detail': _detail,
      'viewport_dp': [viewport.width, viewport.height],
      'dpr': dpr,
      'build_mode': kProfileMode
          ? 'profile'
          : kReleaseMode
          ? 'release'
          : 'debug',
      'pan': {
        'zoom': widget.args.zoom,
        'path_fraction': pathFraction(widget.args.zoom),
        'path_length_z10_tiles': panLengthTilesZ10,
        'duration_s': panDuration.inSeconds,
      },
      'data': _data!.info,
      'idle_fog_update': ?_lastUpdate?.toJson(),
      'passes': passes,
    };
    final dir = Directory('${(await filesDir()).path}/results')
      ..createSync(recursive: true);
    final name =
        'rb_${_strategy.name}_${widget.args.texture ? 'tex' : 'vd'}'
        '_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$name')
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
    debugPrint('RENDER_BENCH_DONE ${file.path}');
    if (mounted) setState(() => _status = 'done → $name');
  }

  Future<void> _setStrategy(FogStrategy s) async {
    setState(() => _strategy = s);
    _shown = {};
    await _refreshFog(force: true, measureEncode: true);
  }

  Future<void> _setDetail(int d) async {
    setState(() => _detail = d.clamp(2, 9));
    _fog?.detail = _detail;
    _shown = {};
    await _refreshFog(force: true, measureEncode: true);
  }

  @override
  Widget build(BuildContext context) {
    final u = _lastUpdate;
    final fogLine = u == null
        ? ''
        : 'L${u.stats.level} tiles ${u.stats.tiles} rects ${u.stats.rects} '
              'build ${u.stats.buildMs.toStringAsFixed(1)} ms'
              '${u.encodeMs == null ? '' : ' encode ${u.encodeMs!.toStringAsFixed(1)} ms ${(u.bytes! / 1024).toStringAsFixed(0)} KiB'}'
              ' set ${u.setMs.toStringAsFixed(1)} ms';
    return Scaffold(
      body: Stack(
        children: [
          if (widget.showMap)
            MapLibreMap(
              styleString: styleUrl,
              initialCameraPosition: CameraPosition(
                target: LatLng(panWaypoints.first.lat, panWaypoints.first.lon),
                zoom: widget.args.zoom,
              ),
              onMapCreated: (c) => _map = c,
              onStyleLoadedCallback: () => unawaited(_onStyleLoaded()),
              onCameraIdle: _onCameraIdle,
              trackCameraPosition: true,
              onCameraMove: _onCameraMove,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              compassEnabled: false,
              attributionButtonPosition: AttributionButtonPosition.bottomRight,
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                color: Colors.black54,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'render_bench · ${widget.args.texture ? 'TextureView' : 'GLSurfaceView/VD'} · $_status',
                    ),
                    if (fogLine.isNotEmpty)
                      Text(fogLine, style: const TextStyle(fontSize: 11)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final s in FogStrategy.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ChoiceChip(
                              label: Text(
                                s == FogStrategy.holes
                                    ? '(a) holes'
                                    : '(b) inverse',
                              ),
                              selected: _strategy == s,
                              onSelected: _running
                                  ? null
                                  : (_) => _setStrategy(s),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _running
                              ? null
                              : () => _setDetail(_detail - 1),
                        ),
                        Text('+$_detail'),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _running
                              ? null
                              : () => _setDetail(_detail + 1),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: _running ? null : _runBenchmark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomLeft,
            child: SafeArea(child: MapCredits()),
          ),
        ],
      ),
    );
  }
}

/// Always-visible credits (handoff, Compliance → Map attribution). The link to
/// the ODbL page and the About screen are S01-33's.
class MapCredits extends StatelessWidget {
  const MapCredits({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4, bottom: 4, right: 48),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: Colors.black54,
      child: const Text(
        '© OpenStreetMap contributors · '
        'OpenFreeMap © OpenMapTiles Data from OpenStreetMap',
        style: TextStyle(fontSize: 10, color: Colors.white70),
      ),
    );
  }
}
