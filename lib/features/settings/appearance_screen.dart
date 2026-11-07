import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'launcher_screen.dart';
import '../../core/ui/icon_styles.dart';

import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../core/theme/presets.dart';
import '../chat/avatar.dart';
import '../home/bottom_bar.dart';
import 'chats_settings.dart';
import 'customize_screen.dart';
import 'widgets.dart';

/// Themes, glass look and bottom bar — every option has a live preview.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) => STabbedPage(
        title: context.t('Appearance', 'المظهر'),
        tabs: [
          STab(context.t('Themes', 'الثيمات'), Icons.palette_outlined,
              (c) => const _ThemesTab(),
              preview: (c) => const _MiniApp()),
          STab(context.t('Glass', 'الزجاج'), Icons.blur_on,
              (c) => const _GlassTab(),
              preview: (c) => const _MiniApp()),
          ...customizeTabs(context),
          STab(context.t('Wallpaper & text', 'الخلفية والنص'), Icons.wallpaper,
              (c) => const WallpaperTextTab(),
              preview: (c) => const ChatPreviewMock()),
          STab(context.t('Icons', 'الأيقونات'), Icons.interests_outlined,
              (c) => const _IconsTab(),
              preview: (c) => const _MiniApp()),
          STab(context.t('App icon', 'أيقونة التطبيق'), Icons.apps,
              (c) => const LauncherTab()),
          STab(context.t('Bottom bar', 'الشريط السفلي'), Icons.view_agenda_outlined,
              (c) => const _BarTab(),
              preview: (c) => const _MiniApp()),
        ],
      );
}

/// A small copy of the home screen drawn with the live settings.
class _MiniApp extends ConsumerWidget {
  const _MiniApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    Widget row(String n, String m, int u) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: GlassSurface(
            radius: 14,
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              AvatarCircle(title: n, size: 30, shape: s.avatarShape == 'hidden' ? 'circle' : s.avatarShape),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(m, style: const TextStyle(fontSize: 11, color: GlassTokens.textSecondary)),
              ])),
              if (u > 0)
                CircleAvatar(
                    radius: 9,
                    backgroundColor: GlassScope.of(context).accent,
                    child: Text('$u', style: const TextStyle(fontSize: 10))),
            ]),
          ),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 210,
        child: GlassBackdrop(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(children: [
                const Expanded(
                    child: Text('SUDOGRAM',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                GlassIconButton(icon: Icons.search, tooltip: '', size: 30),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(children: [
                row(context.t('Sudo Friend', 'صاحبي'), context.t('See you at five', 'نتقابل الساعة خمسة'), 2),
                row(context.t('Team group', 'جروب الشغل'), context.t('Meeting moved', 'الاجتماع اتأجل'), 0),
              ]),
            ),
            const Spacer(),
            if (s.barOn) const AppBottomBar(preview: true),
          ]),
        ),
      ),
    );
  }
}

class _ThemesTab extends ConsumerWidget {
  const _ThemesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    return Column(children: [
      SGroup(title: context.t('Presets', 'ثيمات جاهزة'), children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            for (final p in themePresets)
              GestureDetector(
                onTap: () {
                  c.setX('themeId', p.id);
                  c.setAccent(p.accent);
                },
                child: Container(
                  width: 92,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        width: s.themeId == p.id ? 2.5 : 1,
                        color: s.themeId == p.id ? p.accent : Colors.white24),
                  ),
                  child: Column(children: [
                    Container(
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [p.base, p.c3, p.c2, p.accent]),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(context.t(p.en, p.ar),
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ),
          ]),
        ),
      ]),
      SGroup(title: context.t('Accent colour', 'لون التمييز'), children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SHint(context.t('Buttons, badges, your bubbles and highlights use this colour.',
                'الأزرار والعدّادات وفقاعاتك والتمييز بيستخدموا اللون ده.')),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final col in const [
                Color(0xFF4F46E5), Color(0xFF3B82F6), Color(0xFF0EA5E9), Color(0xFF14B8A6),
                Color(0xFF22C55E), Color(0xFF84CC16), Color(0xFFEAB308), Color(0xFFF97316),
                Color(0xFFEF4444), Color(0xFFF43F5E), Color(0xFFEC4899), Color(0xFFD946EF),
                Color(0xFF8B5CF6), Color(0xFF64748B), Color(0xFFD4AF37), Color(0xFFFFFFFF),
              ])
                GestureDetector(
                  onTap: () => c.setAccent(col),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: col,
                    child: s.accent == col.toARGB32()
                        ? SIcon(Icons.check,
                            size: 18,
                            color: col.computeLuminance() > .6 ? Colors.black : Colors.white)
                        : null,
                  ),
                ),
            ]),
          ]),
        ),
      ]),
      SGroup(title: context.t('Background', 'الخلفية'), children: [
        SwitchRow(
            icon: Icons.blur_circular,
            title: context.t('Coloured light', 'الإضاءة الملوّنة'),
            hint: context.t('The soft colour blobs behind the app. Off = flat colour.',
                'البقع الملوّنة الناعمة ورا التطبيق. مقفولة = لون ثابت.'),
            keyName: 'bgBlobs',
            value: s.bgBlobs),
        if (s.bgBlobs)
          SliderRow(
              icon: Icons.brightness_6_outlined,
              title: context.t('Light strength', 'قوة الإضاءة'),
              hint: context.t('How bright the coloured light behind the app is.', 'قد إيه الإضاءة الملوّنة ورا التطبيق قوية.'),
            keyName: 'bgIntensity',
              value: s.bgIntensity,
              min: .2,
              max: 1.6,
              divisions: 14,
              fmt: (v) => '${(v * 100).round()}%'),
      ]),
    ]);
  }
}

class _GlassTab extends ConsumerWidget {
  const _GlassTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return Column(children: [
      SGroup(children: [
        SliderRow(
            icon: Icons.opacity,
            title: context.t('Panel opacity', 'شفافية الألواح'),
            hint: context.t('Higher = more solid panels, easier to read.',
                'أعلى = ألواح أكتر صلابة وأسهل في القراءة.'),
            keyName: 'glassFill',
            value: s.glassFill,
            min: .4,
            max: 3,
            divisions: 26,
            fmt: (v) => '${(v * 100).round()}%'),
        SliderRow(
            icon: Icons.blur_on,
            title: context.t('Blur', 'التغبيش'),
            hint: context.t('Frosted-glass blur on bars and sheets. Costs battery.',
                'تغبيش الزجاج على الأشرطة والقوائم. بيستهلك بطارية.'),
            keyName: 'glassBlur',
            value: s.glassBlur,
            min: 0,
            max: 50,
            divisions: 25,
            fmt: (v) => '${v.round()}'),
        SliderRow(
            icon: Icons.rounded_corner,
            title: context.t('Corner roundness', 'استدارة الحواف'),
            hint: context.t('Scales every card, sheet and button.',
                'بتكبّر أو بتصغّر كل الكروت والقوائم والأزرار.'),
            keyName: 'cornerScale',
            value: s.cornerScale,
            min: .2,
            max: 1.6,
            divisions: 14,
            fmt: (v) => '${(v * 100).round()}%'),
      ]),
    ]);
  }
}

class _BarTab extends ConsumerWidget {
  const _BarTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final items = s.barItems;
    final free = [for (final b in barCatalog) if (!items.contains(b.id)) b];
    return Column(children: [
      SGroup(children: [
        SwitchRow(
            icon: Icons.view_agenda_outlined,
            title: context.t('Show bottom bar', 'إظهار الشريط السفلي'),
            hint: context.t('Quick buttons at the bottom of the home screen.',
                'أزرار سريعة أسفل الشاشة الرئيسية.'),
            keyName: 'barOn',
            value: s.barOn),
      ]),
      if (s.barOn) ...[
        SGroup(title: context.t('Buttons (drag to reorder)', 'الأزرار (اسحب للترتيب)'), children: [
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorderItem: (a, b) {
              final l = List<String>.of(items);
              l.insert(b, l.removeAt(a));
              c.setX('barItems', l);
            },
            children: [
              for (final id in items)
                if (barItemById(id) != null)
                  ListTile(
                    key: ValueKey(id),
                    leading: SIcon(barItemById(id)!.icon(s.barIcons)),
                    title: Text(context.isAr ? barItemById(id)!.ar : barItemById(id)!.en),
                    trailing: items.length > 2
                        ? IconButton(
                            icon: const SIcon(Icons.remove_circle_outline),
                            onPressed: () =>
                                c.setX('barItems', [for (final e in items) if (e != id) e]),
                          )
                        : null,
                  ),
            ],
          ),
        ]),
        if (free.isNotEmpty && items.length < 6)
          SGroup(title: context.t('Add a button', 'إضافة زر'), children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(spacing: 8, runSpacing: 6, children: [
                for (final b in free)
                  ActionChip(
                    avatar: SIcon(b.icon(s.barIcons), size: 18),
                    label: Text(context.isAr ? b.ar : b.en),
                    onPressed: () => c.setX('barItems', [...items, b.id]),
                  ),
              ]),
            ),
          ]),
        SGroup(title: context.t('Look', 'الشكل'), children: [
          ChoiceRow(
              icon: Icons.web_asset,
              title: context.t('Style', 'النمط'),
              hint: context.t('Floating pill, full-width dock, or a slim bar.',
                  'كبسولة عايمة، أو شريط كامل العرض، أو شريط رفيع.'),
              keyName: 'barStyle',
              current: s.barStyle,
              options: {
                'floating': context.t('Floating', 'عايم'),
                'docked': context.t('Docked', 'ملتصق'),
                'compact': context.t('Compact', 'مضغوط'),
              }),
          ChoiceRow(
              icon: Icons.interests_outlined,
              title: context.t('Icon set', 'شكل الأيقونات'),
              hint: context.t('Style of the icons on the bar.', 'شكل الأيقونات على الشريط.'),
            keyName: 'barIcons',
              current: s.barIcons,
              options: {
                'outlined': context.t('Outlined', 'خطوط'),
                'rounded': context.t('Rounded', 'مدورة'),
                'sharp': context.t('Sharp', 'حادة'),
                'filled': context.t('Filled', 'ممتلئة'),
              }),
          ChoiceRow(
              icon: Icons.label_outline,
              title: context.t('Labels', 'الأسماء'),
              hint: context.t('When to show the text under each icon.', 'إمتى يظهر النص تحت كل أيقونة.'),
            keyName: 'barLabels',
              current: s.barLabels,
              options: {
                'always': context.t('Always', 'دايمًا'),
                'active': context.t('Active only', 'النشط بس'),
                'never': context.t('Never', 'أبدًا'),
              }),
          ChoiceRow(
              icon: Icons.radio_button_checked,
              title: context.t('Active marker', 'علامة الزر النشط'),
              hint: context.t('How the current button is highlighted.', 'إزاي الزر الحالي بيتميّز.'),
            keyName: 'barIndicator',
              current: s.barIndicator,
              options: {
                'pill': context.t('Pill', 'كبسولة'),
                'underline': context.t('Underline', 'خط'),
                'glow': context.t('Glow', 'توهج'),
                'none': context.t('None', 'بدون'),
              }),
          SliderRow(
              icon: Icons.height,
              title: context.t('Height', 'الارتفاع'),
              hint: context.t('Taller bars are easier to tap.', 'الشريط الأطول أسهل في الضغط.'),
            keyName: 'barHeight',
              value: s.barHeight,
              min: 48,
              max: 88,
              divisions: 10,
              fmt: (v) => '${v.round()}'),
          SliderRow(
              icon: Icons.opacity,
              title: context.t('Opacity', 'الشفافية'),
              hint: context.t('Higher = more solid, lower = more see-through.', 'أعلى = أصلب، أقل = أشفّ.'),
            keyName: 'barOpacity',
              value: s.barOpacity,
              min: .2,
              max: 3,
              divisions: 28,
              fmt: (v) => '${(v * 100).round()}%'),
        ]),
        SGroup(title: context.t('Behaviour', 'السلوك'), children: [
          SwitchRow(
              icon: Icons.vibration,
              title: context.t('Haptic feedback', 'اهتزاز عند الضغط'),
              hint: context.t('A small vibration when you tap a button.', 'اهتزاز خفيف لما تضغط على زر.'),
            keyName: 'barHaptic',
              value: s.barHaptic),
          SwitchRow(
              icon: Icons.mark_chat_unread_outlined,
              title: context.t('Unread badge', 'عدّاد غير المقروء'),
              hint: context.t('Shows how many chats have unread messages on the Chats button.',
                  'بيعرض عدد الشاتات غير المقروءة على زر الشاتات.'),
              keyName: 'barBadge',
              value: s.barBadge),
        ]),
      ],
    ]);
  }
}


/// Picks one of seven icon looks for the whole app, each shown live.
class _IconsTab extends ConsumerWidget {
  const _IconsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = ref.watch(settingsProvider).iconStyle;
    final names = {
      'default': context.t('Default', 'الافتراضي'),
      'outlined': context.t('Outlined', 'خطوط'),
      'filled': context.t('Filled', 'ممتلئة'),
      'rounded': context.t('Rounded', 'مدورة'),
      'sharp': context.t('Sharp', 'حادة'),
      'glow': context.t('Glow', 'توهج'),
      'badge': context.t('Badge', 'دائرة'),
    };
    const sample = [
      Icons.chat_bubble,
      Icons.person,
      Icons.settings,
      Icons.lock,
      Icons.photo_camera,
    ];
    return Column(children: [
      SHint(context.t(
          'Changes every icon in the app at once. Tap a style to apply it.',
          'بيغير كل الأيقونات في التطبيق مرة واحدة. اضغط على نمط عشان يتطبق.')),
      for (final k in kIconStyles)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => ref.read(settingsProvider.notifier).setX('iconStyle', k),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withValues(alpha: k == cur ? 0.14 : 0.05),
                border: Border.all(
                    color: k == cur ? GlassScope.of(context).accent : Colors.white12),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(names[k]!,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                for (final i in sample)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: SIcon(i, size: 22, styleOverride: k == 'default' ? 'filled' : k),
                  ),
                if (k == cur) const SIcon(Icons.check_circle, size: 18),
              ]),
            ),
          ),
        ),
    ]);
  }
}
