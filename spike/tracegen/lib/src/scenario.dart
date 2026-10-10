import 'dart:math' as math;

import 'package:footnoted_geo/footnoted_geo.dart' hide SegmentKind;

import 'model.dart';
import 'paths.dart';
import 'rng.dart';

/// Knobs that move the dataset size. Defaults hit about 1 M unique z20
/// cells for `--years 5` (see the S01-10 session note).
class Knobs {
  const Knobs({this.walkScale = 1.0});

  /// Multiplies the chance of every leisure walk (home and abroad).
  final double walkScale;
}

class _City {
  const _City(
    this.name,
    this.utcOffsetH,
    this.hotel,
    this.centres, {
    this.gridAngle = 0,
    this.block = 110,
  });

  final String name;
  final double utcOffsetH;
  final LatLng hotel;
  final List<(LatLng, double)> centres;
  final double gridAngle;
  final double block;

  Frame get frame => Frame(hotel, gridAngle);
}

class _Airport {
  const _Airport(this.code, this.at, this.city);
  final String code;
  final LatLng at;
  final _City city;
}

// Home: Mexico City. Low latitude keeps a 1,000 km × 500 m corridor near
// the handoff's ~0.8 M cells instead of ~1.4 M at 45°.
const _home = LatLng(19.3925, -99.1560); // Narvarte
const _workA = LatLng(19.4270, -99.1676); // Reforma, until 2023-07
const _workB = LatLng(19.3600, -99.2600); // Santa Fe, from 2023-07

const _cdmx = _City('Mexico City', -6, _home, [
  (LatLng(19.3925, -99.1560), 3), // Narvarte (home)
  (LatLng(19.3800, -99.1650), 2), // Del Valle
  (LatLng(19.4120, -99.1730), 3), // Condesa
  (LatLng(19.4180, -99.1600), 3), // Roma
  (LatLng(19.4330, -99.1330), 2), // Centro Histórico
  (LatLng(19.4200, -99.1890), 2), // Chapultepec
  (LatLng(19.4330, -99.1950), 1.5), // Polanco
  (LatLng(19.3500, -99.1620), 2), // Coyoacán
  (LatLng(19.3460, -99.1900), 1), // San Ángel
  (LatLng(19.3320, -99.1870), 1), // Ciudad Universitaria
  (LatLng(19.4500, -99.1600), 1), // Santa María la Ribera
  (LatLng(19.4510, -99.1370), 0.5), // Tlatelolco
  (LatLng(19.4840, -99.1170), 0.5), // Basílica
  (LatLng(19.2890, -99.1680), 0.5), // Tlalpan
  (LatLng(19.2570, -99.1030), 0.5), // Xochimilco
  (LatLng(19.3570, -99.0930), 0.3), // Iztapalapa
  (LatLng(19.4840, -99.1860), 0.3), // Azcapotzalco
  (LatLng(19.3590, -99.2590), 0.5), // Santa Fe
], gridAngle: 2);

const _cancun = _City('Cancún', -5, LatLng(21.1350, -86.7470), [
  (LatLng(21.1350, -86.7470), 2),
  (LatLng(21.1619, -86.8515), 1),
], gridAngle: 30);
const _madrid = _City('Madrid', 2, LatLng(40.4168, -3.7038), [
  (LatLng(40.4168, -3.7038), 2), // Sol
  (LatLng(40.4153, -3.6845), 1), // Retiro
  (LatLng(40.4260, -3.7040), 1), // Malasaña
  (LatLng(40.4110, -3.7100), 1), // La Latina
  (LatLng(40.4300, -3.6800), 1), // Salamanca
  (LatLng(40.4085, -3.7010), 1), // Lavapiés
], gridAngle: 8);
const _tokyo = _City(
  'Tokyo',
  9,
  LatLng(35.6900, 139.7000),
  [
    (LatLng(35.6900, 139.7000), 2), // Shinjuku
    (LatLng(35.6595, 139.7005), 1), // Shibuya
    (LatLng(35.7148, 139.7967), 1), // Asakusa
    (LatLng(35.6717, 139.7650), 1), // Ginza
    (LatLng(35.7138, 139.7773), 1), // Ueno
    (LatLng(35.6984, 139.7731), 1), // Akihabara
    (LatLng(35.6628, 139.7314), 1), // Roppongi
    (LatLng(35.6618, 139.6681), 1), // Shimokitazawa
  ],
  gridAngle: 20,
  block: 90,
);
const _honolulu = _City('Honolulu', -10, LatLng(21.2793, -157.8292), [
  (LatLng(21.2793, -157.8292), 2), // Waikiki
  (LatLng(21.2620, -157.8060), 1), // Diamond Head
  (LatLng(21.3069, -157.8583), 1), // Downtown
], gridAngle: 35);
const _helsinki = _City('Helsinki', 3, LatLng(60.1699, 24.9384), [
  (LatLng(60.1699, 24.9384), 2), // Keskusta
  (LatLng(60.1841, 24.9497), 1), // Kallio
  (LatLng(60.1567, 24.9381), 1), // Eira
  (LatLng(60.1800, 24.9200), 1), // Töölö
  (LatLng(60.1727, 24.9550), 1), // Kruununhaka
], gridAngle: 15);
const _monterrey = _City('Monterrey', -6, LatLng(25.6714, -100.3090), [
  (LatLng(25.6714, -100.3090), 2),
  (LatLng(25.6787, -100.2847), 1),
  (LatLng(25.6573, -100.4020), 1),
]);
const _slp = _City('San Luis Potosí', -6, LatLng(22.1510, -100.9765), [
  (LatLng(22.1510, -100.9765), 1),
]);
const _nuevoLaredo = _City('Nuevo Laredo', -6, LatLng(27.4980, -99.5070), [
  (LatLng(27.4980, -99.5070), 1),
]);
const _losAngeles = _City('Los Angeles', -7, LatLng(34.0522, -118.2437), [
  (LatLng(34.0522, -118.2437), 1),
]);
const _amsterdam = _City('Amsterdam', 2, LatLng(52.3676, 4.9041), [
  (LatLng(52.3676, 4.9041), 1),
]);

const _mex = _Airport('MEX', LatLng(19.4363, -99.0721), _cdmx);
const _cun = _Airport('CUN', LatLng(21.0365, -86.8771), _cancun);
const _mad = _Airport('MAD', LatLng(40.4983, -3.5676), _madrid);
const _hnd = _Airport('HND', LatLng(35.5494, 139.7798), _tokyo);
const _hnl = _Airport('HNL', LatLng(21.3245, -157.9251), _honolulu);
const _lax = _Airport('LAX', LatLng(33.9416, -118.4085), _losAngeles);
const _ams = _Airport('AMS', LatLng(52.3105, 4.7683), _amsterdam);
const _hel = _Airport('HEL', LatLng(60.3172, 24.9633), _helsinki);

// Highway 57 / 85 corridor; indices into this list name the stops.
const _corridorVia = [
  LatLng(19.4326, -99.1332), // 0 CDMX
  LatLng(20.5888, -100.3899), // 1 Querétaro
  LatLng(22.1565, -100.9855), // 2 San Luis Potosí
  LatLng(23.6486, -100.6436), // 3 Matehuala
  LatLng(25.4232, -101.0053), // 4 Saltillo
  LatLng(25.6866, -100.3161), // 5 Monterrey
  LatLng(27.4769, -99.5164), // 6 Nuevo Laredo
];
const _corridorNames = [
  'CDMX',
  'Querétaro',
  'San Luis Potosí',
  'Matehuala',
  'Saltillo',
  'Monterrey',
  'Nuevo Laredo',
];

typedef _DayAction = void Function(Rng rng, DateTime day);

class Scenario {
  Scenario({
    required this.seed,
    required this.years,
    this.knobs = const Knobs(),
  }) : start = DateTime.utc(2021, 1, 1),
       end = DateTime.utc(2021 + years, 1, 1);

  final int seed;
  final int years;
  final Knobs knobs;
  final DateTime start;
  final DateTime end;

  final List<Segment> _segments = [];
  int _lastEnd = 0;
  late final List<List<LatLng>> _corridorPieces;
  late final List<List<LatLng>> _commutesA;
  late final List<List<LatLng>> _commutesB;

  List<Segment> generate() {
    final master = Rng(seed);
    final roadRng = master.fork();
    _corridorPieces = [
      for (var i = 1; i < _corridorVia.length; i++)
        roadPolyline(roadRng, [_corridorVia[i - 1], _corridorVia[i]]),
    ];
    final commuteRng = master.fork();
    _commutesA = _commuteRoutes(commuteRng, _workA);
    _commutesB = _commuteRoutes(commuteRng, _workB);

    final trips = _trips();
    var day = start;
    while (day.isBefore(end)) {
      final rng = master.fork();
      final actions = trips[day];
      if (actions != null) {
        for (final a in actions) {
          a(rng, day);
        }
      } else {
        _homeDay(rng, day);
      }
      day = day.add(const Duration(days: 1));
    }
    for (var i = 0; i < _segments.length; i++) {
      _segments[i].id = i;
    }
    return _segments;
  }

  List<List<LatLng>> _commuteRoutes(Rng rng, LatLng work) => [
    for (var i = 0; i < 3; i++)
      manhattanPath(rng, _cdmx.frame, _home, work, block: 110, maxBlocks: 14),
  ];

  // ---- scheduling ----------------------------------------------------------

  int _startTs(Rng rng, DateTime day, double localHour, _City city) {
    final wanted =
        day.millisecondsSinceEpoch +
        ((localHour - city.utcOffsetH) * 3600000).round();
    final earliest = _lastEnd + rng.uniform(20, 90).round() * 60000;
    return math.max(wanted, earliest);
  }

  void _add(Segment s) {
    if (s.points.isEmpty) return;
    assert(s.startTs > _lastEnd);
    if (s.startTs >= end.millisecondsSinceEpoch) return;
    _segments.add(s);
    _lastEnd = s.endTs;
  }

  String _date(DateTime d) => d.toIso8601String().substring(0, 10);

  // ---- segment builders ----------------------------------------------------

  void _local(
    Rng rng,
    DateTime day,
    _City city,
    double hour,
    List<LatLng> path, {
    required String label,
    required String category,
    required double speed,
    double mediaShare = 0,
  }) {
    final ts = _startTs(rng, day, hour, city);
    _add(
      Segment(
        kind: SegmentKind.local,
        mode: JoinMode.straight,
        bufferM: 100,
        reveal: Reveal.line,
        label: '$label ${_date(day)}',
        category: category,
        points: samplePath(
          rng,
          path,
          startTs: ts,
          speedMps: speed,
          minM: 150,
          maxM: 400,
          accMin: 4,
          accMax: 25,
          mediaShare: mediaShare,
        ),
      ),
    );
  }

  void _walk(
    Rng rng,
    DateTime day,
    _City city,
    double hour,
    String category, {
    LatLng? from,
  }) {
    final weights = [for (final c in city.centres) c.$2];
    final centre = from ?? city.centres[rng.weighted(weights)].$1;
    final startAt = jitter(rng, centre, 350);
    final path = wanderLoop(
      rng,
      Frame(startAt, city.gridAngle),
      startAt,
      radiusM: rng.uniform(500, 2200),
      stops: 2 + rng.nextInt(3),
      block: city.block,
    );
    _local(
      rng,
      day,
      city,
      hour,
      path,
      label: '${city.name}: walk',
      category: category,
      speed: rng.uniform(1.1, 1.5),
      mediaShare: 0.08,
    );
  }

  void _transfer(
    Rng rng,
    DateTime day,
    _City city,
    double hour,
    LatLng a,
    LatLng b,
    String what,
    String category,
  ) {
    final path = manhattanPath(
      rng,
      Frame(a, city.gridAngle),
      a,
      b,
      block: city.block,
      maxBlocks: 15,
    );
    _local(
      rng,
      day,
      city,
      hour,
      path,
      label: '${city.name}: $what',
      category: category,
      speed: rng.uniform(6, 11),
    );
  }

  void _drive(Rng rng, DateTime day, double hour, int from, int to) {
    final pieces = from < to
        ? _corridorPieces.sublist(from, to)
        : _corridorPieces
              .sublist(to, from)
              .reversed
              .map((p) => p.reversed.toList());
    final path = <LatLng>[];
    for (final p in pieces) {
      path.addAll(path.isEmpty ? p : p.skip(1));
    }
    final ts = _startTs(rng, day, hour, _cdmx);
    _add(
      Segment(
        kind: SegmentKind.transit,
        mode: JoinMode.straight,
        bufferM: 500,
        reveal: Reveal.line,
        label:
            'road: ${_corridorNames[from]} → ${_corridorNames[to]} '
            '${_date(day)}',
        category: 'road',
        points: samplePath(
          rng,
          path,
          startTs: ts,
          speedMps: rng.uniform(22, 28),
          minM: 200,
          maxM: 600,
          accMin: 4,
          accMax: 15,
        ),
      ),
    );
  }

  void _fly(Rng rng, DateTime day, double hour, _Airport from, _Airport to) {
    final arc = densifyGreatCircle([
      from.at,
      to.at,
    ], maxStepDegrees: rng.uniform(1.0, 2.5));
    var ts = _startTs(rng, day, hour, from.city);
    final points = <TracePoint>[];
    var gate = jitter(rng, from.at, 40);
    points.add(TracePoint(ts, gate.lat, gate.lon, 10, false));
    ts += 20 * 60000; // taxi
    for (var i = 1; i < arc.length - 1; i++) {
      ts += (greatCircleMeters(arc[i - 1], arc[i]) / 230 * 1000).round();
      if (rng.chance(0.3)) continue; // no fix through the window
      final acc = rng.uniform(30, 300).roundToDouble();
      final p = jitter(rng, arc[i], acc / 2);
      points.add(TracePoint(ts, p.lat, p.lon, acc, false));
    }
    ts +=
        (greatCircleMeters(arc[arc.length - 2], arc.last) / 230 * 1000)
            .round() +
        15 * 60000;
    gate = jitter(rng, to.at, 40);
    points.add(TracePoint(ts, gate.lat, gate.lon, 10, false));
    _add(
      Segment(
        kind: SegmentKind.transit,
        mode: JoinMode.greatCircle,
        bufferM: 500,
        reveal: Reveal.endpoints,
        label: 'flight: ${from.code} → ${to.code} ${_date(day)}',
        category: 'flight',
        points: points,
      ),
    );
  }

  // ---- days ----------------------------------------------------------------

  void _homeDay(Rng rng, DateTime day) {
    final weekend = day.weekday >= DateTime.saturday;
    final s = knobs.walkScale;
    if (!weekend && !rng.chance(0.08)) {
      final routes = day.isBefore(DateTime.utc(2023, 7, 1))
          ? _commutesA
          : _commutesB;
      final am = routes[rng.weighted(const [0.6, 0.25, 0.15])];
      final pm = routes[rng.weighted(const [0.6, 0.25, 0.15])];
      _local(
        rng,
        day,
        _cdmx,
        rng.uniform(7.5, 8.5),
        am,
        label: 'home: commute am',
        category: 'home',
        speed: rng.uniform(5, 8),
      );
      _local(
        rng,
        day,
        _cdmx,
        rng.uniform(18, 19.5),
        pm.reversed.toList(),
        label: 'home: commute pm',
        category: 'home',
        speed: rng.uniform(5, 8),
      );
      if (rng.chance(0.05 * s)) {
        _walk(rng, day, _cdmx, 20.5, 'home', from: _home);
      }
      return;
    }
    if (!weekend) return;
    final p = day.weekday == DateTime.saturday ? 0.75 : 0.5;
    if (!rng.chance(math.min(1, p * s))) return;
    final weights = [for (final c in _cdmx.centres) c.$2];
    final centre = _cdmx.centres[rng.weighted(weights)].$1;
    final far = greatCircleMeters(_home, centre) > 3000;
    final hour = rng.uniform(9.5, 12);
    if (far && rng.chance(0.6)) {
      _transfer(rng, day, _cdmx, hour, _home, centre, 'drive out', 'home');
      _walk(rng, day, _cdmx, hour + 0.5, 'home', from: centre);
      _transfer(rng, day, _cdmx, hour + 3, centre, _home, 'drive back', 'home');
    } else {
      _walk(rng, day, _cdmx, hour, 'home', from: far ? centre : null);
    }
  }

  void _stayDay(Rng rng, DateTime day, _City city, {int maxWalks = 2}) {
    final n = 1 + rng.nextInt(maxWalks);
    for (var i = 0; i < n; i++) {
      if (i > 0 && !rng.chance(math.min(1, 0.8 * knobs.walkScale))) continue;
      _walk(rng, day, city, 10.0 + i * 5, 'stay');
    }
  }

  _DayAction _stay(_City city, {int maxWalks = 2}) =>
      (rng, day) => _stayDay(rng, day, city, maxWalks: maxWalks);

  _DayAction _flight(_Airport from, _Airport to, double hour) =>
      (rng, day) => _fly(rng, day, hour, from, to);

  _DayAction _road(int from, int to, double hour) =>
      (rng, day) => _drive(rng, day, hour, from, to);

  _DayAction _toAirport(_Airport a, double hour, {LatLng? fromPoint}) =>
      (rng, day) => _transfer(
        rng,
        day,
        a.city,
        hour,
        fromPoint ?? a.city.hotel,
        a.at,
        'to ${a.code}',
        a.city == _cdmx ? 'home' : 'stay',
      );

  _DayAction _fromAirport(_Airport a, double hour, {LatLng? toPoint}) =>
      (rng, day) => _transfer(
        rng,
        day,
        a.city,
        hour,
        a.at,
        toPoint ?? a.city.hotel,
        'from ${a.code}',
        a.city == _cdmx ? 'home' : 'stay',
      );

  Map<DateTime, List<_DayAction>> _trips() {
    final plan = <(DateTime, List<List<_DayAction>>)>[
      // Year 1: Cancún by air; road trip 1 (CDMX → Nuevo Laredo in one day).
      (
        DateTime.utc(2021, 3, 13),
        [
          [
            _toAirport(_mex, 7),
            _flight(_mex, _cun, 10),
            _fromAirport(_cun, 13),
          ],
          for (var i = 0; i < 4; i++) [_stay(_cancun)],
          [
            _toAirport(_cun, 12),
            _flight(_cun, _mex, 16),
            _fromAirport(_mex, 19),
          ],
        ],
      ),
      (
        DateTime.utc(2021, 12, 18),
        [
          [_road(0, 6, 5.0)],
          [_stay(_nuevoLaredo, maxWalks: 1)],
          [_road(6, 5, 9.0), _stay(_monterrey, maxWalks: 1)],
          [_stay(_monterrey)],
          [_stay(_monterrey)],
          [_road(5, 0, 6.0)],
        ],
      ),
      // Year 2: Madrid.
      (
        DateTime.utc(2022, 5, 14),
        [
          [_toAirport(_mex, 16, fromPoint: _home), _flight(_mex, _mad, 20)],
          [_fromAirport(_mad, 14), _stay(_madrid, maxWalks: 1)],
          for (var i = 0; i < 7; i++) [_stay(_madrid)],
          [
            _toAirport(_mad, 9),
            _flight(_mad, _mex, 12),
            _fromAirport(_mex, 19),
          ],
        ],
      ),
      // Year 3: road trip 2; Tokyo → Honolulu (antimeridian) → LA → home.
      (
        DateTime.utc(2023, 4, 1),
        [
          [_road(0, 2, 7.0)],
          [_stay(_slp)],
          [_road(2, 4, 8.0)],
          [_road(4, 5, 10.0), _stay(_monterrey, maxWalks: 1)],
          [_stay(_monterrey)],
          [_road(5, 0, 6.0)],
        ],
      ),
      (
        DateTime.utc(2023, 10, 7),
        [
          [_toAirport(_mex, 0.5, fromPoint: _home), _flight(_mex, _hnd, 2)],
          [],
          [_fromAirport(_hnd, 8), _stay(_tokyo, maxWalks: 1)],
          for (var i = 0; i < 9; i++) [_stay(_tokyo)],
          [_toAirport(_hnd, 18), _flight(_hnd, _hnl, 21)],
          [_fromAirport(_hnl, 12), _stay(_honolulu, maxWalks: 1)],
          [_stay(_honolulu)],
          [_stay(_honolulu)],
          [_toAirport(_hnl, 7), _flight(_hnl, _lax, 10)],
          [_flight(_lax, _mex, 8), _fromAirport(_mex, 16, toPoint: _home)],
        ],
      ),
      // Year 4: Helsinki via Amsterdam.
      (
        DateTime.utc(2024, 6, 15),
        [
          [_toAirport(_mex, 15, fromPoint: _home), _flight(_mex, _ams, 18)],
          [_flight(_ams, _hel, 15), _fromAirport(_hel, 19)],
          for (var i = 0; i < 6; i++) [_stay(_helsinki)],
          [
            _toAirport(_hel, 6),
            _flight(_hel, _ams, 9),
            _flight(_ams, _mex, 13),
            _fromAirport(_mex, 20, toPoint: _home),
          ],
        ],
      ),
      // Year 5: road trip 3.
      (
        DateTime.utc(2025, 7, 12),
        [
          [_road(0, 4, 6.0)],
          [_road(4, 5, 9.0), _stay(_monterrey, maxWalks: 1)],
          [_stay(_monterrey)],
          [_stay(_monterrey)],
          [_road(5, 0, 6.0)],
        ],
      ),
    ];
    final byDay = <DateTime, List<_DayAction>>{};
    for (final (first, days) in plan) {
      for (var i = 0; i < days.length; i++) {
        byDay[first.add(Duration(days: i))] = days[i];
      }
    }
    return byDay;
  }
}
