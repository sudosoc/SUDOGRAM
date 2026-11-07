import 'package:flutter/material.dart';
import '../../core/ui/notice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ui/icon_styles.dart';

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
    builder: (dctx) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: c, autofocus: true, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text(AppLocalizations.of(context).cancelAction)),
        TextButton(
            onPressed: () => Navigator.pop(dctx, c.text),
            child: Text(AppLocalizations.of(context).vaultSave)),
      ],
    ),
  );
}

/// Public text prompt (used by other screens).
Future<String?> askText(BuildContext context, String title, String hint,
        {String initial = ''}) =>
    _ask(context, title, hint, initial: initial);

/// Yes/no dialog. The buttons use the dialog's own context, so it closes
/// correctly even when [context] belongs to a screen that is busy.
Future<bool> confirmDialog(BuildContext context, String message,
    {String? action, bool danger = true}) async {
  final l = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: Text(l.confirm),
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dctx, false),
                child: Text(l.cancelAction)),
            TextButton(
                onPressed: () => Navigator.pop(dctx, true),
                child: Text(action ?? l.yesAction,
                    style: danger
                        ? const TextStyle(color: GlassTokens.ringDanger)
                        : null)),
          ],
        ),
      ) ??
      false;
}

enum ChatDanger { clear, leave, block, unblock }

/// Confirms, runs and reports a destructive chat action. Returns true when
/// it went through. Errors are shown instead of being swallowed.
Future<bool> runChatDanger(
    BuildContext root, WidgetRef ref, ChatSummary chat, ChatDanger what) async {
  final l = AppLocalizations.of(root);
  final messenger = ScaffoldMessenger.of(root);
  final g = ref.read(gatewayProvider);
  final msg = switch (what) {
    ChatDanger.clear => l.clearHistoryQ,
    ChatDanger.leave =>
      chat.type == ChatType.private || chat.type == ChatType.secret
          ? l.deleteChatQ
          : l.leaveChatQ,
    ChatDanger.block => l.blockQ,
    ChatDanger.unblock => l.unblockQ,
  };
  if (!await confirmDialog(root, msg, danger: what != ChatDanger.unblock)) {
    return false;
  }
  try {
    switch (what) {
      case ChatDanger.clear:
        await g.clearHistory(chat.id);
      case ChatDanger.leave:
        await g.leaveChat(chat.id);
      case ChatDanger.block:
        await g.blockUser(chat.id, true);
      case ChatDanger.unblock:
        await g.blockUser(chat.id, false);
    }
    messenger.showSnackBar(SnackBar(content: Text(l.doneMsg)));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e, ar: l.localeName == 'ar'))));
    return false;
  }
}

/// Local-only actions for a chat: pin, folders, alias, hide, ghost.
void showChatActions(BuildContext context, WidgetRef ref, ChatSummary chat,
    {bool inHidden = false}) {
  final root = context;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheet) => Consumer(builder: (sctx, ref, _) {
      final l = AppLocalizations.of(sctx);
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
                leading: SIcon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
                title: Text(pinned ? l.unpin : l.pin),
                onTap: () {
                  c.togglePin(chat.id);
                  Navigator.pop(sheet);
                },
              ),
              if (chat.unread > 0 || chat.markedUnread)
                ListTile(
                  leading: const SIcon(Icons.done_all),
                  title: Text(l.markRead),
                  onTap: () {
                    ref.read(gatewayProvider).markChatRead(chat.id);
                    Navigator.pop(sheet);
                  },
                ),
              if (chat.unread == 0 && !chat.markedUnread)
                ListTile(
                  leading: SIcon(chat.markedUnread
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
                leading: SIcon(chat.muted ? Icons.volume_up_outlined : Icons.volume_off_outlined),
                title: Text(chat.muted ? l.unmute : l.mute),
                onTap: () {
                  ref.read(gatewayProvider).setMuted(chat.id, !chat.muted);
                  Navigator.pop(sheet);
                },
              ),
              ListTile(
                leading: const SIcon(Icons.archive_outlined),
                title: Text(l.archiveChat),
                onTap: () {
                  ref.read(gatewayProvider).setArchived(chat.id, true);
                  Navigator.pop(sheet);
                },
              ),
              ListTile(
                leading: const SIcon(Icons.edit_outlined),
                title: Text(l.rename),
                subtitle: s.aliases[chat.id] == null ? null : Text(s.aliases[chat.id]!),
                onTap: () async {
                  Navigator.pop(sheet);
                  final v = await _ask(root, l.rename, l.aliasHint,
                      initial: s.aliases[chat.id] ?? '');
                  if (v != null) c.setAlias(chat.id, v);
                },
              ),
              ListTile(
                leading: SIcon(hidden ? Icons.lock_open : Icons.lock_outline),
                title: Text(hidden ? l.unhideChat : l.hideChat),
                onTap: () {
                  c.setHidden(chat.id, !hidden);
                  Navigator.pop(sheet);
                },
              ),
              ListTile(
                leading: const SIcon(Icons.visibility_off_outlined),
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
                for (final name in (inHidden ? s.hiddenFolders : s.folders).keys)
                  FilterChip(
                    label: Text(name),
                    selected: (inHidden ? s.hiddenFolders : s.folders)[name]!
                        .contains(chat.id),
                    onSelected: (_) => inHidden
                        ? c.toggleInHiddenFolder(name, chat.id)
                        : c.toggleInFolder(name, chat.id),
                  ),
                ActionChip(
                  avatar: const SIcon(Icons.add, size: 16),
                  label: Text(l.newFolder),
                  onPressed: () async {
                    final n = await _ask(root, l.newFolder, l.folderName);
                    if (n != null && n.trim().isNotEmpty) {
                      inHidden
                          ? c.toggleInHiddenFolder(n.trim(), chat.id)
                          : c.toggleInFolder(n.trim(), chat.id);
                    }
                  },
                ),
              ]),
              const SizedBox(height: 8),
              const Divider(),
              ListTile(
                leading: const SIcon(Icons.cleaning_services_outlined,
                    color: GlassTokens.ringDanger),
                title: Text(l.clearHistory,
                    style: const TextStyle(color: GlassTokens.ringDanger)),
                onTap: () {
                  Navigator.pop(sheet);
                  runChatDanger(root, ref, chat, ChatDanger.clear);
                },
              ),
              ListTile(
                leading: const SIcon(Icons.delete_outline,
                    color: GlassTokens.ringDanger),
                title: Text(
                    chat.type == ChatType.private ? l.deleteChat : l.leaveChat,
                    style: const TextStyle(color: GlassTokens.ringDanger)),
                onTap: () {
                  Navigator.pop(sheet);
                  runChatDanger(root, ref, chat, ChatDanger.leave);
                },
              ),
              if (chat.type == ChatType.private)
                ListTile(
                  leading: const SIcon(Icons.block, color: GlassTokens.ringDanger),
                  title: Text(l.blockUser,
                      style: const TextStyle(color: GlassTokens.ringDanger)),
                  onTap: () {
                    Navigator.pop(sheet);
                    runChatDanger(root, ref, chat, ChatDanger.block);
                  },
                ),
            ]),
          ),
        ),
      );
    }),
  );
}
