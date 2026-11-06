import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../l10n/app_localizations.dart';
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
              title: Text(l.performanceMode),
              value: s.performanceMode,
              onChanged: c.setPerformanceMode,
            ),
            for (final (label, icon, builder) in <(String, IconData, WidgetBuilder)>[
              (l.vault, Icons.lock_outline, (_) => const VaultScreen()),
              (l.timeMachine, Icons.history, (_) => const TimeMachineScreen()),
              (l.contactLog, Icons.person_search_outlined,
                  (_) => const ContactLogScreen()),
              (l.joinParts, Icons.merge_type, (_) => const JoinPartsScreen()),
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
