import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/diagnostics.dart';
import '../../core/i18n/tr.dart';
import '../../core/ui/icon_styles.dart';
import '../../core/ui/notice.dart';
import '../downloads/keep_alive.dart';
import 'widgets.dart';

/// Battery / stability controls and the "why did the app close" report.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  List<ExitInfo> _exits = const [];
  bool? _bg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await recentExits();
    final b = await backgroundAllowed();
    if (mounted) {
      setState(() {
        _exits = e;
        _bg = b;
      });
    }
  }

  String _report() {
    final b = StringBuffer('SUDOGRAM diagnostics\n');
    b.writeln('battery exemption: $_bg');
    for (final e in _exits) {
      b.writeln('${e.time.toIso8601String()}  ${e.reason}  ${e.desc}');
    }
    b.writeln('\n--- error log ---');
    b.writeln(CrashLog.read());
    return b.toString();
  }

  @override
  Widget build(BuildContext context) => SPage(
        title: context.t('Battery & stability', 'البطارية والاستقرار'),
        children: [
          SGroup(title: context.t('Stay alive in background', 'الاستمرار في الخلفية'), children: [
            ListTile(
              leading: SIcon(_bg == true ? Icons.battery_charging_full : Icons.battery_alert),
              title: Text(context.t('Battery optimisation', 'تحسين البطارية')),
              subtitle: SHint(_bg == true
                  ? context.t('Exempted — the connection survives in the background.',
                      'مستثنى — الاتصال بيفضل شغال في الخلفية.')
                  : context.t('Not exempted — Android may close the app and delay notifications.',
                      'مش مستثنى — أندرويد ممكن يقفل التطبيق ويأخر الإشعارات.')),
              trailing: _bg == true
                  ? const SIcon(Icons.check_circle, color: Color(0xFF34C759))
                  : TextButton(
                      onPressed: () async {
                        await requestBackground();
                        await _load();
                      },
                      child: Text(context.t('Exempt', 'استثناء')),
                    ),
            ),
            ListTile(
              leading: const SIcon(Icons.settings_applications_outlined),
              title: Text(context.t('Open battery settings', 'فتح إعدادات البطارية')),
              subtitle: SHint(context.t(
                  'Also set the app to "Unrestricted" and keep Battery saver from limiting it (some phones have extra "sleeping apps" lists).',
                  'اضبط التطبيق على "بدون قيود" ومتخليش موفّر البطارية يقيّده (فيه موبايلات عندها قوائم "تطبيقات نايمة" إضافية).')),
              onTap: openBatterySettings,
            ),
          ]),
          SGroup(title: context.t('Why did the app close?', 'ليه التطبيق اتقفل؟'), children: [
            if (_exits.isEmpty)
              ListTile(
                title: Text(context.t('No recent exits recorded (needs Android 11+).',
                    'مفيش خروج مسجّل (محتاج أندرويد 11+).')),
              ),
            for (final e in _exits)
              ListTile(
                dense: true,
                leading: SIcon(
                    e.reason.startsWith('CRASH') || e.reason.startsWith('ANR')
                        ? Icons.error_outline
                        : Icons.info_outline,
                    size: 20),
                title: Text(e.reason),
                subtitle: Text('${e.time.toString().split('.').first}\n${e.desc}'),
                isThreeLine: e.desc.isNotEmpty,
              ),
          ]),
          SGroup(children: [
            ListTile(
              leading: const SIcon(Icons.copy),
              title: Text(context.t('Copy report', 'نسخ التقرير')),
              onTap: () {
                Clipboard.setData(ClipboardData(text: _report()));
                notice(context, context.t('Copied', 'تم النسخ'), kind: NoticeKind.success);
              },
            ),
            ListTile(
              leading: const SIcon(Icons.ios_share),
              title: Text(context.t('Share report', 'مشاركة التقرير')),
              onTap: () => SharePlus.instance.share(ShareParams(text: _report())),
            ),
            ListTile(
              leading: const SIcon(Icons.delete_outline),
              title: Text(context.t('Clear error log', 'مسح سجل الأخطاء')),
              onTap: () {
                CrashLog.clear();
                notice(context, context.t('Cleared', 'تم المسح'), kind: NoticeKind.success);
              },
            ),
          ]),
        ],
      );
}
