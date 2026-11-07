import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ui/icon_styles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../home/hidden_gate.dart';
import '../vault/intruder_camera.dart';
import 'widgets.dart';

class AppLockScreen extends ConsumerWidget {
  const AppLockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return STabbedPage(
      title: context.t('App Lock', 'قفل التطبيق'),
      tabs: [
        STab(
          context.t('Methods', 'الطرق'),
          Icons.fingerprint,
          (c) => const _Methods(),
        ),
        STab(
          context.t('Options', 'الخيارات'),
          Icons.tune,
          (c) => const _Options(),
        ),
        STab(
          context.t('Security', 'الأمان'),
          Icons.shield_outlined,
          (c) => const _Security(),
        ),
      ],
    );
  }
}

Future<void> _setLockPin(BuildContext context, WidgetRef ref) async {
  var kind = ref.read(settingsProvider).lockPinKind;
  final a = TextEditingController();
  final b = TextEditingController();
  String? err;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dc) => StatefulBuilder(
      builder: (dc, setS) {
        final digits = kind != 'text';
        final len = int.tryParse(kind) ?? 0;
        return AlertDialog(
          title: Text(context.t('App passcode', 'باسكود التطبيق')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 6,
                  children: [
                    for (final k in const ['4', '6', '8', '10', 'text'])
                      ChoiceChip(
                        label: Text(
                          k == 'text' ? context.t('Word', 'كلمة') : k,
                        ),
                        selected: kind == k,
                        onSelected: (_) => setS(() {
                          kind = k;
                          a.clear();
                          b.clear();
                          err = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: a,
                  obscureText: true,
                  keyboardType: digits
                      ? TextInputType.number
                      : TextInputType.text,
                  inputFormatters: digits
                      ? [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(len),
                        ]
                      : null,
                  decoration: InputDecoration(
                    hintText: context.t('New code', 'الكود الجديد'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: b,
                  obscureText: true,
                  keyboardType: digits
                      ? TextInputType.number
                      : TextInputType.text,
                  inputFormatters: digits
                      ? [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(len),
                        ]
                      : null,
                  decoration: InputDecoration(
                    hintText: context.t('Repeat', 'كرره'),
                  ),
                ),
                if (err != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      err!,
                      style: const TextStyle(color: GlassTokens.ringDanger),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: Text(context.t('Cancel', 'إلغاء')),
            ),
            TextButton(
              onPressed: () {
                if (a.text.isEmpty ||
                    (digits && a.text.length != len) ||
                    (!digits && a.text.length < 3)) {
                  setS(() => err = context.t('Wrong length', 'الطول غلط'));
                } else if (a.text != b.text) {
                  setS(
                    () => err = context.t(
                      "Codes don't match",
                      'الكودين مش زي بعض',
                    ),
                  );
                } else {
                  Navigator.pop(dc, true);
                }
              },
              child: Text(context.t('Save', 'حفظ')),
            ),
          ],
        );
      },
    ),
  );
  if (ok != true) return;
  final c = ref.read(settingsProvider.notifier);
  final salt = newSalt();
  c.setX('lockPinSalt', salt);
  c.setX('lockPinHash', hashPin(salt, a.text));
  c.setX('lockPinKind', kind);
  final m = ref.read(settingsProvider).lockMethods.toSet()
    ..removeWhere((e) => e == 'pin' || e == 'word')
    ..add(kind == 'text' ? 'word' : 'pin');
  c.setX('lockMethods', m.toList());
}

class _Methods extends ConsumerWidget {
  const _Methods();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final hasPin = s.lockPinHash.isNotEmpty;
    void toggle(String m, bool on) {
      final set = s.lockMethods.toSet();
      if (on) {
        set.add(m);
      } else {
        set.remove(m);
        if (set.isEmpty) return; // never leave the lock without a method
      }
      c.setX('lockMethods', set.toList());
    }

    return Column(
      children: [
        SGroup(
          children: [
            SwitchListTile(
              secondary: const SIcon(Icons.lock_outline),
              title: Text(context.t('Lock the app', 'قفل التطبيق')),
              subtitle: Text(
                context.t(
                  'Ask to unlock every time the app is opened.',
                  'اطلب فتح القفل كل ما التطبيق يتفتح.',
                ),
              ),
              value: s.appLock,
              onChanged: (v) {
                if (v && !s.lockMethods.contains('biometric') && !hasPin) {
                  c.setX('lockMethods', ['biometric']);
                }
                c.setAppLock(v);
              },
            ),
          ],
        ),
        SGroup(
          title: context.t('Unlock with', 'الفتح بـ'),
          children: [
            SwitchListTile(
              secondary: const SIcon(Icons.fingerprint),
              title: Text(
                context.t(
                  'Fingerprint / face / device lock',
                  'بصمة / وجه / قفل الجهاز',
                ),
              ),
              value: s.lockMethods.contains('biometric'),
              onChanged: (v) => toggle('biometric', v),
            ),
            ListTile(
              leading: const SIcon(Icons.pin_outlined),
              title: Text(
                hasPin
                    ? context.t('Change passcode', 'تغيير الباسكود')
                    : context.t(
                        'Set a passcode (4–10 digits or a word)',
                        'ضبط باسكود (4–10 أرقام أو كلمة)',
                      ),
              ),
              subtitle: hasPin
                  ? Text(
                      s.lockPinKind == 'text'
                          ? context.t('Word', 'كلمة')
                          : context.t(
                              '${s.lockPinKind} digits',
                              '${s.lockPinKind} أرقام',
                            ),
                    )
                  : null,
              trailing: const SIcon(Icons.chevron_right),
              onTap: () => _setLockPin(context, ref),
            ),
            if (hasPin)
              ListTile(
                leading: const SIcon(
                  Icons.delete_outline,
                  color: GlassTokens.ringDanger,
                ),
                title: Text(
                  context.t('Remove passcode', 'حذف الباسكود'),
                  style: const TextStyle(color: GlassTokens.ringDanger),
                ),
                onTap: () {
                  final set = s.lockMethods.toSet()
                    ..removeWhere((e) => e == 'pin' || e == 'word');
                  if (set.isEmpty) set.add('biometric');
                  c.setX('lockMethods', set.toList());
                  c.setX('lockPinHash', null);
                  c.setX('lockPinSalt', null);
                },
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            context.t(
              'There is no recovery for a forgotten passcode: keep fingerprint on, or you will have to reinstall (and sign in again).',
              'مفيش استرجاع للباسكود لو نسيته: سيب البصمة شغالة، أو هتضطر تمسح التطبيق وتسجل دخول من جديد.',
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

class _Options extends ConsumerWidget {
  const _Options();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final delays = {
      '0': context.t('Immediately', 'فورًا'),
      '30': context.t('30 s', '30 ث'),
      '60': context.t('1 min', 'دقيقة'),
      '300': context.t('5 min', '5 دقايق'),
      '900': context.t('15 min', '15 دقيقة'),
      '3600': context.t('1 hour', 'ساعة'),
    };
    return Column(
      children: [
        SGroup(
          title: context.t(
            'Auto-lock after leaving the app',
            'القفل بعد الخروج من التطبيق',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final e in delays.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: s.lockDelay.toString() == e.key,
                      onSelected: (_) => ref
                          .read(settingsProvider.notifier)
                          .setX('lockDelay', int.parse(e.key)),
                    ),
                ],
              ),
            ),
          ],
        ),
        SGroup(
          children: [
            SwitchRow(
              icon: Icons.visibility_off_outlined,
              title: context.t(
                'Hide app preview in recents',
                'إخفاء معاينة التطبيق في الأخيرة',
              ),
              keyName: 'lockBlockScreenshots',
              value: s.lockBlockScreenshots,
              subtitle: context.t(
                'Also blocks screenshots and screen recording.',
                'وبيمنع لقطات الشاشة وتسجيلها كمان.',
              ),
            ),
            ListTile(
              leading: const SIcon(Icons.timer_outlined),
              title: Text(
                context.t(
                  'Wrong attempts before a 30 s pause',
                  'محاولات خاطئة قبل إيقاف 30 ثانية',
                ),
              ),
              subtitle: Slider(
                value: s.lockMaxFails.toDouble(),
                min: 3,
                max: 10,
                divisions: 7,
                label: '${s.lockMaxFails}',
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .setX('lockMaxFails', v.round()),
              ),
              trailing: Text('${s.lockMaxFails}'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Security extends ConsumerWidget {
  const _Security();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return Column(
      children: [
        SGroup(
          children: [
            SwitchListTile(
              secondary: const SIcon(Icons.camera_front_outlined),
              title: Text(context.t('Intruder photo', 'صورة المتسلل')),
              subtitle: Text(
                context.t(
                  'Take a silent front-camera photo after a wrong passcode (kept only on this phone).',
                  'تصوير صامت بالكاميرا الأمامية بعد باسكود غلط (بتتحفظ على التليفون بس).',
                ),
              ),
              value: s.lockPhotoIntruder,
              onChanged: (v) async {
                if (v) await IntruderCamera.requestPermission();
                ref
                    .read(settingsProvider.notifier)
                    .setX('lockPhotoIntruder', v);
              },
            ),
            SwitchRow(
              icon: Icons.notifications_off_outlined,
              title: context.t(
                'Hide notification text while locked',
                'إخفاء نص الإشعارات والتطبيق مقفول',
              ),
              hint: context.t('While App Lock is active, notifications show no names or text.', 'وقت ما قفل التطبيق شغّال، الإشعارات متظهرش أسماء ولا نص.'),
            keyName: 'lockHidePreview',
              value: s.lockHidePreview,
            ),
          ],
        ),
        SGroup(
          children: [
            ListTile(
              leading: const SIcon(Icons.lock_clock),
              title: Text(context.t('Lock now', 'اقفل دلوقتي')),
              onTap: () {
                if (!s.appLock) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.t('Turn the lock on first', 'شغّل القفل الأول'),
                      ),
                    ),
                  );
                  return;
                }
                ref.read(appLockedProvider.notifier).lock();
              },
            ),
          ],
        ),
      ],
    );
  }
}
