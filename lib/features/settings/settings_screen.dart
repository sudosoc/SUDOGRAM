import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../l10n/app_localizations.dart';
import '../chat/avatar.dart';
import '../chat/wallpapers.dart';
import '../downloads/keep_alive.dart';
import '../home/hidden_screen.dart';
import '../rules/rules_screen.dart';
import '../tools/tools_screens.dart';
import 'account_screens.dart';
import 'devices_screen.dart';
import 'ghost_screen.dart';
import 'privacy_screen.dart';
import 'profile_screen.dart';

/// Full settings page, grouped like Telegram's: profile card on top, then
/// account, Ghost & hidden chats, chats, notifications, tools.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _accents = [
    0xFF4F46E5, 0xFF06B6D4, 0xFF22C55E, 0xFFF59E0B, 0xFFEC4899, 0xFFEF4444,
    0xFF7C3AED,
  ];

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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                child: Text(title,
                    style: const TextStyle(
                        color: GlassTokens.textSecondary,
                        fontWeight: FontWeight.w600)),
              ),
            GlassSurface(radius: 20, child: Column(children: children)),
          ]),
        );

    Widget nav(IconData i, String t, WidgetBuilder b, {String? sub}) => ListTile(
          leading: Icon(i),
          title: Text(t),
          subtitle: sub == null ? null : Text(sub),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => _push(context, b),
        );

    final name = me == null
        ? ''
        : '${me.firstName} ${me.lastName}'.trim();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(l.settings)),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 32), children: [
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _push(context, (_) => const ProfileScreen()),
          child: GlassSurface(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              AvatarCircle(
                  title: name.isEmpty ? 'S' : name, photo: me?.avatar, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name.isEmpty ? l.profile : name,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (me != null && me.phone.isNotEmpty)
                    Text('+${me.phone}',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: GlassTokens.textSecondary)),
                  if (me != null && me.username.isNotEmpty)
                    Text('@${me.username}',
                        style: TextStyle(color: GlassScope.of(context).accent)),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        group(l.settingsAccount, [
          nav(Icons.shield_outlined, l.privacy, (_) => const PrivacyScreen()),
          nav(Icons.password, l.twoStep, (_) => const TwoStepScreen()),
          nav(Icons.devices_other, l.devices, (_) => const DevicesScreen()),
          nav(Icons.block, l.blocked, (_) => const BlockedScreen()),
        ]),
        group(l.settingsGhostHidden, [
          nav(Icons.visibility_off_outlined, l.ghostSettings,
              (_) => const GhostScreen(),
              sub: s.ghostGlobal ? l.ghostStatusOn : l.ghostStatusOff),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l.hiddenSettings),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () async {
              final ok = await ref.read(vaultUnlockProvider.notifier).unlock(
                  reason: l.vaultAuthReason, requireAuth: true);
              if (ok && context.mounted) {
                _push(context, (_) => const HiddenSettingsScreen());
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: Text(l.appLock),
            subtitle: Text(l.appLockHint),
            value: s.appLock,
            onChanged: c.setAppLock,
          ),
          nav(Icons.lock_outline, l.vault, (_) => const VaultScreen()),
        ]),
        group(l.settingsChats, [
          ListTile(
            leading: const Icon(Icons.title),
            title: Text(l.titleStyle),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 0, label: Text(l.titleAppName)),
                  ButtonSegment(value: 1, label: Text(l.titleUsername)),
                  ButtonSegment(value: 2, label: Text(l.titleNothing)),
                ],
                selected: {s.titleMode},
                onSelectionChanged: (v) => c.setX('titleMode', v.first),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.wallpaper_outlined),
            title: Text(l.wallpaper),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < wallpapers.length; i++)
                  GestureDetector(
                    onTap: () => c.setWallpaper(i),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: wallpapers[i],
                        color: wallpapers[i] == null ? Colors.white12 : null,
                        border: Border.all(
                            color: s.wallpaper == i ? Colors.white : Colors.white24,
                            width: s.wallpaper == i ? 2.5 : 1),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l.accentColor),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in _accents)
                  GestureDetector(
                    onTap: () => c.setAccent(Color(a)),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(a),
                        border: Border.all(
                            color: s.accent == a ? Colors.white : Colors.white24,
                            width: s.accent == a ? 2.5 : 1),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.language),
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
          SwitchListTile(
            secondary: const Icon(Icons.speed),
            title: Text(l.performanceMode),
            value: s.performanceMode,
            onChanged: c.setPerformanceMode,
          ),
        ]),
        group(l.notificationsTitle, [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(l.notificationsTitle),
            subtitle: Text(l.notificationsHint),
            value: s.notifications,
            onChanged: (v) async {
              c.setNotifications(v);
              if (v && !await backgroundAllowed()) await requestBackground();
            },
          ),
        ]),
        group(l.settingsTools, [
          nav(Icons.history, l.timeMachine, (_) => const TimeMachineScreen()),
          nav(Icons.person_search_outlined, l.contactLog,
              (_) => const ContactLogScreen()),
          nav(Icons.rule, l.rules, (_) => const RulesScreen()),
          nav(Icons.merge_type, l.joinParts, (_) => const JoinPartsScreen()),
          nav(Icons.network_check, l.networkInspector,
              (_) => const NetworkInspectorScreen()),
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
                        child: Text(l.cancelAction)),
                    TextButton(
                        onPressed: () => Navigator.pop(dctx, c2.text),
                        child: Text(l.vaultSave)),
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
              child: Wrap(spacing: 8, children: [
                for (final name in s.profiles.keys)
                  InputChip(
                    label: Text(name),
                    onPressed: () => c.applyProfile(name),
                    onDeleted: () => c.deleteProfile(name),
                  ),
              ]),
            ),
        ]),
      ]),
    );
  }
}
