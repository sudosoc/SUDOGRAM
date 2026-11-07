import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../core/ui/notice.dart';
import 'launcher_icons.g.dart';

/// Chooses the home-screen icon + name (50 looks, many of them disguises).
class LauncherTab extends ConsumerWidget {
  const LauncherTab({super.key});

  static const _ch = MethodChannel('sudogram/window');

  Future<void> _pick(BuildContext context, WidgetRef ref, LauncherIcon i) async {
    try {
      await _ch.invokeMethod<void>('setLauncher', {'index': i.index});
      ref.read(settingsProvider.notifier).setX('launcherIcon', i.index);
      if (context.mounted) {
        notice(
          context,
          context.t('Icon changed to "${i.en}". The launcher may take a few seconds to refresh.',
              'تم تغيير الأيقونة إلى "${i.ar}". الشاشة الرئيسية ممكن تاخد ثواني لتتحدث.'),
          kind: NoticeKind.success,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      if (context.mounted) {
        notice(context, friendlyError(e, ar: context.isAr), kind: NoticeKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = (ref.watch(settingsProvider).x['launcherIcon'] as num?)?.toInt() ?? 0;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(
          context.t(
              'Changes the icon and the name shown on your home screen. Disguises (Calculator, Notes, Weather…) hide what the app is.',
              'بيغير أيقونة واسم التطبيق على الشاشة الرئيسية. التمويهات (آلة حاسبة، ملاحظات، طقس…) بتخفي حقيقة التطبيق.'),
          style: const TextStyle(color: GlassTokens.textSecondary, fontSize: 13),
        ),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.78,
        ),
        itemCount: kLauncherIcons.length,
        itemBuilder: (_, k) {
          final i = kLauncherIcons[k];
          final sel = i.index == cur;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _pick(context, ref, i),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withValues(alpha: sel ? 0.14 : 0.04),
                border: Border.all(
                    color: sel ? GlassScope.of(context).accent : Colors.transparent,
                    width: 2),
              ),
              child: Column(children: [
                Expanded(
                  child: i.index == 0
                      ? Image.asset('assets/launcher_default.png', fit: BoxFit.contain)
                      : Image.asset('assets/launcher/ic_l${i.index.toString().padLeft(2, '0')}.png',
                          fit: BoxFit.contain),
                ),
                const SizedBox(height: 4),
                Text(context.isAr ? i.ar : i.en,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11)),
              ]),
            ),
          );
        },
      ),
    ]);
  }
}
