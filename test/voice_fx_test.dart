import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudogram/core/voice_fx.dart';

double _crossings(Float32List y) {
  var c = 0;
  for (var i = 1; i < y.length; i++) {
    if ((y[i - 1] < 0) != (y[i] < 0)) c++;
  }
  return c / 2 / (y.length / kFxRate);
}

void main() {
  final x = Float32List(kFxRate * 2);
  for (var i = 0; i < x.length; i++) {
    x[i] = 0.5 * math.sin(2 * math.pi * 300 * i / kFxRate);
  }

  test('pitch effects keep duration and move frequency', () {
    final deep = fxProcess(x, VoiceFx.deep);
    final high = fxProcess(x, VoiceFx.chipmunk);
    expect(deep.length, x.length);
    expect(high.length, x.length);
    final f0 = _crossings(x);
    final trim = (deep.length * 0.2).round();
    final fd = _crossings(Float32List.sublistView(deep, trim, deep.length - trim));
    final fh = _crossings(Float32List.sublistView(high, trim, high.length - trim));
    expect(fd, lessThan(f0 * 0.9));
    expect(fh, greaterThan(f0 * 1.3));
  });

  test('echo extends, none is identity', () {
    expect(fxProcess(x, VoiceFx.echo).length, greaterThan(x.length));
    expect(identical(fxProcess(x, VoiceFx.none), x), true);
  });

  test('every effect gives finite, audible output', () {
    final noisy = Float32List(kFxRate * 2);
    final r = math.Random(3);
    for (var i = 0; i < noisy.length; i++) {
      noisy[i] = 0.4 * math.sin(2 * math.pi * 220 * i / kFxRate) * (0.6 + 0.4 * math.sin(i / 4000)) +
          (r.nextDouble() - .5) * .02;
    }
    for (final f in VoiceFx.values) {
      final y = fxProcess(noisy, f);
      var peak = 0.0;
      for (final v in y) {
        expect(v.isFinite, true, reason: f.name);
        if (v.abs() > peak) peak = v.abs();
      }
      expect(peak, greaterThan(0.005), reason: f.name);
    }
  });
}
