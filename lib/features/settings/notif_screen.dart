import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../downloads/keep_alive.dart';
import 'widgets.dart';

Map<String, String> _sounds(BuildContext c) => {
  'default': c.t('Default', 'الافتراضي'),
  'notification': c.t('System notification', 'نغمة الإشعار'),
  'ringtone': c.t('Ringtone', 'نغمة الرنين'),
  'alarm': c.t('Alarm', 'المنبه'),
  'silent': c.t('Silent', 'صامت'),
};

Map<String, String> _vibs(BuildContext c) => {
  'default': c.t('Default', 'الافتراضي'),
  'short': c.t('Short', 'قصير'),
  'long': c.t('Long', 'طويل'),
  'double': c.t('Double', 'مزدوج'),
  'triple': c.t('Triple', 'ثلاثي'),
  'none': c.t('Off', 'بدون'),
};

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => STabbedPage(
    title: context.t('Notifications', 'الإشعارات'),
    tabs: [
      STab(
        context.t('General', 'عام'),
        Icons.notifications_outlined,
        (c) => const _General(),
      ),
      STab(
        context.t('Content', 'المحتوى'),
        Icons.subject,
        (c) => const _Content(),
      ),
      STab(
        context.t('Per chat', 'لكل شات'),
        Icons.person_pin_outlined,
        (c) => const _PerChat(),
      ),
    ],
  );
}

class _General extends ConsumerWidget {
  const _General();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    return Column(
      children: [
        SGroup(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: Text(
                context.t('Message notifications', 'إشعارات الرسائل'),
              ),
              subtitle: Text(
                context.t(
                  'Only arrive while the app is running (no push server).',
                  'بتوصل والتطبيق شغال بس (مفيش سيرفر push).',
                ),
              ),
              value: s.notifications,
              onChanged: (v) async {
                c.setNotifications(v);
                if (v && !await backgroundAllowed()) await requestBackground();
              },
            ),
            SwitchRow(
              icon: Icons.volume_up_outlined,
              title: context.t('Sound', 'الصوت'),
              hint: context.t('Notification sound for all chats (per-chat can differ).', 'صوت الإشعار لكل الشاتات (ممكن يختلف لكل شات).'),
            keyName: 'notifSound',
              value: s.notifSound,
            ),
            SwitchRow(
              icon: Icons.vibration,
              title: context.t('Vibration', 'الاهتزاز'),
              hint: context.t('Vibration pattern for new messages.', 'نمط الاهتزاز للرسايل الجديدة.'),
            keyName: 'notifVibrate',
              value: s.notifVibrate,
            ),
          ],
        ),
        SGroup(
          title: context.t('Default tone', 'النغمة الافتراضية'),
          children: [
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: Text(
                context.t('Send a test notification', 'ابعت إشعار تجريبي'),
              ),
              onTap: () => ref
                  .read(notifierProvider)
                  .preview(
                    s.notifSound ? 'default' : 'silent',
                    s.notifVibrate ? 'default' : 'none',
                    'SUDOGRAM',
                    context.t('Test message', 'رسالة تجريبية'),
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return Column(
      children: [
        SGroup(
          title: context.t(
            'What the notification shows',
            'اللي بيظهر في الإشعار',
          ),
          children: [
            RadioGroup<String>(
              groupValue: s.notifContent,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setX('notifContent', v),
              child: Column(
                children: [
                  for (final (k, en, ar, subEn, subAr) in const [
                    (
                      'full',
                      'Name + message',
                      'الاسم + الرسالة',
                      'Ahmed: see you at 5',
                      'أحمد: نتقابل الساعة 5',
                    ),
                    (
                      'nameOnly',
                      'Name only',
                      'الاسم بس',
                      'Ahmed — new message',
                      'أحمد — رسالة جديدة',
                    ),
                    (
                      'generic',
                      'Just "you got a message"',
                      'مجرد "جاتلك رسالة"',
                      'SUDOGRAM — new message',
                      'SUDOGRAM — رسالة جديدة',
                    ),
                    (
                      'count',
                      'Number of new messages',
                      'عدد الرسائل الجديدة',
                      'SUDOGRAM — 3 new messages',
                      'SUDOGRAM — 3 رسائل جديدة',
                    ),
                  ])
                    RadioListTile<String>(
                      value: k,
                      title: Text(context.t(en, ar)),
                      subtitle: Text(context.t(subEn, subAr)),
                    ),
                ],
              ),
            ),
          ],
        ),
        SGroup(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_outlined),
              title: Text(context.t('Never show text', 'مفيش نص أبدًا')),
              subtitle: Text(
                context.t(
                  'Same as "just you got a message" for every chat.',
                  'زي "جاتلك رسالة" لكل الشاتات.',
                ),
              ),
              value: !s.notifPreview,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setX('notifPreview', !v),
            ),
          ],
        ),
      ],
    );
  }
}

class _PerChat extends ConsumerWidget {
  const _PerChat();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final chats = ref.watch(chatsProvider).value ?? const [];
    final per = s.notifChats;
    final byId = {for (final c in chats) '${c.id}': c};
    final c = ref.read(settingsProvider.notifier);

    void save(String id, Map<String, dynamic> m) {
      final all = {
        for (final e in per.entries) e.key: Map<String, dynamic>.of(e.value),
      };
      if (m.isEmpty) {
        all.remove(id);
      } else {
        all[id] = m;
      }
      c.setX('notifChats', all);
    }

    Future<void> edit(String id, String title) async {
      var cur = Map<String, dynamic>.of(per[id] ?? {});
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sc) => StatefulBuilder(
          builder: (sc, setS) {
            Widget pick(String label, String key, Map<String, String> opts) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: GlassTokens.textSecondary,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final e in opts.entries)
                            ChoiceChip(
                              label: Text(e.value),
                              selected: (cur[key] ?? 'default') == e.key,
                              onSelected: (_) {
                                setS(() {
                                  if (e.key == 'default') {
                                    cur.remove(key);
                                  } else {
                                    cur[key] = e.key;
                                  }
                                });
                                save(id, cur);
                                ref
                                    .read(notifierProvider)
                                    .preview(
                                      (cur['sound'] as String?) ?? 'default',
                                      (cur['vib'] as String?) ?? 'default',
                                      title,
                                      context.t('Preview', 'معاينة'),
                                    );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                );
            return GlassSurface(
              radius: 24,
              blur: true,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(sc).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    pick(
                      context.t('Sound', 'الصوت'),
                      'sound',
                      _sounds(context),
                    ),
                    pick(
                      context.t('Vibration', 'الاهتزاز'),
                      'vib',
                      _vibs(context),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.t('Mute this chat', 'كتم الشات ده')),
                      value: cur['mute'] == true,
                      onChanged: (v) {
                        setS(() => v ? cur['mute'] = true : cur.remove('mute'));
                        save(id, cur);
                      },
                    ),
                    TextButton(
                      onPressed: () {
                        setS(cur.clear);
                        save(id, {});
                      },
                      child: Text(
                        context.t('Reset to default', 'رجوع للافتراضي'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    final ids = <String>{...per.keys};
    final list = [for (final ch in chats) ch]
      ..sort((a, b) {
        final pa = per.containsKey('${a.id}') ? 0 : 1;
        final pb = per.containsKey('${b.id}') ? 0 : 1;
        return pa != pb ? pa - pb : a.title.compareTo(b.title);
      });
    return Column(
      children: [
        if (ids.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              context.t(
                '${ids.length} chats have their own tone',
                '${ids.length} شات له نغمة خاصة',
              ),
              style: const TextStyle(color: GlassTokens.textSecondary),
            ),
          ),
        SGroup(
          children: [
            for (final ch
                in list.where((x) => !s.hiddenChats.contains(x.id)).take(80))
              ListTile(
                leading: Icon(
                  per.containsKey('${ch.id}')
                      ? Icons.music_note
                      : Icons.music_note_outlined,
                ),
                title: Text(
                  ch.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: per.containsKey('${ch.id}')
                    ? Text(_sum(context, per['${ch.id}']!))
                    : null,
                onTap: () =>
                    edit('${ch.id}', byId['${ch.id}']?.title ?? ch.title),
              ),
          ],
        ),
      ],
    );
  }

  String _sum(BuildContext c, Map<String, dynamic> m) {
    final parts = <String>[];
    if (m['mute'] == true) parts.add(c.t('muted', 'مكتوم'));
    if (m['sound'] != null) parts.add(_sounds(c)[m['sound']] ?? '');
    if (m['vib'] != null) parts.add(_vibs(c)[m['vib']] ?? '');
    return parts.join(' · ');
  }
}
