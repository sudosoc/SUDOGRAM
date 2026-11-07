import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ui/icon_styles.dart';

import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../app/providers.dart';
import '../chat/wallpapers.dart';
import 'widgets.dart';

class ChatsSettingsScreen extends StatelessWidget {
  const ChatsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => STabbedPage(
    title: context.t('Chat behaviour', 'سلوك الشات'),
    tabs: [
      STab(
        context.t('Gestures', 'الإيماءات'),
        Icons.swipe,
        (c) => const _Gestures(),
      ),
      STab(context.t('General', 'عام'), Icons.tune, (c) => const _General()),
    ],
  );
}

class WallpaperTextTab extends ConsumerWidget {
  const WallpaperTextTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    return Column(
      children: [
        SGroup(
          title: context.t('Chat background', 'خلفية الشات'),
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < wallpapers.length; i++)
                    GestureDetector(
                      onTap: () => c.setWallpaper(i),
                      child: Container(
                        width: 46,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: wallpapers[i],
                          color: wallpapers[i] == null ? Colors.white12 : null,
                          border: Border.all(
                            color: s.wallpaper == i
                                ? Colors.white
                                : Colors.white24,
                            width: s.wallpaper == i ? 2.5 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        SGroup(
          children: [
            SliderRow(
              icon: Icons.format_size,
              title: context.t('App text size', 'حجم الخط في التطبيق'),
              hint: context.t('Scales text everywhere in the app.', 'بيكبّر أو بيصغّر النص في التطبيق كله.'),
            keyName: 'textScale',
              value: s.textScale,
              min: .8,
              max: 1.4,
              divisions: 12,
              fmt: (v) => '${(v * 100).round()}%',
            ),
            ListTile(
              leading: const SIcon(Icons.download_for_offline_outlined),
              title: Text(context.t('Media downloads', 'تنزيل الوسائط')),
              subtitle: SHint(context.t('Auto-save photos / videos to the gallery, per chat rules.',
                  'حفظ الصور والفيديو تلقائيًا في المعرض مع قواعد لكل شات.')),
              trailing: const SIcon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const MediaDownloadsScreen())),
            ),
            ListTile(
              leading: const SIcon(Icons.attach_file),
              title: Text(context.t('Attach menu', 'قايمة المرفقات')),
              subtitle: SHint(context.t('Choose which options the paperclip shows.',
                  'اختار الخيارات اللي تظهر في قايمة المرفقات.')),
              trailing: const SIcon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AttachMenuScreen())),
            ),
            SwitchListTile(
              secondary: const SIcon(Icons.speed),
              title: Text(context.t('Performance mode', 'وضع الأداء')),
              subtitle: Text(
                context.t(
                  'Turns off blur for smoother scrolling.',
                  'بيقفل التمويه عشان السكرول يبقى أسلس.',
                ),
              ),
              value: s.performanceMode,
              onChanged: c.setPerformanceMode,
            ),
          ],
        ),
      ],
    );
  }
}

String _actLabel(BuildContext c, String a) => switch (a) {
  'reply' => c.t('Reply', 'رد'),
  'forward' => c.t('Forward', 'تحويل'),
  'copy' => c.t('Copy', 'نسخ'),
  'translate' => c.t('Translate', 'ترجمة'),
  'react' => c.t('React', 'تفاعل'),
  'heart' => c.t('Heart', 'قلب'),
  'pin' => c.t('Pin', 'تثبيت'),
  'select' => c.t('Select', 'تحديد'),
  'delete' => c.t('Delete', 'حذف'),
  'share' => c.t('Share', 'مشاركة'),
  'save' => c.t('Save to Saved', 'حفظ في المحفوظات'),
  'menu' => c.t('Open menu', 'فتح القائمة'),
  'archive' => c.t('Archive', 'أرشفة'),
  'mute' => c.t('Mute / unmute', 'كتم / إلغاء'),
  'read' => c.t('Mark read / unread', 'مقروء / غير مقروء'),
  'hide' => c.t('Hide / unhide', 'إخفاء / إظهار'),
  _ => c.t('Nothing', 'لا شيء'),
};

class _Gestures extends StatelessWidget {
  const _Gestures();

  @override
  Widget build(BuildContext context) {
    final tabs = [
      Tab(text: context.t('In chat', 'داخل الشات')),
      Tab(text: context.t('Home list', 'قائمة الهوم')),
    ];
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(tabs: tabs, dividerColor: Colors.transparent),
          const SizedBox(height: 8),
          const _GestureBody(),
        ],
      ),
    );
  }
}

class _GestureBody extends StatelessWidget {
  const _GestureBody();

  @override
  Widget build(BuildContext context) {
    final ctrl = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, _) =>
          ctrl.index == 0 ? const _ChatGestures() : const _HomeGestures(),
    );
  }
}

class _ActionPick extends ConsumerWidget {
  const _ActionPick(
    this.icon,
    this.title,
    this.keyName,
    this.current,
    this.options,
  );
  final IconData icon;
  final String title;
  final String keyName;
  final String current;
  final List<String> options;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: SIcon(icon),
    title: Text(title),
    trailing: PopupMenuButton<String>(
      initialValue: current,
      onSelected: (v) => ref.read(settingsProvider.notifier).setX(keyName, v),
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem(value: o, child: Text(_actLabel(context, o))),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _actLabel(context, current),
            style: TextStyle(color: GlassScope.of(context).accent),
          ),
          const SIcon(Icons.arrow_drop_down),
        ],
      ),
    ),
  );
}

class _ChatGestures extends ConsumerWidget {
  const _ChatGestures();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    const opts = [
      'reply',
      'forward',
      'copy',
      'translate',
      'react',
      'heart',
      'pin',
      'select',
      'delete',
      'share',
      'save',
      'menu',
      'none',
    ];
    return SGroup(
      title: context.t('Messages', 'الرسائل'),
      children: [
        _ActionPick(
          Icons.swipe_right_alt,
          context.t('Swipe right', 'سحب لليمين'),
          'swipeRight',
          s.swipeRight,
          opts,
        ),
        _ActionPick(
          Icons.swipe_left_alt,
          context.t('Swipe left', 'سحب لليسار'),
          'swipeLeft',
          s.swipeLeft,
          opts,
        ),
        _ActionPick(
          Icons.touch_app_outlined,
          context.t('Double tap', 'ضغطتين'),
          'doubleTap',
          s.doubleTap,
          opts,
        ),
      ],
    );
  }
}

class _HomeGestures extends ConsumerWidget {
  const _HomeGestures();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    const opts = ['pin', 'archive', 'mute', 'read', 'hide', 'none'];
    return SGroup(
      title: context.t('Chat list rows', 'صفوف الشاتات'),
      children: [
        _ActionPick(
          Icons.swipe_right_alt,
          context.t('Swipe right', 'سحب لليمين'),
          'homeSwipeRight',
          s.homeSwipeRight,
          opts,
        ),
        _ActionPick(
          Icons.swipe_left_alt,
          context.t('Swipe left', 'سحب لليسار'),
          'homeSwipeLeft',
          s.homeSwipeLeft,
          opts,
        ),
      ],
    );
  }
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
            ListTile(
              leading: const SIcon(Icons.language),
              title: Text(context.t('Language', 'اللغة')),
              trailing: SegmentedButton<String?>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: null, label: Text('Auto')),
                  ButtonSegment(value: 'ar', label: Text('ع')),
                  ButtonSegment(value: 'en', label: Text('EN')),
                ],
                selected: {s.localeCode},
                onSelectionChanged: (v) => c.setLocale(v.first),
              ),
            ),
            SwitchRow(
              icon: Icons.description_outlined,
              title: context.t('Long text as a file', 'النص الطويل كملف'),
              hint: context.t('Text longer than the Telegram limit is sent as a .txt file instead of many messages.', 'النص الأطول من حد تليجرام بيتبعت كملف txt بدل رسايل كتير.'),
              keyName: 'longAsFile',
              value: s.longAsFile,
            ),
            SwitchRow(
              icon: Icons.view_carousel_outlined,
              title: context.t('Home sections', 'أقسام الهوم'),
              hint: context.t('The All / Unread / People / Groups chips on top of the chat list.', 'شرايح الكل / غير المقروء / أشخاص / جروبات فوق قائمة الشاتات.'),
            keyName: 'homeSections',
              value: s.homeSections,
            ),
          ],
        ),
      ],
    );
  }
}

/// Choose which entries the attach (paperclip) menu shows, and their order.
class AttachMenuScreen extends ConsumerWidget {
  const AttachMenuScreen({super.key});

  static const _all = <String, (IconData, String, String)>{
    'gallery': (Icons.photo_library_outlined, 'Gallery', 'المعرض'),
    'photo': (Icons.photo_camera_outlined, 'Camera photo', 'تصوير صورة'),
    'video': (Icons.videocam_outlined, 'Camera video', 'تصوير فيديو'),
    'file': (Icons.attach_file, 'File', 'ملف'),
    'location': (Icons.location_on_outlined, 'Location', 'الموقع'),
    'live': (Icons.share_location, 'Live location', 'الموقع المباشر'),
    'contact': (Icons.contact_page_outlined, 'Contact', 'جهة اتصال'),
    'poll': (Icons.poll_outlined, 'Poll', 'استطلاع'),
    'scheduled': (Icons.schedule_send_outlined, 'Scheduled messages', 'الرسايل المجدولة'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(settingsProvider).attachItems;
    final order = [...on, for (final k in _all.keys) if (!on.contains(k)) k];
    void save(List<String> ids) =>
        ref.read(settingsProvider.notifier).setX('attachItems', ids);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(context.t('Attach menu', 'قايمة المرفقات')),
      ),
      body: ReorderableListView(
        padding: const EdgeInsets.only(bottom: 32),
        header: SHint(context.t(
            'Choose what the paperclip menu shows. Drag to reorder.',
            'اختار إيه اللي يظهر في قايمة المرفقات. اسحب لإعادة الترتيب.')),
        onReorderItem: (a, b) {
          final l = [...order];
          l.insert(b, l.removeAt(a));
          save([for (final k in l) if (on.contains(k)) k]);
        },
        children: [
          for (final k in order)
            SwitchListTile(
              key: ValueKey(k),
              secondary: SIcon(_all[k]!.$1),
              title: Text(context.t(_all[k]!.$2, _all[k]!.$3)),
              value: on.contains(k),
              onChanged: (v) => save([
                for (final x in order)
                  if (x == k ? v : on.contains(x)) x,
              ]),
            ),
        ],
      ),
    );
  }
}

/// Save received photos / videos to the gallery — globally and per chat.
class MediaDownloadsScreen extends ConsumerWidget {
  const MediaDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final modes = <String, String>{
      for (final e in ((s.x['saveChatModes'] as Map?) ?? const {}).entries)
        '${e.key}': '${e.value}',
    };
    final chats = ref.watch(chatsProvider).value ?? const [];
    String nameOf(String id) {
      for (final ch in chats) {
        if ('${ch.id}' == id) return ch.title;
      }
      return id;
    }

    void setMode(String id, String? mode) {
      final m = {...modes};
      if (mode == null) {
        m.remove(id);
      } else {
        m[id] = mode;
      }
      c.setX('saveChatModes', m);
    }

    return SPage(
      title: context.t('Media downloads', 'تنزيل الوسائط'),
      children: [
        SGroup(title: context.t('Save to gallery automatically', 'حفظ تلقائي في المعرض'), children: [
          SwitchListTile(
            secondary: const SIcon(Icons.photo_outlined),
            title: Text(context.t('Photos', 'الصور')),
            subtitle: SHint(context.t('Received photos are copied to the gallery when they finish downloading.',
                'الصور المستلمة بتتنسخ للمعرض أول ما تخلص تحميل.')),
            value: s.x['saveGalleryPhotos'] == true,
            onChanged: (v) => c.setX('saveGalleryPhotos', v),
          ),
          SwitchListTile(
            secondary: const SIcon(Icons.videocam_outlined),
            title: Text(context.t('Videos', 'الفيديوهات')),
            value: s.x['saveGalleryVideos'] == true,
            onChanged: (v) => c.setX('saveGalleryVideos', v),
          ),
        ]),
        SGroup(
          title: context.t('Per-chat exceptions', 'استثناءات لكل شات'),
          children: [
            SHint(context.t(
                'A chat can always save or never save, whatever the switches above say.',
                'أي شات تقدر تخليه يحفظ دايمًا أو ما يحفظش أبدًا، بغض النظر عن المفاتيح اللي فوق.')),
            for (final e in modes.entries)
              ListTile(
                leading: SIcon(e.value == 'always' ? Icons.download_done : Icons.block),
                title: Text(nameOf(e.key)),
                subtitle: Text(e.value == 'always'
                    ? context.t('Always save', 'احفظ دايمًا')
                    : context.t('Never save', 'ما تحفظش أبدًا')),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => setMode(e.key, v == 'default' ? null : v),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'always', child: Text(context.t('Always save', 'احفظ دايمًا'))),
                    PopupMenuItem(value: 'never', child: Text(context.t('Never save', 'ما تحفظش أبدًا'))),
                    PopupMenuItem(value: 'default', child: Text(context.t('Remove exception', 'شيل الاستثناء'))),
                  ],
                ),
              ),
            ListTile(
              leading: const SIcon(Icons.add),
              title: Text(context.t('Add a chat…', 'إضافة شات…')),
              onTap: () async {
                final picked = await showModalBottomSheet<(String, String)>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SafeArea(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                      child: ListView(shrinkWrap: true, children: [
                        for (final ch in chats)
                          ListTile(
                            title: Text(ch.title),
                            onTap: () => Navigator.pop(context, ('${ch.id}', ch.title)),
                          ),
                      ]),
                    ),
                  ),
                );
                if (picked == null || !context.mounted) return;
                final mode = await showDialog<String>(
                  context: context,
                  builder: (_) => SimpleDialog(
                    title: Text(picked.$2),
                    children: [
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(context, 'always'),
                        child: Text(context.t('Always save', 'احفظ دايمًا')),
                      ),
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(context, 'never'),
                        child: Text(context.t('Never save', 'ما تحفظش أبدًا')),
                      ),
                    ],
                  ),
                );
                if (mode != null) setMode(picked.$1, mode);
              },
            ),
          ],
        ),
        SHint(context.t(
            'Tip: long-press any photo, video, file or voice note in a chat → "Save to device".',
            'تلميحة: اضغط مطولًا على أي صورة أو فيديو أو ملف أو ريكورد في الشات ← "حفظ على الجهاز".')),
      ],
    );
  }
}
