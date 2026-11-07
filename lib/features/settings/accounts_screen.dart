import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../chat/avatar.dart';
import '../home/account_switcher.dart';
import 'widgets.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final accs = s.accounts.isEmpty
        ? [
            <String, dynamic>{
              'slot': 0,
              'name': '',
              'username': '',
              'unread': 0,
            },
          ]
        : s.accounts;
    return SPage(
      title: context.t('Accounts', 'الحسابات'),
      children: [
        SGroup(
          children: [
            for (final a in accs)
              ListTile(
                leading: AvatarCircle(
                  title: accountLabel(context, a),
                  size: 42,
                ),
                title: Text(accountLabel(context, a)),
                subtitle: Text(
                  [
                    if ((a['username'] as String? ?? '').isNotEmpty)
                      '@${a['username']}',
                    if (((a['unread'] as int?) ?? 0) > 0)
                      context.t(
                        '${a['unread']} unread',
                        '${a['unread']} غير مقروء',
                      ),
                  ].join(' · '),
                ),
                trailing: a['slot'] == s.activeSlot
                    ? const Icon(
                        Icons.check_circle,
                        color: GlassTokens.ringSafe,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () {
                              switchToAccount(ref, a['slot'] as int);
                              Navigator.of(context).popUntil((r) => r.isFirst);
                            },
                            child: Text(context.t('Switch', 'تبديل')),
                          ),
                          if (accs.length > 1)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: GlassTokens.ringDanger,
                              ),
                              onPressed: () async {
                                final slot = a['slot'] as int;
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (dc) => AlertDialog(
                                    title: Text(
                                      context.t(
                                        'Remove account?',
                                        'حذف الحساب؟',
                                      ),
                                    ),
                                    content: Text(
                                      context.t(
                                        'It is only removed from this app (local data deleted). The Telegram account itself stays; end its session from Devices if you want.',
                                        'بيتشال من التطبيق ده بس (البيانات المحلية بتتمسح). حساب تليجرام نفسه فاضل؛ لو عايز تفصله من الأجهزة.',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dc, false),
                                        child: Text(
                                          context.t('Cancel', 'إلغاء'),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dc, true),
                                        child: Text(context.t('Remove', 'حذف')),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  c.removeAccount(slot);
                                  await wipeSlot(slot);
                                }
                              },
                            ),
                        ],
                      ),
              ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: Text(context.t('Add account', 'إضافة حساب')),
              subtitle: Text(
                context.t(
                  'Sign in with another phone number or QR; switch any time.',
                  'سجّل برقم تاني أو QR، وبدّل في أي وقت.',
                ),
              ),
              onTap: () {
                addAccountFlow(ref);
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
            ),
          ],
        ),
        SGroup(
          children: [
            SwitchRow(
              icon: Icons.switch_account_outlined,
              title: context.t(
                'Show accounts icon on Home',
                'إظهار أيقونة الحسابات في الهوم',
              ),
              subtitle: context.t(
                'The drop-down appears only with 2+ accounts.',
                'القائمة بتظهر مع حسابين أو أكتر بس.',
              ),
              keyName: 'showAccountSwitcher',
              value: s.showAccountSwitcher,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            context.t(
              'Only the active account is connected at a time: unread counts of the others are the ones from the last time you used them.',
              'حساب واحد بس بيبقى متصل في المرة: عدادات الحسابات التانية هي آخر قيمة شوفتها لما كنت فيها.',
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
