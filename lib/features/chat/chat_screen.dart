import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_screen.dart' show kindLabel;
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'dart:async';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../splitter/file_splitter.dart';
import '../splitter/smart_splitter.dart';
import '../../core/drafts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'avatar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:geolocator/geolocator.dart';
import 'wallpapers.dart';
import 'sticker_picker.dart';
import 'package:lottie/lottie.dart';
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
  final Set<int> _selected = {};
  bool _showJump = false;
  final Map<int, GlobalKey> _keys = {};
  int? _highlight;

  /// Scrolls to [id], loading older history first when it isn't loaded yet.
  Future<void> _jumpTo(int id) async {
    for (var tries = 0; tries < 12; tries++) {
      final list = ref.read(messagesProvider(widget.chat.id)).value ??
          const <ChatMessage>[];
      final idx = list.indexWhere((m) => m.id == id);
      if (idx >= 0) {
        final ctx = _keys[id]?.currentContext;
        if (ctx != null) {
          // ignore: use_build_context_synchronously
          await Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 300), alignment: 0.5);
        } else if (_scroll.hasClients) {
          // not built yet: move close, then retry once the item exists
          await _scroll.animateTo(
              (idx * 90.0).clamp(0, _scroll.position.maxScrollExtent),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut);
          await Future<void>.delayed(const Duration(milliseconds: 60));
          final c2 = _keys[id]?.currentContext;
          if (c2 != null) {
            // ignore: use_build_context_synchronously
            await Scrollable.ensureVisible(c2,
                duration: const Duration(milliseconds: 200), alignment: 0.5);
          }
        }
        if (!mounted) return;
        setState(() => _highlight = id);
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (mounted && _highlight == id) setState(() => _highlight = null);
        });
        return;
      }
      final more = await _gateway.loadOlder(widget.chat.id);
      if (!more) return;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

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
    _recTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final far = _scroll.position.pixels > 600;
    if (far != _showJump) setState(() => _showJump = far);
    if (_loadingOlder) return;
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

  Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.sendFailed('$e'))));
    }
  }

  Future<void> _sendPaths(List<String> paths) =>
      _safe(() => _gateway.sendMedia(widget.chat.id, paths));

  Future<void> _pickGallery() async {
    final picked = await ImagePicker().pickMultipleMedia();
    if (picked.isEmpty || !mounted) return;
    await _sendPaths([for (final x in picked) x.path]);
  }

  Future<void> _pickCamera({required bool video}) async {
    final x = video
        ? await ImagePicker().pickVideo(source: ImageSource.camera)
        : await ImagePicker().pickImage(source: ImageSource.camera);
    if (x == null || !mounted) return;
    await _sendPaths([x.path]);
  }

  Future<void> _scheduleSend() async {
    final l = AppLocalizations.of(context);
    final text = _c.text.trim();
    if (text.isEmpty || _editing != null) return;
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5))));
    if (t == null || !mounted) return;
    final at = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (!at.isAfter(now.add(const Duration(seconds: 30)))) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.pickTime)));
      return;
    }
    await _safe(() => _gateway.scheduleText(widget.chat.id, text, at));
    _c.clear();
    DraftStore.set(widget.chat.id, '');
    setState(() {});
  }

  Future<void> _showScheduled() async {
    final l = AppLocalizations.of(context);
    final list = await _gateway.scheduledMessages(widget.chat.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.scheduledMessages),
        content: SizedBox(
          width: double.maxFinite,
          child: list.isEmpty
              ? Text(l.noScheduled)
              : ListView(shrinkWrap: true, children: [
                  for (final m in list)
                    ListTile(
                      title: Text(m.text.isEmpty ? kindLabel(l, m.kind) : m.text,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(l.scheduledFor(
                          '${m.time.day}/${m.time.month} ${m.time.hour.toString().padLeft(2, '0')}:${m.time.minute.toString().padLeft(2, '0')}')),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await _gateway.deleteMessages(widget.chat.id, [m.id],
                              forAll: true);
                          // ignore: use_build_context_synchronously
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    ),
                ]),
        ),
      ),
    );
  }

  Future<void> _newPoll() async {
    final l = AppLocalizations.of(context);
    final q = TextEditingController();
    final opts = [TextEditingController(), TextEditingController()];
    var multiple = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(l.createPoll),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: q,
                  decoration: InputDecoration(hintText: l.pollQuestion)),
              for (var i = 0; i < opts.length; i++)
                TextField(
                    controller: opts[i],
                    decoration:
                        InputDecoration(hintText: l.pollOption('${i + 1}'))),
              if (opts.length < 10)
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l.pollOption('${opts.length + 1}')),
                  onPressed: () => set(() => opts.add(TextEditingController())),
                ),
              SwitchListTile(
                  title: Text(l.pollMultiple),
                  value: multiple,
                  onChanged: (v) => set(() => multiple = v)),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.send2)),
          ],
        ),
      ),
    );
    final options = [
      for (final o in opts)
        if (o.text.trim().isNotEmpty) o.text.trim()
    ];
    if (ok != true || q.text.trim().isEmpty || options.length < 2) return;
    await _safe(() =>
        _gateway.sendPoll(widget.chat.id, q.text.trim(), options, multiple: multiple));
  }

  Future<void> _shareLocation() async {
    final l = AppLocalizations.of(context);
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.locationDenied)));
      }
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    await _gateway.sendLocation(widget.chat.id, pos.latitude, pos.longitude);
  }

  Future<void> _shareContact() async {
    final contacts = await _gateway.contacts();
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final picked = await showDialog<ChatSummary>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(l.contactLabel),
        children: [
          SizedBox(
            width: double.maxFinite,
            height: 360,
            child: ListView(children: [
              for (final c in contacts)
                ListTile(
                    title: Text(c.title),
                    onTap: () => Navigator.pop(context, c)),
            ]),
          ),
        ],
      ),
    );
    if (picked != null) {
      await _safe(() => _gateway.sendContact(widget.chat.id, picked.id));
    }
  }

  void _attachSheet() {
    final l = AppLocalizations.of(context);
    Widget item(IconData i, String t, VoidCallback f) => ListTile(
          leading: Icon(i),
          title: Text(t),
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
            item(Icons.photo_library_outlined, l.gallery, _pickGallery),
            item(Icons.photo_camera_outlined, l.cameraPhoto,
                () => _pickCamera(video: false)),
            item(Icons.videocam_outlined, l.cameraVideo,
                () => _pickCamera(video: true)),
            item(Icons.attach_file, l.fileLabel, () => _safe(_attach)),
            item(Icons.poll_outlined, l.createPoll, _newPoll),
            item(Icons.schedule_send_outlined, l.scheduledMessages, _showScheduled),
            item(Icons.location_on_outlined, l.location, () => _safe(_shareLocation)),
            item(Icons.contact_page_outlined, l.contactLabel, _shareContact),
          ]),
        ),
      ),
    );
  }

  // ---- voice notes (tap mic to start, tap send to deliver)
  final _recorder = AudioRecorder();
  bool _recording = false;
  int _recSeconds = 0;
  Timer? _recTimer;
  String? _recPath;

  Future<void> _startRecording() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!await _recorder.hasPermission()) {
        messenger.showSnackBar(SnackBar(content: Text(l.micDenied)));
        return;
      }
      if (!await _recorder.isEncoderSupported(AudioEncoder.opus)) {
        messenger.showSnackBar(SnackBar(content: Text(l.micUnsupported)));
        return;
      }
      final tmp = await getTemporaryDirectory();
      _recPath = '${tmp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.ogg';
      await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.opus, bitRate: 32000, sampleRate: 48000),
          path: _recPath!);
      _recSeconds = 0;
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recSeconds++);
      });
      setState(() => _recording = true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.sendFailed('$e'))));
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    _recTimer?.cancel();
    final secs = _recSeconds;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
    if (mounted) setState(() => _recording = false);
    if (!send || path == null || secs < 1) {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      return;
    }
    await _safe(() => _gateway.sendVoice(widget.chat.id, path!, secs));
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
            item(Icons.check_circle_outline, l.select,
                () => setState(() => _selected.add(m.id))),
            if (m.sendState == 2)
              item(Icons.refresh, l.resend,
                  () => _safe(() => _gateway.resend(widget.chat.id, m.id))),
            if (m.text.isNotEmpty || (m.file?.downloaded ?? false))
              item(Icons.ios_share, l.share, () => _share([m])),
            if (!m.deletedByPeer && widget.chat.type != ChatType.secret)
              item(Icons.shortcut, l.forward, () => _pickForward(m, chats)),
            if (m.edited)
              item(Icons.history, l.editHistory, () => _showEdits(context, m)),
            if (!m.deletedByPeer &&
                (widget.chat.type == ChatType.private || widget.chat.canSend))
              item(
                  _pinned?.id == m.id ? Icons.push_pin : Icons.push_pin_outlined,
                  _pinned?.id == m.id ? l.unpin : l.pin, () async {
                final unpin = _pinned?.id == m.id;
                await _safe(() => _gateway.pinMessage(widget.chat.id, m.id,
                    pin: !unpin));
                final p = await _gateway.pinnedMessage(widget.chat.id);
                if (mounted) setState(() => _pinned = p);
              }),
            if (!m.deletedByPeer)
              item(Icons.delete_outline, l.delete, () => _confirmDelete(m),
                  c: GlassTokens.ringDanger),
          ]),
        ),
      ),
    );
  }

  Future<void> _share(List<ChatMessage> ms) async {
    final files = [
      for (final m in ms)
        if (m.file?.downloaded == true && m.file!.localPath != null)
          XFile(m.file!.localPath!)
    ];
    final text = ms.map((m) => m.text).where((t) => t.isNotEmpty).join('\n');
    await SharePlus.instance.share(ShareParams(
        text: text.isEmpty ? null : text, files: files.isEmpty ? null : files));
  }

  List<ChatMessage> _selectedMessages() {
    final all = ref.read(messagesProvider(widget.chat.id)).value ?? const <ChatMessage>[];
    return [for (final m in all) if (_selected.contains(m.id)) m]
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<void> _deleteSelected() async {
    final l = AppLocalizations.of(context);
    final ids = _selected.toList();
    final mine = _selectedMessages().every((m) => m.outgoing);
    final choice = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(l.deleteTitle),
        children: [
          SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 1),
              child: Text(l.deleteForMe)),
          if (mine || widget.chat.type == ChatType.private)
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 2),
                child: Text(l.deleteForAll)),
        ],
      ),
    );
    if (choice == null) return;
    setState(_selected.clear);
    await _safe(() => _gateway.deleteMessages(widget.chat.id, ids, forAll: choice == 2));
  }

  void _forwardSelected() {
    final ms = _selectedMessages();
    final chats = ref.read(chatsProvider).value ?? const <ChatSummary>[];
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
                        leading: AvatarCircle(title: c.title, photo: c.avatar, size: 40),
                        title: Text(c.title),
                        onTap: () {
                          Navigator.of(context).pop();
                          _gateway.forwardMessages(
                              c.id, widget.chat.id, [for (final m in ms) m.id]);
                          setState(_selected.clear);
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
    if (f.name.endsWith('.tgs') || f.name.endsWith('.webm')) return; // animated
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
    final wall = wallpapers[ref.watch(settingsProvider).wallpaper.clamp(0, wallpapers.length - 1)];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: wall),
        child: SafeArea(
        child: Column(
          children: [
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: GlassSurface(
                  blur: true,
                  radius: 22,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_selected.clear),
                    ),
                    Expanded(child: Text(l.selectedCount('${_selected.length}'))),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                            text: _selectedMessages().map((m) => m.text).join('\n')));
                        setState(_selected.clear);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.ios_share),
                      onPressed: () => _share(_selectedMessages()),
                    ),
                    if (widget.chat.type != ChatType.secret)
                      IconButton(
                        icon: const Icon(Icons.shortcut),
                        onPressed: _forwardSelected,
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: GlassTokens.ringDanger),
                      onPressed: _deleteSelected,
                    ),
                  ]),
                ),
              )
            else
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
              GestureDetector(
                onTap: () => _jumpTo(_pinned!.id),
                child: Padding(
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
              )),
            if (ghost)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l.silentRead,
                    style: const TextStyle(
                        fontSize: 12, color: GlassTokens.ghost)),
              ),
            Expanded(
              child: Stack(children: [
                Positioned.fill(child: msgs.when(
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
                        KeyedSubtree(
                          key: _keys.putIfAbsent(m.id, GlobalKey.new),
                          child: _Bubble(
                          m: m,
                          onJump: () => _jumpTo(m.replyToId),
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
                          selected:
                              _selected.contains(m.id) || _highlight == m.id,
                          selecting: _selected.isNotEmpty,
                          onTapSelect: () => setState(() {
                            _selected.contains(m.id)
                                ? _selected.remove(m.id)
                                : _selected.add(m.id);
                          }),
                        )),
                      ]);
                    },
                  );
                },
              )),
                if (_showJump)
                  PositionedDirectional(
                    end: 12,
                    bottom: 12,
                    child: FloatingActionButton.small(
                      tooltip: l.jumpToLatest,
                      onPressed: () => _scroll.animateTo(0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut),
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ),
              ]),
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
                  child: _recording
                      ? Row(children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _stopRecording(send: false),
                          ),
                          const Icon(Icons.fiber_manual_record,
                              size: 14, color: GlassTokens.ringDanger),
                          const SizedBox(width: 6),
                          Text(
                              '${l.recording} ${_recSeconds ~/ 60}:${(_recSeconds % 60).toString().padLeft(2, '0')}'),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.send_rounded),
                            onPressed: () => _stopRecording(send: true),
                          ),
                        ])
                      : Row(children: [
                    IconButton(
                      tooltip: l.attach,
                      icon: const Icon(Icons.attach_file),
                      onPressed: _attachSheet,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _c,
                        minLines: 1,
                        maxLines: 6,
                        onChanged: (v) {
                          _onChanged(v);
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          hintText: l.typeMessage,
                          border: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                    if (_c.text.trim().isEmpty && _editing == null)
                      IconButton(
                        tooltip: l.stickers,
                        icon: const Icon(Icons.emoji_emotions_outlined),
                        onPressed: () => showStickerPicker(context, _gateway,
                            onPick: (st) => _safe(
                                () => st.gif
                                ? _gateway.sendGif(widget.chat.id, st)
                                : _gateway.sendSticker(widget.chat.id, st))),
                      ),
                    if (_c.text.trim().isEmpty && _editing == null)
                      IconButton(
                        tooltip: l.kindVoice,
                        icon: const Icon(Icons.mic_none),
                        onPressed: _startRecording,
                      )
                    else
                      GestureDetector(
                        onLongPress: _scheduleSend,
                        child: IconButton(
                          tooltip: l.send,
                          icon: const Icon(Icons.send_rounded),
                          onPressed: () => _safe(_send),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
          ],
        ),
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
    required this.onTapSelect,
    required this.onJump,
    this.selected = false,
    this.selecting = false,
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
  final VoidCallback onTapSelect;
  final VoidCallback onJump;
  final bool selected;
  final bool selecting;

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
        onTap: selecting ? onTapSelect : null,
        onLongPress: selecting ? onTapSelect : onLongPress,
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
                    width: selected ? 2.5 : 1,
                    color: selected
                        ? accent
                        : m.deletedByPeer
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
                GestureDetector(
                  onTap: onJump,
                  child: Container(
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
                )),
              if (isVisual)
                GestureDetector(
                  onTap: onOpen,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(sticker ? 0 : 12),
                    child: (sticker &&
                            m.file != null &&
                            m.file!.name.endsWith('.webm') &&
                            m.file!.downloaded &&
                            m.file!.localPath != null)
                        ? _WebmSticker(path: m.file!.localPath!)
                        : (sticker &&
                            m.file != null &&
                            m.file!.name.endsWith('.tgs') &&
                            m.file!.downloaded &&
                            m.file!.localPath != null)
                        ? SizedBox(
                            width: 150,
                            height: 150,
                            child: Lottie.file(File(m.file!.localPath!),
                                decoder: LottieComposition.decodeGZip,
                                errorBuilder: (_, _, _) => Center(
                                    child: Text(m.emoji,
                                        style: const TextStyle(fontSize: 56)))),
                          )
                        : previewPath != null
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
                _LinkText(text: text, color: accent),
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
                    Icon(
                        m.sendState == 2
                            ? Icons.error_outline
                            : m.sendState == 1
                                ? Icons.schedule
                                : (m.read ? Icons.done_all : Icons.done),
                        size: 14,
                        color: m.sendState == 2
                            ? GlassTokens.ringDanger
                            : (m.read ? accent : GlassTokens.textTertiary)),
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


/// Looping, muted WebM sticker.
class _WebmSticker extends StatefulWidget {
  const _WebmSticker({required this.path});
  final String path;

  @override
  State<_WebmSticker> createState() => _WebmStickerState();
}

class _WebmStickerState extends State<_WebmSticker> {
  late final VideoPlayerController _c = VideoPlayerController.file(File(widget.path))
    ..setLooping(true)
    ..setVolume(0)
    ..initialize().then((_) {
      if (mounted) {
        setState(() {});
        _c.play();
      }
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        height: 150,
        child: _c.value.isInitialized
            ? AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c))
            : const SizedBox.shrink(),
      );
}

/// Message text with tappable links and highlighted @mentions.
class _LinkText extends StatefulWidget {
  const _LinkText({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  State<_LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<_LinkText> {
  final _recognizers = <TapGestureRecognizer>[];

  void _clear() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final text = widget.text;
    final out = <InlineSpan>[];
    var last = 0;
    final re = RegExp(r'(https?://[^\s]+)|(@\w{3,32})');
    for (final m in re.allMatches(text)) {
      if (m.start > last) out.add(TextSpan(text: text.substring(last, m.start)));
      final url = m.group(1);
      final style = TextStyle(
          color: widget.color,
          decoration: url != null ? TextDecoration.underline : null);
      if (url != null) {
        final r = TapGestureRecognizer()
          ..onTap = () => launchUrl(Uri.parse(url),
              mode: LaunchMode.externalApplication);
        _recognizers.add(r);
        out.add(TextSpan(text: url, style: style, recognizer: r));
      } else {
        out.add(TextSpan(text: m.group(0), style: style));
      }
      last = m.end;
    }
    if (last < text.length) out.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(children: out));
  }
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
