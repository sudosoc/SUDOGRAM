import 'dart:convert';
import 'dart:math';
import '../../core/ui/icon_styles.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/providers.dart';
import '../../core/i18n/tr.dart';
import '../../core/theme/glass.dart';
import '../rules/rules_screen.dart';
import '../settings/qr_tools.dart';
import '../settings/widgets.dart';
import 'premium_hub.dart';
import 'tools_screens.dart';

class ToolsHubScreen extends ConsumerWidget {
  const ToolsHubScreen({super.key});

  Widget _t(BuildContext c, IconData i, String en, String ar, String hen,
          String har, Widget Function() w) =>
      ListTile(
        leading: SIcon(i),
        title: Text(c.t(en, ar)),
        subtitle: SHint(c.t(hen, har)),
        trailing: const SIcon(Icons.chevron_right, size: 20),
        onTap: () => Navigator.of(c)
            .push(MaterialPageRoute<void>(builder: (_) => w())),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) => SPage(
        title: context.t('Tools', 'الأدوات'),
        children: [
          SGroup(title: context.t('Telegram tools', 'أدوات تليجرام'), children: [
            _t(context, Icons.auto_awesome_outlined, 'Power features', 'مزايا متقدمة',
                'Proxy, storage, auto-download, export chat, bulk tools and more.',
                'بروكسي وتخزين وتحميل تلقائي وتصدير شات وأدوات جماعية وأكتر.',
                () => const PremiumHubScreen()),
            ListTile(
              leading: const SIcon(Icons.done_all),
              title: Text(context.t('Mark all chats as read', 'تعليم كل الشاتات كمقروءة')),
              subtitle: SHint(context.t(
                  'Clears every unread badge in one go (works even in Ghost mode).',
                  'بيمسح كل عدّادات غير المقروء مرة واحدة (حتى في وضع الشبح).')),
              onTap: () async {
                final g = ref.read(gatewayProvider);
                final msg = ScaffoldMessenger.of(context);
                final done = context.t('Done', 'تم');
                final all = ref.read(chatsProvider).value ?? const [];
                for (final c in all) {
                  if (c.unread > 0 || c.markedUnread) await g.markChatRead(c.id);
                }
                msg.showSnackBar(SnackBar(content: Text(done)));
              },
            ),
            _t(context, Icons.history, 'Time machine', 'آلة الزمن',
                'Browse deleted and edited messages kept in the archive.',
                'تصفّح الرسائل المحذوفة والمعدّلة المحفوظة في الأرشيف.',
                () => const TimeMachineScreen()),
            _t(context, Icons.person_search_outlined, 'Contact change log',
                'سجل تغييرات الأسماء',
                'Who changed their name, photo or username, and when.',
                'مين غيّر اسمه أو صورته أو يوزره ومتى.',
                () => const ContactLogScreen()),
            _t(context, Icons.rule, 'Rules engine', 'محرك القواعد',
                'Automations: when X happens, do Y.', 'أتمتة: لما يحصل X اعمل Y.',
                () => const RulesScreen()),
            _t(context, Icons.merge_type, 'Join file parts', 'تجميع أجزاء الملفات',
                'Rebuild a file split by the Smart Splitter.',
                'رجّع ملف اتقسّم بالـ Smart Splitter.',
                () => const JoinPartsScreen()),
            _t(context, Icons.network_check, 'Network inspector', 'فاحص الشبكة',
                'Connection state and traffic of the Telegram client.',
                'حالة الاتصال وحركة بيانات العميل.',
                () => const NetworkInspectorScreen()),
            _t(context, Icons.lock_outline, 'Vault', 'الخزنة',
                'Encrypted private storage.', 'تخزين خاص مشفّر.',
                () => const VaultScreen()),
          ]),
          SGroup(title: context.t('Extra utilities', 'أدوات إضافية'), children: [
            _t(context, Icons.qr_code_scanner, 'QR reader', 'قارئ QR',
                'Scan with the camera or read a code from a photo.',
                'امسح بالكاميرا أو اقرأ كود من صورة.',
                () => const _QrReader()),
            _t(context, Icons.qr_code_2, 'QR generator', 'مولّد QR',
                'Turn any text or link into a QR code.',
                'حوّل أي نص أو لينك لكود QR.', () => const _QrMaker()),
            _t(context, Icons.password, 'Password generator', 'مولّد كلمات السر',
                'Strong random passwords with the character sets you pick.',
                'كلمات سر قوية عشوائية بالأنواع اللي تختارها.',
                () => const _PassGen()),
            _t(context, Icons.tag, 'Hash calculator', 'حاسبة الهاش',
                'MD5, SHA-1, SHA-256 and SHA-512 of any text.',
                'MD5 و SHA-1 و SHA-256 و SHA-512 لأي نص.',
                () => const _Hasher()),
            _t(context, Icons.transform, 'Encode / decode', 'ترميز / فك ترميز',
                'Base64, URL and hex converters.', 'محوّلات Base64 و URL و Hex.',
                () => const _Coder()),
            _t(context, Icons.text_fields, 'Text counter', 'عدّاد النص',
                'Characters, words, lines and reading time.',
                'حروف وكلمات وأسطر ووقت القراءة.', () => const _Counter()),
            _t(context, Icons.schedule, 'Timestamp converter', 'محوّل الوقت',
                'Unix time ↔ readable date.', 'وقت Unix ↔ تاريخ مقروء.',
                () => const _Stamp()),
          ]),
        ],
      );
}

Widget _page(BuildContext c, String title, List<Widget> kids) => Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(title)),
      body: ListView(padding: const EdgeInsets.all(14), children: kids),
    );

Widget _result(BuildContext c, String text) => GlassSurface(
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(child: SelectableText(text)),
        IconButton(
          icon: const SIcon(Icons.copy, size: 18),
          onPressed: () => Clipboard.setData(ClipboardData(text: text)),
        ),
      ]),
    );

class _QrReader extends StatefulWidget {
  const _QrReader();
  @override
  State<_QrReader> createState() => _QrReaderState();
}

class _QrReaderState extends State<_QrReader> {
  String? _text;

  Future<void> _cam() async {
    final r = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const ScanQrScreen()));
    if (r != null) setState(() => _text = r);
  }

  Future<void> _gal() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f == null) return;
    final cap = await MobileScannerController().analyzeImage(f.path);
    final v = cap?.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (!mounted) return;
    setState(() => _text = v ?? context.t('No QR found', 'مفيش QR'));
  }

  @override
  Widget build(BuildContext context) =>
      _page(context, context.t('QR reader', 'قارئ QR'), [
        FilledButton.icon(
            onPressed: _cam,
            icon: const SIcon(Icons.qr_code_scanner),
            label: Text(context.t('Scan with camera', 'مسح بالكاميرا'))),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
            onPressed: _gal,
            icon: const SIcon(Icons.photo_library_outlined),
            label: Text(context.t('Read from a photo', 'قراءة من صورة'))),
        const SizedBox(height: 14),
        if (_text != null) _result(context, _text!),
      ]);
}

class _QrMaker extends StatefulWidget {
  const _QrMaker();
  @override
  State<_QrMaker> createState() => _QrMakerState();
}

class _QrMakerState extends State<_QrMaker> {
  final _c = TextEditingController();

  @override
  Widget build(BuildContext context) =>
      _page(context, context.t('QR generator', 'مولّد QR'), [
        TextField(
          controller: _c,
          maxLines: 4,
          decoration: InputDecoration(
              hintText: context.t('Text or link', 'نص أو لينك')),
        ),
        const SizedBox(height: 8),
        FilledButton(
            onPressed: () => _c.text.trim().isEmpty
                ? null
                : showQrSheet(context, context.t('QR code', 'كود QR'), _c.text.trim()),
            child: Text(context.t('Generate', 'إنشاء'))),
      ]);
}

class _PassGen extends StatefulWidget {
  const _PassGen();
  @override
  State<_PassGen> createState() => _PassGenState();
}

class _PassGenState extends State<_PassGen> {
  double _len = 20;
  bool _lo = true, _up = true, _dg = true, _sy = true;
  String _out = '';

  void _gen() {
    final sets = [
      if (_lo) 'abcdefghijklmnopqrstuvwxyz',
      if (_up) 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
      if (_dg) '0123456789',
      if (_sy) r'!@#$%^&*()-_=+[]{};:,.?',
    ];
    if (sets.isEmpty) return;
    final r = Random.secure();
    final all = sets.join();
    final chars = [for (final s in sets) s[r.nextInt(s.length)]];
    while (chars.length < _len.round()) {
      chars.add(all[r.nextInt(all.length)]);
    }
    chars.shuffle(r);
    setState(() => _out = chars.join());
  }

  @override
  void initState() {
    super.initState();
    _gen();
  }

  @override
  Widget build(BuildContext context) =>
      _page(context, context.t('Password generator', 'مولّد كلمات السر'), [
        if (_out.isNotEmpty) _result(context, _out),
        Slider(
            value: _len,
            min: 8,
            max: 64,
            divisions: 56,
            label: '${_len.round()}',
            onChanged: (v) => setState(() => _len = v)),
        Text(context.t('Length: ${_len.round()}', 'الطول: ${_len.round()}')),
        SwitchListTile(
            title: const Text('a-z'),
            value: _lo,
            onChanged: (v) => setState(() => _lo = v)),
        SwitchListTile(
            title: const Text('A-Z'),
            value: _up,
            onChanged: (v) => setState(() => _up = v)),
        SwitchListTile(
            title: const Text('0-9'),
            value: _dg,
            onChanged: (v) => setState(() => _dg = v)),
        SwitchListTile(
            title: const Text(r'!@#$%'),
            value: _sy,
            onChanged: (v) => setState(() => _sy = v)),
        FilledButton(onPressed: _gen, child: Text(context.t('Generate', 'توليد'))),
      ]);
}

class _Hasher extends StatefulWidget {
  const _Hasher();
  @override
  State<_Hasher> createState() => _HasherState();
}

class _HasherState extends State<_Hasher> {
  final _c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final b = utf8.encode(_c.text);
    return _page(context, context.t('Hash calculator', 'حاسبة الهاش'), [
      TextField(
        controller: _c,
        maxLines: 4,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(hintText: context.t('Text', 'النص')),
      ),
      const SizedBox(height: 12),
      for (final (n, h) in [
        ('MD5', md5),
        ('SHA-1', sha1),
        ('SHA-256', sha256),
        ('SHA-512', sha512),
      ]) ...[
        Text(n, style: const TextStyle(color: GlassTokens.textSecondary)),
        _result(context, h.convert(b).toString()),
        const SizedBox(height: 8),
      ],
    ]);
  }
}

class _Coder extends StatefulWidget {
  const _Coder();
  @override
  State<_Coder> createState() => _CoderState();
}

class _CoderState extends State<_Coder> {
  final _c = TextEditingController();
  String _mode = 'b64';
  bool _enc = true;

  String _run() {
    final t = _c.text;
    try {
      switch (_mode) {
        case 'b64':
          return _enc
              ? base64.encode(utf8.encode(t))
              : utf8.decode(base64.decode(base64.normalize(t.trim())));
        case 'url':
          return _enc ? Uri.encodeComponent(t) : Uri.decodeComponent(t);
        default:
          return _enc
              ? utf8.encode(t).map((e) => e.toRadixString(16).padLeft(2, '0')).join()
              : utf8.decode([
                  for (var i = 0; i + 1 < t.trim().length; i += 2)
                    int.parse(t.trim().substring(i, i + 2), radix: 16),
                ]);
      }
    } catch (_) {
      return context.t('Invalid input', 'مدخل غير صالح');
    }
  }

  @override
  Widget build(BuildContext context) =>
      _page(context, context.t('Encode / decode', 'ترميز / فك ترميز'), [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'b64', label: Text('Base64')),
            ButtonSegment(value: 'url', label: Text('URL')),
            ButtonSegment(value: 'hex', label: Text('Hex')),
          ],
          selected: {_mode},
          onSelectionChanged: (v) => setState(() => _mode = v.first),
        ),
        SwitchListTile(
          title: Text(_enc ? context.t('Encode', 'ترميز') : context.t('Decode', 'فك')),
          value: _enc,
          onChanged: (v) => setState(() => _enc = v),
        ),
        TextField(
          controller: _c,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _result(context, _run()),
      ]);
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  final _c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final t = _c.text;
    final words = t.trim().isEmpty ? 0 : t.trim().split(RegExp(r'\s+')).length;
    final lines = t.isEmpty ? 0 : t.split('\n').length;
    return _page(context, context.t('Text counter', 'عدّاد النص'), [
      TextField(
        controller: _c,
        maxLines: 8,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      _result(
          context,
          context.t(
            '${t.characters.length} characters · $words words · $lines lines · ~${(words / 200).ceil()} min read',
            '${t.characters.length} حرف · $words كلمة · $lines سطر · ~${(words / 200).ceil()} دقيقة قراءة',
          )),
    ]);
  }
}

class _Stamp extends StatefulWidget {
  const _Stamp();
  @override
  State<_Stamp> createState() => _StampState();
}

class _StampState extends State<_Stamp> {
  final _c = TextEditingController(
      text: '${DateTime.now().millisecondsSinceEpoch ~/ 1000}');

  @override
  Widget build(BuildContext context) {
    final n = int.tryParse(_c.text.trim());
    DateTime? d;
    if (n != null) {
      d = DateTime.fromMillisecondsSinceEpoch(n > 20000000000 ? n : n * 1000);
    }
    return _page(context, context.t('Timestamp converter', 'محوّل الوقت'), [
      TextField(
        controller: _c,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: 'Unix time'),
      ),
      const SizedBox(height: 12),
      if (d != null) ...[
        _result(context, 'Local: ${d.toLocal()}'),
        const SizedBox(height: 8),
        _result(context, 'UTC: ${d.toUtc().toIso8601String()}'),
      ],
      const SizedBox(height: 8),
      FilledButton.tonal(
          onPressed: () => setState(() =>
              _c.text = '${DateTime.now().millisecondsSinceEpoch ~/ 1000}'),
          child: Text(context.t('Now', 'دلوقتي'))),
    ]);
  }
}
