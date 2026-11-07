import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../chat/contacts_screen.dart';
import '../settings/accounts_screen.dart';
import '../settings/appearance_screen.dart';
import '../settings/customize_screen.dart';
import '../settings/devices_screen.dart';
import '../settings/ghost_screen.dart';
import '../settings/privacy_screen.dart';
import '../settings/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../tools/tools_hub.dart';
import '../tools/tools_screens.dart';
import 'archive_screen.dart';

/// One thing the bar can hold. [icons] = outlined, rounded, sharp, filled.
class BarItem {
  const BarItem(this.id, this.en, this.ar, this.icons, [this.screen]);
  final String id;
  final String en;
  final String ar;
  final List<IconData> icons;
  final Widget Function()? screen;

  IconData icon(String style) => switch (style) {
        'outlined' => icons[0],
        'sharp' => icons[2],
        'filled' => icons[3],
        _ => icons[1],
      };
}

final barCatalog = <BarItem>[
  const BarItem('chats', 'Chats', 'الشاتات', [
    Icons.chat_bubble_outline,
    Icons.chat_bubble_outline_rounded,
    Icons.chat_bubble_outline_sharp,
    Icons.chat_bubble
  ]),
  BarItem('contacts', 'Contacts', 'جهات الاتصال', const [
    Icons.people_outline,
    Icons.people_outline_rounded,
    Icons.people_outline_sharp,
    Icons.people
  ], () => const ContactsScreen()),
  BarItem('archive', 'Archive', 'الأرشيف', const [
    Icons.archive_outlined,
    Icons.archive_rounded,
    Icons.archive_sharp,
    Icons.archive
  ], () => const ArchiveScreen()),
  BarItem('tools', 'Tools', 'الأدوات', const [
    Icons.handyman_outlined,
    Icons.handyman_rounded,
    Icons.handyman_sharp,
    Icons.handyman
  ], () => const ToolsHubScreen()),
  BarItem('ghost', 'Ghost', 'الشبح', const [
    Icons.visibility_off_outlined,
    Icons.visibility_off_rounded,
    Icons.visibility_off_sharp,
    Icons.visibility_off
  ], () => const GhostScreen()),
  BarItem('settings', 'Settings', 'الإعدادات', const [
    Icons.settings_outlined,
    Icons.settings_rounded,
    Icons.settings_sharp,
    Icons.settings
  ], () => const SettingsScreen()),
  BarItem('profile', 'Profile', 'البروفايل', const [
    Icons.person_outline,
    Icons.person_outline_rounded,
    Icons.person_outline_sharp,
    Icons.person
  ], () => const ProfileScreen()),
  BarItem('accounts', 'Accounts', 'الحسابات', const [
    Icons.switch_account_outlined,
    Icons.switch_account_rounded,
    Icons.switch_account_sharp,
    Icons.switch_account
  ], () => const AccountsScreen()),
  BarItem('devices', 'Devices', 'الأجهزة', const [
    Icons.devices_other_outlined,
    Icons.devices_other_rounded,
    Icons.devices_other_sharp,
    Icons.devices_other
  ], () => const DevicesScreen()),
  BarItem('privacy', 'Privacy', 'الخصوصية', const [
    Icons.shield_outlined,
    Icons.shield_rounded,
    Icons.shield_sharp,
    Icons.shield
  ], () => const PrivacyScreen()),
  BarItem('vault', 'Vault', 'الخزنة', const [
    Icons.lock_outline,
    Icons.lock_outline_rounded,
    Icons.lock_outline_sharp,
    Icons.lock
  ], () => const VaultScreen()),
  BarItem('themes', 'Themes', 'الثيمات', const [
    Icons.palette_outlined,
    Icons.palette_rounded,
    Icons.palette_sharp,
    Icons.palette
  ], () => const AppearanceScreen()),
  BarItem('customize', 'Customize', 'التخصيص', const [
    Icons.dashboard_customize_outlined,
    Icons.dashboard_customize_rounded,
    Icons.dashboard_customize_sharp,
    Icons.dashboard_customize
  ], () => const CustomizeScreen()),
];

BarItem? barItemById(String id) {
  for (final b in barCatalog) {
    if (b.id == id) return b;
  }
  return null;
}

/// The configurable bottom bar. [preview] draws it inert, for settings.
class AppBottomBar extends ConsumerWidget {
  const AppBottomBar({super.key, this.preview = false});
  final bool preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    if (!s.barOn && !preview) return const SizedBox.shrink();
    final items = [
      for (final id in s.barItems)
        if (barItemById(id) != null) barItemById(id)!,
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    final accent = GlassScope.of(context).accent;
    final unread = preview
        ? 3
        : (ref.watch(chatsProvider).value ?? const [])
            .where((c) => !c.muted && c.unread > 0)
            .length;
    final compact = s.barStyle == 'compact';
    final showLabel = s.barLabels != 'never' && !compact;

    Widget cell(BarItem b) {
      final active = b.id == 'chats';
      final color = active ? accent : GlassTokens.textSecondary;
      final label = context.isAr ? b.ar : b.en;
      Widget icon = Icon(b.icon(s.barIcons), color: color, size: compact ? 22 : 24);
      if (s.barBadge && b.id == 'chats' && unread > 0) {
        icon = Badge(label: Text('$unread'), child: icon);
      }
      Widget body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
                horizontal: s.barIndicator == 'pill' && active ? 16 : 0,
                vertical: 4),
            decoration: BoxDecoration(
              color: s.barIndicator == 'pill' && active
                  ? accent.withValues(alpha: .22)
                  : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: s.barIndicator == 'glow' && active
                  ? [BoxShadow(color: accent.withValues(alpha: .6), blurRadius: 16)]
                  : null,
            ),
            child: icon,
          ),
          if (showLabel && (s.barLabels == 'always' || active))
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          if (s.barIndicator == 'underline')
            Container(
              margin: const EdgeInsets.only(top: 3),
              height: 3,
              width: active ? 18 : 0,
              decoration: BoxDecoration(
                  color: accent, borderRadius: BorderRadius.circular(2)),
            ),
        ],
      );
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: preview
              ? null
              : () {
                  if (s.barHaptic) HapticFeedback.selectionClick();
                  final scr = b.screen;
                  if (scr != null) {
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => scr()));
                  }
                },
          child: body,
        ),
      );
    }

    final bar = GlassSurface(
      blur: true,
      radius: s.barStyle == 'docked' ? 0 : 28,
      fill: GlassTokens.fillStrong * s.barOpacity,
      child: SizedBox(
        height: compact ? s.barHeight - 12 : s.barHeight,
        child: Row(children: [for (final b in items) cell(b)]),
      ),
    );
    if (s.barStyle == 'docked') return bar;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: bar,
    );
  }
}
