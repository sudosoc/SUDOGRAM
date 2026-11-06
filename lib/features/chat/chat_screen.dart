import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_screen.dart' show kindLabel;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../splitter/file_splitter.dart';
import '../splitter/smart_splitter.dart';
import '../../core/drafts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'avatar.dart';
import 'info_screen.dart';
import 'voice_player.dart';
import 'file_card.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chat});

  final ChatSummary chat;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _c = TextEditingController();
  int _limit = 4096;
  int _parts = 1;
  late final _gateway = ref.read(gatewayProvider);
  late final _notifier = ref.read(notifierProvider);
  final _scroll = ScrollController();
  ChatMessage? _replyTo;
  ChatMessage? _editing;
  bool _loadingOlder = false;
  bool _searching = false;
  List<MentionCandidate> _mentions = const [];
  List<ChatMessage>? _hits;
  ChatMessage? _pinned;
  int _lastReadSig = 0;

  @override
  void initState() {
    super.initState();
    _gateway.openChat(widget.chat.id);
    _notifier.openChat = widget.chat.id;
    _c.text = DraftStore.get(widget.chat.id);
    _scroll.addListener(_onScroll);
    _gateway.pinnedMessage(widget.chat.id).then((m) {
      if (mounted) setState(() => _pinned = m);
    });
    _gateway.messageTextLimit().then((v) {
      if (mounted) setState(() => _limit = v);
    });
  }

  @override
  void dispose() {
    _gateway.closeChat(widget.chat.id);
    if (_notifier.openChat == widget.chat.id) _notifier.openChat = null;
    DraftStore.set(widget.chat.id, _editing == null ? _c.text : '');
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingOlder || !_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadingOlder = true;
      _gateway.loadOlder(widget.chat.id).whenComplete(() {
        _loadingOlder = false;
      });
    }
  }

  /// Marks incoming messages read — only when Ghost is off for this chat.
  void _maybeMarkRead(List<ChatMessage> list) {
    if (ref.read(settingsProvider).ghostFor(widget.chat.id)) return;
    final ids = [
      for (final m in list)
        if (!m.outgoing) m.id
    ];
    if (ids.isEmpty) return;
    final sig = Object.hash(ids.first, ids.length);
    if (sig == _lastReadSig) return;
    _lastReadSig = sig;
    _gateway.markRead(widget.chat.id, ids.take(50).toList());
  }

  Future<void> _updateMentions(String v) async {
    if (widget.chat.type != ChatType.group) return;
    final m = RegExp(r'(?:^|\s)@(\w{0,32})$').firstMatch(v);
    if (m == null) {
      if (_mentions.isNotEmpty) setState(() => _mentions = const []);
      return;
    }
    final r = await _gateway.searchMembers(widget.chat.id, m.group(1)!);
    if (mounted) setState(() => _mentions = r);
  }

  void _pickMention(MentionCandidate c) {
    final t = _c.text.replaceFirst(RegExp(r'@\w*$'), '@${c.username} ');
    _c.value = TextEditingValue(
        text: t, selection: TextSelection.collapsed(offset: t.length));
    setState(() => _mentions = const []);
  }

  void _onChanged(String v) {
    _updateMentions(v);
    // Typing indicator goes through the Ghost guard; in ghost mode it's dropped.
    if (v.isNotEmpty) _gateway.sendTyping(widget.chat.id);
    final n = v.isEmpty ? 1 : SmartSplitter.countParts(v, SplitOptions(maxLength: _limit));
    if (n != _parts) setState(() => _parts = n);
  }

  /// Telegram's per-file limit is 2000 MB (4000 MB with Premium); we stay
  /// safely under the non-Premium one.
  static const _maxFile = 1950 * 1024 * 1024;

  Future<void> _attach() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.pickFile();
    final path = picked?.path;
    if (path == null || !mounted) return;
    final file = File(path);
    final size = await file.length();
    if (size <= _maxFile) {
      await _gateway.sendFile(widget.chat.id, path);
      return;
    }
    final count = (size / _maxFile).ceil();
    messenger.showSnackBar(SnackBar(
        content: Text(l.fileSplitNotice('$count')),
        duration: const Duration(seconds: 4)));
    final tmp = await getTemporaryDirectory();
    final out = Directory('${tmp.path}/split_${DateTime.now().millisecondsSinceEpoch}');
    try {
      // 3+ parts: add one Reed-Solomon parity part so one lost or damaged
      // part can be rebuilt on the other side.
      final r = await FileSplitter.split(file, out,
          partSize: _maxFile, parityParts: count >= 3 ? 1 : 0);
      for (final p in [...r.parts, ...r.parity, r.manifest]) {
        await _gateway.sendFile(widget.chat.id, p.path); // in order
      }
    } finally {
      if (await out.exists()) await out.delete(recursive: true);
    }
  }

  Future<void> _attachMedia() async {
    final picked = await FilePicker.pickFiles(type: FileType.media);
    final paths = [for (final f in picked) if (f.path != null) f.path!];
    if (paths.isEmpty || !mounted) return;
    await _gateway.sendMedia(widget.chat.id, paths);
  }

  Future<void> _send() async {
    final text = _c.text;
    if (text.trim().isEmpty) return;
    final editing = _editing;
    final reply = _replyTo;
    _c.clear();
    DraftStore.set(widget.chat.id, '');
    setState(() {
      _parts = 1;
      _editing = null;
      _replyTo = null;
    });
    if (editing != null) {
      await _gateway.editText(widget.chat.id, editing.id, text);
      return;
    }
    final parts = SmartSplitter.split(text, SplitOptions(maxLength: _limit));
    for (var i = 0; i < parts.length; i++) {
      // strictly in order; only the first part carries the reply
      await _gateway.sendText(widget.chat.id, parts[i],
          replyTo: i == 0 ? (reply?.id ?? 0) : 0);
    }
  }

  void _actions(ChatMessage m) {
    final l = AppLocalizations.of(context);
    final chats = ref.read(chatsProvider).value ?? const <ChatSummary>[];
    Widget item(IconData i, String t, VoidCallback f, {Color? c}) => ListTile(
          leading: Icon(i, color: c),
          title: Text(t, style: TextStyle(color: c)),
          onTap: () {
            Navigator.of(context).pop();
            f();
          },
        );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: GlassSurface(
          blur: true,
          radius: 24,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!m.deletedByPeer)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final e in const ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥'])
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        _gateway.toggleReaction(widget.chat.id, m.id, e,
                            on: !m.myReactions.contains(e));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: m.myReactions.contains(e)
                              ? Colors.white24
                              : null,
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                ],
              ),
            if (widget.chat.canSend && !m.deletedByPeer)
              item(Icons.reply, l.reply, () => setState(() {
                    _replyTo = m;
                    _editing = null;
                  })),
            if (m.text.isNotEmpty)
              item(Icons.copy, l.copy, () {
                Clipboard.setData(ClipboardData(text: m.text));
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l.copied)));
              }),
            if (m.outgoing && m.kind == MessageKind.text && !m.deletedByPeer)
              item(Icons.edit_outlined, l.edit, () {
                setState(() {
                  _editing = m;
                  _replyTo = null;
                  _c.text = m.text;
                });
              }),
            if (!m.deletedByPeer && widget.chat.type != ChatType.secret)
              item(Icons.shortcut, l.forward, () => _pickForward(m, chats)),
            if (m.edited)
              item(Icons.history, l.editHistory, () => _showEdits(context, m)),
            if (!m.deletedByPeer)
              item(Icons.delete_outline, l.delete, () => _confirmDelete(m),
                  c: GlassTokens.ringDanger),
          ]),
        ),
      ),
    );
  }

  void _pickForward(ChatMessage m, List<ChatSummary> chats) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: GlassSurface(
          blur: true,
          radius: 24,
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(l.forwardTo,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Expanded(
                child: ListView(children: [
                  for (final c in chats)
                    if (c.canSend)
                      ListTile(
                        leading: AvatarCircle(
                            title: c.title, photo: c.avatar, size: 40),
                        title: Text(c.title),
                        onTap: () {
                          Navigator.of(context).pop();
                          _gateway.forwardMessages(
                              c.id, widget.chat.id, [m.id]);
                        },
                      ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ChatMessage m) async {
    final l = AppLocalizations.of(context);
    final choice = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(l.deleteTitle),
        children: [
          SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 1),
              child: Text(l.deleteForMe)),
          if (m.outgoing || widget.chat.type == ChatType.private)
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 2),
                child: Text(l.deleteForAll)),
        ],
      ),
    );
    if (choice == null) return;
    await _gateway.deleteMessages(widget.chat.id, [m.id], forAll: choice == 2);
  }

  void _openMedia(ChatMessage m) {
    final f = m.file ?? m.thumb;
    if (f == null) return;
    if (!f.downloaded || f.localPath == null) {
      _gateway.downloadFile(f.fileId);
      return;
    }
    if (m.kind == MessageKind.photo || m.kind == MessageKind.sticker) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent),
          body: Center(
              child: InteractiveViewer(child: Image.file(File(f.localPath!)))),
        ),
      ));
    } else {
      OpenFilex.open(f.localPath!);
    }
  }

  String _statusText(AppLocalizations l, ChatStatus s) {
    if (s.typing) return l.typing;
    switch (s.seen) {
      case SeenKind.online:
        return l.online;
      case SeenKind.recently:
        return l.seenRecently;
      case SeenKind.lastWeek:
        return l.seenWeek;
      case SeenKind.lastMonth:
        return l.seenMonth;
      case SeenKind.at:
        final t = s.lastSeen;
        if (t == null) return '';
        final hh = t.hour.toString().padLeft(2, '0');
        final mm = t.minute.toString().padLeft(2, '0');
        return l.seenAt('${t.day}/${t.month} $hh:$mm');
      case SeenKind.unknown:
        return widget.chat.type == ChatType.secret
            ? l.secretChat
            : widget.chat.type == ChatType.group
            ? l.groupLabel
            : widget.chat.type == ChatType.channel
                ? l.channelLabel
                : '';
    }
  }

  String _dayLabel(AppLocalizations l, DateTime t) {
    final n = DateTime.now();
    final d = DateTime(t.year, t.month, t.day);
    final today = DateTime(n.year, n.month, n.day);
    if (d == today) return l.today;
    if (d == today.subtract(const Duration(days: 1))) return l.yesterday;
    return '${t.day}/${t.month}/${t.year}';
  }

  /// "Forwarded from X": private chats share their id with the user, so the
  /// name comes from the chat list; unknown origins show their id.
  String? _forwardLabel(AppLocalizations l, String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final m = RegExp(r'^(user|chat):(\d+)$').firstMatch(raw);
    if (m == null) return l.forwardedFrom(raw);
    final id = int.parse(m.group(2)!);
    final chats = ref.read(chatsProvider).value ?? const <ChatSummary>[];
    for (final c in chats) {
      if (c.id == id) return l.forwardedFrom(c.title);
    }
    return l.forwardedFrom('#$id');
  }

  void _showEdits(BuildContext context, ChatMessage m) {
    final l = AppLocalizations.of(context);
    final edits = ref.read(archiveProvider).editsFor(m.chatId, m.id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: GlassSurface(
          blur: true,
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.editHistory,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (edits.isEmpty) Text(l.noEdits),
              for (final e in edits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(e.oldText,
                      style: const TextStyle(
                          color: GlassTokens.textSecondary)),
                ),
              const Divider(),
              Text('${l.currentVersion}: ${m.text}'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final msgs = ref.watch(messagesProvider(widget.chat.id));
    final ghost = ref.watch(settingsProvider).ghostFor(widget.chat.id);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: GlassSurface(
                blur: true,
                radius: 22,
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(children: [
                  IconButton(
                    tooltip: l.back,
                    icon: const BackButtonIcon(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                ChatInfoScreen(chat: widget.chat))),
                    child: AvatarCircle(
                        title: widget.chat.title,
                        photo: widget.chat.avatar,
                        size: 38),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            ref.watch(settingsProvider)
                                    .aliases[widget.chat.id] ??
                                widget.chat.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16)),
                        StreamBuilder<ChatStatus>(
                          stream: _gateway.watchChatStatus(widget.chat.id),
                          initialData: ChatStatus.none,
                          builder: (_, snap) {
                            final t = _statusText(
                                l, snap.data ?? ChatStatus.none);
                            return t.isEmpty
                                ? const SizedBox.shrink()
                                : Text(t,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: (snap.data?.typing ?? false)
                                            ? GlassScope.of(context).accent
                                            : GlassTokens.textSecondary));
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l.searchInChat,
                    icon: Icon(_searching ? Icons.close : Icons.search),
                    onPressed: () => setState(() {
                      _searching = !_searching;
                      _hits = null;
                    }),
                  ),
                  Tooltip(
                    message:
                        ghost ? l.ghostOffForChat : l.ghostOnForChat,
                    child: IconButton(
                      icon: Icon(Icons.visibility_off_outlined,
                          color: ghost ? GlassTokens.ghost : Colors.white54),
                      onPressed: () => ref
                          .read(settingsProvider.notifier)
                          .setGhostOverride(widget.chat.id, !ghost),
                    ),
                  ),
                ]),
              ),
            ),
            if (_searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(hintText: l.searchInChat),
                  onSubmitted: (v) async {
                    final r = await _gateway.searchChat(widget.chat.id, v);
                    if (mounted) setState(() => _hits = r);
                  },
                ),
              ),
            if (_pinned != null && !_searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: GlassSurface(
                  radius: 14,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(children: [
                    const Icon(Icons.push_pin, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          _pinned!.text.isNotEmpty
                              ? _pinned!.text
                              : kindLabel(l, _pinned!.kind),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ]),
                ),
              ),
            if (ghost)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l.silentRead,
                    style: const TextStyle(
                        fontSize: 12, color: GlassTokens.ghost)),
              ),
            Expanded(
              child: msgs.when(
                loading: () => Center(child: Text(l.connecting)),
                error: (e, _) => Center(child: Text(l.errorGeneric)),
                data: (list0) {
                  final list = _searching && _hits != null ? _hits! : list0;
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _maybeMarkRead(list0));
                  if (list.isEmpty) return Center(child: Text(l.noMessages));
                  final byId = {for (final m in list) m.id: m};
                  return ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final m = list[i];
                      final older = i + 1 < list.length ? list[i + 1] : null;
                      final newDay = older == null ||
                          older.time.day != m.time.day ||
                          older.time.month != m.time.month ||
                          older.time.year != m.time.year;
                      return Column(children: [
                        if (newDay)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(_dayLabel(l, m.time),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: GlassTokens.textSecondary)),
                          ),
                        _Bubble(
                          m: m,
                          showSender: widget.chat.type == ChatType.group &&
                              !m.outgoing,
                          replied: m.replyToId != 0 ? byId[m.replyToId] : null,
                          forwardLabel: _forwardLabel(l, m.forwardedFrom),
                          onDownload: (id) => _gateway.downloadFile(id),
                          onCancel: (id) => _gateway.cancelDownload(id),
                          onOpen: () => _openMedia(m),
                          onVote: (ids) =>
                              _gateway.votePoll(widget.chat.id, m.id, ids),
                          onLongPress: () => _actions(m),
                        ),
                      ]);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Column(children: [
                if (_parts > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(l.splitNotice('$_parts'),
                        style: const TextStyle(
                            fontSize: 12, color: GlassTokens.textSecondary)),
                  ),
                if (_mentions.isNotEmpty)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final c in _mentions)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: AvatarCircle(title: c.name, size: 24),
                              label: Text(c.name.isEmpty ? '@${c.username}' : c.name),
                              onPressed: () => _pickMention(c),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_replyTo != null || _editing != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassSurface(
                      radius: 16,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(children: [
                        Icon(_editing != null ? Icons.edit : Icons.reply,
                            size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              '${_editing != null ? l.editingMessage : l.replyingTo}: ${(_editing ?? _replyTo)!.text}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() {
                            if (_editing != null) _c.clear();
                            _editing = null;
                            _replyTo = null;
                          }),
                        ),
                      ]),
                    ),
                  ),
                if (!widget.chat.canSend)
                  GlassSurface(
                    radius: 26,
                    padding: const EdgeInsets.all(14),
                    child: Center(child: Text(l.cantPost)),
                  )
                else
                GlassSurface(
                  blur: true,
                  radius: 26,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _c,
                        minLines: 1,
                        maxLines: 6,
                        onChanged: _onChanged,
                        decoration: InputDecoration(
                          hintText: l.typeMessage,
                          border: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l.attachMedia,
                      icon: const Icon(Icons.photo_library_outlined),
                      onPressed: _attachMedia,
                    ),
                    IconButton(
                      tooltip: l.attachFile,
                      icon: const Icon(Icons.attach_file),
                      onPressed: _attach,
                    ),
                    IconButton(
                      tooltip: l.send,
                      icon: const Icon(Icons.send_rounded),
                      onPressed: _send,
                    ),
                  ]),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.m,
    required this.onLongPress,
    required this.onDownload,
    required this.onCancel,
    required this.onOpen,
    required this.onVote,
    this.forwardLabel,
    this.replied,
    this.showSender = false,
  });

  final String? forwardLabel;
  final ChatMessage m;
  final ChatMessage? replied;
  final bool showSender;
  final void Function(int) onDownload;
  final void Function(int) onCancel;
  final VoidCallback onOpen;
  final void Function(List<int>) onVote;
  final VoidCallback onLongPress;

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accent = GlassScope.of(context).accent;
    final isVisual = m.kind == MessageKind.photo ||
        m.kind == MessageKind.sticker ||
        m.kind == MessageKind.video;
    final preview = m.thumb ?? (m.kind == MessageKind.photo ? m.file : null);
    final previewPath = preview != null && preview.downloaded
        ? preview.localPath
        : null;
    final showText = m.text.isNotEmpty || (m.file == null && !isVisual);
    final text = m.text.isNotEmpty ? m.text : kindLabel(l, m.kind);
    final sticker = m.kind == MessageKind.sticker;
    return Align(
      alignment: m.outgoing
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: sticker
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: sticker
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: m.outgoing
                      ? accent.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: GlassTokens.fill),
                  border: Border.all(
                    color: m.deletedByPeer
                        ? GlassTokens.ringDanger.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: GlassTokens.border),
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSender && m.senderName.isNotEmpty)
                Text(m.senderName,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: accent)),
              if (forwardLabel != null)
                Text(forwardLabel!,
                    style: const TextStyle(
                        fontSize: 11, color: GlassTokens.ghost)),
              if (m.replyToId != 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 4, top: 2),
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  decoration: BoxDecoration(
                    border: BorderDirectional(
                        start: BorderSide(color: accent, width: 2)),
                  ),
                  child: Text(
                      replied == null
                          ? '…'
                          : (replied!.text.isNotEmpty
                              ? replied!.text
                              : kindLabel(l, replied!.kind)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: GlassTokens.textSecondary)),
                ),
              if (isVisual)
                GestureDetector(
                  onTap: onOpen,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(sticker ? 0 : 12),
                    child: previewPath != null
                        ? Image.file(File(previewPath),
                            width: sticker ? 150 : 220, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const SizedBox(width: 150, height: 100))
                        : SizedBox(
                            width: sticker ? 120 : 220,
                            height: sticker ? 120 : 140,
                            child: Center(
                                child: sticker && m.emoji.isNotEmpty
                                    ? Text(m.emoji,
                                        style: const TextStyle(fontSize: 56))
                                    : Text(l.photoLoading)),
                          ),
                  ),
                ),
              if (showText && !(sticker && m.text.isEmpty))
                Text.rich(TextSpan(children: _spans(text, accent))),
              if (m.file != null && m.kind == MessageKind.voice)
                VoicePlayer(
                    file: m.file!, onDownload: () => onDownload(m.file!.fileId))
              else if (m.file != null && !isVisual)
                FileCard(
                  file: m.file!,
                  onDownload: () => onDownload(m.file!.fileId),
                  onCancel: () => onCancel(m.file!.fileId),
                ),
              if (m.poll != null)
                _PollView(
                  poll: m.poll!,
                  onVote: (ids) => onVote(ids),
                ),
              if (m.link != null)
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse(m.link!.url),
                      mode: LaunchMode.externalApplication),
                  child: Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    decoration: BoxDecoration(
                      border: BorderDirectional(
                          start: BorderSide(color: accent, width: 2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (m.link!.site.isNotEmpty)
                          Text(m.link!.site,
                              style: TextStyle(fontSize: 12, color: accent)),
                        if (m.link!.title.isNotEmpty)
                          Text(m.link!.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                        if (m.link!.description.isNotEmpty)
                          Text(m.link!.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: GlassTokens.textSecondary)),
                      ],
                    ),
                  ),
                ),
              if (m.reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(spacing: 4, runSpacing: 4, children: [
                    for (final e in m.reactions.entries)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: m.myReactions.contains(e.key)
                              ? accent.withValues(alpha: 0.5)
                              : Colors.white12,
                        ),
                        child: Text('${e.key} ${e.value}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (m.deletedByPeer || m.edited)
                    Flexible(
                      child: Text(
                        '${[
                          if (m.deletedByPeer) l.deletedByPeer,
                          if (m.edited) l.edited,
                        ].join(' · ')}  ',
                        style: const TextStyle(
                            fontSize: 11, color: GlassTokens.textTertiary),
                      ),
                    ),
                  Text(_hm(m.time),
                      style: const TextStyle(
                          fontSize: 11, color: GlassTokens.textTertiary)),
                  if (m.outgoing) ...[
                    const SizedBox(width: 3),
                    Icon(m.read ? Icons.done_all : Icons.done,
                        size: 14,
                        color: m.read
                            ? accent
                            : GlassTokens.textTertiary),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


List<InlineSpan> _spans(String text, Color accent) {
  final out = <InlineSpan>[];
  var last = 0;
  for (final m in RegExp(r'@\w{3,32}').allMatches(text)) {
    if (m.start > last) out.add(TextSpan(text: text.substring(last, m.start)));
    out.add(TextSpan(text: m.group(0), style: TextStyle(color: accent)));
    last = m.end;
  }
  if (last < text.length) out.add(TextSpan(text: text.substring(last)));
  return out;
}

class _PollView extends StatelessWidget {
  const _PollView({required this.poll, required this.onVote});

  final PollData poll;
  final void Function(List<int>) onVote;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accent = GlassScope.of(context).accent;
    final voted = poll.options.any((o) => o.chosen);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < poll.options.length; i++)
          InkWell(
            onTap: poll.closed || voted ? null : () => onVote([i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(
                      poll.options[i].chosen
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(poll.options[i].text)),
                  if (voted || poll.closed)
                    Text(poll.total == 0
                        ? '0%'
                        : '${(poll.options[i].votes * 100 / poll.total).round()}%'),
                ]),
                if (voted || poll.closed)
                  LinearProgressIndicator(
                    value: poll.total == 0
                        ? 0
                        : poll.options[i].votes / poll.total,
                    color: accent,
                  ),
              ]),
            ),
          ),
        Text(
            poll.closed
                ? l.pollClosed
                : l.votesCount('${poll.total}'),
            style: const TextStyle(
                fontSize: 11, color: GlassTokens.textTertiary)),
      ]),
    );
  }
}
