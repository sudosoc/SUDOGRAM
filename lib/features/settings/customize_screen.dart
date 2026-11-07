import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../chat/avatar.dart';
import '../chat/wallpapers.dart';
import 'widgets.dart';

class CustomizeScreen extends StatelessWidget {
  const CustomizeScreen({super.key});

  @override
  Widget build(BuildContext context) => STabbedPage(
        title: context.t('Customization', 'التخصيص'),
        tabs: [
          STab(context.t('Top bar', 'الشريط العلوي'), Icons.web_asset,
              (c) => const _BarTab(),
              preview: (c) => const _HomePreview()),
          STab(context.t('Chat list', 'قائمة الشاتات'), Icons.view_list_outlined,
              (c) => const _ListTab(),
              preview: (c) => const _HomePreview()),
          STab(context.t('Chat Pro', 'الشات Pro'), Icons.chat_bubble_outline,
              (c) => const _ChatTab(),
              preview: (c) => const _ChatPreview()),
        ],
      );
}

Map<String, String> _shapes(BuildContext c, {bool hidden = false}) => {
      'circle': c.t('Circle', 'دايرة'),
      'squircle': c.t('Rounded', 'مربع مدور'),
      'square': c.t('Square', 'مربع'),
      if (hidden) 'hidden': c.t('Hidden', 'مخفي'),
    };

// ------------------------------------------------------------ previews

class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.child, this.gradient});
  final Widget child;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: gradient,
          color: gradient == null ? Colors.black26 : null,
          border: Border.all(color: Colors.white24),
        ),
        padding: const EdgeInsets.all(10),
        child: child,
      );
}

class _HomePreview extends ConsumerWidget {
  const _HomePreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final accent = GlassScope.of(context).accent;
    final title = switch (s.titleMode) {
      0 => 'SUDOGRAM',
      1 => '@sudosoc',
      _ => '',
    };
    final compact = s.rowMode == 'compact';
    Widget row(String name, String msg, String time, int unread) => Container(
          margin: const EdgeInsets.only(top: 6),
          padding: EdgeInsets.all(compact ? 6 : 9),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            if (s.avatarShape != 'hidden') ...[
              AvatarCircle(
                  title: name,
                  shape: s.avatarShape,
                  size: (compact ? s.avatarSize * .8 : s.avatarSize) * .8),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    if (s.rowMode != 'nameOnly')
                      Text(msg,
                          maxLines: compact ? 1 : s.homeLines,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: GlassTokens.textSecondary)),
                  ]),
            ),
            Column(children: [
              if (s.homeShowTime)
                Text(time,
                    style: const TextStyle(
                        fontSize: 11, color: GlassTokens.textTertiary)),
              if (unread > 0 && s.homeShowUnreadBadge)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: accent, borderRadius: BorderRadius.circular(9)),
                  child: Text('$unread', style: const TextStyle(fontSize: 11)),
                ),
            ]),
          ]),
        );
    return _PreviewFrame(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18))),
          if (s.showAccountSwitcher)
            const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.switch_account_outlined, size: 20)),
          if (s.homeShowGhost)
            const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.visibility_off_outlined, size: 20)),
          if (s.homeShowSearch)
            const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20)),
          const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.tune, size: 20)),
        ]),
        if (s.homeSections)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              for (final (i, l) in [
                context.t('All', 'الكل'),
                context.t('People', 'أشخاص'),
                context.t('Groups', 'جروبات'),
              ].indexed)
                Container(
                  margin: const EdgeInsetsDirectional.only(end: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: i == 0 ? accent.withValues(alpha: .5) : Colors.white10,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(l, style: const TextStyle(fontSize: 11)),
                ),
            ]),
          ),
        row(context.t('Sudo Friend', 'صاحبي'),
            context.t("See you at five, don't forget the files we talked about",
                'نتقابل الساعة خمسة، ماتنساش الملفات اللي اتكلمنا عنها'),
            '12:30', 3),
        row(context.t('Team group', 'جروب الشغل'),
            context.t('Meeting moved to tomorrow morning, please confirm',
                'الاجتماع اتأجل لبكرة الصبح، أكدوا من فضلكم'),
            '11:02', 0),
      ]),
    );
  }
}

class _ChatPreview extends ConsumerWidget {
  const _ChatPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final accent = GlassScope.of(context).accent;
    Widget bubble(bool out, String text, {String? name}) => Align(
          alignment: out ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.symmetric(vertical: s.chatSpacing * .75),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: _previewDeco(s, accent, out),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (name != null && s.chatShowNames)
                    Text(name,
                        style: TextStyle(
                            fontSize: 12 * s.chatFontScale,
                            fontWeight: FontWeight.w600,
                            color: accent)),
                  Text(text, textScaler: TextScaler.linear(s.chatFontScale)),
                  if (s.chatShowTime || (out && s.chatShowTicks))
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      if (s.chatShowTime)
                        const Text('12:30',
                            style: TextStyle(
                                fontSize: 10, color: GlassTokens.textTertiary)),
                      if (out && s.chatShowTicks)
                        const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.done_all, size: 13, color: Colors.lightBlueAccent)),
                    ]),
                ]),
          ),
        );
    return _PreviewFrame(
      gradient: s.wallpaper >= 0 && s.wallpaper < wallpapers.length
          ? wallpapers[s.wallpaper]
          : null,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          AvatarCircle(title: 'Sudo', shape: s.chatAvatarShape, size: 30),
          const SizedBox(width: 8),
          Text(context.t('Sudo Friend', 'صاحبي'),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          const Icon(Icons.more_vert, size: 18),
        ]),
        if (s.chatDateChips)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.black38, borderRadius: BorderRadius.circular(10)),
            child: Text(context.t('Today', 'النهاردة'),
                style: const TextStyle(fontSize: 11)),
          ),
        bubble(false, context.t('How are you?', 'عامل إيه؟'),
            name: context.t('Sudo', 'سودو')),
        bubble(true, context.t('Great, thanks!', 'تمام، شكرًا!')),
      ]),
    );
  }
}

// ----------------------------------------------------------------- tabs

class _BarTab extends ConsumerWidget {
  const _BarTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    return Column(children: [
      SGroup(children: [
        ListTile(
          leading: const Icon(Icons.title),
          title: Text(context.t('Title', 'العنوان')),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SHint(context.t('What is written at the top-left of the home screen.',
                'اللي مكتوب فوق الشمال في الشاشة الرئيسية.')),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 0, label: Text(context.t('App name', 'اسم التطبيق'))),
                ButtonSegment(value: 1, label: Text(context.t('@username', '@اليوزر'))),
                ButtonSegment(value: 2, label: Text(context.t('Nothing', 'ولا حاجة'))),
              ],
              selected: {s.titleMode},
              onSelectionChanged: (v) => c.setX('titleMode', v.first),
            ),
          ]),
        ),
        SwitchRow(
            icon: Icons.visibility_off_outlined,
            title: context.t('Ghost button', 'زر الشبح'),
            hint: context.t('Quick access to Ghost mode from the top bar.',
                'وصول سريع للوضع الشبح من الشريط العلوي.'),
            keyName: 'homeShowGhost',
            value: s.homeShowGhost),
        SwitchRow(
            icon: Icons.search,
            title: context.t('Search button', 'زر البحث'),
            hint: context.t('Hide it if you prefer pulling search another way.',
                'خبّيه لو مش بتستخدمه.'),
            keyName: 'homeShowSearch',
            value: s.homeShowSearch),
        SwitchRow(
            icon: Icons.switch_account_outlined,
            title: context.t('Accounts icon', 'أيقونة الحسابات'),
            hint: context.t(
                'Drop-down to switch accounts. Appears only when you have 2+ accounts.',
                'قائمة لتبديل الحسابات. بتظهر لما يبقى عندك حسابين أو أكتر بس.'),
            keyName: 'showAccountSwitcher',
            value: s.showAccountSwitcher),
        SwitchRow(
            icon: Icons.view_carousel_outlined,
            title: context.t('Section chips', 'شرايح الأقسام'),
            hint: context.t('All / People / Groups / your own sections under the title.',
                'الكل / أشخاص / جروبات / أقسامك تحت العنوان.'),
            keyName: 'homeSections',
            value: s.homeSections),
      ]),
      Padding(
        padding: const EdgeInsets.all(8),
        child: SHint(context.t(
            'If you hide search or the Ghost button, open hidden chats with a method that does not need them (title taps, pencil, settings).',
            'لو خبّيت البحث أو زر الشبح، افتح الشاتات المخفية بطريقة مش محتاجاهم (ضغطات العنوان، القلم، الإعدادات).')),
      ),
    ]);
  }
}

class _ListTab extends ConsumerWidget {
  const _ListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return Column(children: [
      SGroup(title: context.t('Display mode', 'طريقة العرض'), children: [
        ChoiceRow(
            icon: Icons.view_agenda_outlined,
            title: context.t('Row layout', 'شكل الصف'),
            hint: context.t(
                'Full shows name and last message; names-only is a clean list; compact fits more chats on screen.',
                'الكامل بيعرض الاسم وآخر رسالة؛ الأسماء بس قائمة نظيفة؛ المضغوط بيعرض شاتات أكتر.'),
            keyName: 'rowMode',
            current: s.rowMode,
            options: {
              'full': context.t('Name + last message', 'الاسم + آخر رسالة'),
              'nameOnly': context.t('Names only', 'الأسماء بس'),
              'compact': context.t('Compact', 'مضغوط'),
            }),
        if (s.rowMode == 'full')
          SliderRow(
              icon: Icons.format_line_spacing,
              title: context.t('Message lines', 'عدد أسطر الرسالة'),
              hint: context.t('How many lines of the last message to show.',
                  'كام سطر من آخر رسالة يظهروا.'),
              keyName: 'homeLines',
              asInt: true,
              value: s.homeLines.toDouble(),
              min: 1,
              max: 3,
              divisions: 2,
              fmt: (v) => '${v.round()}'),
      ]),
      SGroup(title: context.t('Avatars', 'الصور'), children: [
        ChoiceRow(
            icon: Icons.account_circle_outlined,
            title: context.t('Avatar shape', 'شكل الصورة'),
            hint: context.t('Pick "Hidden" for a text-only list.',
                'اختار "مخفي" لقائمة نصية بس.'),
            keyName: 'avatarShape',
            current: s.avatarShape,
            options: _shapes(context, hidden: true)),
        if (s.avatarShape != 'hidden')
          SliderRow(
              icon: Icons.photo_size_select_large,
              title: context.t('Avatar size', 'حجم الصورة'),
              keyName: 'avatarSize',
              value: s.avatarSize,
              min: 36,
              max: 72,
              divisions: 9,
              fmt: (v) => '${v.round()}'),
      ]),
      SGroup(title: context.t('Details', 'التفاصيل'), children: [
        SwitchRow(
            icon: Icons.schedule,
            title: context.t('Time', 'الوقت'),
            hint: context.t('Time of the last message on the right.',
                'وقت آخر رسالة على اليمين.'),
            keyName: 'homeShowTime',
            value: s.homeShowTime),
        SwitchRow(
            icon: Icons.markunread_outlined,
            title: context.t('Unread badge', 'عداد غير المقروء'),
            hint: context.t('The number bubble for unread messages.',
                'فقاعة الرقم للرسائل غير المقروءة.'),
            keyName: 'homeShowUnreadBadge',
            value: s.homeShowUnreadBadge),
      ]),
    ]);
  }
}

class _ChatTab extends ConsumerWidget {
  const _ChatTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return Column(children: [
      SGroup(title: context.t('Bubbles', 'الفقاعات'), children: [
        ChoiceRow(
            icon: Icons.style_outlined,
            title: context.t('Style', 'النمط'),
            hint: context.t(
                'Glass is translucent, solid is opaque, gradient fades, outline is borders only.',
                'زجاجي شفاف، ممتلئ معتم، متدرج، وحدود فقط.'),
            keyName: 'bubbleStyle',
            current: s.bubbleStyle,
            options: {
              'glass': context.t('Glass', 'زجاجي'),
              'solid': context.t('Solid', 'ممتلئ'),
              'gradient': context.t('Gradient', 'متدرج'),
              'outline': context.t('Outline', 'حدود'),
            }),
        SliderRow(
            icon: Icons.rounded_corner,
            title: context.t('Corner radius', 'استدارة الحواف'),
            keyName: 'bubbleRadius',
            value: s.bubbleRadius,
            min: 4,
            max: 28,
            divisions: 12,
            fmt: (v) => '${v.round()}'),
        SwitchRow(
            icon: Icons.chat_bubble_outline,
            title: context.t('Bubble tail', 'ذيل الفقاعة'),
            hint: context.t('A sharper corner toward the sender.',
                'ركن حاد ناحية المرسل.'),
            keyName: 'chatTail',
            value: s.chatTail),
        SliderRow(
            icon: Icons.format_line_spacing,
            title: context.t('Spacing', 'المسافة بين الرسائل'),
            keyName: 'chatSpacing',
            value: s.chatSpacing,
            min: 0,
            max: 14,
            divisions: 14,
            fmt: (v) => '${v.round()}'),
        SliderRow(
            icon: Icons.format_size,
            title: context.t('Text size', 'حجم النص'),
            hint: context.t('Only message text, not the whole app.',
                'نص الرسائل بس، مش التطبيق كله.'),
            keyName: 'chatFontScale',
            value: s.chatFontScale,
            min: .8,
            max: 1.5,
            divisions: 14,
            fmt: (v) => '${(v * 100).round()}%'),
      ]),
      SGroup(title: context.t('Details', 'التفاصيل'), children: [
        SwitchRow(
            icon: Icons.schedule,
            title: context.t('Message time', 'وقت الرسالة'),
            keyName: 'chatShowTime',
            value: s.chatShowTime),
        SwitchRow(
            icon: Icons.done_all,
            title: context.t('Read ticks', 'علامات القراءة'),
            hint: context.t('The ✓✓ on your sent messages.', 'علامة ✓✓ على رسائلك.'),
            keyName: 'chatShowTicks',
            value: s.chatShowTicks),
        SwitchRow(
            icon: Icons.badge_outlined,
            title: context.t('Sender names in groups', 'أسماء المرسلين في الجروبات'),
            keyName: 'chatShowNames',
            value: s.chatShowNames),
        SwitchRow(
            icon: Icons.calendar_today_outlined,
            title: context.t('Date separators', 'فواصل التاريخ'),
            keyName: 'chatDateChips',
            value: s.chatDateChips),
      ]),
      SGroup(title: context.t('Header', 'الهيدر'), children: [
        ChoiceRow(
            icon: Icons.account_circle_outlined,
            title: context.t('Header avatar shape', 'شكل صورة الهيدر'),
            keyName: 'chatAvatarShape',
            current: s.chatAvatarShape,
            options: _shapes(context)),
      ]),
    ]);
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
          bottomRight: out ? tail : r)
      : BorderRadius.circular(s.bubbleRadius);
  switch (s.bubbleStyle) {
    case 'solid':
      return BoxDecoration(
          borderRadius: shape,
          color: out ? accent.withValues(alpha: .9) : const Color(0xFF1F2745));
    case 'gradient':
      return BoxDecoration(
          borderRadius: shape,
          gradient: LinearGradient(
              colors: out
                  ? [accent.withValues(alpha: .75), accent.withValues(alpha: .35)]
                  : [Colors.white.withValues(alpha: .16), Colors.white.withValues(alpha: .04)]));
    case 'outline':
      return BoxDecoration(
          borderRadius: shape,
          border: Border.all(width: 1.4, color: out ? accent : Colors.white38));
    default:
      return BoxDecoration(
          borderRadius: shape,
          color: out ? accent.withValues(alpha: .35) : Colors.white.withValues(alpha: .08),
          border: Border.all(color: Colors.white24));
  }
}
