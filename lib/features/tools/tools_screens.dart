import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../data/vault/vault_store.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';

Widget _page(BuildContext context, String title, Widget body) {
  return Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(title),
    ),
    body: SafeArea(child: body),
  );
}

// ------------------------------------------------------------------ Vault

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  VaultSession? _session;
  String? _error;

  @override
  void dispose() {
    _session?.close();
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _setup(AppLocalizations l) {
    if (_a.text.isEmpty || _b.text.isEmpty || _a.text == _b.text) {
      setState(() => _error = l.vaultSamePass);
      return;
    }
    ref.read(vaultServiceProvider).setUp(_a.text, _b.text, decoyItems: [
      ('Shopping', 'Milk, bread, eggs'),
      ('Ideas', 'Weekend trip'),
    ]);
    _a.clear();
    _b.clear();
    setState(() => _error = null);
  }

  void _unlock(AppLocalizations l) {
    final s = ref.read(vaultServiceProvider).unlock(_a.text);
    if (s == null) {
      ref.read(archiveProvider).logIntruder('vault passcode');
      setState(() => _error = l.vaultWrong);
    } else {
      setState(() {
        _session = s;
        _error = null;
      });
    }
    _a.clear();
  }

  Widget _field(TextEditingController c, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: true,
          keyboardType: TextInputType.visiblePassword,
          decoration: InputDecoration(hintText: hint),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final svc = ref.watch(vaultServiceProvider);
    final session = _session;
    if (session != null) return _page(context, l.vault, _items(session, l));

    final setUp = svc.isSetUp;
    final intruders = setUp ? ref.read(archiveProvider).intruders() : const [];
    return _page(
      context,
      setUp ? l.vault : l.vaultSetupTitle,
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!setUp) ...[
            _field(_a, l.vaultRealPass),
            _field(_b, l.vaultDecoyPass),
          ] else
            _field(_a, l.vaultEnter),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!,
                  style: const TextStyle(color: GlassTokens.ringDanger)),
            ),
          FilledButton(
            onPressed: () => setUp ? _unlock(l) : _setup(l),
            child: Text(setUp ? l.unlock : l.vaultSave),
          ),
          if (intruders.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(l.intruderLog,
                style: const TextStyle(color: GlassTokens.textSecondary)),
            for (final (t, w) in intruders.take(10))
              Text('${t.toLocal().toString().substring(0, 16)}  $w',
                  style: const TextStyle(
                      fontSize: 12, color: GlassTokens.textTertiary)),
          ],
        ],
      ),
    );
  }

  Widget _items(VaultSession s, AppLocalizations l) {
    final items = s.items();
    return Column(
      children: [
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(l.vaultEmpty))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final i in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: GlassSurface(
                          radius: 16,
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(i.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  Text(i.body),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => setState(() => s.remove(i.id)),
                            ),
                          ]),
                        ),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l.vaultAdd),
            onPressed: () => _addDialog(s, l),
          ),
        ),
      ],
    );
  }

  Future<void> _addDialog(VaultSession s, AppLocalizations l) async {
    final t = TextEditingController();
    final b = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: t,
              decoration: InputDecoration(hintText: l.vaultAddTitle)),
          TextField(
              controller: b,
              maxLines: 5,
              decoration: InputDecoration(hintText: l.vaultAddBody)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.vaultSave)),
        ],
      ),
    );
    if (ok == true && (t.text.isNotEmpty || b.text.isNotEmpty)) {
      setState(() => s.add(t.text, b.text));
    }
  }
}

// ----------------------------------------------------------- Time Machine

class TimeMachineScreen extends ConsumerStatefulWidget {
  const TimeMachineScreen({super.key});

  @override
  ConsumerState<TimeMachineScreen> createState() => _TimeMachineState();
}

class _TimeMachineState extends ConsumerState<TimeMachineScreen> {
  int? _chat;
  DateTime _at = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final unlocked = ref.watch(vaultUnlockProvider);
    final chats = (ref.watch(chatsProvider).value ?? const <ChatSummary>[])
        .where((c) => unlocked || !settings.hiddenChats.contains(c.id))
        .toList();
    final msgs = _chat == null
        ? const <ChatMessage>[]
        : ref.read(archiveProvider).chatAt(
            _chat!, DateTime(_at.year, _at.month, _at.day, 23, 59, 59));
    return _page(
      context,
      l.timeMachine,
      Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: DropdownButton<int>(
                isExpanded: true,
                hint: Text(l.pickChat),
                value: _chat,
                items: [
                  for (final c in chats)
                    DropdownMenuItem(value: c.id, child: Text(c.title)),
                ],
                onChanged: (v) => setState(() => _chat = v),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _at,
                  firstDate: DateTime(2013),
                  lastDate: DateTime.now(),
                  helpText: l.pickDate,
                );
                if (d != null) setState(() => _at = d);
              },
              child: Text('${_at.year}-${_at.month}-${_at.day}'),
            ),
          ]),
        ),
        Expanded(
          child: ListView(
            reverse: true,
            padding: const EdgeInsets.all(12),
            children: [
              for (final m in msgs)
                Align(
                  alignment: m.outgoing
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white.withValues(alpha: GlassTokens.fill),
                      border: Border.all(
                          color: m.deletedByPeer
                              ? GlassTokens.ringDanger
                              : Colors.white
                                  .withValues(alpha: GlassTokens.border)),
                    ),
                    child: Text(m.text),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------- Contact change log

class ContactLogScreen extends ConsumerWidget {
  const ContactLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final log = ref.read(archiveProvider).contactLog();
    String field(String f) => switch (f) {
          'username' => l.fieldUsername,
          'phone' => l.fieldPhone,
          _ => l.fieldName,
        };
    return _page(
      context,
      l.contactLog,
      log.isEmpty
          ? Center(child: Text(l.contactLogEmpty))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final c in log)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: GlassSurface(
                      radius: 16,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${c.displayName} · ${field(c.field)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          Text('${c.oldValue ?? ''}  →  ${c.newValue ?? ''}',
                              textDirection: TextDirection.ltr),
                          Text(c.at.toLocal().toString().substring(0, 16),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: GlassTokens.textTertiary)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
