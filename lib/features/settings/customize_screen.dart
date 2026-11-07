import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../chat/avatar.dart';
import 'widgets.dart';

class CustomizeScreen extends StatelessWidget {
  const CustomizeScreen({super.key});

  @override
  Widget build(BuildContext context) => STabbedPage(
    title: context.t('Customization', 'التخصيص'),
    tabs: [
      STab(
        context.t('Home', 'الرئيسية'),
        Icons.home_outlined,
        (c) => const _HomeTab(),
      ),
      STab(
        context.t('Chat list', 'قائمة الشاتات'),
        Icons.view_list_outlined,
        (c) => const _ListTab(),
      ),
      STab(
        context.t('Chat Pro', 'الشات Pro'),
        Icons.chat_bubble_outline,
        (c) => const _ChatTab(),
      ),
    ],
  );
}

Map<String, String> _shapes(BuildContext c, {bool hidden = false}) => {
  'circle': c.t('Circle', 'دايرة'),
  'squircle': c.t('Rounded', 'مربع مدور'),
  'square': c.t('Square', 'مربع'),
  if (hidden) 'hidden': c.t('Hidden', 'مخفي'),
};

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    return Column(
      children: [
        SGroup(
          title: context.t('Top bar', 'الشريط العلوي'),
          children: [
            ListTile(
              leading: const Icon(Icons.title),
              title: Text(context.t('Title', 'العنوان')),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: 0,
                      label: Text(context.t('App name', 'اسم التطبيق')),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text(context.t('@username', '@اليوزر')),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text(context.t('Nothing', 'ولا حاجة')),
                    ),
                  ],
                  selected: {s.titleMode},
                  onSelectionChanged: (v) => c.setX('titleMode', v.first),
                ),
              ),
            ),
            SwitchRow(
              icon: Icons.visibility_off_outlined,
              title: context.t('Show Ghost button', 'إظهار زر الشبح'),
              keyName: 'homeShowGhost',
              value: s.homeShowGhost,
            ),
            SwitchRow(
              icon: Icons.search,
              title: context.t('Show search button', 'إظهار زر البحث'),
              keyName: 'homeShowSearch',
              value: s.homeShowSearch,
            ),
            SwitchRow(
              icon: Icons.switch_account_outlined,
              title: context.t('Show accounts icon', 'إظهار أيقونة الحسابات'),
              subtitle: context.t(
                'Only appears when you have 2+ accounts.',
                'بتظهر لما يبقى عندك حسابين أو أكتر.',
              ),
              keyName: 'showAccountSwitcher',
              value: s.showAccountSwitcher,
            ),
            SwitchRow(
              icon: Icons.view_carousel_outlined,
              title: context.t(
                'Section chips (People / Groups…)',
                'شرايح الأقسام (أشخاص / جروبات…)',
              ),
              keyName: 'homeSections',
              value: s.homeSections,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            context.t(
              'Tip: if you hide search or the Ghost button, open hidden chats with a method that does not need them (title taps, pencil, settings).',
              'تنبيه: لو خبّيت البحث أو زر الشبح، افتح الشاتات المخفية بطريقة مش محتاجاهم (ضغطات العنوان، القلم، الإعدادات).',
            ),
            style: const TextStyle(
              color: GlassTokens.textSecondary,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ListTab extends ConsumerWidget {
  const _ListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final modes = {
      'full': context.t('Name + last message', 'الاسم + آخر رسالة'),
      'nameOnly': context.t('Names only', 'الأسماء بس'),
      'compact': context.t('Compact', 'مضغوط'),
    };
    return Column(
      children: [
        SGroup(
          title: context.t('Preview', 'معاينة'),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: _RowPreview(s: s),
            ),
          ],
        ),
        SGroup(
          title: context.t('Display mode', 'طريقة العرض'),
          children: [
            ChoiceRow(
              icon: Icons.view_agenda_outlined,
              title: context.t('Row layout', 'شكل الصف'),
              keyName: 'rowMode',
              current: s.rowMode,
              options: modes,
            ),
            if (s.rowMode == 'full')
              SliderRow(
                icon: Icons.format_line_spacing,
                title: context.t('Message lines', 'عدد أسطر الرسالة'),
                keyName: 'homeLines',
                value: s.homeLines.toDouble(),
                min: 1,
                max: 3,
                divisions: 2,
                fmt: (v) => '${v.round()}',
              ),
          ],
        ),
        SGroup(
          title: context.t('Avatars', 'الصور'),
          children: [
            ChoiceRow(
              icon: Icons.account_circle_outlined,
              title: context.t('Avatar shape', 'شكل الصورة'),
              keyName: 'avatarShape',
              current: s.avatarShape,
              options: _shapes(context, hidden: true),
            ),
            if (s.avatarShape != 'hidden')
              SliderRow(
                icon: Icons.photo_size_select_large,
                title: context.t('Avatar size', 'حجم الصورة'),
                keyName: 'avatarSize',
                value: s.avatarSize,
                min: 36,
                max: 72,
                divisions: 9,
                fmt: (v) => '${v.round()}',
              ),
          ],
        ),
        SGroup(
          title: context.t('Details', 'التفاصيل'),
          children: [
            SwitchRow(
              icon: Icons.schedule,
              title: context.t('Show time', 'إظهار الوقت'),
              keyName: 'homeShowTime',
              value: s.homeShowTime,
            ),
            SwitchRow(
              icon: Icons.markunread_outlined,
              title: context.t('Show unread badge', 'إظهار عداد غير المقروء'),
              keyName: 'homeShowUnreadBadge',
              value: s.homeShowUnreadBadge,
            ),
          ],
        ),
      ],
    );
  }
}

class _RowPreview extends StatelessWidget {
  const _RowPreview({required this.s});
  final AppSettings s;

  @override
  Widget build(BuildContext context) {
    final compact = s.rowMode == 'compact';
    return Row(
      children: [
        if (s.avatarShape != 'hidden') ...[
          AvatarCircle(
            title: 'Sudo',
            shape: s.avatarShape,
            size: compact ? s.avatarSize * .8 : s.avatarSize,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('Sudo Friend', 'صاحبي'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              if (s.rowMode != 'nameOnly')
                Text(
                  context.t(
                    'See you at five, don\'t forget the files we talked about yesterday',
                    'نتقابل الساعة خمسة، ماتنساش الملفات اللي اتكلمنا عنها إمبارح',
                  ),
                  maxLines: compact ? 1 : s.homeLines,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: GlassTokens.textSecondary),
                ),
            ],
          ),
        ),
        Column(
          children: [
            if (s.homeShowTime)
              const Text(
                '12:30',
                style: TextStyle(fontSize: 12, color: GlassTokens.textTertiary),
              ),
            if (s.homeShowUnreadBadge)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: GlassScope.of(context).accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('3', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChatTab extends ConsumerWidget {
  const _ChatTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final accent = GlassScope.of(context).accent;
    Widget bubble(bool out) => Align(
      alignment: out ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: s.chatSpacing * .75),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: _previewDeco(s, accent, out),
        child: Text(
          out
              ? context.t('Hello!', 'أهلاً!')
              : context.t('How are you?', 'عامل إيه؟'),
          textScaler: TextScaler.linear(s.chatFontScale),
        ),
      ),
    );
    return Column(
      children: [
        SGroup(
          title: context.t('Preview', 'معاينة'),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [bubble(false), bubble(true)]),
            ),
          ],
        ),
        SGroup(
          title: context.t('Bubbles', 'الفقاعات'),
          children: [
            ChoiceRow(
              icon: Icons.style_outlined,
              title: context.t('Style', 'النمط'),
              keyName: 'bubbleStyle',
              current: s.bubbleStyle,
              options: {
                'glass': context.t('Glass', 'زجاجي'),
                'solid': context.t('Solid', 'ممتلئ'),
                'gradient': context.t('Gradient', 'متدرج'),
                'outline': context.t('Outline', 'حدود'),
              },
            ),
            SliderRow(
              icon: Icons.rounded_corner,
              title: context.t('Corner radius', 'استدارة الحواف'),
              keyName: 'bubbleRadius',
              value: s.bubbleRadius,
              min: 4,
              max: 28,
              divisions: 12,
              fmt: (v) => '${v.round()}',
            ),
            SwitchRow(
              icon: Icons.chat_bubble_outline,
              title: context.t('Bubble tail', 'ذيل الفقاعة'),
              keyName: 'chatTail',
              value: s.chatTail,
            ),
            SliderRow(
              icon: Icons.format_line_spacing,
              title: context.t(
                'Spacing between messages',
                'المسافة بين الرسائل',
              ),
              keyName: 'chatSpacing',
              value: s.chatSpacing,
              min: 0,
              max: 14,
              divisions: 14,
              fmt: (v) => '${v.round()}',
            ),
            SliderRow(
              icon: Icons.format_size,
              title: context.t('Message text size', 'حجم نص الرسائل'),
              keyName: 'chatFontScale',
              value: s.chatFontScale,
              min: .8,
              max: 1.5,
              divisions: 14,
              fmt: (v) => '${(v * 100).round()}%',
            ),
          ],
        ),
        SGroup(
          title: context.t('Details', 'التفاصيل'),
          children: [
            SwitchRow(
              icon: Icons.schedule,
              title: context.t('Message time', 'وقت الرسالة'),
              keyName: 'chatShowTime',
              value: s.chatShowTime,
            ),
            SwitchRow(
              icon: Icons.done_all,
              title: context.t('Read ticks', 'علامات القراءة'),
              keyName: 'chatShowTicks',
              value: s.chatShowTicks,
            ),
            SwitchRow(
              icon: Icons.badge_outlined,
              title: context.t(
                'Sender names in groups',
                'أسماء المرسلين في الجروبات',
              ),
              keyName: 'chatShowNames',
              value: s.chatShowNames,
            ),
            SwitchRow(
              icon: Icons.calendar_today_outlined,
              title: context.t('Date separators', 'فواصل التاريخ'),
              keyName: 'chatDateChips',
              value: s.chatDateChips,
            ),
          ],
        ),
        SGroup(
          title: context.t('Header', 'الهيدر'),
          children: [
            ChoiceRow(
              icon: Icons.account_circle_outlined,
              title: context.t('Header avatar shape', 'شكل صورة الهيدر'),
              keyName: 'chatAvatarShape',
              current: s.chatAvatarShape,
              options: _shapes(context),
            ),
          ],
        ),
      ],
    );
  }
}

BoxDecoration _previewDeco(AppSettings s, Color accent, bool out) {
  final r = Radius.circular(s.bubbleRadius);
  const tail = Radius.circular(4);
  final shape = s.chatTail
      ? BorderRadius.only(
          topLeft: r,
          topRight: r,
          bottomLeft: out ? r : tail,
          bottomRight: out ? tail : r,
        )
      : BorderRadius.circular(s.bubbleRadius);
  switch (s.bubbleStyle) {
    case 'solid':
      return BoxDecoration(
        borderRadius: shape,
        color: out ? accent.withValues(alpha: .9) : const Color(0xFF1F2745),
      );
    case 'gradient':
      return BoxDecoration(
        borderRadius: shape,
        gradient: LinearGradient(
          colors: out
              ? [accent.withValues(alpha: .75), accent.withValues(alpha: .35)]
              : [
                  Colors.white.withValues(alpha: .16),
                  Colors.white.withValues(alpha: .04),
                ],
        ),
      );
    case 'outline':
      return BoxDecoration(
        borderRadius: shape,
        border: Border.all(width: 1.4, color: out ? accent : Colors.white38),
      );
    default:
      return BoxDecoration(
        borderRadius: shape,
        color: out
            ? accent.withValues(alpha: .35)
            : Colors.white.withValues(alpha: .08),
        border: Border.all(color: Colors.white24),
      );
  }
}
