import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/ui/icon_styles.dart';
import '../../core/ui/notice.dart';
import 'widgets.dart';

/// Save every look & behaviour setting to a file and load it back later.
class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  String _json(WidgetRef ref) => const JsonEncoder.withIndent('  ')
      .convert(ref.read(settingsProvider.notifier).exportBackup());

  Future<void> _apply(BuildContext context, WidgetRef ref, String text) async {
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      ref.read(settingsProvider.notifier).importBackup(j);
      final icon = (ref.read(settingsProvider).x['launcherIcon'] as num?)?.toInt();
      if (icon != null) {
        try {
          await const MethodChannel('sudogram/window')
              .invokeMethod<void>('setLauncher', {'index': icon});
        } catch (_) {}
      }
      if (context.mounted) {
        notice(context, context.t('Settings imported', 'تم استيراد الإعدادات'),
            kind: NoticeKind.success);
      }
    } catch (_) {
      if (context.mounted) {
        notice(context,
            context.t('This is not a valid SUDOGRAM settings file',
                'الملف ده مش ملف إعدادات SUDOGRAM صالح'),
            kind: NoticeKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => SPage(
        title: context.t('Backup & restore settings', 'نسخ واستيراد الإعدادات'),
        children: [
          SGroup(title: context.t('Export', 'تصدير'), children: [
            ListTile(
              leading: const SIcon(Icons.ios_share),
              title: Text(context.t('Save as a file', 'حفظ كملف')),
              subtitle: SHint(context.t(
                  'Themes, icons, bar, chat look, notifications, rules — everything except passcodes and hidden chats.',
                  'الثيمات والأيقونات والشريط وشكل الشات والإشعارات والقواعد — كل حاجة ما عدا الأكواد والشاتات المخفية.')),
              onTap: () async {
                final dir = await getTemporaryDirectory();
                final d = DateTime.now();
                final f = File(
                    '${dir.path}/sudogram-settings-${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.json');
                await f.writeAsString(_json(ref));
                await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
              },
            ),
            ListTile(
              leading: const SIcon(Icons.copy),
              title: Text(context.t('Copy to clipboard', 'نسخ للحافظة')),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: _json(ref)));
                if (context.mounted) {
                  notice(context, context.t('Copied', 'تم النسخ'),
                      kind: NoticeKind.success);
                }
              },
            ),
          ]),
          SGroup(title: context.t('Import', 'استيراد'), children: [
            ListTile(
              leading: const SIcon(Icons.file_open_outlined),
              title: Text(context.t('Choose a settings file', 'اختار ملف إعدادات')),
              onTap: () async {
                final r = await FilePicker.pickFile();
                final path = r?.path;
                if (path == null) return;
                final text = await File(path).readAsString();
                if (!context.mounted) return;
                await _apply(context, ref, text);
              },
            ),
            ListTile(
              leading: const SIcon(Icons.content_paste),
              title: Text(context.t('Paste from clipboard', 'لصق من الحافظة')),
              onTap: () async {
                final t = (await Clipboard.getData('text/plain'))?.text ?? '';
                if (!context.mounted) return;
                await _apply(context, ref, t);
              },
            ),
          ]),
        ],
      );
}
