import 'dart:math' as math;

import 'package:characters/characters.dart';

/// Options for [SmartSplitter].
class SplitOptions {
  const SplitOptions({
    this.maxLength = 4096,
    this.numbering = false,
    this.keepDirection = true,
    this.fenceAware = true,
  });

  /// Hard limit per message. Read it from the server at runtime
  /// (`message_text_length_max`); 4096 is only the fallback.
  final int maxLength;

  /// Append `[i/n]` to every part.
  final bool numbering;

  /// Prefix parts with an RLM/LRM mark when their first strong character
  /// would otherwise flip the paragraph direction of the original text.
  final bool keepDirection;

  /// Close and reopen ``` code fences across part boundaries.
  final bool fenceAware;
}

/// Splits long text into messages that each fit the server limit.
///
/// Cut priority: paragraph break, line break, sentence end (Arabic and
/// English punctuation), clause punctuation, whitespace, and only as a last
/// resort a grapheme-safe hard cut. Lengths are measured in UTF-16 code units
/// (Dart's `String.length`), which is never smaller than a code-point count,
/// so parts stay within the limit however the server counts.
class SmartSplitter {
  const SmartSplitter._();

  static const _rlm = '‏';
  static const _lrm = '‎';
  static const _footerReserve = 12; // "\n\n[999/999]"
  static const _fenceClose = '\n```';

  static List<String> split(String text,
      [SplitOptions options = const SplitOptions()]) {
    if (options.maxLength < 32) {
      throw ArgumentError.value(
          options.maxLength, 'maxLength', 'must be at least 32');
    }
    if (text.length <= options.maxLength) return [text];

    final baseRtl = _firstStrongIsRtl(text) ?? false;
    final effective = options.maxLength -
        (options.numbering ? _footerReserve : 0) -
        (options.keepDirection ? 1 : 0);

    final bodies = <_Body>[];
    var rest = text;
    var inFence = false;
    var lang = '';
    var prefix = '';

    while (true) {
      final budget = effective - prefix.length;
      if (budget < 8) {
        throw StateError('maxLength is too small for this text');
      }
      if (rest.length <= budget) {
        bodies.add(_Body(prefix, rest, ''));
        break;
      }

      var cut = _findCut(rest, budget);
      var fence = options.fenceAware
          ? _fenceStateAt(rest, cut.end, inFence, lang)
          : (open: false, lang: '');
      if (fence.open) {
        cut = _findCut(rest, budget - _fenceClose.length);
        fence = _fenceStateAt(rest, cut.end, inFence, lang);
      }

      bodies.add(_Body(
        prefix,
        rest.substring(0, cut.end),
        fence.open ? _fenceClose : '',
      ));

      final nextStart = math.min(rest.length, cut.end + cut.skip);
      rest = rest.substring(nextStart);
      prefix = fence.open ? '```${fence.lang}\n' : '';
      inFence = fence.open;
      lang = fence.lang;
      if (rest.isEmpty) break;
    }

    final total = bodies.length;
    final out = <String>[];
    for (var i = 0; i < total; i++) {
      final b = bodies[i];
      var dirMark = '';
      if (options.keepDirection && i > 0 && b.prefix.isEmpty) {
        final rtl = _firstStrongIsRtl(b.content);
        if (rtl != null && rtl != baseRtl) {
          dirMark = baseRtl ? _rlm : _lrm;
        }
      }
      var part = '$dirMark${b.prefix}${b.content}${b.suffix}';
      if (options.numbering) part += '\n\n[${i + 1}/$total]';
      out.add(part);
    }
    return out;
  }

  /// Number of messages [text] would be split into.
  static int countParts(String text,
          [SplitOptions options = const SplitOptions()]) =>
      split(text, options).length;

  // ---------------------------------------------------------------- cuts

  static ({int end, int skip}) _findCut(String s, int maxCut) {
    final half = math.max(1, (maxCut * 0.5).floor());
    for (final minCut in [half, 1]) {
      final c = _lastParagraph(s, maxCut, minCut) ??
          _lastLine(s, maxCut, minCut) ??
          _lastEnder(s, maxCut, minCut, _sentenceEnders) ??
          _lastEnder(s, maxCut, minCut, _clauseEnders) ??
          _lastSpace(s, maxCut, minCut);
      if (c != null) return c;
    }
    return (end: _graphemeBoundary(s, maxCut), skip: 0);
  }

  static ({int end, int skip})? _lastParagraph(String s, int maxCut, int minCut) {
    final i = s.lastIndexOf('\n\n', maxCut);
    if (i < minCut) return null;
    var j = i;
    while (j < s.length && (s[j] == '\n' || s[j] == '\r')) {
      j++;
    }
    return (end: i, skip: j - i);
  }

  static ({int end, int skip})? _lastLine(String s, int maxCut, int minCut) {
    final i = s.lastIndexOf('\n', maxCut);
    if (i < minCut) return null;
    return (end: i, skip: 1);
  }

  static const _sentenceEnders = {'.', '!', '?', '؟', '…', '۔', '。'};
  static const _clauseEnders = {',', ';', ':', '،', '؛'};

  static ({int end, int skip})? _lastEnder(
      String s, int maxCut, int minCut, Set<String> enders) {
    for (var p = math.min(maxCut, s.length - 1); p >= minCut; p--) {
      if (_isBlank(s.codeUnitAt(p)) && enders.contains(s[p - 1])) {
        return (end: p, skip: _blankRun(s, p));
      }
    }
    return null;
  }

  static ({int end, int skip})? _lastSpace(String s, int maxCut, int minCut) {
    for (var p = math.min(maxCut, s.length - 1); p >= minCut; p--) {
      if (_isBlank(s.codeUnitAt(p))) {
        return (end: p, skip: _blankRun(s, p));
      }
    }
    return null;
  }

  static bool _isBlank(int u) => u == 0x20 || u == 0x09 || u == 0xA0;

  static int _blankRun(String s, int from) {
    var j = from;
    while (j < s.length && _isBlank(s.codeUnitAt(j))) {
      j++;
    }
    return j - from;
  }

  /// Largest index <= [maxCut] that does not fall inside a grapheme cluster
  /// (combining marks such as tashkeel, ZWJ emoji sequences, flags).
  static int _graphemeBoundary(String s, int maxCut) {
    var acc = 0;
    final window = s.substring(0, math.min(s.length, maxCut + 64));
    for (final g in window.characters) {
      if (acc + g.length > maxCut) break;
      acc += g.length;
    }
    if (acc > 0) return acc;
    // A single cluster longer than the limit: cut without splitting a
    // surrogate pair.
    var c = maxCut;
    final u = s.codeUnitAt(c - 1);
    if (u >= 0xD800 && u <= 0xDBFF) c -= 1;
    return math.max(1, c);
  }

  // --------------------------------------------------------------- fences

  static ({bool open, String lang}) _fenceStateAt(
      String s, int end, bool inFence, String lang) {
    var open = inFence;
    var curLang = lang;
    var i = 0;
    while (true) {
      final j = s.indexOf('```', i);
      if (j < 0 || j >= end) break;
      if (open) {
        open = false;
        curLang = '';
      } else {
        open = true;
        final nl = s.indexOf('\n', j + 3);
        final candidate =
            nl < 0 ? s.substring(j + 3) : s.substring(j + 3, nl);
        final trimmed = candidate.trim();
        curLang = RegExp(r'^[A-Za-z0-9_+\-#.]{0,24}$').hasMatch(trimmed)
            ? trimmed
            : '';
      }
      i = j + 3;
    }
    return (open: open, lang: curLang);
  }

  // ------------------------------------------------------------ direction

  /// true = RTL, false = LTR, null = no strong character.
  static bool? _firstStrongIsRtl(String s) {
    for (final r in s.runes) {
      if (_isRtlRune(r)) return true;
      if (_isLetter(r)) return false;
    }
    return null;
  }

  static bool _isRtlRune(int r) =>
      (r >= 0x0590 && r <= 0x08FF) ||
      (r >= 0xFB1D && r <= 0xFDFF) ||
      (r >= 0xFE70 && r <= 0xFEFF);

  static final RegExp _letter = RegExp(r'^\p{L}$', unicode: true);

  static bool _isLetter(int r) => _letter.hasMatch(String.fromCharCode(r));
}

class _Body {
  const _Body(this.prefix, this.content, this.suffix);

  final String prefix;
  final String content;
  final String suffix;
}
