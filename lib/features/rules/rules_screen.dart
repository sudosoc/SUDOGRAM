import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ui/icon_styles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import 'rules.dart';
import 'rules_controller.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  String _actionLabel(AppLocalizations l, RuleAction a) => switch (a) {
        RuleAction.pin => l.actPin,
        RuleAction.hide => l.actHide,
        RuleAction.ghostOn => l.actGhostOn,
        RuleAction.ghostOff => l.actGhostOff,
        RuleAction.addToFolder => l.actFolder,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final rules = ref.watch(rulesProvider);
    final c = ref.read(rulesProvider.notifier);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l.rules),
        actions: [
          IconButton(
            tooltip: l.ruleExport,
            icon: const SIcon(Icons.copy),
            onPressed: rules.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                        ClipboardData(text: Rule.encodeAll(rules)));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(l.ruleCopied)));
                    }
                  },
          ),
          IconButton(
            tooltip: l.ruleImport,
            icon: const SIcon(Icons.paste),
            onPressed: () => _import(context, ref, l),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l.ruleAdd,
        onPressed: () => _add(context, ref, l),
        child: const SIcon(Icons.add),
      ),
      body: SafeArea(
        child: rules.isEmpty
            ? Center(child: Text(l.rulesEmpty))
            : ListView(children: [
                for (final r in rules)
                  SwitchListTile(
                    title: Text(r.name),
                    subtitle: Text([
                      if (r.chatContains.isNotEmpty) '${l.ruleChat}: ${r.chatContains}',
                      if (r.textContains.isNotEmpty) '${l.ruleText}: ${r.textContains}',
                      '${l.ruleDo}: ${_actionLabel(l, r.action)}'
                          '${r.folder.isEmpty ? '' : ' (${r.folder})'}',
                    ].join('\n')),
                    isThreeLine: true,
                    value: r.enabled,
                    onChanged: (_) => c.toggle(r.id),
                    secondary: IconButton(
                      icon: const SIcon(Icons.delete_outline),
                      onPressed: () => c.remove(r.id),
                    ),
                  ),
              ]),
      ),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref, AppLocalizations l) async {
    final t = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: TextField(
            controller: t,
            maxLines: 6,
            decoration: InputDecoration(hintText: l.ruleImportHint)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.vaultSave)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = ref.read(rulesProvider.notifier).import(Rule.decodeAll(t.text));
      messenger.showSnackBar(SnackBar(content: Text(l.ruleImported(n))));
    } on FormatException {
      messenger.showSnackBar(SnackBar(content: Text(l.ruleBad)));
    }
  }

  Future<void> _add(BuildContext context, WidgetRef ref, AppLocalizations l) async {
    final name = TextEditingController();
    final chat = TextEditingController();
    final text = TextEditingController();
    final folder = TextEditingController();
    MessageKind? kind;
    var action = RuleAction.pin;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(l.ruleAdd),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: InputDecoration(hintText: l.ruleName)),
              TextField(controller: chat, decoration: InputDecoration(hintText: l.ruleChat)),
              TextField(controller: text, decoration: InputDecoration(hintText: l.ruleText)),
              DropdownButton<MessageKind?>(
                isExpanded: true,
                value: kind,
                hint: Text(l.ruleKind),
                items: [
                  DropdownMenuItem(value: null, child: Text(l.anyKind)),
                  for (final k in MessageKind.values)
                    DropdownMenuItem(value: k, child: Text(k.name)),
                ],
                onChanged: (v) => set(() => kind = v),
              ),
              DropdownButton<RuleAction>(
                isExpanded: true,
                value: action,
                items: [
                  for (final a in RuleAction.values)
                    DropdownMenuItem(value: a, child: Text(_actionLabel(l, a))),
                ],
                onChanged: (v) => set(() => action = v!),
              ),
              if (action == RuleAction.addToFolder)
                TextField(controller: folder, decoration: InputDecoration(hintText: l.folderName)),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.vaultSave)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (chat.text.isEmpty && text.text.isEmpty && kind == null) return; // matches everything
    ref.read(rulesProvider.notifier).add(Rule(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name.text.isEmpty ? _actionLabel(l, action) : name.text,
          action: action,
          chatContains: chat.text,
          textContains: text.text,
          kind: kind,
          folder: folder.text.trim(),
        ));
  }
}
