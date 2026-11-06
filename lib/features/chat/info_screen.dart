import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../home/chat_actions.dart';
import 'avatar.dart';
import 'chat_screen.dart';
import 'members_screen.dart';
import 'status_text.dart';

/// What the profile page hands back to the chat that opened it.
sealed class InfoResult {
  const InfoResult();
}

class InfoSearch extends InfoResult {
  const InfoSearch();
}

class InfoJump extends InfoResult {
  const InfoJump(this.messageId);
  final int messageId;
}

/// Profile (private chats) or group / channel details, Telegram style:
/// header, quick actions, info rows, switches, shared media, danger zone.
class ChatInfoScreen extends ConsumerStatefulWidget {
  const ChatInfoScreen({super.key, required this.chat});

  final ChatSummary chat;

  @override
  ConsumerState<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends ConsumerState<ChatInfoScreen> {
  late final Future<ChatInfo?> _info =
      ref.read(gatewayProvider).chatInfo(widget.chat.id);
  String _tab = 'photo';
  Future<List<ChatMessage>>? _media;

  ChatSummary get _chat =>
      ref.watch(chatsProvider).value?.where((c) => c.id == widget.chat.id).firstOrNull ??
      widget.chat;

  void _copy(String v) {
    Clipboard.setData(ClipboardData(text: v));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).copied)));
  }

  void _loadMedia(String f) {
    _tab = f;
    _media = ref.read(gatewayProvider).sharedMedia(widget.chat.id, f);
  }

  @override
  void initState() {
    super.initState();
    _loadMedia('photo');
  }

  Widget _action(IconData i, String label, VoidCallback f, {Color? color}) =>
      Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: f,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(i, color: color ?? GlassScope.of(context).accent),
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: color)),
            ]),
          ),
        ),
      );

  Widget _row(IconData i, String label, String v) =>
      ListTile(
        leading: Icon(i),
        title: Text(v),
        subtitle: Text(label,
            style: const TextStyle(color: GlassTokens.textSecondary)),
        onTap: () => _copy(v),
        onLongPress: () => _copy(v),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final chat = _chat;
    final s = ref.watch(settingsProvider);
    final sc = ref.read(settingsProvider.notifier);
    final isPrivate = chat.type == ChatType.private || chat.type == ChatType.secret;
    final isGroup = chat.type == ChatType.group || chat.type == ChatType.channel;
    final name = s.aliases[chat.id] ?? chat.title;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(l.info)),
      body: FutureBuilder<ChatInfo?>(
        future: _info,
        builder: (_, snap) {
          final i = snap.data;
          return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
            const SizedBox(height: 8),
            Center(
                child: AvatarCircle(title: chat.title, photo: chat.avatar, size: 104)),
            const SizedBox(height: 12),
            Center(
                child: Text(name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge)),
            StreamBuilder<ChatStatus>(
              stream: ref.read(gatewayProvider).watchChatStatus(chat.id),
              initialData: ChatStatus.none,
              builder: (_, st) {
                var t = chatStatusText(l, st.data ?? ChatStatus.none, chat.type);
                if (isGroup && i != null && i.members > 0) {
                  t = l.membersCount('${i.members}');
                }
                return Center(
                    child: Text(t,
                        style: TextStyle(
                            color: (st.data?.typing ?? false)
                                ? GlassScope.of(context).accent
                                : GlassTokens.textSecondary)));
              },
            ),
            if (i != null && i.isBot)
              Center(
                  child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Chip(label: Text(l.botLabel)),
              )),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GlassSurface(
                radius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  _action(
                      chat.muted
                          ? Icons.notifications_off_outlined
                          : Icons.notifications_outlined,
                      chat.muted ? l.unmute : l.mute,
                      () => ref.read(gatewayProvider).setMuted(chat.id, !chat.muted)),
                  _action(Icons.search, l.search,
                      () => Navigator.of(context).pop(const InfoSearch())),
                  if (isPrivate && chat.type == ChatType.private)
                    _action(Icons.lock_outline, l.secretChat, () async {
                      final nav = Navigator.of(context);
                      final c = await ref.read(gatewayProvider).createSecretChat(chat.id);
                      if (c == null) return;
                      nav.pushReplacement(MaterialPageRoute<void>(
                          builder: (_) => ChatScreen(chat: c)));
                    }),
                  if (isGroup)
                    _action(Icons.group_outlined, l.members, () {
                      Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => MembersScreen(chat: chat)));
                    }),
                  _action(
                      s.hiddenChats.contains(chat.id)
                          ? Icons.lock_open
                          : Icons.lock_outline,
                      s.hiddenChats.contains(chat.id) ? l.unhideChat : l.hideChat,
                      () => sc.setHidden(chat.id, !s.hiddenChats.contains(chat.id))),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            if (i != null) ...[
              if (i.phone.isNotEmpty)
                _row(Icons.phone_outlined, l.phone, '+${i.phone}'),
              if (i.username.isNotEmpty) ...[
                _row(Icons.alternate_email, l.username, '@${i.username}'),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: Text('t.me/${i.username}'),
                  subtitle: Text(l.copyLink,
                      style: const TextStyle(color: GlassTokens.textSecondary)),
                  onTap: () => _copy('https://t.me/${i.username}'),
                  onLongPress: () => launchUrl(Uri.parse('https://t.me/${i.username}'),
                      mode: LaunchMode.externalApplication),
                ),
              ],
              if (i.about.isNotEmpty) _row(Icons.info_outline, l.about, i.about),
              if (i.commonGroups > 0)
                ListTile(
                  leading: const Icon(Icons.groups_2_outlined),
                  title: Text(l.commonGroups),
                  trailing: Text('${i.commonGroups}'),
                ),
            ],
            const Divider(),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_outlined),
              title: Text(l.ghostOnForChat),
              value: s.ghostFor(chat.id),
              onChanged: (v) => sc.setGhostOverride(chat.id, v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.push_pin_outlined),
              title: Text(l.pin),
              value: s.pinned.contains(chat.id),
              onChanged: (_) => sc.togglePin(chat.id),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.rename),
              subtitle: s.aliases[chat.id] == null ? null : Text(s.aliases[chat.id]!),
              onTap: () async {
                final v = await askText(context, l.rename, l.aliasHint,
                    initial: s.aliases[chat.id] ?? '');
                if (v != null) sc.setAlias(chat.id, v);
              },
            ),
            if (chat.type == ChatType.secret)
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(l.selfDestruct),
                trailing: PopupMenuButton<int>(
                  onSelected: (v) =>
                      ref.read(gatewayProvider).setAutoDelete(chat.id, v),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 0, child: Text(l.timerOff)),
                    PopupMenuItem(value: 60, child: Text(l.timer1m)),
                    PopupMenuItem(value: 3600, child: Text(l.timer1h)),
                    PopupMenuItem(value: 86400, child: Text(l.timer1d)),
                  ],
                ),
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(spacing: 8, children: [
                for (final (key, label) in [
                  ('photo', l.sharedPhotos),
                  ('video', l.sharedVideos),
                  ('document', l.sharedFiles),
                  ('voice', l.sharedVoice),
                  ('link', l.sharedLinks),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _tab == key,
                    onSelected: (_) => setState(() => _loadMedia(key)),
                  ),
              ]),
            ),
            FutureBuilder<List<ChatMessage>>(
              future: _media,
              builder: (_, m) {
                final list = m.data ?? const <ChatMessage>[];
                if (m.connectionState != ConnectionState.done) {
                  return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()));
                }
                if (list.isEmpty) {
                  return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(l.noMedia)));
                }
                if (_tab == 'photo' || _tab == 'video') {
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 3,
                    crossAxisSpacing: 3,
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final x in list)
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(InfoJump(x.id)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _thumb(x),
                          ),
                        ),
                    ],
                  );
                }
                return Column(children: [
                  for (final x in list)
                    ListTile(
                      dense: true,
                      leading: Icon(_tab == 'link'
                          ? Icons.link
                          : _tab == 'voice'
                              ? Icons.mic_none
                              : Icons.insert_drive_file_outlined),
                      title: Text(
                          x.file?.name.isNotEmpty == true
                              ? x.file!.name
                              : (x.text.isEmpty ? kindName(l, x.kind) : x.text),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${x.time.day}/${x.time.month}/${x.time.year}'),
                      onTap: () => Navigator.of(context).pop(InfoJump(x.id)),
                    ),
                ]);
              },
            ),
            const Divider(),
            if (isPrivate && chat.type == ChatType.private)
              ListTile(
                leading: Icon(i?.blocked == true ? Icons.lock_open : Icons.block,
                    color: GlassTokens.ringDanger),
                title: Text(i?.blocked == true ? l.unblock : l.blockUser,
                    style: const TextStyle(color: GlassTokens.ringDanger)),
                onTap: () async {
                  final ok = await runChatDanger(context, ref, chat,
                      i?.blocked == true ? ChatDanger.unblock : ChatDanger.block);
                  if (ok && mounted) setState(() {});
                },
              ),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined,
                  color: GlassTokens.ringDanger),
              title: Text(l.clearHistory,
                  style: const TextStyle(color: GlassTokens.ringDanger)),
              onTap: () => runChatDanger(context, ref, chat, ChatDanger.clear),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: GlassTokens.ringDanger),
              title: Text(isPrivate ? l.deleteChat : l.leaveChat,
                  style: const TextStyle(color: GlassTokens.ringDanger)),
              onTap: () async {
                final nav = Navigator.of(context);
                final ok = await runChatDanger(context, ref, chat, ChatDanger.leave);
                if (ok) nav.popUntil((r) => r.isFirst);
              },
            ),
          ]);
        },
      ),
    );
  }

  String kindName(AppLocalizations l, MessageKind k) => switch (k) {
        MessageKind.photo => l.kindPhoto,
        MessageKind.video => l.kindVideo,
        MessageKind.voice => l.kindVoice,
        MessageKind.document => l.kindDocument,
        _ => l.kindOther,
      };

  Widget _thumb(ChatMessage x) {
    final a = x.thumb ?? x.file;
    final path = a != null && a.downloaded ? a.localPath : null;
    if (path == null) {
      return Container(
          color: Colors.white10,
          child: Center(
              child: Icon(x.kind == MessageKind.video
                  ? Icons.play_circle_outline
                  : Icons.image_outlined)));
    }
    return Stack(fit: StackFit.expand, children: [
      Image.file(File(path), fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(color: Colors.white10)),
      if (x.kind == MessageKind.video)
        const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70)),
    ]);
  }
}
