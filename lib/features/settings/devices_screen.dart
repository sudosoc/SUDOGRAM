import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/providers.dart';
import '../../core/i18n/tr.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import 'qr_tools.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  List<DeviceSession>? _list;
  int _ttl = 180;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = ref.read(gatewayProvider);
    final l = await g.sessions();
    final t = await g.sessionTtlDays();
    if (mounted) {
      setState(() {
        _list = l;
        _ttl = t;
      });
    }
  }

  void _toast(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (dc) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: Text(context.t('Cancel', 'إلغاء')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dc, true),
              child: Text(context.t('Confirm', 'تأكيد')),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _terminate(DeviceSession d) async {
    if (!await _confirm(
      context.t('Terminate session?', 'إنهاء الجلسة؟'),
      '${d.app.isEmpty ? d.device : d.app}\n${d.country} ${d.ip}',
    )) {
      return;
    }
    if (!mounted) return;
    final okMsg = context.t('Session terminated', 'تم إنهاء الجلسة');
    final freshMsg = context.t(
      'Telegram only lets you end sessions older than 24 hours.',
      'تليجرام بيسمح بإنهاء الجلسات الأقدم من 24 ساعة بس.',
    );
    final failMsg = context.t('Could not terminate', 'مقدرش ينهيها');
    try {
      await ref.read(gatewayProvider).terminateSession(d.id);
      _toast(okMsg);
    } catch (e) {
      _toast('$e'.contains('FRESH') ? freshMsg : '$failMsg: $e');
    }
    await _load();
  }

  Future<void> _terminateOthers() async {
    if (!await _confirm(
      context.t('Terminate all other sessions?', 'إنهاء كل الجلسات التانية؟'),
      context.t(
        'Every device except this one will be logged out.',
        'كل الأجهزة ما عدا ده هتتفصل.',
      ),
    )) {
      return;
    }
    if (!mounted) return;
    final okMsg = context.t(
      'Other sessions terminated',
      'تم إنهاء الجلسات التانية',
    );
    try {
      await ref.read(gatewayProvider).terminateOtherSessions();
      _toast(okMsg);
    } catch (e) {
      _toast('$e');
    }
    await _load();
  }

  Future<void> _link(String raw) async {
    final link = extractLoginLink(raw);
    if (link == null) {
      _toast(context.t('That is not a Telegram login QR', 'ده مش كود دخول تليجرام'));
      return;
    }
    final okMsg = context.t('Device linked', 'تم ربط الجهاز');
    final failMsg = context.t('Could not link', 'مقدرش يربط');
    try {
      await ref.read(gatewayProvider).confirmQrLink(link);
      _toast(okMsg);
      await _load();
    } catch (e) {
      _toast('$failMsg: $e');
    }
  }

  Future<void> _addDevice() async {
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (dc) => GlassSurface(
        radius: 24,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (k, ic, en, ar, hen, har) in [
            ('cam', Icons.qr_code_scanner, 'Scan QR with camera', 'مسح QR بالكاميرا',
                'Point at the QR on the new device (Log in by QR).',
                'وجّه الكاميرا على كود QR في الجهاز الجديد.'),
            ('gal', Icons.photo_library_outlined, 'Read QR from a photo', 'قراءة QR من صورة',
                'Pick a screenshot or photo that contains the code.',
                'اختار لقطة شاشة أو صورة فيها الكود.'),
            ('paste', Icons.link, 'Paste login link', 'لصق لينك الدخول',
                'tg://login?token=… copied from the new device.',
                'لينك tg://login?token=… منسوخ من الجهاز الجديد.'),
            ('mine', Icons.qr_code_2, 'Show my profile QR', 'عرض QR الملف الشخصي',
                'Let someone scan it to open your profile.',
                'خلّي حد يمسحه عشان يفتح بروفايلك.'),
          ])
            ListTile(
              leading: Icon(ic),
              title: Text(context.t(en, ar)),
              subtitle: Text(context.t(hen, har),
                  style: const TextStyle(color: GlassTokens.textSecondary)),
              onTap: () => Navigator.pop(dc, k),
            ),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    switch (pick) {
      case 'cam':
        final r = await Navigator.of(context)
            .push<String>(MaterialPageRoute(builder: (_) => const ScanQrScreen()));
        if (r != null) await _link(r);
      case 'gal':
        final f = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (f == null) return;
        final cap = await MobileScannerController().analyzeImage(f.path);
        final v = cap?.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
        if (!mounted) return;
        if (v == null) {
          _toast(context.t('No QR code found in that image', 'مفيش كود QR في الصورة دي'));
        } else {
          await _link(v);
        }
      case 'paste':
        final d = await Clipboard.getData('text/plain');
        await _link(d?.text ?? '');
      case 'mine':
        final me = await ref.read(meProvider.future);
        if (!mounted) return;
        if (me == null || me.username.isEmpty) {
          _toast(context.t('Set a username first', 'اعمل يوزرنيم الأول'));
        } else {
          await showQrSheet(context, context.t('My profile', 'بروفايلي'),
              'https://t.me/${me.username}');
        }
    }
  }

  Future<void> _ttlPick() async {
    final v = await showDialog<int>(
      context: context,
      builder: (dc) => SimpleDialog(
        title: Text(
          context.t(
            'Terminate inactive sessions after',
            'إنهاء الجلسات الخاملة بعد',
          ),
        ),
        children: [
          RadioGroup<int>(
            groupValue: _ttl,
            onChanged: (x) => Navigator.pop(dc, x),
            child: Column(
              children: [
                for (final (d, en, ar) in const [
                  (7, '1 week', 'أسبوع'),
                  (30, '1 month', 'شهر'),
                  (90, '3 months', '3 شهور'),
                  (180, '6 months', '6 شهور'),
                  (365, '1 year', 'سنة'),
                ])
                  RadioListTile<int>(value: d, title: Text(context.t(en, ar))),
              ],
            ),
          ),
        ],
      ),
    );
    if (v == null) return;
    try {
      await ref.read(gatewayProvider).setSessionTtlDays(v);
      setState(() => _ttl = v);
    } catch (e) {
      _toast('$e');
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 2) return context.t('online', 'متصل');
    if (d.inHours < 1) {
      return context.t('${d.inMinutes} min ago', 'من ${d.inMinutes} دقيقة');
    }
    if (d.inDays < 1) {
      return context.t('${d.inHours} h ago', 'من ${d.inHours} ساعة');
    }
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  IconData _icon(DeviceSession d) {
    final p = d.platform.toLowerCase();
    if (p.contains('android')) return Icons.android;
    if (p.contains('ios') || p.contains('iphone')) return Icons.phone_iphone;
    if (p.contains('web')) return Icons.language;
    if (p.contains('windows') || p.contains('mac') || p.contains('linux')) {
      return Icons.computer;
    }
    return Icons.devices_other;
  }

  void _details(DeviceSession d) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => GlassSurface(
        radius: 24,
        blur: true,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              d.app.isEmpty ? d.device : d.app,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _row(context.t('Device', 'الجهاز'), d.device),
            _row(context.t('Platform', 'النظام'), d.platform),
            _row('IP', d.ip),
            _row(
              context.t('Location', 'المكان'),
              '${d.country} ${d.region}'.trim(),
            ),
            if (d.loggedIn != null)
              _row(
                context.t('Logged in', 'سجّل دخول'),
                '${d.loggedIn}'.split('.').first,
              ),
            _row(context.t('Last active', 'آخر نشاط'), _ago(d.lastActive)),
            _row(
              context.t('Official app', 'تطبيق رسمي'),
              d.official ? context.t('Yes', 'أيوه') : context.t('No', 'لأ'),
            ),
            _row(
              context.t('Accepts calls', 'يستقبل مكالمات'),
              d.canAcceptCalls ? '✓' : '✗',
            ),
            _row(
              context.t('Secret chats', 'محادثات سرية'),
              d.canAcceptSecret ? '✓' : '✗',
            ),
            if (d.passwordPending)
              Text(
                context.t(
                  'Waiting for 2-step password',
                  'مستني باسورد التحقق بخطوتين',
                ),
                style: const TextStyle(color: GlassTokens.ringCaution),
              ),
            const SizedBox(height: 10),
            if (!d.current)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: GlassTokens.ringDanger,
                ),
                icon: const Icon(Icons.logout),
                label: Text(context.t('Terminate session', 'إنهاء الجلسة')),
                onPressed: () {
                  Navigator.pop(context);
                  _terminate(d);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            k,
            style: const TextStyle(color: GlassTokens.textSecondary),
          ),
        ),
        Expanded(child: SelectableText(v.isEmpty ? '—' : v)),
      ],
    ),
  );

  bool _fresh(DeviceSession d) =>
      d.loggedIn != null &&
      DateTime.now().difference(d.loggedIn!) < const Duration(hours: 24);

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final cur = list?.where((d) => d.current).toList() ?? const [];
    final others = list?.where((d) => !d.current).toList() ?? const [];
    Widget tile(DeviceSession d) => ListTile(
      leading: Icon(_icon(d)),
      title: Text(d.app.isEmpty ? d.device : d.app),
      subtitle: Text(
        '${d.device}\n${d.country} ${d.ip} · ${_ago(d.lastActive)}',
        style: const TextStyle(color: GlassTokens.textSecondary),
      ),
      isThreeLine: true,
      onTap: () => _details(d),
      trailing: d.current
          ? null
          : _fresh(d)
          ? Tooltip(
              message: context.t(
                'Telegram lets you end this session after 24 hours',
                'تليجرام بيسمح بإنهاء الجلسة دي بعد 24 ساعة',
              ),
              child: const Icon(Icons.lock_clock, color: GlassTokens.textTertiary),
            )
          : IconButton(
              icon: const Icon(Icons.close, color: GlassTokens.ringDanger),
              onPressed: () => _terminate(d),
            ),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(context.t('Devices', 'الأجهزة')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDevice,
        icon: const Icon(Icons.add_to_queue),
        label: Text(context.t('Link device', 'ربط جهاز')),
      ),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  if (_error != null) Text(_error!),
                  _head(context.t('This device', 'الجهاز ده')),
                  for (final d in cur) tile(d),
                  if (others.isNotEmpty) ...[
                    ListTile(
                      leading: const Icon(
                        Icons.logout,
                        color: GlassTokens.ringDanger,
                      ),
                      title: Text(
                        context.t(
                          'Terminate all other sessions',
                          'إنهاء كل الجلسات التانية',
                        ),
                        style: const TextStyle(color: GlassTokens.ringDanger),
                      ),
                      onTap: _terminateOthers,
                    ),
                    _head(context.t('Active sessions', 'الجلسات النشطة')),
                    for (final d in others) tile(d),
                  ],
                  _head(context.t('Auto-terminate', 'إنهاء تلقائي')),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(context.t('If inactive for', 'لو خاملة لمدة')),
                    subtitle: Text(
                      _ttl >= 365
                          ? context.t('1 year', 'سنة')
                          : context.t('$_ttl days', '$_ttl يوم'),
                    ),
                    onTap: _ttlPick,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _head(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      t,
      style: const TextStyle(
        color: GlassTokens.cyan,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
