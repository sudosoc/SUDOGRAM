import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../data/archive/archive_db.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../chat/chat_screen.dart';
import '../settings/settings_sheet.dart';
import 'chat_actions.dart';

String kindLabel(AppLocalizations l, MessageKind k) => switch (k) {
      MessageKind.photo => l.kindPhoto,
      MessageKind.video => l.kindVideo,
      MessageKind.voice => l.kindVoice,
      MessageKind.document => l.kindDocument,
      MessageKind.sticker => l.kindSticker,
      _ => l.kindOther,
    };

String _fmtTime(DateTime t) {
  final n = DateTime.now();
  if (n.difference(t).inHours < 24 && n.day == t.day) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
  return '${t.day}/${t.month}';
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _searching = false;
  String _query = '';
  String? _folder; // null = all chats

  /// Long-press on search → biometric → hidden chats appear instantly.
  Future<void> _openVault() async {
    final l = AppLocalizations.of(context);
    final ok = await ref
        .read(vaultUnlockProvider.notifier)
        .unlock(reason: l.vaultAuthReason);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? l.vaultUnlocked : l.vaultUnavailable),
      duration: const Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final unlocked = ref.watch(vaultUnlockProvider);
    final chats = ref.watch(chatsProvider);
    final demo = ref.watch(gatewayProvider).isDemo;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _searching
                        ? TextField(
                            autofocus: true,
                            decoration:
                                InputDecoration(hintText: l.searchHint),
                            onChanged: (v) => setState(() => _query = v),
                          )
                        : Text(l.appTitle,
                            style: Theme.of(context).textTheme.titleLarge),
                  ),
                  if (demo)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: GlassSurface(
                        radius: 14,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        child: Text(l.demoMode,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => ref
                        .read(settingsProvider.notifier)
                        .setGhostGlobal(!settings.ghostGlobal),
                    child: GlassSurface(
                      radius: 16,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      borderColor: settings.ghostGlobal
                          ? GlassTokens.ghost.withValues(alpha: 0.6)
                          : null,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.visibility_off_outlined,
                            size: 16,
                            color: settings.ghostGlobal
                                ? GlassTokens.ghost
                                : Colors.white54),
                        const SizedBox(width: 4),
                        Text(l.ghostMode,
                            style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassIconButton(
                    icon: Icons.tune,
                    tooltip: l.settings,
                    onPressed: () => showSettingsSheet(context),
                  ),
                  const SizedBox(width: 8),
                  GlassIconButton(
                    icon: _searching ? Icons.close : Icons.search,
                    tooltip: l.search,
                    onPressed: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _query = '';
                    }),
                    onLongPress: _openVault,
                  ),
                ],
              ),
            ),
            if (settings.folders.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final name in [null, ...settings.folders.keys])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(name ?? l.folderAll),
                          selected: _folder == name,
                          onSelected: (_) => setState(() => _folder = name),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: chats.when(
                loading: () => Center(child: Text(l.connecting)),
                error: (e, _) => Center(child: Text(l.errorGeneric)),
                data: (all) {
                  final q = _query.trim().toLowerCase();
                  final inFolder = _folder == null ? null : settings.folders[_folder];
                  final shown = all.where((c) {
                    final hidden = settings.hiddenChats.contains(c.id);
                    if (hidden && !unlocked) return false;
                    if (inFolder != null && !inFolder.contains(c.id)) return false;
                    final name =
                        (settings.aliases[c.id] ?? c.title).toLowerCase();
                    return q.isEmpty || name.contains(q);
                  }).toList()
                    // Pinned chats first; the rest keep Telegram's order.
                    ..sort((a, b) {
                      final pa = settings.pinned.contains(a.id) ? 0 : 1;
                      final pb = settings.pinned.contains(b.id) ? 0 : 1;
                      return pa.compareTo(pb);
                    });
                  final hits = q.isEmpty
                      ? const <SearchHit>[]
                      : ref
                          .read(archiveProvider)
                          .search(q)
                          .where((h) =>
                              unlocked ||
                              !settings.hiddenChats.contains(h.message.chatId))
                          .toList();
                  if (shown.isEmpty && hits.isEmpty) {
                    return Center(child: Text(l.noChats));
                  }
                  final byId = {for (final c in all) c.id: c};
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      for (final c in shown)
                        _ChatRow(
                          chat: c,
                          hidden: settings.hiddenChats.contains(c.id),
                          pinned: settings.pinned.contains(c.id),
                          alias: settings.aliases[c.id],
                        ),
                      if (hits.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
                          child: Text(l.archiveResults,
                              style: const TextStyle(
                                  color: GlassTokens.textSecondary)),
                        ),
                        for (final h in hits)
                          if (byId[h.message.chatId] != null)
                            _HitRow(hit: h, chat: byId[h.message.chatId]!),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatRow extends ConsumerWidget {
  const _ChatRow({
    required this.chat,
    required this.hidden,
    required this.pinned,
    this.alias,
  });

  final ChatSummary chat;
  final bool hidden;
  final bool pinned;
  final String? alias;

  Color? get _ring => switch (chat.risk) {
        RiskLevel.safe => GlassTokens.ringSafe,
        RiskLevel.caution => GlassTokens.ringCaution,
        RiskLevel.danger => GlassTokens.ringDanger,
        RiskLevel.none => null,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final preview =
        chat.lastText.isNotEmpty ? chat.lastText : kindLabel(l, chat.lastKind);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ChatScreen(chat: chat))),
        onLongPress: () => showChatActions(context, ref, chat),
        child: GlassSurface(
          radius: 20,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: _ring == null
                      ? null
                      : Border.all(color: _ring!, width: 2.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  chat.title.characters.isEmpty
                      ? '?'
                      : chat.title.characters.first.toUpperCase(),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(alias ?? chat.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                      if (pinned)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.push_pin,
                              size: 13, color: GlassTokens.textSecondary),
                        ),
                      if (hidden)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.lock_outline,
                              size: 14, color: GlassTokens.ghost),
                        ),
                    ]),
                    const SizedBox(height: 2),
                    Text(preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: GlassTokens.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (chat.lastTime != null)
                    Text(_fmtTime(chat.lastTime!),
                        style: const TextStyle(
                            fontSize: 12, color: GlassTokens.textTertiary)),
                  if (chat.unread > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: GlassScope.of(context).accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${chat.unread}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HitRow extends StatelessWidget {
  const _HitRow({required this.hit, required this.chat});

  final SearchHit hit;
  final ChatSummary chat;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ChatScreen(chat: chat))),
        child: GlassSurface(
          radius: 16,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(chat.title,
                  style: const TextStyle(
                      fontSize: 13, color: GlassTokens.textSecondary)),
              const SizedBox(height: 2),
              Text(hit.message.text, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (hit.deleted)
                Text(l.deletedBadge,
                    style: const TextStyle(
                        fontSize: 11, color: GlassTokens.ringDanger)),
            ],
          ),
        ),
      ),
    );
  }
}
