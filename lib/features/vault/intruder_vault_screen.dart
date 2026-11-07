import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../core/ui/icon_styles.dart';
import '../../core/ui/notice.dart';
import '../home/hidden_gate.dart';

/// Opens the intruder-photo vault only after fingerprint / the app password.
Future<void> openIntruderVault(BuildContext context, WidgetRef ref) async {
  final s = ref.read(settingsProvider);
  final hasLock = s.lockMethods.contains('biometric') ||
      (s.lockMethods.any((m) => m == 'pin' || m == 'word') && s.lockPinHash.isNotEmpty);
  bool ok;
  if (hasLock) {
    ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (ctx) => Scaffold(
              backgroundColor: GlassTokens.base,
              body: HiddenGateView(
                app: true,
                onUnlocked: () => Navigator.of(ctx).pop(true),
                onCancel: () => Navigator.of(ctx).pop(false),
              ),
            ),
          ),
        ) ??
        false;
  } else {
    ok = await ref
        .read(vaultUnlockProvider.notifier)
        .deviceAuth(context.t('Open intruder photos', 'فتح صور المتطفلين'));
  }
  if (ok && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const IntruderVaultScreen()),
    );
  }
}

class IntruderVaultScreen extends ConsumerStatefulWidget {
  const IntruderVaultScreen({super.key});

  @override
  ConsumerState<IntruderVaultScreen> createState() => _State();
}

class _Entry {
  _Entry(this.at, this.screen, this.path);
  final DateTime at;
  final String screen;
  final String? path;
}

class _State extends ConsumerState<IntruderVaultScreen> {
  late List<_Entry> _items = _load();

  List<_Entry> _load() => [
        for (final (t, w) in ref.read(archiveProvider).intruders())
          _Entry(
            t,
            w.split('|').first,
            w.contains('|') && File(w.split('|').last).existsSync() ? w.split('|').last : null,
          ),
      ];

  static String _fmt(DateTime t, bool ar) {
    final l = t.toLocal();
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const arD = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    String two(int v) => v.toString().padLeft(2, '0');
    return '${(ar ? arD : en)[l.weekday - 1]} ${l.year}-${two(l.month)}-${two(l.day)}  ${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }

  String _screenName(String s, BuildContext c) {
    final k = s.toLowerCase();
    if (k.contains('vault')) return c.t('Vault', 'الخزنة');
    if (k.contains('hidden')) return c.t('Hidden chats', 'الشاتات المخفية');
    return c.t('App lock', 'قفل التطبيق');
  }

  Future<void> _clear() async {
    final db = ref.read(archiveProvider);
    for (final e in _items) {
      if (e.path != null) {
        try {
          File(e.path!).deleteSync();
        } catch (_) {}
      }
    }
    db.clearIntruders();
    setState(() => _items = []);
    if (mounted) notice(context, context.t('Cleared', 'تم المسح'), kind: NoticeKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.isAr;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Intruder photos', 'صور المتطفلين')),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const SIcon(Icons.delete_sweep_outlined),
              onPressed: _clear,
            ),
        ],
      ),
      body: _items.isEmpty
          ? Center(child: Text(context.t('No attempts logged', 'مفيش محاولات مسجلة')))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final e = _items[i];
                return Card(
                  child: ListTile(
                    leading: e.path == null
                        ? const SIcon(Icons.no_photography_outlined, size: 36)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(e.path!), width: 56, height: 56, fit: BoxFit.cover),
                          ),
                    title: Text(context.t(
                        'Tried to open: ${_screenName(e.screen, context)}',
                        'حاول يفتح: ${_screenName(e.screen, context)}')),
                    subtitle: Text(_fmt(e.at, ar)),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => _Detail(
                        entry: e,
                        title: _screenName(e.screen, context),
                        when: _fmt(e.at, ar),
                      ),
                    )),
                  ),
                );
              },
            ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.entry, required this.title, required this.when});
  final _Entry entry;
  final String title;
  final String when;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(when, style: const TextStyle(fontSize: 14))),
      body: Column(children: [
        Expanded(
          child: entry.path == null
              ? Center(child: Text(context.t('No photo (camera unavailable)', 'مفيش صورة (الكاميرا مش متاحة)')))
              : InteractiveViewer(child: Center(child: Image.file(File(entry.path!)))),
        ),
        ListTile(
          leading: const SIcon(Icons.lock_outline),
          title: Text(context.t('Tried to open', 'كان بيحاول يفتح')),
          subtitle: Text(title),
        ),
        ListTile(
          leading: const SIcon(Icons.schedule),
          title: Text(context.t('Taken at', 'وقت الالتقاط')),
          subtitle: Text(when),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}
