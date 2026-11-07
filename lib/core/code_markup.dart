/// A code entity inside a message text (UTF-16 offsets, like Telegram).
class TextEnt {
  const TextEnt(this.offset, this.length, this.block, [this.lang = '', this.style = '']);
  final int offset;
  final int length;

  /// For style entities: bold | italic | strike | underline | spoiler
  /// (empty for code entities).
  final String style;

  /// true = multi-line code block, false = inline code.
  final bool block;
  final String lang;
}

class ParsedText {
  const ParsedText(this.text, this.ents);
  final String text;
  final List<TextEnt> ents;
}

final _fence = RegExp(r'```([A-Za-z0-9_+#.\-]*)[ \t]*\r?\n?([\s\S]*?)```');
final _inline = RegExp(r'`([^`\n]+)`');
final _styles = <String, RegExp>{
  'bold': RegExp(r'\*\*(\S(?:[\s\S]*?\S)?)\*\*'),
  'italic': RegExp(r'__(\S(?:[\s\S]*?\S)?)__'),
  'strike': RegExp(r'~~(\S(?:[\s\S]*?\S)?)~~'),
  'spoiler': RegExp(r'\|\|(\S(?:[\s\S]*?\S)?)\|\|'),
};

/// Turns ```lang ... ``` blocks and `inline` code in typed text into
/// Telegram-style entities, removing the markers from the text.
ParsedText parseCode(String input) {
  if (!input.contains('`') &&
      !input.contains('**') &&
      !input.contains('__') &&
      !input.contains('~~') &&
      !input.contains('||')) {
    return ParsedText(input, const []);
  }
  final out = StringBuffer();
  final ents = <TextEnt>[];
  var last = 0;

  void styled(String s) {
    while (true) {
      RegExpMatch? best;
      String? bestStyle;
      for (final e in _styles.entries) {
        final m = e.value.firstMatch(s);
        if (m != null && (best == null || m.start < best.start)) {
          best = m;
          bestStyle = e.key;
        }
      }
      if (best == null) {
        out.write(s);
        return;
      }
      out.write(s.substring(0, best.start));
      final start = out.length;
      styled(best.group(1)!);
      ents.add(TextEnt(start, out.length - start, false, '', bestStyle!));
      s = s.substring(best.end);
    }
  }

  void plain(String s) {
    var l = 0;
    for (final m in _inline.allMatches(s)) {
      styled(s.substring(l, m.start));
      final code = m.group(1)!;
      ents.add(TextEnt(out.length, code.length, false));
      out.write(code);
      l = m.end;
    }
    styled(s.substring(l));
  }

  for (final m in _fence.allMatches(input)) {
    plain(input.substring(last, m.start));
    var code = m.group(2)!;
    if (code.endsWith('\n')) code = code.substring(0, code.length - 1);
    if (code.trim().isNotEmpty) {
      ents.add(TextEnt(out.length, code.length, true, m.group(1) ?? ''));
      out.write(code);
    }
    last = m.end;
  }
  plain(input.substring(last));
  ents.sort((a, b) => a.offset.compareTo(b.offset));
  return ParsedText(out.toString(), ents);
}

/// TDLib `formattedText` for a typed message.
Map<String, dynamic> toFormattedText(String input) {
  final p = parseCode(input);
  return {
    '@type': 'formattedText',
    'text': p.text,
    'entities': [
      for (final e in p.ents)
        {
          '@type': 'textEntity',
          'offset': e.offset,
          'length': e.length,
          'type': e.style.isNotEmpty
              ? {
                  '@type': switch (e.style) {
                    'bold' => 'textEntityTypeBold',
                    'italic' => 'textEntityTypeItalic',
                    'strike' => 'textEntityTypeStrikethrough',
                    'underline' => 'textEntityTypeUnderline',
                    _ => 'textEntityTypeSpoiler',
                  }
                }
              : e.block
                  ? (e.lang.isEmpty
                      ? {'@type': 'textEntityTypePre'}
                      : {'@type': 'textEntityTypePreCode', 'language': e.lang})
                  : {'@type': 'textEntityTypeCode'},
        },
    ],
  };
}

/// Code entities of a TDLib formattedText map.
List<TextEnt> entsFromTd(Object? formatted) {
  final list = (formatted is Map ? formatted['entities'] : null) as List?;
  if (list == null) return const [];
  final out = <TextEnt>[];
  for (final e in list) {
    if (e is! Map) continue;
    final t = (e['type'] as Map?)?['@type'];
    final off = (e['offset'] as num?)?.toInt() ?? 0;
    final len = (e['length'] as num?)?.toInt() ?? 0;
    final style = switch (t) {
      'textEntityTypeBold' => 'bold',
      'textEntityTypeItalic' => 'italic',
      'textEntityTypeStrikethrough' => 'strike',
      'textEntityTypeUnderline' => 'underline',
      'textEntityTypeSpoiler' => 'spoiler',
      _ => '',
    };
    if (style.isNotEmpty) {
      out.add(TextEnt(off, len, false, '', style));
    } else if (t == 'textEntityTypePre') {
      out.add(TextEnt(off, len, true));
    } else if (t == 'textEntityTypePreCode') {
      out.add(TextEnt(off, len, true, ((e['type'] as Map)['language'] ?? '').toString()));
    } else if (t == 'textEntityTypeCode') {
      out.add(TextEnt(off, len, false));
    }
  }
  out.sort((a, b) => a.offset.compareTo(b.offset));
  return out;
}
