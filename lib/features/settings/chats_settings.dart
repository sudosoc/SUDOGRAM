import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../chat/wallpapers.dart';
import 'widgets.dart';

const _accents = [
  0xFF4F46E5,
  0xFF06B6D4,
  0xFF22C55E,
  0xFFF59E0B,
  0xFFEC4899,
  0xFFEF4444,
  0xFF7C3AED,
  0xFF0EA5E9,
  0xFF14B8A6,
  0xFFF97316,
  0xFFA3E635,
  0xFFE11D48,
];

class _Theme {
  const _Theme(
    this.en,
    this.ar,
    this.accent,
    this.wall,
    this.style,
    this.radius,
  );
  final String en;
  final String ar;
  final int accent;
  final int wall;
  final String style;
  final double radius;
}

const _themes = [
  _Theme('Midnight', 'منتصف الليل', 0xFF4F46E5, 5, 'glass', 18),
  _Theme('Ocean', 'المحيط', 0xFF06B6D4, 1, 'gradient', 20),
  _Theme('Aurora', 'الشفق', 0xFF22C55E, 3, 'glass', 22),
  _Theme('Sunset', 'الغروب', 0xFFF97316, 11, 'gradient', 20),
  _Theme('Rose', 'وردي', 0xFFEC4899, 4, 'gradient', 24),
  _Theme('Royal', 'ملكي', 0xFF7C3AED, 7, 'solid', 16),
  _Theme('Crimson', 'قرمزي', 0xFFEF4444, 9, 'solid', 12),
  _Theme('Pitch black', 'أسود تام', 0xFF38BDF8, 6, 'outline', 14),
  _Theme('Forest', 'الغابة', 0xFF14B8A6, 12, 'glass', 18),
  _Theme('Graphite', 'جرافيت', 0xFFA3E635, 13, 'solid', 10),
];

class ChatsSettingsScreen extends StatelessWidget {
  const ChatsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => STabbedPage(
    title: context.t('Chats', 'الشاتات'),
    tabs: [
      STab(
        context.t('Appearance', 'المظهر'),
        Icons.palette_outlined,
        (c) => const _Appearance(),
      ),
      STab(
        context.t('Gestures', 'الإيماءات'),
        Icons.swipe,
        (c) => const _Gestures(),
      ),
      STab(context.t('General', 'عام'), Icons.tune, (c) => const _General()),
    ],
  );
}

class _Appearance extends ConsumerWidget {
  const _Appearance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    return Column(
      children: [
        SGroup(
          title: context.t('Themes', 'الثيمات'),
          children: [
            SizedBox(
              height: 108,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                children: [
                  for (final t in _themes)
                    GestureDetector(
                      onTap: () {
                        c.setAccent(Color(t.accent));
                        c.setWallpaper(t.wall);
                        c.setX('bubbleStyle', t.style);
                        c.setX('bubbleRadius', t.radius);
                      },
                      child: Container(
                        width: 88,
                        margin: const EdgeInsetsDirectional.only(end: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: wallpapers[t.wall],
                          color: wallpapers[t.wall] == null
                              ? Colors.white12
                              : null,
                          border: Border.all(
                            color: s.accent == t.accent && s.wallpaper == t.wall
                                ? Colors.white
                                : Colors.white24,
                            width: s.accent == t.accent && s.wallpaper == t.wall
                                ? 2.5
                                : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Color(t.accent),
                                borderRadius: BorderRadius.circular(
                                  t.radius / 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.t(t.en, t.ar),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        SGroup(
          title: context.t('Accent color', 'اللون الأساسي'),
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final a in _accents)
                    GestureDetector(
                      onTap: () => c.setAccent(Color(a)),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(a),
                          border: Border.all(
                            color: s.accent == a
                                ? Colors.white
                                : Colors.white24,
                            width: s.accent == a ? 2.5 : 1,
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
            SliderRow(
              icon: Icons.undo,
              title: context.t('Undo-send delay', 'مهلة التراجع عن الإرسال'),
              hint: context.t(
                  'Hold every text message for a few seconds so you can tap Undo. 0 = send instantly.',
                  'بيأجّل كل رسالة نصية كام ثانية عشان تقدر تتراجع. 0 = إرسال فوري.'),
              keyName: 'sendDelay',
              asInt: true,
              value: s.sendDelay.toDouble(),
              min: 0,
              max: 15,
              divisions: 15,
              fmt: (v) => v.round() == 0 ? context.t('off', 'مقفول') : '${v.round()}s',
            ),
            SwitchListTile(
              secondary: const Icon(Icons.speed),
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
    leading: Icon(icon),
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
          const Icon(Icons.arrow_drop_down),
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
              leading: const Icon(Icons.language),
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
