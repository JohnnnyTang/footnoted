import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:render_bench/src/cells.dart';
import 'package:render_bench/src/criterion.dart';
import 'package:render_bench/src/pan.dart';

double _mercDist(Waypoint a, Waypoint b) {
  final dx = lonToX(a.lon, 0) - lonToX(b.lon, 0);
  final dy = latToY(a.lat, 0) - latToY(b.lat, 0);
  return math.sqrt(dx * dx + dy * dy);
}

Map<String, dynamic> _summary(
  List<(double, double)?> passes, {
  double zoom = 10,
  bool texture = false,
  String strategy = 'holes',
}) => {
  'strategy': strategy,
  'texture': texture,
  'fog': true,
  'zoom': zoom,
  'source': 'db',
  'layout': 'B',
  'detail': 6,
  'passes': {
    for (var i = 0; i < passes.length; i++)
      '${i + 1}': {
        'surfaceflinger': {
          if (passes[i] case (final fps, final over))
            'SurfaceView[x/x.MainActivity]#1(BLAST)#2': {
              'median_fps': fps,
              'pct_over_32ms': over,
              'frames': 1100,
            },
          'other#3': {'median_fps': 1, 'pct_over_32ms': 99, 'frames': 2},
        },
      },
  },
};

void main() {
  test('the z10 pan runs from Mexico City to Monterrey at constant speed', () {
    final start = panAt(0), end = panAt(1);
    expect(start.lat, closeTo(19.42, 1e-6));
    expect(start.lon, closeTo(-99.20, 1e-6));
    expect(end.lat, closeTo(25.6866, 1e-6));
    expect(end.lon, closeTo(-100.3161, 1e-6));
    // A step that straddles a waypoint cuts the corner, so it is shorter;
    // every other step has the same length.
    final steps = [
      for (var i = 0; i < 1000; i++)
        _mercDist(panAt(i / 1000), panAt((i + 1) / 1000)),
    ]..sort();
    final typical = steps[steps.length ~/ 2];
    expect(steps.last, closeTo(typical, typical * 1e-6));
    expect(
      steps.where((s) => s < typical * 0.999).length,
      lessThan(panWaypoints.length),
    );
    expect(panLengthTilesZ10, inInclusiveRange(15, 40));
  });

  test('spot zooms keep the z10 screen speed inside Mexico City', () {
    expect(pathFraction(5), 1);
    expect(pathFraction(10), 1);
    expect(pathFraction(14), 1 / 16);
    expect(pathFraction(18), 1 / 256);
    final z18 = panAt(1, zoom: 18), z14 = panAt(1, zoom: 14);
    // z18 stays within a few km of the start, z14 inside the metro area.
    expect(_mercDist(panAt(0), z18) * 40075, lessThan(5));
    expect(z14.lat, inInclusiveRange(19.2, 19.9));
    expect(z14.lon, inInclusiveRange(-99.6, -98.9));
  });

  test('criterion 2 takes the worst pass of every run per configuration', () {
    final runs = [
      RunResult.fromJson(_summary([(59.0, 3.0), (57.0, 4.9), (58.0, 1.0)])),
      RunResult.fromJson(_summary([(58.0, 2.0), (55.0, 3.0), (60.0, 0.5)])),
      RunResult.fromJson(_summary([(50.0, 9.0)], texture: true)),
      RunResult.fromJson(_summary([(40.0, 20.0)], zoom: 18)),
      RunResult.fromJson(_summary([(59.0, 1.0), null])),
    ];
    final v = verdicts(runs.take(4).toList());
    expect(v.length, 3);
    expect((v[0].runs, v[0].passes), (2, 6));
    expect((v[0].worstFps, v[0].worstOver32), (55.0, 4.9));
    expect(v[0].met, isTrue);
    expect(v[1].met, isFalse);

    const phone = {
      'manufacturer': 'Acme',
      'model': 'P1',
      'android': '15',
      'emulator': false,
    };
    final md = criterion2Markdown(runs.take(4).toList(), phone);
    expect(md, contains('| MET |'));
    expect(md, contains('| MISSED |'));
    expect(md, contains('spot (outside the bar)'));
    expect(md, isNot(contains('no pass/fail')));

    final emu = criterion2Markdown(runs.take(4).toList(), {
      ...phone,
      'emulator': true,
    });
    expect(emu, isNot(contains('MET')));
    expect(emu, isNot(contains('MISSED')));
    expect('emulator — no pass/fail'.allMatches(emu).length, 4);

    final gap = criterion2Markdown([runs.last], phone);
    expect(gap, contains('NO DATA'));
  });

  test('criterion 2 shows the cipher_version of the fog connection', () {
    final r = RunResult.fromJson(_summary([(59.0, 1.0)]), {
      'data': {
        'z20_cells': 1169242,
        'db': {'cipher_version': '4.19.0 community'},
      },
    });
    final md = criterion2Markdown([r], const {'emulator': true});
    expect(md, contains('4.19.0 community'));
    expect(md, contains('1169242'));
    expect(r.config, 'z10 · GLSurfaceView/VD · holes d6 · SQLCipher layout B');
  });
}
