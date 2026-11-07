import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/i18n/tr.dart';
import '../../core/theme/glass.dart';
import '../../core/ui/icon_styles.dart';
import '../downloads/keep_alive.dart';

const _kSetupDone = 'setup_v2_done';

Future<bool> setupAlreadyDone() async =>
    (await SharedPreferences.getInstance()).getBool(_kSetupDone) ?? false;

/// One-time first-run page: every permission explained and asked in one place.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _Item {
  _Item(this.icon, this.en, this.ar, this.hEn, this.hAr, this.check, this.ask);
  final IconData icon;
  final String en, ar, hEn, hAr;
  final Future<bool> Function() check;
  final Future<void> Function() ask;
  bool ok = false;
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  late final List<_Item> _items = [
    _perm(Icons.notifications_active_outlined, 'Notifications', 'الإشعارات',
        'So new messages reach you.', 'عشان توصلك الرسايل الجديدة.', Permission.notification),
    _Item(
      Icons.battery_charging_full,
      'Run in background',
      'الشغل في الخلفية',
      'Exempts the app from battery optimisation so it stays connected and notifies you instantly. It only runs when needed.',
      'بيستثني التطبيق من تحسين البطارية عشان يفضل متصل وينبّهك فورًا. وبيشتغل بس وقت الحاجة.',
      backgroundAllowed,
      requestBackground,
    ),
    _perm(Icons.contacts_outlined, 'Contacts', 'جهات الاتصال',
        'Shows people you know in new chats.', 'عشان تظهرلك معارفك في المحادثة الجديدة.', Permission.contacts),
    _perm(Icons.mic_none, 'Microphone', 'الميكروفون',
        'Voice messages.', 'الرسايل الصوتية.', Permission.microphone),
    _perm(Icons.photo_camera_outlined, 'Camera', 'الكاميرا',
        'Photos, videos and QR scanning.', 'تصوير صور وفيديو وقراءة QR.', Permission.camera),
    _perm(Icons.location_on_outlined, 'Location', 'الموقع',
        'Only when you share a location.', 'بس لما تبعت موقع.', Permission.location),
  ];

  _Item _perm(IconData i, String en, String ar, String hEn, String hAr, Permission p) =>
      _Item(i, en, ar, hEn, hAr, () async => (await p.status).isGranted, () async {
        final st = await p.status;
        if (st.isPermanentlyDenied) {
          await openAppSettings();
        } else {
          await p.request();
        }
      });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    for (final i in _items) {
      i.ok = await i.check();
    }
    if (mounted) setState(() {});
  }

  Future<void> _finish() async {
    (await SharedPreferences.getInstance()).setBool(_kSetupDone, true);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _allowAll() async {
    for (final i in _items) {
      if (!await i.check()) await i.ask();
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final accent = GlassScope.of(context).accent;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.t('Quick setup', 'إعداد سريع'),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                  context.t('Allow these once and the app just works — fast and without surprises.',
                      'اسمح بيهم مرة واحدة والتطبيق يشتغل بسرعة وبدون مفاجآت.'),
                  style: const TextStyle(color: GlassTokens.textSecondary)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(children: [
                  for (final i in _items)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: i.ok ? const Color(0xFF34C759).withValues(alpha: 0.5) : Colors.white12),
                      ),
                      child: Row(children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: accent.withValues(alpha: 0.16)),
                          child: SIcon(i.icon, color: accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(context.t(i.en, i.ar),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(context.t(i.hEn, i.hAr),
                                style: const TextStyle(fontSize: 12, color: GlassTokens.textSecondary)),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        i.ok
                            ? const SIcon(Icons.check_circle, color: Color(0xFF34C759))
                            : FilledButton.tonal(
                                onPressed: () async {
                                  await i.ask();
                                  await _refresh();
                                },
                                child: Text(context.t('Allow', 'سماح')),
                              ),
                      ]),
                    ),
                ]),
              ),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _allowAll,
                    child: Text(context.t('Allow all', 'سماح للكل')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _finish,
                    child: Text(context.t('Continue', 'متابعة')),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
