import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';

Future<String?> _ask(BuildContext context, String title, String hint,
    {String initial = ''}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: c, autofocus: true, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: Text(AppLocalizations.of(context).vaultSave)),
      ],
    ),
  );
}

Future<bool> _confirm(BuildContext context) async {
  final l = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l.confirm),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancelAction)),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('OK')),
          ],
        ),
      ) ??
      false;
}

/// Local-only actions for a chat: pin, folders, alias, hide, ghost.
void showChatActions(BuildContext context, WidgetRef ref, ChatSummary chat) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheet) => Consumer(builder: (context, ref, _) {
      final l = AppLocalizations.of(context);
      final s = ref.watch(settingsProvider);
      final c = ref.read(settingsProvider.notifier);
      final pinned = s.pinned.contains(chat.id);
      final hidden = s.hiddenChats.contains(chat.id);
      return Padding(
        padding: const EdgeInsets.all(12),
        child: GlassSurface(
          blur: true,
          radius: 28,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                leading: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
                title: Text(pinned ? l.unpin : l.pin),
                onTap: () {
                  c.togglePin(chat.id);
                  Navigator.pop(sheet);
                },
              ),
              if (chat.unread == 0)
                ListTile(
                  leading: Icon(chat.markedUnread
                      ? Icons.mark_chat_read_outlined
                      : Icons.mark_chat_unread_outlined),
                  title: Text(chat.markedUnread ? l.markRead : l.markUnread),
                  onTap: () {
                    ref
                        .read(gatewayProvider)
                        .markUnread(chat.id, !chat.markedUnread);
                    Navigator.pop(sheet);
                  },
                ),
              ListTile(
                leading: Icon(chat.muted ? Icons.volume_up_outlined : Icons.volume_off_outlined),
                title: Text(chat.muted ? l.unmute : l.mute),
                onTap: () {
                  ref.read(gatewayProvider).setMuted(chat.id, !chat.muted);
                  Navigator.pop(sheet);
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: Text(l.archiveChat),
                onTap: () {
                  ref.read(gatewayProvider).setArchived(chat.id, true);
                  Navigator.pop(sheet);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l.rename),
                subtitle: s.aliases[chat.id] == null ? null : Text(s.aliases[chat.id]!),
                onTap: () async {
                  Navigator.pop(sheet);
                  final v = await _ask(context, l.rename, l.aliasHint,
                      initial: s.aliases[chat.id] ?? '');
                  if (v != null) c.setAlias(chat.id, v);
                },
              ),
              ListTile(
                leading: Icon(hidden ? Icons.lock_open : Icons.lock_outline),
                title: Text(hidden ? l.unhideChat : l.hideChat),
                onTap: () {
                  c.setHidden(chat.id, !hidden);
                  Navigator.pop(sheet);
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: Text(s.ghostFor(chat.id) ? l.ghostOffForChat : l.ghostOnForChat),
                onTap: () {
                  c.setGhostOverride(chat.id, !s.ghostFor(chat.id));
                  Navigator.pop(sheet);
                },
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(l.addToFolder,
                      style: const TextStyle(color: GlassTokens.textSecondary)),
                ),
              ),
              Wrap(spacing: 8, children: [
                for (final name in s.folders.keys)
                  FilterChip(
                    label: Text(name),
                    selected: s.folders[name]!.contains(chat.id),
                    onSelected: (_) => c.toggleInFolder(name, chat.id),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(l.newFolder),
                  onPressed: () async {
                    final n = await _ask(context, l.newFolder, l.folderName);
                    if (n != null && n.trim().isNotEmpty) {
                      c.toggleInFolder(n.trim(), chat.id);
                    }
                  },
                ),
              ]),
              const SizedBox(height: 8),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined,
                    color: GlassTokens.ringDanger),
                title: Text(l.clearHistory,
                    style: const TextStyle(color: GlassTokens.ringDanger)),
                onTap: () async {
                  Navigator.pop(sheet);
                  if (await _confirm(context)) {
                    await ref.read(gatewayProvider).clearHistory(chat.id);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: GlassTokens.ringDanger),
                title: Text(
                    chat.type == ChatType.private ? l.deleteChat : l.leaveChat,
                    style: const TextStyle(color: GlassTokens.ringDanger)),
                onTap: () async {
                  Navigator.pop(sheet);
                  if (await _confirm(context)) {
                    await ref.read(gatewayProvider).leaveChat(chat.id);
                  }
                },
              ),
              if (chat.type == ChatType.private)
                ListTile(
                  leading: const Icon(Icons.block, color: GlassTokens.ringDanger),
                  title: Text(l.blockUser,
                      style: const TextStyle(color: GlassTokens.ringDanger)),
                  onTap: () async {
                    Navigator.pop(sheet);
                    if (await _confirm(context)) {
                      await ref.read(gatewayProvider).blockUser(chat.id, true);
                    }
                  },
                ),
            ]),
          ),
        ),
      );
    }),
  );
}
