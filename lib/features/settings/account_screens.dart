import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';

class BlockedScreen extends ConsumerStatefulWidget {
  const BlockedScreen({super.key});

  @override
  ConsumerState<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends ConsumerState<BlockedScreen> {
  late Future<List<ChatSummary>> _f = ref.read(gatewayProvider).blockedUsers();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(l.blocked)),
      body: FutureBuilder<List<ChatSummary>>(
        future: _f,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: Text(l.connecting));
          }
          final list = snap.data ?? const <ChatSummary>[];
          if (list.isEmpty) return Center(child: Text(l.noBlocked));
          return ListView(children: [
            for (final c in list)
              ListTile(
                title: Text(c.title),
                trailing: TextButton(
                  child: Text(l.unblockUser),
                  onPressed: () async {
                    await ref.read(gatewayProvider).blockUser(c.id, false);
                    if (mounted) {
                      setState(() => _f = ref.read(gatewayProvider).blockedUsers());
                    }
                  },
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class TwoStepScreen extends ConsumerStatefulWidget {
  const TwoStepScreen({super.key});

  @override
  ConsumerState<TwoStepScreen> createState() => _TwoStepScreenState();
}

class _TwoStepScreenState extends ConsumerState<TwoStepScreen> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _hint = TextEditingController();
  bool? _on;

  @override
  void initState() {
    super.initState();
    ref.read(gatewayProvider).hasCloudPassword().then((v) {
      if (mounted) setState(() => _on = v);
    });
  }

  Future<void> _apply() async {
    final l = AppLocalizations.of(context);
    final ok = await ref.read(gatewayProvider).setCloudPassword(
        oldPassword: _old.text, newPassword: _new.text, hint: _hint.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? l.passwordChanged : l.passwordFailed)));
    if (ok) {
      _old.clear();
      _new.clear();
      _hint.clear();
      final v = await ref.read(gatewayProvider).hasCloudPassword();
      if (mounted) setState(() => _on = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(l.twoStep)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ListTile(
          leading: const Icon(Icons.password),
          title: Text(l.twoStep),
          trailing: Text(_on == null ? '…' : (_on! ? l.twoStepOn : l.twoStepOff)),
        ),
        if (_on == true) ...[
          TextField(
              controller: _old,
              obscureText: true,
              decoration: InputDecoration(labelText: l.oldPassword)),
          const SizedBox(height: 12),
        ],
        TextField(
            controller: _new,
            obscureText: true,
            decoration: InputDecoration(labelText: l.newPassword)),
        const SizedBox(height: 12),
        TextField(
            controller: _hint,
            decoration: InputDecoration(labelText: l.passwordHint)),
        const SizedBox(height: 16),
        FilledButton(onPressed: _apply, child: Text(l.vaultSave)),
      ]),
    );
  }
}
