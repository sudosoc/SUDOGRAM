import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum VoiceFx { none, deep, monster, high, chipmunk, robot, telephone, echo, alien, cave, whisper, radio, megaphone, underwater, demon, vibrato }

extension VoiceFxInfo on VoiceFx {
  String get id => name;
  String label(bool ar) => switch (this) {
        VoiceFx.none => ar ? 'عادي' : 'Normal',
        VoiceFx.deep => ar ? 'صوت غليظ' : 'Deep',
        VoiceFx.monster => ar ? 'وحش' : 'Monster',
        VoiceFx.high => ar ? 'صوت رفيع' : 'High',
        VoiceFx.chipmunk => ar ? 'سنجاب' : 'Chipmunk',
        VoiceFx.robot => ar ? 'روبوت' : 'Robot',
        VoiceFx.telephone => ar ? 'تليفون' : 'Telephone',
        VoiceFx.echo => ar ? 'صدى' : 'Echo',
        VoiceFx.alien => ar ? 'فضائي' : 'Alien',
        VoiceFx.cave => ar ? 'كهف' : 'Cave',
        VoiceFx.whisper => ar ? 'همس' : 'Whisper',
        VoiceFx.radio => ar ? 'راديو' : 'Radio',
        VoiceFx.megaphone => ar ? 'ميكروفون عالي' : 'Megaphone',
        VoiceFx.underwater => ar ? 'تحت المية' : 'Underwater',
        VoiceFx.demon => ar ? 'شيطان' : 'Demon',
        VoiceFx.vibrato => ar ? 'مرتعش' : 'Wobble',
      };
  IconData get icon => switch (this) {
        VoiceFx.none => Icons.mic_none,
        VoiceFx.deep => Icons.south,
        VoiceFx.monster => Icons.pest_control,
        VoiceFx.high => Icons.north,
        VoiceFx.chipmunk => Icons.cruelty_free,
        VoiceFx.robot => Icons.smart_toy_outlined,
        VoiceFx.telephone => Icons.phone_in_talk_outlined,
        VoiceFx.echo => Icons.surround_sound_outlined,
        VoiceFx.alien => Icons.blur_on,
        VoiceFx.cave => Icons.landscape_outlined,
        VoiceFx.whisper => Icons.volume_down_outlined,
        VoiceFx.radio => Icons.radio_outlined,
        VoiceFx.megaphone => Icons.campaign_outlined,
        VoiceFx.underwater => Icons.water,
        VoiceFx.demon => Icons.local_fire_department_outlined,
        VoiceFx.vibrato => Icons.waves,
      };
}

VoiceFx voiceFxFrom(String? id) =>
    VoiceFx.values.firstWhere((e) => e.name == id, orElse: () => VoiceFx.none);

const _ch = MethodChannel('sudogram/window');
const kFxRate = 48000;

/// Result of processing: path of the OGG/Opus voice note + its length.
class FxResult {
  FxResult(this.path, this.seconds, {this.fallbackWav = false});
  final String path;
  final int seconds;

  /// True when Opus encoding was unavailable and a WAV was produced instead.
  final bool fallbackWav;
}

/// Applies [fx] to a 48 kHz mono 16-bit WAV recording and encodes the result
/// as OGG/Opus (what Telegram voice notes use).
Future<FxResult> applyVoiceFx(String wavPath, VoiceFx fx) async {
  final outWav = wavPath.replaceFirst(RegExp(r'\.wav$'), '_fx.wav');
  final samples = await Isolate.run(() => _processFile(wavPath, outWav, fx.index));
  final secs = (samples / kFxRate).ceil().clamp(1, 100000);
  final ogg = outWav.replaceFirst(RegExp(r'\.wav$'), '.ogg');
  try {
    await _ch.invokeMethod('encodeOpus', {'src': outWav, 'dst': ogg});
    return FxResult(ogg, secs);
  } catch (_) {
    return FxResult(outWav, secs, fallbackWav: true);
  }
}

// ------------------------------------------------------------- isolate

int _processFile(String inPath, String outPath, int fxIndex) {
  final x = _readWav(File(inPath).readAsBytesSync());
  var y = _run(x, VoiceFx.values[fxIndex]);
  var peak = 0.0;
  for (final v in y) {
    if (v.abs() > peak) peak = v.abs();
  }
  if (peak > 0) {
    final g = 0.89 / peak;
    if (g < 1 || peak < 0.3) {
      for (var i = 0; i < y.length; i++) {
        y[i] *= g.clamp(0.0, 3.0);
      }
    }
  }
  File(outPath).writeAsBytesSync(_writeWav(y));
  return y.length;
}

Float32List _readWav(Uint8List b) {
  final bd = ByteData.sublistView(b);
  var pos = 12;
  var dataAt = 44, dataLen = b.length - 44;
  while (pos + 8 <= b.length) {
    final id = String.fromCharCodes(b.sublist(pos, pos + 4));
    final len = bd.getUint32(pos + 4, Endian.little);
    if (id == 'data') {
      dataAt = pos + 8;
      dataLen = math.min(len, b.length - dataAt);
      break;
    }
    pos += 8 + len + (len & 1);
  }
  final n = dataLen ~/ 2;
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    out[i] = bd.getInt16(dataAt + i * 2, Endian.little) / 32768.0;
  }
  return out;
}

Uint8List _writeWav(Float32List y) {
  final n = y.length;
  final b = ByteData(44 + n * 2);
  void s(int o, String t) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(o + i, t.codeUnitAt(i));
    }
  }

  s(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
  s(8, 'WAVE');
  s(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, kFxRate, Endian.little);
  b.setUint32(28, kFxRate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  s(36, 'data');
  b.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    b.setInt16(44 + i * 2, (y[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

Float32List _run(Float32List x, VoiceFx fx) {
  switch (fx) {
    case VoiceFx.none:
      return x;
    case VoiceFx.deep:
      return _pitch(x, math.pow(2, -4 / 12).toDouble());
    case VoiceFx.monster:
      return _ring(_pitch(x, math.pow(2, -8 / 12).toDouble()), 28, 0.35);
    case VoiceFx.high:
      return _pitch(x, math.pow(2, 4 / 12).toDouble());
    case VoiceFx.chipmunk:
      return _pitch(x, math.pow(2, 8 / 12).toDouble());
    case VoiceFx.robot:
      return _comb(_ring(x, 55, 0.7), 436, 0.5);
    case VoiceFx.telephone:
      return _telephone(x);
    case VoiceFx.echo:
      return _echo(x);
    case VoiceFx.alien:
      return _ring(_pitch(x, math.pow(2, 3 / 12).toDouble()), 90, 0.5);
    case VoiceFx.cave:
      return _reverb(x);
    case VoiceFx.whisper:
      return _whisper(x);
    case VoiceFx.radio:
      return _radio(x);
    case VoiceFx.megaphone:
      return _megaphone(x);
    case VoiceFx.underwater:
      return _underwater(x);
    case VoiceFx.demon:
      return _echo(_ring(_pitch(x, math.pow(2, -10 / 12).toDouble()), 18, 0.3));
    case VoiceFx.vibrato:
      return _vibrato(x);
  }
}

/// Pitch shift keeping duration: WSOLA time-stretch, then resample.
Float32List _pitch(Float32List x, double r) {
  if (x.length < 8192) return x;
  final st = _stretch(x, r);
  final out = Float32List(x.length);
  for (var i = 0; i < out.length; i++) {
    final p = i * r;
    final i0 = p.floor();
    if (i0 + 1 >= st.length) break;
    final f = p - i0;
    out[i] = (st[i0] * (1 - f) + st[i0 + 1] * f).toDouble();
  }
  return out;
}

Float32List _stretch(Float32List x, double alpha) {
  const n = 2048, hs = 1024, delta = 512;
  final win = Float32List(n);
  for (var i = 0; i < n; i++) {
    win[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / n);
  }
  final outLen = (x.length * alpha).ceil() + n * 2;
  final out = Float32List(outLen);
  final ha = hs / alpha;

  for (var i = 0; i < n && i < x.length; i++) {
    out[i] += x[i] * win[i];
  }
  var prev = 0;
  for (var k = 1;; k++) {
    final outPos = k * hs;
    final target = (k * ha).round();
    if (outPos + n >= outLen || target + n + delta >= x.length) break;
    final nat = prev + hs;
    var best = target;
    if (nat + hs < x.length) {
      var bestC = -1e30;
      for (var d = -delta; d <= delta; d += 4) {
        final cand = target + d;
        if (cand < 0 || cand + hs >= x.length) continue;
        var c = 0.0, e = 1e-9;
        for (var i = 0; i < hs; i += 4) {
          final a = x[nat + i], b = x[cand + i];
          c += a * b;
          e += b * b;
        }
        final score = c / math.sqrt(e);
        if (score > bestC) {
          bestC = score;
          best = cand;
        }
      }
    }
    for (var i = 0; i < n; i++) {
      out[outPos + i] += x[best + i] * win[i];
    }
    prev = best;
  }
  return out;
}

Float32List _ring(Float32List x, double hz, double wet) {
  final y = Float32List(x.length);
  for (var i = 0; i < x.length; i++) {
    final m = math.sin(2 * math.pi * hz * i / kFxRate);
    y[i] = x[i] * (1 - wet) + x[i] * m * wet;
  }
  return y;
}

Float32List _comb(Float32List x, int delay, double g) {
  final y = Float32List.fromList(x);
  for (var i = delay; i < y.length; i++) {
    y[i] += g * y[i - delay];
  }
  return y;
}

Float32List _telephone(Float32List x) {
  final y = Float32List(x.length);
  // one-pole high-pass ~350 Hz, two-stage low-pass ~3200 Hz
  final hp = math.exp(-2 * math.pi * 350 / kFxRate);
  final lp = 1 - math.exp(-2 * math.pi * 3200 / kFxRate);
  var px = 0.0, py = 0.0, l1 = 0.0, l2 = 0.0;
  for (var i = 0; i < x.length; i++) {
    py = hp * (py + x[i] - px);
    px = x[i];
    l1 += lp * (py - l1);
    l2 += lp * (l1 - l2);
    y[i] = (math.tan(l2 * 1.6) * 0.8).clamp(-1.0, 1.0);
  }
  return y;
}

Float32List _echo(Float32List x) {
  const d = (kFxRate * 0.22) ~/ 1;
  final y = Float32List(x.length + kFxRate * 2);
  for (var i = 0; i < y.length; i++) {
    final dry = i < x.length ? x[i] : 0.0;
    y[i] = dry + (i >= d ? 0.42 * y[i - d] : 0.0);
  }
  return y;
}

Float32List _reverb(Float32List x) {
  const delays = [0.047, 0.071, 0.103, 0.149, 0.211];
  final y = Float32List(x.length + kFxRate * 2);
  for (var i = 0; i < x.length; i++) {
    y[i] = x[i];
  }
  for (final dsec in delays) {
    final d = (kFxRate * dsec).round();
    final c = Float32List(y.length);
    for (var i = 0; i < y.length; i++) {
      final dry = i < x.length ? x[i] : 0.0;
      c[i] = dry + (i >= d ? 0.62 * c[i - d] : 0.0);
    }
    for (var i = 0; i < y.length; i++) {
      y[i] += c[i] * 0.28;
    }
  }
  return y;
}

Float32List _hpf(Float32List x, double hz) {
  final a = math.exp(-2 * math.pi * hz / kFxRate);
  final y = Float32List(x.length);
  var px = 0.0, py = 0.0;
  for (var i = 0; i < x.length; i++) {
    py = a * (py + x[i] - px);
    px = x[i];
    y[i] = py;
  }
  return y;
}

Float32List _lpf(Float32List x, double hz, {int stages = 2}) {
  final a = 1 - math.exp(-2 * math.pi * hz / kFxRate);
  var cur = x;
  for (var s = 0; s < stages; s++) {
    final y = Float32List(cur.length);
    var st = 0.0;
    for (var i = 0; i < cur.length; i++) {
      st += a * (cur[i] - st);
      y[i] = st;
    }
    cur = y;
  }
  return cur;
}

Float32List _whisper(Float32List x) {
  final rnd = math.Random(7);
  final y = Float32List(x.length);
  final att = 1 - math.exp(-1 / (kFxRate * 0.004));
  final rel = 1 - math.exp(-1 / (kFxRate * 0.030));
  var env = 0.0, prev = 0.0;
  for (var i = 0; i < x.length; i++) {
    final a = x[i].abs();
    env += (a > env ? att : rel) * (a - env);
    final n = rnd.nextDouble() * 2 - 1;
    final hn = n - prev * 0.6; // tilt noise to the highs
    prev = n;
    y[i] = hn * env * 3.2;
  }
  final hp = _hpf(x, 1800);
  for (var i = 0; i < y.length; i++) {
    y[i] += hp[i] * 0.4;
  }
  return y;
}

Float32List _radio(Float32List x) {
  final b = _lpf(_hpf(x, 420), 2800);
  final rnd = math.Random(11);
  final y = Float32List(b.length);
  for (var i = 0; i < b.length; i++) {
    y[i] = _tanh(b[i] * 2.4) * 0.8 + (rnd.nextDouble() - 0.5) * 0.012;
  }
  return y;
}

double _tanh(double v) {
  final e = math.exp(2 * v.clamp(-12.0, 12.0));
  return (e - 1) / (e + 1);
}

Float32List _megaphone(Float32List x) {
  final b = _lpf(_hpf(x, 650), 3800);
  final y = Float32List(b.length);
  for (var i = 0; i < b.length; i++) {
    y[i] = (b[i] * 5).clamp(-0.55, 0.55).toDouble();
  }
  return _comb(y, 140, 0.35);
}

Float32List _underwater(Float32List x) {
  final b = _lpf(x, 650, stages: 3);
  final y = Float32List(b.length);
  for (var i = 0; i < b.length; i++) {
    final t = i / kFxRate;
    y[i] = b[i] * 2.8 * (1 + 0.45 * math.sin(2 * math.pi * 6 * t));
  }
  return y;
}

Float32List _vibrato(Float32List x) {
  final y = Float32List(x.length);
  for (var i = 0; i < x.length; i++) {
    final d = 70 + 60 * math.sin(2 * math.pi * 6 * i / kFxRate);
    final p = i - d;
    if (p < 0) continue;
    final i0 = p.floor();
    final f = p - i0;
    y[i] = (x[i0] * (1 - f) + x[math.min(i0 + 1, x.length - 1)] * f).toDouble();
  }
  return y;
}

// ---------------------------------------------------------------- preview

/// Spoken sample (same sentence in Arabic and English) processed with [fx],
/// so the user can hear a voice before using it. Uses the phone's own TTS.
class FxPreview {
  static const sentences = {
    'ar': 'مرحباً، أنا بجرّب تغيير الصوت في سودوجرام',
    'en': 'Hello, I am trying the voice changer in Sudogram',
  };
  static final _out = <String, String>{};
  static final _base = <String, String>{};

  /// Returns a playable wav path, or throws when the phone has no TTS voice.
  static Future<String> sample(String lang, VoiceFx fx, String dir) async {
    final key = '$lang-${fx.name}';
    final hit = _out[key];
    if (hit != null && File(hit).existsSync()) return hit;
    var base = _base[lang];
    if (base == null || !File(base).existsSync()) {
      final raw = '$dir/fxs_$lang.raw.wav';
      base = '$dir/fxs_$lang.wav';
      await _ch
          .invokeMethod('tts', {'text': sentences[lang], 'lang': lang, 'dst': raw})
          .timeout(const Duration(seconds: 25));
      await Isolate.run(() => _to48k(raw, base!));
      _base[lang] = base;
    }
    if (fx == VoiceFx.none) return _out[key] = base;
    final dst = '$dir/fxs_${lang}_${fx.name}.wav';
    await Isolate.run(() => _processFile(base!, dst, fx.index));
    return _out[key] = dst;
  }
}

int _to48k(String src, String dst) {
  final b = File(src).readAsBytesSync();
  final bd = ByteData.sublistView(b);
  var pos = 12, rate = 22050, ch = 1, at = 44, len = b.length - 44;
  while (pos + 8 <= b.length) {
    final id = String.fromCharCodes(b.sublist(pos, pos + 4));
    final l = bd.getUint32(pos + 4, Endian.little);
    if (id == 'fmt ') {
      ch = bd.getUint16(pos + 10, Endian.little);
      rate = bd.getUint32(pos + 12, Endian.little);
    } else if (id == 'data') {
      at = pos + 8;
      len = math.min(l, b.length - at);
      break;
    }
    pos += 8 + l + (l & 1);
  }
  final n = len ~/ (2 * ch);
  final mono = Float32List(n);
  for (var i = 0; i < n; i++) {
    mono[i] = bd.getInt16(at + i * 2 * ch, Endian.little) / 32768.0;
  }
  final outN = (n * kFxRate / rate).floor();
  final y = Float32List(outN);
  for (var i = 0; i < outN; i++) {
    final p = i * rate / kFxRate;
    final i0 = p.floor();
    final f = p - i0;
    y[i] = (mono[i0] * (1 - f) + mono[math.min(i0 + 1, n - 1)] * f).toDouble();
  }
  File(dst).writeAsBytesSync(_writeWav(y));
  return outN;
}

/// Exposed for tests.
@visibleForTesting
Float32List fxProcess(Float32List x, VoiceFx fx) => _run(x, fx);
