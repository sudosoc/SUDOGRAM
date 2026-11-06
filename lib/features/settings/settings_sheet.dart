import '../downloads/keep_alive.dart';
import 'devices_screen.dart';
import 'privacy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../l10n/app_localizations.dart';
import '../rules/rules_screen.dart';
import '../tools/tools_screens.dart';

void showSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GlassSurface(
        blur: true,
        radius: 28,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text(l.ghostMode),
              subtitle: Text(l.ghostHint),
              value: s.ghostGlobal,
              onChanged: c.setGhostGlobal,
            ),
            SwitchListTile(
              title: Text(l.appLock),
              subtitle: Text(l.appLockHint),
              value: s.appLock,
              onChanged: c.setAppLock,
            ),
            SwitchListTile(
              title: Text(l.notificationsTitle),
              subtitle: Text(l.notificationsHint),
              value: s.notifications,
              onChanged: (v) async {
                c.setNotifications(v);
                if (v && !await backgroundAllowed()) await requestBackground();
              },
            ),
            SwitchListTile(
              title: Text(l.performanceMode),
              value: s.performanceMode,
              onChanged: c.setPerformanceMode,
            ),
            for (final (label, icon, builder) in <(String, IconData, WidgetBuilder)>[
              (l.vault, Icons.lock_outline, (_) => const VaultScreen()),
              (l.timeMachine, Icons.history, (_) => const TimeMachineScreen()),
              (l.contactLog, Icons.person_search_outlined,
                  (_) => const ContactLogScreen()),
              (l.rules, Icons.rule, (_) => const RulesScreen()),
              (l.joinParts, Icons.merge_type, (_) => const JoinPartsScreen()),
              (l.devices, Icons.devices_other, (_) => const DevicesScreen()),
              (l.privacy, Icons.shield_outlined, (_) => const PrivacyScreen()),
              (l.networkInspector, Icons.network_check,
                  (_) => const NetworkInspectorScreen()),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: builder));
                },
              ),
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined),
              title: Text(l.saveProfile),
              onTap: () async {
                final c2 = TextEditingController();
                final name = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(l.profileName),
                    content: TextField(controller: c2, autofocus: true),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, c2.text),
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(spacing: 8, children: [
                  for (final name in s.profiles.keys)
                    InputChip(
                      label: Text(name),
                      onPressed: () => c.applyProfile(name),
                      onDeleted: () => c.deleteProfile(name),
                    ),
                ]),
              ),
            ListTile(
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
          ],
        ),
      ),
    );
  }
}
