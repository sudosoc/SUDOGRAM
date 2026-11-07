import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/i18n/tr.dart';
import '../../core/ui/icon_styles.dart';
import 'diagnostics_screen.dart';
import 'widgets.dart';

/// What the app needs, why, and whether it was granted.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => PermissionsScreenState();
}

class PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  final Map<Permission, PermissionStatus> _st = {};

  static final items = <(Permission, IconData, String, String, String, String)>[
    (Permission.notification, Icons.notifications_outlined, 'Notifications', 'الإشعارات',
        'Show new messages.', 'عرض الرسايل الجديدة.'),
    (Permission.location, Icons.location_on_outlined, 'Location', 'الموقع',
        'Country detection at login, sending location and live location.',
        'تحديد الدولة عند الدخول وإرسال الموقع والموقع المباشر.'),
    (Permission.contacts, Icons.contacts_outlined, 'Contacts', 'جهات الاتصال',
        'Sync your phone book so everyone shows up in new chat.',
        'مزامنة دفتر الهاتف عشان الكل يظهر في المحادثة الجديدة.'),
    (Permission.camera, Icons.photo_camera_outlined, 'Camera', 'الكاميرا',
        'Take photos / videos and scan QR codes.', 'تصوير صور وفيديو وقراءة QR.'),
    (Permission.microphone, Icons.mic_none, 'Microphone', 'الميكروفون',
        'Voice messages and video recording.', 'الرسايل الصوتية وتسجيل الفيديو.'),
  ];

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    for (final it in items) {
      _st[it.$1] = await it.$1.status;
    }
    if (mounted) setState(() {});
  }

  Future<void> _grant(Permission p) async {
    final cur = await p.status;
    if (cur.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      await p.request();
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => SPage(
        title: context.t('Permissions', 'الصلاحيات'),
        children: [
          SGroup(title: context.t('Status', 'الحالة'), children: [
            for (final it in items)
              ListTile(
                leading: SIcon(it.$2),
                title: Text(context.t(it.$3, it.$4)),
                subtitle: SHint(context.t(it.$5, it.$6)),
                trailing: (_st[it.$1]?.isGranted ?? false)
                    ? const SIcon(Icons.check_circle, color: Color(0xFF34C759))
                    : TextButton(
                        onPressed: () => _grant(it.$1),
                        child: Text(
                          (_st[it.$1]?.isPermanentlyDenied ?? false)
                              ? context.t('Open settings', 'فتح الإعدادات')
                              : context.t('Allow', 'سماح'),
                        ),
                      ),
              ),
          ]),
          SGroup(children: [
            ListTile(
              leading: const SIcon(Icons.battery_saver_outlined),
              title: Text(context.t('Battery & stability', 'البطارية والاستقرار')),
              subtitle: SHint(context.t('Background exemption and the "why did it close" report.',
                  'استثناء الخلفية وتقرير "ليه اتقفل".')),
              trailing: const SIcon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DiagnosticsScreen())),
            ),
          ]),
        ],
      );
}
