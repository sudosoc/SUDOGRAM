import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/providers.dart';
import '../../core/audio_hub.dart';
import '../../core/i18n/tr.dart';
import '../../core/theme/glass.dart';
import '../../core/ui/icon_styles.dart';
import '../../core/ui/notice.dart';

// ------------------------------------------------------------ translate

bool _mostlyArabic(String s) {
  var ar = 0, letters = 0;
  for (final r in s.runes) {
    if (r >= 0x0600 && r <= 0x06FF) {
      ar++;
      letters++;
    } else if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A)) {
      letters++;
    }
  }
  return letters > 0 && ar / letters > 0.4;
}

const _langs = {
  'ar': 'العربية',
  'en': 'English',
  'fr': 'Français',
  'de': 'Deutsch',
  'es': 'Español',
  'tr': 'Türkçe',
  'ru': 'Русский',
};

Future<(String text, String from)> _translate(String text, String to) async {
  final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
    'client': 'gtx',
    'sl': 'auto',
    'tl': to,
    'dt': 't',
    'q': text,
  });
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  try {
    final req = await c.getUrl(uri);
    final res = await req.close().timeout(const Duration(seconds: 20));
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
    final j = jsonDecode(body) as List;
    final out = StringBuffer();
    for (final seg in (j[0] as List)) {
      out.write((seg as List)[0] ?? '');
    }
    return (out.toString(), (j.length > 2 ? j[2] : '').toString());
  } finally {
    c.close(force: true);
  }
}

/// Bottom sheet that translates a message (Arabic <-> English by default).
void showTranslateSheet(BuildContext context, String text) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TranslateSheet(text: text),
  );
}

class _TranslateSheet extends StatefulWidget {
  const _TranslateSheet({required this.text});
  final String text;

  @override
  State<_TranslateSheet> createState() => _TranslateSheetState();
}

class _TranslateSheetState extends State<_TranslateSheet> {
  late String _to = _mostlyArabic(widget.text) ? 'en' : 'ar';
  String? _out;
  String _from = '';
  Object? _err;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _out = null;
      _err = null;
    });
    try {
      final r = await _translate(widget.text, _to);
      if (mounted) {
        setState(() {
          _out = r.$1;
          _from = r.$2;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = GlassScope.of(context).accent;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.of(context).viewInsets.bottom),
      child: GlassSurface(
        blur: true,
        radius: 26,
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  SIcon(Icons.translate_rounded, color: accent),
                  const SizedBox(width: 8),
                  Text(context.t('Translate', 'ترجمة'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_from.isNotEmpty)
                    Text(_langs[_from] ?? _from,
                        style: const TextStyle(fontSize: 12, color: GlassTokens.textSecondary)),
                ]),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(widget.text,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: GlassTokens.textSecondary)),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final e in _langs.entries)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: ChoiceChip(
                            label: Text(e.value),
                            selected: _to == e.key,
                            onSelected: (_) {
                              _to = e.key;
                              _run();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: _err != null
                      ? Row(children: [
                          Expanded(
                              child: Text(context.t('Translation failed — check the connection',
                                  'فشلت الترجمة — اتأكد من الإنترنت'))),
                          TextButton(onPressed: _run, child: Text(context.t('Retry', 'إعادة'))),
                        ])
                      : _out == null
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            )
                          : SelectableText(_out!, style: const TextStyle(fontSize: 16, height: 1.4)),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Text(context.t('via Google Translate', 'عن طريق Google Translate'),
                      style: const TextStyle(fontSize: 11, color: GlassTokens.textSecondary)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _out == null
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: _out!));
                            notice(context, context.t('Copied', 'تم النسخ'), kind: NoticeKind.success);
                          },
                    icon: const SIcon(Icons.copy_rounded, size: 16),
                    label: Text(context.t('Copy', 'نسخ')),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------- connection banner

/// Slim animated pill shown while the client is not connected.
class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({super.key});

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  Timer? _t;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    netLog.addListener(_changed);
    _changed();
  }

  bool get _bad {
    final c = netLog.connection;
    return c.isNotEmpty && c != '—' && c != 'Ready';
  }

  void _changed() {
    if (_bad) {
      _t ??= Timer(const Duration(milliseconds: 1500), () {
        if (mounted && _bad) setState(() => _show = true);
      });
    } else {
      _t?.cancel();
      _t = null;
      if (_show && mounted) setState(() => _show = false);
    }
  }

  @override
  void dispose() {
    netLog.removeListener(_changed);
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = netLog.connection;
    final (icon, label) = switch (c) {
      'WaitingForNetwork' => (Icons.wifi_off_rounded, context.t('Waiting for network…', 'مستني الإنترنت…')),
      'ConnectingToProxy' => (Icons.vpn_lock_rounded, context.t('Connecting to proxy…', 'بيتصل بالبروكسي…')),
      'Updating' => (Icons.sync_rounded, context.t('Updating…', 'بيحدّث…')),
      _ => (Icons.cloud_sync_rounded, context.t('Connecting…', 'جاري الاتصال…')),
    };
    final accent = GlassScope.of(context).accent;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: !_show
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SIcon(icon, size: 16, color: accent),
                        const SizedBox(width: 8),
                        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    LinearProgressIndicator(
                      minHeight: 2,
                      color: accent,
                      backgroundColor: Colors.transparent,
                    ),
                  ]),
                ),
              ),
            ),
    );
  }
}

// -------------------------------------------------------- mini player

/// Playback bar shown while a voice note plays (also after leaving its chat).
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final hub = AudioHub.instance;
    final accent = GlassScope.of(context).accent;
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        if (hub.key == null) return const SizedBox(width: double.infinity);
        final total = hub.dur.inMilliseconds;
        final v = total == 0 ? 0.0 : (hub.pos.inMilliseconds / total).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  IconButton(
                    onPressed: hub.toggle,
                    icon: SIcon(hub.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: accent),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(hub.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${_fmt(hub.pos)} / ${_fmt(hub.dur)}',
                          style: const TextStyle(fontSize: 11, color: GlassTokens.textSecondary)),
                    ]),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      const s = [1.0, 1.5, 2.0, 0.75];
                      hub.setSpeed(s[(s.indexOf(hub.speed) + 1) % s.length]);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('${hub.speed == hub.speed.roundToDouble() ? hub.speed.toInt() : hub.speed}x',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  IconButton(onPressed: hub.stop, icon: const SIcon(Icons.close_rounded, size: 20)),
                ]),
                LinearProgressIndicator(value: v, minHeight: 2, color: accent, backgroundColor: Colors.transparent),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------ format bar

/// Wraps the composer selection with style markers (see parseCode).
class FormatBar extends StatelessWidget {
  const FormatBar({super.key, required this.controller});
  final TextEditingController controller;

  void _wrap(String open, [String? close]) {
    final c = close ?? open;
    final v = controller.value;
    final sel = v.selection;
    if (!sel.isValid) return;
    final t = v.text;
    final inner = t.substring(sel.start, sel.end);
    final text = t.replaceRange(sel.start, sel.end, '$open$inner$c');
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: sel.start + open.length,
        extentOffset: sel.start + open.length + inner.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = GlassScope.of(context).accent;
    Widget b(Widget child, String tip, VoidCallback f) => Tooltip(
          message: tip,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: f,
            child: Container(
              width: 40,
              height: 36,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
    const base = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          b(const Text('B', style: base), context.t('Bold', 'عريض'), () => _wrap('**')),
          b(const Text('I', style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
              context.t('Italic', 'مائل'), () => _wrap('__')),
          b(const Text('S', style: TextStyle(fontSize: 16, decoration: TextDecoration.lineThrough, fontWeight: FontWeight.w600)),
              context.t('Strikethrough', 'مشطوب'), () => _wrap('~~')),
          b(const SIcon(Icons.visibility_off_outlined, size: 20), context.t('Spoiler', 'سبويلر'), () => _wrap('||')),
          b(const Text('</>', style: TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              context.t('Code', 'كود'), () => _wrap('`')),
          b(const SIcon(Icons.data_object, size: 20), context.t('Code block', 'بلوك كود'),
              () => _wrap('```\n', '\n```')),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------- glass menu

class MenuEntry {
  const MenuEntry(this.value, this.icon, this.label, {this.danger = false}) : divider = false;
  const MenuEntry.divider()
      : value = '',
        icon = Icons.circle,
        label = '',
        danger = false,
        divider = true;
  final String value;
  final IconData icon;
  final String label;
  final bool danger;
  final bool divider;
}

/// Glass bottom sheet used instead of the stock popup menu.
void showMenuSheet(
  BuildContext context,
  String title,
  List<MenuEntry> entries,
  Future<void> Function(String) onSelect,
) {
  final accent = GlassScope.of(context).accent;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => Padding(
      padding: const EdgeInsets.all(12),
      child: GlassSurface(
        blur: true,
        radius: 28,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(children: [
                Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in entries)
                    if (e.divider)
                      Divider(height: 10, color: Colors.white.withValues(alpha: 0.1))
                    else
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(sheet).pop();
                          onSelect(e.value);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          child: Row(children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (e.danger ? GlassTokens.ringDanger : accent).withValues(alpha: 0.15),
                              ),
                              child: SIcon(e.icon,
                                  size: 19, color: e.danger ? GlassTokens.ringDanger : accent),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(e.label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: e.danger ? GlassTokens.ringDanger : null,
                                  )),
                            ),
                          ]),
                        ),
                      ),
                ],
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}
