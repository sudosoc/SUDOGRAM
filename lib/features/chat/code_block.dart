import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:highlight/highlight.dart' as hl;

import '../../core/code_markup.dart';
import '../../core/i18n/tr.dart';
import '../../core/ui/icon_styles.dart';
import '../../core/ui/notice.dart';

const _bg = Color(0xFF1E1E1E);

List<TextSpan> _spans(List<hl.Node> nodes) {
  TextSpan conv(hl.Node n) {
    if (n.value != null) {
      return TextSpan(text: n.value, style: n.className == null ? null : vs2015Theme[n.className!]);
    }
    return TextSpan(
      style: n.className == null ? null : vs2015Theme[n.className!],
      children: [for (final c in n.children ?? <hl.Node>[]) conv(c)],
    );
  }

  return [for (final n in nodes) conv(n)];
}

const _alias = {
  'py': 'python', 'js': 'javascript', 'ts': 'typescript', 'sh': 'bash',
  'shell': 'bash', 'zsh': 'bash', 'c++': 'cpp', 'cs': 'cs', 'c#': 'cs',
  'rs': 'rust', 'kt': 'kotlin', 'yml': 'yaml', 'md': 'markdown',
  'html': 'xml', 'ps1': 'powershell', 'rb': 'ruby',
};

/// VS Code-style code block with syntax colours and a copy button.
class CodeBlock extends StatelessWidget {
  const CodeBlock({super.key, required this.code, this.lang = ''});
  final String code;
  final String lang;

  List<TextSpan> _highlight() {
    final l = lang.toLowerCase();
    try {
      if (l.isNotEmpty) {
        return _spans(hl.highlight.parse(code, language: _alias[l] ?? l).nodes ?? const []);
      }
    } catch (_) {}
    try {
      return _spans(hl.highlight.parse(code, autoDetection: code.length < 4000).nodes ?? const []);
    } catch (_) {
      return [TextSpan(text: code)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = lang.isNotEmpty ? lang : 'code';
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFF2D2D30),
              padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
              child: Row(children: [
                Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    notice(context, context.t('Code copied', 'تم نسخ الكود'), kind: NoticeKind.success);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(children: [
                      const SIcon(Icons.copy_rounded, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(context.t('Copy', 'نسخ'),
                          style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                    ]),
                  ),
                ),
              ]),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: SelectableText.rich(
                TextSpan(
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.4,
                    color: Color(0xFFDCDCDC),
                  ),
                  children: _highlight(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Splits a message into plain-text pieces and code blocks.
/// [plain] renders a text piece (with inline-code ranges relative to it).
List<Widget> codeAwareBody(
  String text,
  List<TextEnt> ents,
  Widget Function(String piece, List<TextEnt> inline) plain,
) {
  final out = <Widget>[];
  var last = 0;
  List<TextEnt> inlineIn(int a, int b) => [
        for (final e in ents)
          if (!e.block && e.offset >= a && e.offset + e.length <= b)
            TextEnt(e.offset - a, e.length, false, '', e.style),
      ];
  void piece(int a, int b) {
    if (b <= a) return;
    final s = text.substring(a, b);
    if (s.trim().isEmpty) return;
    out.add(plain(s, inlineIn(a, b)));
  }

  for (final e in ents.where((e) => e.block)) {
    if (e.offset < last || e.offset + e.length > text.length) continue;
    piece(last, e.offset);
    out.add(CodeBlock(code: text.substring(e.offset, e.offset + e.length), lang: e.lang));
    last = e.offset + e.length;
  }
  piece(last, text.length);
  return out;
}
