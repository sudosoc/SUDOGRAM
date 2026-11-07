import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../l10n/app_localizations.dart';
import '../chat/avatar.dart';
import '../home/hidden_gate.dart';
import '../home/hidden_screen.dart';
import '../rules/rules_screen.dart';
import '../tools/tools_screens.dart';
import '../../core/i18n/tr.dart';
import 'account_screens.dart';
import 'accounts_screen.dart';
import 'applock_screen.dart';
import 'chats_settings.dart';
import '../tools/tools_hub.dart';
import 'appearance_screen.dart';
import 'customize_screen.dart';
import 'notif_screen.dart';
import 'devices_screen.dart';
import 'ghost_screen.dart';
import 'privacy_screen.dart';
import 'profile_screen.dart';

/// Full settings page, grouped like Telegram's: profile card on top, then
/// account, Ghost & hidden chats, chats, notifications, tools.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _push(BuildContext c, WidgetBuilder b) =>
      Navigator.of(c).push(MaterialPageRoute<void>(builder: b));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final me = ref.watch(meProvider).value;

    Widget group(String? title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Text(
                title,
                style: const TextStyle(
                  color: GlassTokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          GlassSurface(radius: 20, child: Column(children: children)),
        ],
      ),
    );

    Widget nav(IconData i, String t, WidgetBuilder b, {String? sub}) =>
        ListTile(
          leading: Icon(i),
          title: Text(t),
          subtitle: sub == null ? null : Text(sub),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => _push(context, b),
        );

    final name = me == null ? '' : '${me.firstName} ${me.lastName}'.trim();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _push(context, (_) => const ProfileScreen()),
            child: GlassSurface(
              radius: 24,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AvatarCircle(
                    title: name.isEmpty ? 'S' : name,
                    photo: me?.avatar,
                    size: 64,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? l.profile : name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (me != null && me.phone.isNotEmpty)
                          Text(
                            '+${me.phone}',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              color: GlassTokens.textSecondary,
                            ),
                          ),
                        if (me != null && me.username.isNotEmpty)
                          Text(
                            '@${me.username}',
                            style: TextStyle(
                              color: GlassScope.of(context).accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          group(l.settingsAccount, [
            nav(Icons.shield_outlined, l.privacy, (_) => const PrivacyScreen()),
            nav(Icons.password, l.twoStep, (_) => const TwoStepScreen()),
            nav(Icons.devices_other, l.devices, (_) => const DevicesScreen()),
            nav(Icons.block, l.blocked, (_) => const BlockedScreen()),
            nav(
              Icons.switch_account_outlined,
              context.t('Accounts', 'الحسابات'),
              (_) => const AccountsScreen(),
              sub: context.t(
                '${s.accounts.isEmpty ? 1 : s.accounts.length} signed in',
                '${s.accounts.isEmpty ? 1 : s.accounts.length} مسجّل',
              ),
            ),
          ]),
          group(l.settingsGhostHidden, [
            nav(
              Icons.visibility_off_outlined,
              l.ghostSettings,
              (_) => const GhostScreen(),
              sub: s.ghostGlobal ? l.ghostStatusOn : l.ghostStatusOff,
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(l.hiddenSettings),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () async {
                final ok = await requireHiddenAuth(context, ref);
                if (ok && context.mounted) {
                  _push(context, (_) => const HiddenSettingsScreen());
                }
              },
            ),
            nav(
              Icons.fingerprint,
              l.appLock,
              (_) => const AppLockScreen(),
              sub: s.appLock
                  ? context.t('On', 'شغال')
                  : context.t('Off', 'مقفول'),
            ),
            nav(Icons.lock_outline, l.vault, (_) => const VaultScreen()),
          ]),
          group(context.t('Look & feel', 'المظهر والسلوك'), [
            nav(
              Icons.chat_outlined,
              l.settingsChats,
              (_) => const ChatsSettingsScreen(),
              sub: context.t(
                'Themes, gestures, language',
                'ثيمات، إيماءات، لغة',
              ),
            ),
            nav(
              Icons.palette_outlined,
              context.t('Themes & look', 'الثيمات والمظهر'),
              (_) => const AppearanceScreen(),
              sub: context.t('12 themes, glass, bottom bar',
                  '12 ثيم، زجاج، شريط سفلي'),
            ),
            nav(
              Icons.dashboard_customize_outlined,
              context.t('Customization', 'التخصيص'),
              (_) => const CustomizeScreen(),
              sub: context.t(
                'Home, chat list, chat Pro',
                'الهوم، القائمة، الشات Pro',
              ),
            ),
            nav(
              Icons.notifications_outlined,
              l.notificationsTitle,
              (_) => const NotificationsScreen(),
              sub: s.notifications
                  ? context.t('On', 'شغالة')
                  : context.t('Off', 'مقفولة'),
            ),
          ]),
          group(l.settingsTools, [
            nav(
              Icons.handyman_outlined,
              context.t('All tools', 'كل الأدوات'),
              (_) => const ToolsHubScreen(),
              sub: context.t('QR, passwords, hashes, encoders…',
                  'QR وباسوردات وهاش وترميز…'),
            ),
            nav(Icons.history, l.timeMachine, (_) => const TimeMachineScreen()),
            nav(
              Icons.person_search_outlined,
              l.contactLog,
              (_) => const ContactLogScreen(),
            ),
            nav(Icons.rule, l.rules, (_) => const RulesScreen()),
            nav(Icons.merge_type, l.joinParts, (_) => const JoinPartsScreen()),
            nav(
              Icons.network_check,
              l.networkInspector,
              (_) => const NetworkInspectorScreen(),
            ),
          ]),
          group(l.settingsPresets, [
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined),
              title: Text(l.saveProfile),
              onTap: () async {
                final c2 = TextEditingController();
                final name = await showDialog<String>(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: Text(l.profileName),
                    content: TextField(controller: c2, autofocus: true),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dctx),
                        child: Text(l.cancelAction),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dctx, c2.text),
                        child: Text(l.vaultSave),
                      ),
                    ],
                  ),
                );
                if (name != null && name.trim().isNotEmpty) {
                  c.saveProfile(name.trim());
                }
              },
            ),
            if (s.profiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final name in s.profiles.keys)
                      InputChip(
                        label: Text(name),
                        onPressed: () => c.applyProfile(name),
                        onDeleted: () => c.deleteProfile(name),
                      ),
                  ],
                ),
              ),
          ]),
        ],
      ),
    );
  }
}
