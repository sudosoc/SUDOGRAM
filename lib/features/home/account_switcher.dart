import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ui/icon_styles.dart';

import '../../app/app.dart' show rootNavKey;
import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../chat/avatar.dart';

/// Switches the whole app to another saved account.
void switchToAccount(WidgetRef ref, int slot) {
  if (ref.read(settingsProvider).activeSlot == slot) return;
  rootNavKey.currentState?.popUntil((r) => r.isFirst);
  ref.read(settingsProvider.notifier).switchAccount(slot);
}

/// Starts a fresh login in a new account slot.
void addAccountFlow(WidgetRef ref) {
  rootNavKey.currentState?.popUntil((r) => r.isFirst);
  ref.read(settingsProvider.notifier).addAccount();
}

String accountLabel(BuildContext c, Map<String, dynamic> a) {
  final n = (a['name'] as String?) ?? '';
  if (n.isNotEmpty) return n;
  final u = (a['username'] as String?) ?? '';
  if (u.isNotEmpty) return '@$u';
  return c.t(
    'Account ${(a['slot'] as int) + 1}',
    'حساب ${(a['slot'] as int) + 1}',
  );
}

/// Header icon: only shown when there are two or more accounts (and the user
/// has not hidden it in Settings → Accounts).
class AccountSwitcherButton extends ConsumerWidget {
  const AccountSwitcherButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final accs = s.accounts;
    if (accs.length < 2 || !s.showAccountSwitcher) {
      return const SizedBox.shrink();
    }
    final others = accs
        .where((a) => a['slot'] != s.activeSlot)
        .fold<int>(0, (n, a) => n + ((a['unread'] as int?) ?? 0));
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: PopupMenuButton<int>(
        tooltip: context.t('Accounts', 'الحسابات'),
        offset: const Offset(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        color: const Color(0xF0141A33),
        onSelected: (slot) {
          if (slot == -1) {
            addAccountFlow(ref);
          } else {
            switchToAccount(ref, slot);
          }
        },
        itemBuilder: (_) => [
          for (final a in accs)
            PopupMenuItem<int>(
              value: a['slot'] as int,
              child: SizedBox(
                width: 230,
                child: Row(
                  children: [
                    AvatarCircle(title: accountLabel(context, a), size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            accountLabel(context, a),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((a['username'] as String? ?? '').isNotEmpty)
                            Text(
                              '@${a['username']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: GlassTokens.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (a['slot'] == s.activeSlot)
                      const SIcon(
                        Icons.check_circle,
                        size: 18,
                        color: GlassTokens.ringSafe,
                      )
                    else if (((a['unread'] as int?) ?? 0) > 0)
                      Badge(label: Text('${a['unread']}')),
                  ],
                ),
              ),
            ),
          const PopupMenuDivider(),
          PopupMenuItem<int>(
            value: -1,
            child: Row(
              children: [
                const SIcon(Icons.person_add_alt_1, size: 20),
                const SizedBox(width: 10),
                Text(context.t('Add account', 'إضافة حساب')),
              ],
            ),
          ),
        ],
        child: Badge(
          isLabelVisible: others > 0,
          label: Text('$others'),
          child: GlassSurface(
            radius: 22,
            padding: const EdgeInsets.all(10),
            child: const SIcon(Icons.switch_account_outlined, size: 20),
          ),
        ),
      ),
    );
  }
}
