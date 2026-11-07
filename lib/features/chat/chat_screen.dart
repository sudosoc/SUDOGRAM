import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ui/icon_styles.dart';

import '../../app/providers.dart';
import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../core/device_perms.dart';
import '../../core/live_location.dart';
import '../../core/ui/notice.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_screen.dart' show kindLabel;

import 'dart:io';

import '../../core/voice_fx.dart';
import 'chat_extras.dart';
import 'code_block.dart';

import '../../core/code_markup.dart';

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


import 'info_screen.dart';
import 'voice_player.dart';
import '../../core/media_save.dart';
import 'tgs_view.dart';
import 'location_card.dart';
import 'file_card.dart';
import 'contact_card.dart';
import '../home/chat_actions.dart';
import '../settings/ghost_screen.dart';
import 'status_text.dart';
import 'emoji_panel.dart';

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

  /// Scrolls to [id], loading history around it first when it isn't loaded.
  Future<void> _jumpTo(int id) async {
    var loaded = false;
    for (var tries = 0; tries < 60; tries++) {
      if (!mounted) return;
      final list =
          ref.read(messagesProvider(widget.chat.id)).value ??
          const <ChatMessage>[];
      final idx = list.indexWhere((m) => m.id == id);
      if (idx < 0) {
        if (!loaded) {
          loaded = true;
          await _gateway.loadAround(widget.chat.id, id);
        } else {
          await _gateway.loadOlder(widget.chat.id);
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
        continue;
      }
      final ctx = _keys[id]?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          alignment: 0.5,
        );
        if (!mounted) return;
        setState(() => _highlight = id);
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (mounted && _highlight == id) setState(() => _highlight = null);
        });
        return;
      }
      if (!_scroll.hasClients) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        continue;
      }
      // Not built yet: find which built rows bracket the target and move
      // towards it until the row appears.
      var lo = list.length, hi = -1;
      for (var i = 0; i < list.length; i++) {
        if (_keys[list[i].id]?.currentContext != null) {
          if (i < lo) lo = i;
          if (i > hi) hi = i;
        }
      }
      final pos = _scroll.position;
      double target;
      if (hi < 0) {
        target = pos.maxScrollExtent * idx / list.length;
      } else if (idx > hi) {
        target = pos.pixels + 700; // older messages are further up
      } else {
        target = pos.pixels - 700;
      }
      _scroll.jumpTo(target.clamp(0.0, pos.maxScrollExtent));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  List<MentionCandidate> _mentions = const [];
  List<ChatMessage>? _hits;
  List<ChatMessage> _pins = const [];
  int _pinIdx = 0;
  final _pinBarKey = GlobalKey();
  bool _emojiOpen = false;
  final _focus = FocusNode();
  late final _area = ref.read(hiddenAreaProvider.notifier);
  bool _inHiddenArea = false;

  /// The pinned message currently shown in the bar.
  ChatMessage? get _pinned =>
      _pins.isEmpty ? null : _pins[_pinIdx.clamp(0, _pins.length - 1)];

  Future<void> _loadPins() async {
    var list = await _gateway.pinnedMessages(widget.chat.id);
    if (list.isEmpty) {
      final one = await _gateway.pinnedMessage(widget.chat.id);
      if (one != null) list = [one];
    }
    if (!mounted) return;
    setState(() {
      _pins = list;
      _pinIdx = 0;
    });
  }

  /// Tap on the bar: jump to the shown pin, then move to the one before it.
  void _pinBarTap() {
    final p = _pinned;
    if (p == null) return;
    _jumpTo(p.id);
    if (_pins.length > 1) {
      setState(() => _pinIdx = (_pinIdx + 1) % _pins.length);
    }
  }

  /// Long-press: drop-down list of every pinned message.
  Future<void> _pinMenu() async {
    final l = AppLocalizations.of(context);
    final box = _pinBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _pins.isEmpty) return;
    final top = box.localToGlobal(Offset.zero);
    final size = MediaQuery.of(context).size;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        16,
        top.dy + box.size.height,
        16,
        size.height - top.dy - box.size.height,
      ),
      constraints: BoxConstraints(
        maxWidth: size.width - 32,
        minWidth: size.width - 32,
      ),
      items: [
        for (final m in _pins)
          PopupMenuItem<String>(
            value: 'jump:${m.id}',
            child: Row(
              children: [
                const SIcon(Icons.push_pin_outlined, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    m.text.isNotEmpty ? m.text : kindLabel(l, m.kind),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.chat.canSend || widget.chat.type == ChatType.private)
                  IconButton(
                    tooltip: l.unpin,
                    icon: const SIcon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop('unpin:${m.id}'),
                  ),
              ],
            ),
          ),
        if (_pins.length > 1 &&
            (widget.chat.canSend || widget.chat.type == ChatType.private))
          PopupMenuItem<String>(
            value: 'unpinall',
            child: Row(
              children: [
                const SIcon(
                  Icons.layers_clear_outlined,
                  size: 18,
                  color: GlassTokens.ringDanger,
                ),
                const SizedBox(width: 10),
                Text(
                  l.unpinAll,
                  style: const TextStyle(color: GlassTokens.ringDanger),
                ),
              ],
            ),
          ),
      ],
    );
    if (choice == null || !mounted) return;
    if (choice.startsWith('jump:')) {
      _jumpTo(int.parse(choice.substring(5)));
    } else if (choice.startsWith('unpin:')) {
      await _safe(
        () => _gateway.pinMessage(
          widget.chat.id,
          int.parse(choice.substring(6)),
          pin: false,
        ),
      );
      await _loadPins();
    } else if (choice == 'unpinall') {
      for (final m in _pins.toList()) {
        await _safe(
          () => _gateway.pinMessage(widget.chat.id, m.id, pin: false),
        );
      }
      await _loadPins();
    }
  }

  int _lastReadSig = 0;

  @override
  void initState() {
    super.initState();
    _gateway.openChat(widget.chat.id);
    _notifier.openChat = widget.chat.id;
    _c.text = DraftStore.get(widget.chat.id);
    _scroll.addListener(_onScroll);
    _loadPins();
    _c.addListener(_onCtl);
    _focus.addListener(() {
      if (_focus.hasFocus && _emojiOpen) setState(() => _emojiOpen = false);
    });
    _inHiddenArea = ref
        .read(settingsProvider)
        .hiddenChats
        .contains(widget.chat.id);
    if (_inHiddenArea) Future.microtask(_area.enter);
    _gateway.messageTextLimit().then((v) {
      if (mounted) setState(() => _limit = v);
    });
  }

  void _onCtl() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_inHiddenArea) Future.microtask(_area.leave);
    _focus.dispose();
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
    if (ref.read(settingsProvider).blocksRead(widget.chat.id)) return;
    final ids = [
      for (final m in list)
        if (!m.outgoing) m.id,
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
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
    setState(() => _mentions = const []);
  }

  void _onChanged(String v) {
    _updateMentions(v);
    // Typing indicator goes through the Ghost guard; in ghost mode it's dropped.
    if (v.isNotEmpty) _gateway.sendTyping(widget.chat.id);
    final n = v.isEmpty
        ? 1
        : SmartSplitter.countParts(v, SplitOptions(maxLength: _limit));
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
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.fileSplitNotice('$count')),
        duration: const Duration(seconds: 4),
      ),
    );
    final tmp = await getTemporaryDirectory();
    final out = Directory(
      '${tmp.path}/split_${DateTime.now().millisecondsSinceEpoch}',
    );
    try {
      // 3+ parts: add one Reed-Solomon parity part so one lost or damaged
      // part can be rebuilt on the other side.
      final r = await FileSplitter.split(
        file,
        out,
        partSize: _maxFile,
        parityParts: count >= 3 ? 1 : 0,
      );
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
      notice(context, friendlyError(e, ar: context.isAr),
          kind: NoticeKind.error);
    }
  }

  final Map<int, ChatMessage> _replyCache = {};
  final Set<int> _replyAsked = {};

  /// Replied-to messages outside the loaded window are fetched on demand.
  ChatMessage? _replyFor(int id) {
    final hit = _replyCache[id];
    if (hit != null) return hit;
    if (_replyAsked.add(id)) _fetchReply(id);
    return null;
  }

  Future<void> _fetchReply(int id) async {
    try {
      final r = await _gateway.tdRaw({
        '@type': 'getMessage',
        'chat_id': widget.chat.id,
        'message_id': id,
      });
      final c = (r['content'] as Map?) ?? const {};
      final t = (c['@type'] ?? '').toString();
      final text = ((c['text'] as Map?)?['text'] ?? (c['caption'] as Map?)?['text'] ?? '').toString();
      final kind = switch (t) {
        'messagePhoto' => MessageKind.photo,
        'messageVideo' => MessageKind.video,
        'messageVoiceNote' => MessageKind.voice,
        'messageSticker' => MessageKind.sticker,
        'messageText' => MessageKind.text,
        'messageDocument' || 'messageAudio' => MessageKind.document,
        _ => MessageKind.other,
      };
      final out = r['is_outgoing'] == true;
      _replyCache[id] = ChatMessage(
        id: id,
        chatId: widget.chat.id,
        text: text,
        kind: kind,
        outgoing: out,
        time: DateTime.now(),
      );
      if (mounted) setState(() {});
    } catch (_) {}
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
    var path = x.path;
    try {
      // Keep our own copy: the picker's cache file can vanish mid-upload.
      final dir = Directory('${(await getApplicationSupportDirectory()).path}/outbox');
      await dir.create(recursive: true);
      final ext = path.contains('.') ? path.split('.').last : (video ? 'mp4' : 'jpg');
      final copy = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(path).copy(copy);
      path = copy;
    } catch (_) {}
    await _sendPaths([path]);
  }

  Future<void> _muteFor(int chatId) async {
    final secs = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(context.t('Mute notifications', 'كتم الإشعارات'))),
          for (final (v, label) in [
            (3600, context.t('For 1 hour', 'لمدة ساعة')),
            (28800, context.t('For 8 hours', 'لمدة 8 ساعات')),
            (172800, context.t('For 2 days', 'لمدة يومين')),
            (2147483647, context.t('Forever', 'للأبد')),
          ])
            ListTile(
              leading: const SIcon(Icons.notifications_off_outlined),
              title: Text(label),
              onTap: () => Navigator.pop(context, v),
            ),
        ]),
      ),
    );
    if (secs == null) return;
    await _safe(() async {
      await _gateway.tdRaw({
        '@type': 'setChatNotificationSettings',
        'chat_id': chatId,
        'notification_settings': {
          '@type': 'chatNotificationSettings',
          'use_default_mute_for': false,
          'mute_for': secs,
          'use_default_sound': true,
          'use_default_show_preview': true,
          'use_default_mute_stories': true,
          'use_default_story_sound': true,
          'use_default_show_story_poster': true,
          'use_default_disable_pinned_message_notifications': true,
          'use_default_disable_mention_notifications': true,
        },
      });
      if (mounted) {
        notice(context, context.t('Muted', 'تم الكتم'), kind: NoticeKind.success);
      }
    });
  }

  Future<void> _sendSilently(String text) async {
    await _safe(() async {
      await _gateway.tdRaw({
        '@type': 'sendMessage',
        'chat_id': widget.chat.id,
        'input_message_content': {
          '@type': 'inputMessageText',
          'text': {'@type': 'formattedText', 'text': text},
        },
        'options': {'@type': 'messageSendOptions', 'disable_notification': true},
      });
      _c.clear();
      DraftStore.set(widget.chat.id, '');
      if (mounted) setState(() {});
    });
  }

  Future<void> _scheduleSend() async {
    final l = AppLocalizations.of(context);
    final text = _c.text.trim();
    if (text.isEmpty || _editing != null) return;
    final how = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const SIcon(Icons.notifications_off_outlined),
            title: Text(context.t('Send without sound', 'إرسال بدون صوت')),
            onTap: () => Navigator.pop(context, 'silent'),
          ),
          ListTile(
            leading: const SIcon(Icons.schedule_send_outlined),
            title: Text(context.t('Schedule…', 'جدولة…')),
            onTap: () => Navigator.pop(context, 'schedule'),
          ),
        ]),
      ),
    );
    if (how == null || !mounted) return;
    if (how == 'silent') {
      await _sendSilently(text);
      return;
    }
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5))),
    );
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
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final m in list)
                      ListTile(
                        title: Text(
                          m.text.isEmpty ? kindLabel(l, m.kind) : m.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          l.scheduledFor(
                            '${m.time.day}/${m.time.month} ${m.time.hour.toString().padLeft(2, '0')}:${m.time.minute.toString().padLeft(2, '0')}',
                          ),
                        ),
                        trailing: IconButton(
                          icon: const SIcon(Icons.delete_outline),
                          onPressed: () async {
                            await _gateway.deleteMessages(widget.chat.id, [
                              m.id,
                            ], forAll: true);
                            // ignore: use_build_context_synchronously
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      ),
                  ],
                ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: q,
                  decoration: InputDecoration(hintText: l.pollQuestion),
                ),
                for (var i = 0; i < opts.length; i++)
                  TextField(
                    controller: opts[i],
                    decoration: InputDecoration(
                      hintText: l.pollOption('${i + 1}'),
                    ),
                  ),
                if (opts.length < 10)
                  TextButton.icon(
                    icon: const SIcon(Icons.add),
                    label: Text(l.pollOption('${opts.length + 1}')),
                    onPressed: () =>
                        set(() => opts.add(TextEditingController())),
                  ),
                SwitchListTile(
                  title: Text(l.pollMultiple),
                  value: multiple,
                  onChanged: (v) => set(() => multiple = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.send2),
            ),
          ],
        ),
      ),
    );
    final options = [
      for (final o in opts)
        if (o.text.trim().isNotEmpty) o.text.trim(),
    ];
    if (ok != true || q.text.trim().isEmpty || options.length < 2) return;
    await _safe(
      () => _gateway.sendPoll(
        widget.chat.id,
        q.text.trim(),
        options,
        multiple: multiple,
      ),
    );
  }

  Future<void> _shareLocation() async {
    final l = AppLocalizations.of(context);
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (mounted) notice(context, l.locationDenied, kind: NoticeKind.error);
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    await _gateway.sendLocation(widget.chat.id, pos.latitude, pos.longitude);
  }

  Future<void> _liveLocation() async {
    if (!await ensureLocationPermission()) {
      if (mounted) {
        notice(context, AppLocalizations.of(context).locationDenied,
            kind: NoticeKind.error);
      }
      return;
    }
    if (!mounted) return;
    final mins = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              title: Text(context.t('Share live location for…', 'مشاركة الموقع المباشر لمدة…'))),
          for (final (m, label) in [
            (15, context.t('15 minutes', '15 دقيقة')),
            (60, context.t('1 hour', 'ساعة')),
            (480, context.t('8 hours', '8 ساعات')),
          ])
            ListTile(
              leading: const SIcon(Icons.share_location),
              title: Text(label),
              onTap: () => Navigator.pop(context, m),
            ),
          if (LiveLocation.isActive(widget.chat.id))
            ListTile(
              leading: const SIcon(Icons.location_off, color: GlassTokens.ringDanger),
              title: Text(context.t('Stop sharing', 'إيقاف المشاركة')),
              onTap: () => Navigator.pop(context, 0),
            ),
        ]),
      ),
    );
    if (mins == null) return;
    if (mins == 0) {
      await LiveLocation.stop(widget.chat.id);
      return;
    }
    await _safe(() => LiveLocation.start(_gateway, widget.chat.id, mins));
    if (mounted) {
      notice(context, context.t('Live location started', 'بدأت مشاركة الموقع المباشر'),
          kind: NoticeKind.success);
    }
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
            child: ListView(
              children: [
                for (final c in contacts)
                  ListTile(
                    title: Text(c.title),
                    onTap: () => Navigator.pop(context, c),
                  ),
              ],
            ),
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
    final all = <String, (IconData, String, VoidCallback)>{
      'gallery': (Icons.photo_library_outlined, l.gallery, _pickGallery),
      'photo': (Icons.photo_camera_outlined, l.cameraPhoto, () => _pickCamera(video: false)),
      'video': (Icons.videocam_outlined, l.cameraVideo, () => _pickCamera(video: true)),
      'file': (Icons.attach_file, l.fileLabel, () => _safe(_attach)),
      'poll': (Icons.poll_outlined, l.createPoll, _newPoll),
      'scheduled': (Icons.schedule_send_outlined, l.scheduledMessages, _showScheduled),
      'location': (Icons.location_on_outlined, l.location, () => _safe(_shareLocation)),
      'live': (Icons.share_location, context.t('Live location', 'الموقع المباشر'), _liveLocation),
      'contact': (Icons.contact_page_outlined, l.contactLabel, _shareContact),
    };
    final ids = ref.read(settingsProvider).attachItems.where(all.containsKey).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: GlassSurface(
          blur: true,
          radius: 24,
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Wrap(
              alignment: WrapAlignment.start,
              spacing: 4,
              runSpacing: 12,
              children: [
                for (final id in ids)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).pop();
                      all[id]!.$3();
                    },
                    child: SizedBox(
                      width: (MediaQuery.of(context).size.width - 24 - 24 - 12) / 4,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: GlassScope.of(context).accent.withValues(alpha: 0.22),
                          ),
                          child: SIcon(all[id]!.$1, size: 26),
                        ),
                        const SizedBox(height: 6),
                        Text(all[id]!.$2,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- voice notes (tap mic to start, tap send to deliver)
  final _recorder = AudioRecorder();
  VoiceFx _recFx = VoiceFx.none;
  bool _fxBusy = false;
  bool _recording = false;
  int _recSeconds = 0;
  Timer? _recTimer;
  String? _recPath;
  bool _recLocked = false;
  bool _recCancel = false;
  Future<void>? _recStart;

  void _micDown() {
    _recLocked = false;
    _recCancel = false;
    HapticFeedback.mediumImpact();
    _recStart = _startRecording();
  }

  void _micMove(LongPressMoveUpdateDetails d) {
    if (_recLocked || !_recording) return;
    final o = d.offsetFromOrigin;
    if (o.dy < -90) {
      HapticFeedback.selectionClick();
      setState(() {
        _recLocked = true;
        _recCancel = false;
      });
      return;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final cancel = rtl ? o.dx > 100 : o.dx < -100;
    if (cancel != _recCancel) setState(() => _recCancel = cancel);
  }

  Future<void> _micUp({bool cancel = false}) async {
    await _recStart;
    if (!mounted || _recLocked) return;
    final c = cancel || _recCancel;
    _recCancel = false;
    if (_recording) await _stopRecording(send: !c);
  }

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
      _recFx = voiceFxFrom(ref.read(settingsProvider).voiceFx);
      final fxOn = _recFx != VoiceFx.none;
      _recPath =
          '${tmp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.${fxOn ? 'wav' : 'ogg'}';
      await _recorder.start(
        fxOn
            ? const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 48000, numChannels: 1)
            : const RecordConfig(
                encoder: AudioEncoder.opus,
                bitRate: 32000,
                sampleRate: 48000,
              ),
        path: _recPath!,
      );
      _recSeconds = 0;
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recSeconds++);
      });
      setState(() => _recording = true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e, ar: l.localeName == 'ar'))));
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
    if (mounted) {
      setState(() {
        _recording = false;
        _recLocked = false;
        _recCancel = false;
      });
    }
    if (!send || path == null || secs < 1) {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      return;
    }
    if (_recFx != VoiceFx.none && path.endsWith('.wav')) {
      if (mounted) setState(() => _fxBusy = true);
      try {
        final r = await applyVoiceFx(path, _recFx);
        if (r.fallbackWav) {
          if (mounted) {
            notice(context,
                context.t('Opus encoding unavailable here — sent the changed voice as an audio file',
                    'تشفير الصوت مش متاح هنا — اتبعت الصوت المتغير كملف صوتي'),
                kind: NoticeKind.info);
          }
          await _safe(() => _gateway.sendMedia(widget.chat.id, [r.path]));
        } else {
          await _safe(() => _gateway.sendVoice(widget.chat.id, r.path, r.seconds));
        }
      } catch (e) {
        if (mounted) notice(context, friendlyError(e, ar: context.isAr), kind: NoticeKind.error);
      } finally {
        if (mounted) setState(() => _fxBusy = false);
      }
      return;
    }
    await _safe(() => _gateway.sendVoice(widget.chat.id, path!, secs));
  }

  void _fxSheet() {
    final accent = GlassScope.of(context).accent;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => Consumer(builder: (ctx, ref2, _) {
        final cur = voiceFxFrom(ref2.watch(settingsProvider).voiceFx);
        return Padding(
          padding: const EdgeInsets.all(12),
          child: GlassSurface(
            blur: true,
            radius: 26,
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.t('Voice changer', 'مغيّر الصوت'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                  context.t('Hold the mic as usual — your recording is sent with the selected voice.',
                      'سجّل زي العادة — التسجيل بيتبعت بالصوت اللي تختاره.'),
                  style: const TextStyle(fontSize: 12, color: GlassTokens.textSecondary)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in VoiceFx.values)
                  ChoiceChip(
                    avatar: SIcon(f.icon, size: 18, color: cur == f ? Colors.white : accent),
                    label: Text(f.label(context.isAr)),
                    selected: cur == f,
                    onSelected: (_) {
                      ref2.read(settingsProvider.notifier).setX('voiceFx', f.id);
                      Navigator.of(sheet).pop();
                    },
                  ),
              ]),
            ]),
          ),
        );
      }),
    );
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
    if (text.length > _limit && ref.read(settingsProvider).longAsFile) {
      try {
        final dir = Directory('${(await getApplicationSupportDirectory()).path}/outbox');
        await dir.create(recursive: true);
        final n = DateTime.now();
        String two(int v) => v.toString().padLeft(2, '0');
        final f = File('${dir.path}/message_${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}.txt');
        await f.writeAsString(text);
        final first = text.trim().split('\n').first;
        await _gateway.sendMedia(
          widget.chat.id,
          [f.path],
          caption: first.length > 100 ? '${first.substring(0, 100)}…' : first,
        );
        return;
      } catch (_) {
        // fall through to normal splitting
      }
    }
    final parts = SmartSplitter.split(text, SplitOptions(maxLength: _limit));
    for (var i = 0; i < parts.length; i++) {
      // strictly in order; only the first part carries the reply
      await _gateway.sendText(
        widget.chat.id,
        parts[i],
        replyTo: i == 0 ? (reply?.id ?? 0) : 0,
      );
    }
    final st = ref.read(settingsProvider);
    if (st.ghostReadOnReply && st.blocksRead(widget.chat.id)) {
      final all =
          ref.read(messagesProvider(widget.chat.id)).value ??
          const <ChatMessage>[];
      final ids = [
        for (final x in all)
          if (!x.outgoing) x.id,
      ];
      if (ids.isNotEmpty) {
        _gateway.markReadManual(
          widget.chat.id,
          ids.skip(ids.length > 100 ? ids.length - 100 : 0).toList(),
        );
      }
    }
  }

  void _toggleEmoji() {
    if (_emojiOpen) {
      setState(() => _emojiOpen = false);
      _focus.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      setState(() => _emojiOpen = true);
    }
  }

  /// Adds / removes a reaction; the reason is shown if the server refuses.
  Future<void> _react(ChatMessage m, String e) async {
    // Only react with what the server says this message accepts.
    if (!(await _gateway.availableReactions(widget.chat.id, m.id))
        .contains(e)) {
      if (mounted) {
        notice(context, friendlyError('reaction not available', ar: context.isAr),
            kind: NoticeKind.error);
      }
      return;
    }
    final live =
        (ref.read(messagesProvider(widget.chat.id)).value ??
                const <ChatMessage>[])
            .where((x) => x.id == m.id)
            .firstOrNull;
    final have = (live ?? m).myReactions.contains(e);
    await _safe(
      () => _gateway.toggleReaction(widget.chat.id, m.id, e, on: !have),
    );
  }

  /// Runs one of the configurable gesture actions on [m].
  Future<void> _gesture(String action, ChatMessage m) async {
    final l = AppLocalizations.of(context);
    final chats = ref.read(chatsProvider).value ?? const <ChatSummary>[];
    switch (action) {
      case 'reply':
        if (widget.chat.canSend && !m.deletedByPeer) {
          setState(() {
            _replyTo = m;
            _editing = null;
          });
          _focus.requestFocus();
        }
      case 'forward':
        if (widget.chat.type != ChatType.secret && !m.deletedByPeer) {
          _pickForward(m, chats);
        }
      case 'translate':
        if (m.text.trim().isNotEmpty) showTranslateSheet(context, m.text);
      case 'copy':
        if (m.text.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: m.text));
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l.copied)));
        }
      case 'react':
        _react(m, ref.read(settingsProvider).quickReaction);
      case 'heart':
        _react(m, '❤️');
      case 'pin':
        final unpin = _pins.any((p) => p.id == m.id);
        await _safe(
          () => _gateway.pinMessage(widget.chat.id, m.id, pin: !unpin),
        );
        await _loadPins();
      case 'select':
        setState(() => _selected.add(m.id));
      case 'delete':
        _confirmDelete(m);
      case 'share':
        _share([m]);
      case 'save':
        await _saveToSaved([m]);
      case 'menu':
        _actions(m);
    }
  }

  Future<void> _saveToSaved(List<ChatMessage> ms) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await _safe(() async {
      final saved = await _gateway.savedMessages();
      if (saved == null) return;
      await _gateway.forwardMessages(saved.id, widget.chat.id, [
        for (final m in ms) m.id,
      ]);
      messenger.showSnackBar(SnackBar(content: Text(l.savedToSaved)));
    });
  }

  void _actions(ChatMessage m) {
    final l = AppLocalizations.of(context);
    final chats = ref.read(chatsProvider).value ?? const <ChatSummary>[];
    Widget item(IconData i, String t, VoidCallback f, {Color? c}) => ListTile(
      leading: SIcon(i, color: c),
      title: Text(t, style: TextStyle(color: c)),
      onTap: () {
        Navigator.of(context).pop();
        f();
      },
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: GlassSurface(
          blur: true,
          radius: 24,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
           child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!m.deletedByPeer)
                SizedBox(
                  height: 52,
                  child: FutureBuilder<List<String>>(
                    future: _gateway.availableReactions(widget.chat.id, m.id),
                    builder: (_, snap) {
                      final list = snap.data ?? const <String>[];
                      if (list.isEmpty) return const SizedBox.shrink();
                      return ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          for (final e in list)
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).pop();
                                _react(m, e);
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: m.myReactions.contains(e)
                                      ? Colors.white24
                                      : null,
                                ),
                                child: Text(
                                  e,
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              if (widget.chat.canSend && !m.deletedByPeer)
                item(
                  Icons.reply,
                  l.reply,
                  () => setState(() {
                    _replyTo = m;
                    _editing = null;
                  }),
                ),
              if (m.text.isNotEmpty)
                item(Icons.copy, l.copy, () {
                  Clipboard.setData(ClipboardData(text: m.text));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l.copied)));
                }),
              if (m.text.trim().isNotEmpty)
                item(Icons.translate, context.t('Translate', 'ترجمة'),
                    () => showTranslateSheet(context, m.text)),
              if (m.outgoing && m.kind == MessageKind.text && !m.deletedByPeer)
                item(Icons.edit_outlined, l.edit, () {
                  setState(() {
                    _editing = m;
                    _replyTo = null;
                    _c.text = m.text;
                  });
                }),
              item(
                Icons.check_circle_outline,
                l.select,
                () => setState(() => _selected.add(m.id)),
              ),
              if (m.sendState == 2)
                item(
                  Icons.refresh,
                  l.resend,
                  () => _safe(() => _gateway.resend(widget.chat.id, m.id)),
                ),
              if (m.file != null)
                item(Icons.download_for_offline_outlined,
                    context.t('Save to device', 'حفظ على الجهاز'), () => _saveDevice(m)),
              if (m.text.isNotEmpty || (m.file?.downloaded ?? false))
                item(Icons.ios_share, l.share, () => _share([m])),
              if (!m.deletedByPeer && widget.chat.type != ChatType.secret)
                item(Icons.shortcut, l.forward, () => _pickForward(m, chats)),
              if (!m.deletedByPeer && widget.chat.type != ChatType.secret)
                item(Icons.forward_to_inbox_outlined,
                    context.t('Forward without author', 'إعادة توجيه بدون اسم المرسل'),
                    () => _pickForward(m, chats, copy: true)),
              if (m.edited)
                item(
                  Icons.history,
                  l.editHistory,
                  () => _showEdits(context, m),
                ),
              if (!m.deletedByPeer &&
                  (widget.chat.type == ChatType.private || widget.chat.canSend))
                item(
                  _pins.any((p) => p.id == m.id)
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  _pins.any((p) => p.id == m.id) ? l.unpin : l.pin,
                  () async {
                    final unpin = _pins.any((p) => p.id == m.id);
                    await _safe(
                      () => _gateway.pinMessage(
                        widget.chat.id,
                        m.id,
                        pin: !unpin,
                      ),
                    );
                    await _loadPins();
                  },
                ),
              if (!m.deletedByPeer)
                item(
                  Icons.bookmark_add_outlined,
                  l.saveToSaved,
                  () => _saveToSaved([m]),
                ),
              item(
                _isStarred(m.id) ? Icons.star : Icons.star_border,
                _isStarred(m.id)
                    ? context.t('Remove star', 'إزالة النجمة')
                    : context.t('Star message', 'تمييز بنجمة'),
                () => _toggleStar(m),
              ),
              if (m.text.isNotEmpty)
                item(Icons.format_quote, context.t('Copy as quote', 'نسخ كاقتباس'), () {
                  Clipboard.setData(ClipboardData(
                      text: m.text.split('\n').map((x) => '> $x').join('\n')));
                  notice(context, l.copied, kind: NoticeKind.success);
                }),
              item(Icons.link, context.t('Copy message link', 'نسخ رابط الرسالة'),
                  () => _copyLink(m)),
              item(Icons.info_outline, context.t('Message info', 'تفاصيل الرسالة'),
                  () => _msgInfo(m)),
              if (!m.outgoing &&
                  ref.read(settingsProvider).blocksRead(widget.chat.id))
                item(Icons.done_all, l.markReadHere, () {
                  final all =
                      ref.read(messagesProvider(widget.chat.id)).value ??
                      const <ChatMessage>[];
                  final ids = [
                    for (final x in all)
                      if (!x.outgoing && x.id <= m.id) x.id,
                  ];
                  _gateway.markReadManual(
                    widget.chat.id,
                    ids.take(100).toList(),
                  );
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l.markedReadMsg)));
                }),
              if (!m.deletedByPeer)
                item(
                  Icons.delete_outline,
                  l.delete,
                  () => _confirmDelete(m),
                  c: GlassTokens.ringDanger,
                ),
            ],
           ),
          ),
        ),
      ),
    );
  }

  /// Downloads first when needed, then saves to the gallery / a chosen folder.
  Future<void> _saveDevice(ChatMessage m) async {
    var cur = m;
    final fid = m.file?.fileId;
    if (fid == null) return;
    try {
      if (!(m.file?.downloaded ?? false)) {
        notice(context, context.t('Downloading…', 'جاري التحميل…'));
        await _gateway.downloadFile(fid);
        for (var i = 0; i < 240; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          final list = ref.read(messagesProvider(widget.chat.id)).value ?? const <ChatMessage>[];
          cur = list.firstWhere((x) => x.id == m.id, orElse: () => cur);
          if (cur.file?.downloaded ?? false) break;
        }
      }
      final ok = await saveToDevice(cur);
      if (mounted) {
        notice(
          context,
          ok
              ? (cur.kind == MessageKind.photo || cur.kind == MessageKind.video
                  ? context.t('Saved to gallery', 'تم الحفظ في المعرض')
                  : context.t('Saved', 'تم الحفظ'))
              : context.t('Could not save', 'تعذر الحفظ'),
          kind: ok ? NoticeKind.success : NoticeKind.error,
        );
      }
    } catch (e) {
      if (mounted) notice(context, friendlyError(e, ar: context.isAr), kind: NoticeKind.error);
    }
  }

  // ---- stars (kept on this phone)
  List<String> get _starRows =>
      ((ref.read(settingsProvider).x['stars'] as List?) ?? const [])
          .map((e) => '$e')
          .toList();

  bool _isStarred(int id) =>
      _starRows.any((r) => r.startsWith('${widget.chat.id}:$id:'));

  void _toggleStar(ChatMessage m) {
    final rows = _starRows;
    final key = '${widget.chat.id}:${m.id}:';
    if (rows.any((r) => r.startsWith(key))) {
      rows.removeWhere((r) => r.startsWith(key));
      notice(context, context.t('Star removed', 'تمت إزالة النجمة'));
    } else {
      final t = m.text.isEmpty ? kindLabel(AppLocalizations.of(context), m.kind) : m.text;
      rows.add('$key${t.replaceAll('\n', ' ').substring(0, t.replaceAll('\n', ' ').length.clamp(0, 80))}');
      notice(context, context.t('Message starred', 'تم تمييز الرسالة'),
          kind: NoticeKind.premium);
    }
    ref.read(settingsProvider.notifier).setX('stars', rows);
  }

  void _showStars() {
    final mine = _starRows.where((r) => r.startsWith('${widget.chat.id}:')).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: mine.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(context.t('No starred messages in this chat',
                      'مفيش رسايل مميزة بنجمة في الشات ده')),
                )
              : ListView(shrinkWrap: true, children: [
                  for (final r in mine)
                    ListTile(
                      leading: const SIcon(Icons.star, color: Color(0xFFFFC53D)),
                      title: Text(r.split(':').skip(2).join(':'),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.pop(context);
                        _jumpTo(int.parse(r.split(':')[1]));
                      },
                    ),
                ]),
        ),
      ),
    );
  }

  Future<void> _copyLink(ChatMessage m) async {
    try {
      final r = await _gateway.tdRaw({
        '@type': 'getMessageLink',
        'chat_id': widget.chat.id,
        'message_id': m.id,
        'media_timestamp': 0,
        'for_album': false,
        'in_message_thread': false,
      });
      await Clipboard.setData(ClipboardData(text: '${r['link']}'));
      if (mounted) {
        notice(context, context.t('Link copied', 'تم نسخ الرابط'), kind: NoticeKind.success);
      }
    } catch (e) {
      if (mounted) {
        notice(
            context,
            context.t('Links only work for groups and channels with a username',
                'الروابط بتشتغل بس مع الجروبات والقنوات اللي ليها يوزر'),
            kind: NoticeKind.error);
      }
    }
  }

  void _msgInfo(ChatMessage m) {
    final t = m.time;
    String two(int v) => v.toString().padLeft(2, '0');
    final rows = <(String, String)>[
      (context.t('Sent', 'اتبعتت'),
          '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}'),
      (context.t('Message ID', 'رقم الرسالة'), '${m.id}'),
      (context.t('Direction', 'الاتجاه'),
          m.outgoing ? context.t('Outgoing', 'صادرة') : context.t('Incoming', 'واردة')),
      if (m.edited) (context.t('Edited', 'معدّلة'), context.t('Yes', 'نعم')),
      if (m.file != null) (context.t('File size', 'حجم الملف'), '${m.file!.size} B'),
      if (m.text.isNotEmpty) (context.t('Characters', 'عدد الحروف'), '${m.text.length}'),
    ];
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (k, v) in rows)
            ListTile(dense: true, title: Text(k), trailing: Text(v)),
        ]),
      ),
    );
  }

  Future<void> _jumpToDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2013),
      lastDate: DateTime.now(),
    );
    if (d == null) return;
    await _safe(() async {
      final r = await _gateway.tdRaw({
        '@type': 'getChatMessageByDate',
        'chat_id': widget.chat.id,
        'date': d.millisecondsSinceEpoch ~/ 1000,
      });
      await _jumpTo((r['id'] as num).toInt());
    });
  }

  Future<void> _autoDelete() async {
    final secs = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              title: Text(context.t('Auto-delete messages', 'حذف الرسايل تلقائيًا'))),
          for (final (v, label) in [
            (0, context.t('Off', 'مقفول')),
            (86400, context.t('After 1 day', 'بعد يوم')),
            (604800, context.t('After 1 week', 'بعد أسبوع')),
            (2678400, context.t('After 1 month', 'بعد شهر')),
          ])
            ListTile(title: Text(label), onTap: () => Navigator.pop(context, v)),
        ]),
      ),
    );
    if (secs == null) return;
    await _safe(() async {
      await _gateway.tdRaw({
        '@type': 'setChatMessageAutoDeleteTime',
        'chat_id': widget.chat.id,
        'message_auto_delete_time': secs,
      });
      if (mounted) {
        notice(context, context.t('Timer updated', 'تم تحديث المؤقت'), kind: NoticeKind.success);
      }
    });
  }

  Future<void> _deleteMine() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.t('Delete all my messages?', 'حذف كل رسايلي؟')),
        content: Text(context.t(
            'Every message you sent in this chat will be deleted for everyone where possible.',
            'كل الرسايل اللي بعتّها في الشات ده هتتحذف للجميع لو متاح.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.t('Cancel', 'إلغاء'))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.t('Delete', 'حذف'),
                  style: const TextStyle(color: GlassTokens.ringDanger))),
        ],
      ),
    );
    if (ok != true) return;
    await _safe(() async {
      final me = await _gateway.tdRaw({'@type': 'getMe'});
      var total = 0;
      for (var round = 0; round < 50; round++) {
        final r = await _gateway.tdRaw({
          '@type': 'searchChatMessages',
          'chat_id': widget.chat.id,
          'query': '',
          'sender_id': {'@type': 'messageSenderUser', 'user_id': me['id']},
          'from_message_id': 0,
          'offset': 0,
          'limit': 100,
        });
        final ids = [
          for (final x in (r['messages'] as List? ?? const []).whereType<Map>())
            (x['id'] as num).toInt(),
        ];
        if (ids.isEmpty) break;
        await _gateway.tdRaw({
          '@type': 'deleteMessages',
          'chat_id': widget.chat.id,
          'message_ids': ids,
          'revoke': true,
        });
        total += ids.length;
      }
      if (mounted) {
        notice(context, context.t('Deleted $total messages', 'تم حذف $total رسالة'),
            kind: NoticeKind.success);
      }
    });
  }

  Future<void> _share(List<ChatMessage> ms) async {
    final files = [
      for (final m in ms)
        if (m.file?.downloaded == true && m.file!.localPath != null)
          XFile(m.file!.localPath!),
    ];
    final text = ms.map((m) => m.text).where((t) => t.isNotEmpty).join('\n');
    await SharePlus.instance.share(
      ShareParams(
        text: text.isEmpty ? null : text,
        files: files.isEmpty ? null : files,
      ),
    );
  }

  List<ChatMessage> _selectedMessages() {
    final all =
        ref.read(messagesProvider(widget.chat.id)).value ??
        const <ChatMessage>[];
    return [
      for (final m in all)
        if (_selected.contains(m.id)) m,
    ]..sort((a, b) => a.id.compareTo(b.id));
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
            child: Text(l.deleteForMe),
          ),
          if (mine || widget.chat.type == ChatType.private)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 2),
              child: Text(l.deleteForAll),
            ),
        ],
      ),
    );
    if (choice == null) return;
    setState(_selected.clear);
    await _safe(
      () => _gateway.deleteMessages(widget.chat.id, ids, forAll: choice == 2),
    );
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    l.forwardTo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final c in chats)
                        if (c.canSend)
                          ListTile(
                            leading: AvatarCircle(
                              title: c.title,
                              photo: c.avatar,
                              size: 40,
                            ),
                            title: Text(c.title),
                            onTap: () {
                              Navigator.of(context).pop();
                              _gateway.forwardMessages(c.id, widget.chat.id, [
                                for (final m in ms) m.id,
                              ]);
                              setState(_selected.clear);
                            },
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pickForward(ChatMessage m, List<ChatSummary> chats, {bool copy = false}) {
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    l.forwardTo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final c in chats)
                        if (c.canSend)
                          ListTile(
                            leading: AvatarCircle(
                              title: c.title,
                              photo: c.avatar,
                              size: 40,
                            ),
                            title: Text(c.title),
                            onTap: () {
                              Navigator.of(context).pop();
                              if (copy) {
                                _safe(() => _gateway.tdRaw({
                                      '@type': 'forwardMessages',
                                      'chat_id': c.id,
                                      'from_chat_id': widget.chat.id,
                                      'message_ids': [m.id],
                                      'send_copy': true,
                                      'remove_caption': false,
                                    }));
                              } else {
                                _gateway.forwardMessages(c.id, widget.chat.id, [
                                  m.id,
                                ]);
                              }
                            },
                          ),
                    ],
                  ),
                ),
              ],
            ),
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
            child: Text(l.deleteForMe),
          ),
          if (m.outgoing || widget.chat.type == ChatType.private)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 2),
              child: Text(l.deleteForAll),
            ),
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
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: Center(
              child: InteractiveViewer(child: Image.file(File(f.localPath!))),
            ),
          ),
        ),
      );
    } else {
      OpenFilex.open(f.localPath!);
    }
  }

  Future<void> _openInfo() async {
    final r = await Navigator.of(context).push<InfoResult>(
      MaterialPageRoute(builder: (_) => ChatInfoScreen(chat: widget.chat)),
    );
    if (!mounted) return;
    if (r is InfoSearch) {
      setState(() {
        _searching = true;
        _hits = null;
      });
    } else if (r is InfoJump) {
      _jumpTo(r.messageId);
    }
  }

  ChatSummary get _liveChat =>
      ref
          .read(chatsProvider)
          .value
          ?.where((c) => c.id == widget.chat.id)
          .firstOrNull ??
      widget.chat;

  Widget _moreMenu(AppLocalizations l) {
    final chat = _liveChat;
    final s = ref.watch(settingsProvider);
    final isPrivate = chat.type == ChatType.private;
    final hidden = s.hiddenChats.contains(chat.id);
    PopupMenuItem<String> item(
      String v,
      IconData i,
      String t, {
      bool danger = false,
    }) => PopupMenuItem(
      value: v,
      child: Row(
        children: [
          SIcon(i, size: 20, color: danger ? GlassTokens.ringDanger : null),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              t,
              style: danger
                  ? const TextStyle(color: GlassTokens.ringDanger)
                  : null,
            ),
          ),
        ],
      ),
    );
    return PopupMenuButton<String>(
      tooltip: l.more,
      icon: const SIcon(Icons.more_vert),
      onSelected: (v) async {
        final sc = ref.read(settingsProvider.notifier);
        switch (v) {
          case 'info':
            _openInfo();
          case 'search':
            setState(() {
              _searching = true;
              _hits = null;
            });
          case 'mute':
            if (chat.muted) {
              _gateway.setMuted(chat.id, false);
            } else {
              _muteFor(chat.id);
            }
          case 'scheduled':
            _showScheduled();
          case 'media':
            _openInfo();
          case 'pin':
            sc.togglePin(chat.id);
          case 'hide':
            sc.setHidden(chat.id, !hidden);
          case 'archive':
            _gateway.setArchived(chat.id, true);
            if (mounted) Navigator.of(context).pop();
          case 'unread':
            _gateway.markUnread(chat.id, true);
            if (mounted) Navigator.of(context).pop();
          case 'read':
            _gateway.markChatRead(chat.id);
          case 'options':
            showChatActions(context, ref, chat);
          case 'ghost':
            _ghostSheet();
          case 'top':
            if (_scroll.hasClients) {
              _scroll.animateTo(_scroll.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut);
            }
          case 'bottom':
            if (_scroll.hasClients) {
              _scroll.animateTo(0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut);
            }
          case 'stars':
            _showStars();
          case 'jumpdate':
            _jumpToDate();
          case 'autodel':
            _autoDelete();
          case 'delmine':
            _deleteMine();
          case 'copyid':
            await Clipboard.setData(ClipboardData(text: '${chat.id}'));
          case 'clear':
            runChatDanger(context, ref, chat, ChatDanger.clear);
          case 'block':
            runChatDanger(context, ref, chat, ChatDanger.block);
          case 'leave':
            final nav = Navigator.of(context);
            final ok = await runChatDanger(
              context,
              ref,
              chat,
              ChatDanger.leave,
            );
            if (ok) nav.pop();
        }
      },
      itemBuilder: (_) => [
        item('info', Icons.account_circle_outlined, l.menuProfile),
        item('search', Icons.search, l.searchInChat),
        item('media', Icons.perm_media_outlined, l.menuMedia),
        item(
          'mute',
          chat.muted
              ? Icons.notifications_outlined
              : Icons.notifications_off_outlined,
          chat.muted ? l.unmute : l.mute,
        ),
        item('scheduled', Icons.schedule_send_outlined, l.scheduledMessages),
        item(
          'pin',
          s.pinned.contains(chat.id) ? Icons.push_pin : Icons.push_pin_outlined,
          s.pinned.contains(chat.id) ? l.unpin : l.pin,
        ),
        item(
          'hide',
          hidden ? Icons.lock_open : Icons.lock_outline,
          hidden ? l.unhideChat : l.hideChat,
        ),
        item('read', Icons.done_all, context.t('Mark all as read', 'تعليم الكل كمقروء')),
        item('unread', Icons.mark_chat_unread_outlined, l.markUnread),
        item('top', Icons.vertical_align_top, context.t('Jump to oldest', 'الرجوع لأقدم رسالة')),
        item('bottom', Icons.vertical_align_bottom, context.t('Jump to latest', 'النزول لآخر رسالة')),
        item('ghost', Icons.visibility_off_outlined, context.t('Ghost for this chat', 'الشبح للشات ده')),
        item('options', Icons.tune, context.t('Chat options', 'خيارات الشات')),
        item('stars', Icons.star_border, context.t('Starred messages', 'الرسايل المميزة')),
        item('jumpdate', Icons.event, context.t('Jump to date', 'الذهاب لتاريخ')),
        item('autodel', Icons.timer_outlined, context.t('Auto-delete timer', 'مؤقت الحذف التلقائي')),
        item('delmine', Icons.delete_sweep_outlined, context.t('Delete all my messages', 'حذف كل رسايلي'), danger: true),
        item('copyid', Icons.tag, context.t('Copy chat ID', 'نسخ معرّف الشات')),
        item('archive', Icons.archive_outlined, l.archiveChat),
        const PopupMenuDivider(),
        item(
          'clear',
          Icons.cleaning_services_outlined,
          l.clearHistory,
          danger: true,
        ),
        if (isPrivate) item('block', Icons.block, l.blockUser, danger: true),
        item(
          'leave',
          Icons.delete_outline,
          isPrivate || chat.type == ChatType.secret
              ? l.deleteChat
              : l.leaveChat,
          danger: true,
        ),
      ],
    );
  }

  /// The eye button: per-chat Ghost controls.
  void _ghostSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Consumer(
        builder: (sctx, ref, _) {
          final l = AppLocalizations.of(sctx);
          final s = ref.watch(settingsProvider);
          final c = ref.read(settingsProvider.notifier);
          final id = widget.chat.id;
          final override = s.ghostOverrides[id];
          return Padding(
            padding: const EdgeInsets.all(12),
            child: GlassSurface(
              blur: true,
              radius: 28,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const SIcon(
                            Icons.visibility_off_outlined,
                            color: GlassTokens.ghost,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l.chatControls,
                              style: Theme.of(sctx).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(value: 0, label: Text(l.ghostFollow)),
                          ButtonSegment(value: 1, label: Text(l.ghostOnShort)),
                          ButtonSegment(value: 2, label: Text(l.ghostOffShort)),
                        ],
                        selected: {override == null ? 0 : (override ? 1 : 2)},
                        onSelectionChanged: (v) => c.setGhostOverride(
                          id,
                          v.first == 0 ? null : v.first == 1,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      title: Text(l.ghostReadReceipts),
                      value: s.chatHidesRead(id) ?? s.ghostRead,
                      onChanged: (v) => c.setChatGhostPart(id, 'read', v),
                    ),
                    SwitchListTile(
                      title: Text(l.ghostTypingT),
                      value: s.chatHidesTyping(id) ?? s.ghostTyping,
                      onChanged: (v) => c.setChatGhostPart(id, 'typing', v),
                    ),
                    ListTile(
                      leading: const SIcon(Icons.restart_alt),
                      title: Text(l.ghostResetChat),
                      onTap: () {
                        c.setGhostOverride(id, null);
                        c.setChatGhostPart(id, 'read', null);
                        c.setChatGhostPart(id, 'typing', null);
                      },
                    ),
                    ListTile(
                      leading: const SIcon(Icons.tune),
                      title: Text(l.ghostSettings),
                      onTap: () {
                        Navigator.pop(sctx);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const GhostScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _statusText(AppLocalizations l, ChatStatus s) =>
      chatStatusText(l, s, widget.chat.type);

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
              Text(
                l.editHistory,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (edits.isEmpty) Text(l.noEdits),
              for (final e in edits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    e.oldText,
                    style: const TextStyle(color: GlassTokens.textSecondary),
                  ),
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
    final wall =
        wallpapers[ref
            .watch(settingsProvider)
            .wallpaper
            .clamp(0, wallpapers.length - 1)];
    return PopScope(
      canPop: !_emojiOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _emojiOpen = false);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: wall),
          child: SafeArea(
            child: Column(
              children: [
                const ConnectionBanner(),
                const MiniPlayer(),
                if (_fxBusy)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(context.t('Changing voice…', 'بيغيّر الصوت…'),
                        style: const TextStyle(fontSize: 12, color: GlassTokens.textSecondary)),
                  ),
                if (_selected.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: GlassSurface(
                      blur: ref.watch(settingsProvider).hdrStyle == 'glass',
                      radius: 22,
                      fill: switch (ref.watch(settingsProvider).hdrStyle) {
                        'solid' => 0.34,
                        'transparent' => 0.0,
                        _ => GlassTokens.fill,
                      },
                      border: ref.watch(settingsProvider).hdrStyle == 'transparent'
                          ? 0
                          : GlassTokens.border,
                      padding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: ref.watch(settingsProvider).hdrCompact ? 0 : 4,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const SIcon(Icons.close),
                            onPressed: () => setState(_selected.clear),
                          ),
                          Expanded(
                            child: Text(l.selectedCount('${_selected.length}')),
                          ),
                          IconButton(
                            icon: const SIcon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text: _selectedMessages()
                                      .map((m) => m.text)
                                      .join('\n'),
                                ),
                              );
                              setState(_selected.clear);
                            },
                          ),
                          IconButton(
                            icon: const SIcon(Icons.ios_share),
                            onPressed: () => _share(_selectedMessages()),
                          ),
                          if (widget.chat.type != ChatType.secret)
                            IconButton(
                              icon: const SIcon(Icons.shortcut),
                              onPressed: _forwardSelected,
                            ),
                          IconButton(
                            icon: const SIcon(
                              Icons.delete_outline,
                              color: GlassTokens.ringDanger,
                            ),
                            onPressed: _deleteSelected,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: GlassSurface(
                      blur: true,
                      radius: 22,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: l.back,
                            icon: const BackButtonIcon(),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _openInfo,
                              child: Row(
                                children: [
                                  if (ref.watch(settingsProvider).hdrAvatar) ...[
                                    AvatarCircle(
                                      title: widget.chat.title,
                                      photo: widget.chat.avatar,
                                      chatId: widget.chat.id,
                                      shape: ref
                                          .watch(settingsProvider)
                                          .chatAvatarShape,
                                      size: ref.watch(settingsProvider).hdrAvatarSize,
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          ref.watch(settingsProvider).hdrCenter
                                              ? CrossAxisAlignment.center
                                              : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ref
                                                  .watch(settingsProvider)
                                                  .aliases[widget.chat.id] ??
                                              widget.chat.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: ref.watch(settingsProvider).hdrBold
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: ref.watch(settingsProvider).hdrNameSize,
                                          ),
                                        ),
                                        if (ref.watch(settingsProvider).hdrStatus)
                                        StreamBuilder<ChatStatus>(
                                          stream: _gateway.watchChatStatus(
                                            widget.chat.id,
                                          ),
                                          initialData: ChatStatus.none,
                                          builder: (_, snap) {
                                            final t = _statusText(
                                              l,
                                              snap.data ?? ChatStatus.none,
                                            );
                                            return t.isEmpty
                                                ? const SizedBox.shrink()
                                                : Text(
                                                    t,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          (snap.data?.typing ??
                                                              false)
                                                          ? GlassScope.of(
                                                              context,
                                                            ).accent
                                                          : GlassTokens
                                                                .textSecondary,
                                                    ),
                                                  );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (ref.watch(settingsProvider).hdrGhost)
                          Tooltip(
                            message: l.chatControls,
                            child: IconButton(
                              icon: SIcon(
                                ghost
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: ghost
                                    ? GlassTokens.ghost
                                    : Colors.white54,
                              ),
                              onPressed: _ghostSheet,
                            ),
                          ),
                          _moreMenu(l),
                        ],
                      ),
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
                    onTap: _pinBarTap,
                    onLongPress: _pinMenu,
                    child: Padding(
                      key: _pinBarKey,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: GlassSurface(
                        radius: 14,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            const SIcon(Icons.push_pin, size: 16),
                            const SizedBox(width: 8),
                            if (_pins.length > 1)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: 8,
                                ),
                                child: Text(
                                  '${(_pinIdx % _pins.length) + 1}/${_pins.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: GlassScope.of(context).accent,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                _pinned!.text.isNotEmpty
                                    ? _pinned!.text
                                    : kindLabel(l, _pinned!.kind),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            if (_pins.length > 1)
                              const SIcon(Icons.keyboard_arrow_down, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (ghost)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      l.silentRead,
                      style: const TextStyle(
                        fontSize: 12,
                        color: GlassTokens.ghost,
                      ),
                    ),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: msgs.when(
                          loading: () => Center(child: Text(l.connecting)),
                          error: (e, _) => Center(child: Text(l.errorGeneric)),
                          data: (list0) {
                            final list = _searching && _hits != null
                                ? _hits!
                                : list0;
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _maybeMarkRead(list0),
                            );
                            if (list.isEmpty) {
                              return Center(child: Text(l.noMessages));
                            }
                            final byId = {for (final m in list) m.id: m};
                            return ListView.builder(
                              controller: _scroll,
                              reverse: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              itemCount: list.length,
                              itemBuilder: (_, i) {
                                final m = list[i];
                                final older = i + 1 < list.length
                                    ? list[i + 1]
                                    : null;
                                final newDay =
                                    older == null ||
                                    older.time.day != m.time.day ||
                                    older.time.month != m.time.month ||
                                    older.time.year != m.time.year;
                                return Column(
                                  children: [
                                    if (newDay &&
                                        ref
                                            .read(settingsProvider)
                                            .chatDateChips)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          _dayLabel(l, m.time),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: GlassTokens.textSecondary,
                                          ),
                                        ),
                                      ),
                                    KeyedSubtree(
                                      key: _keys.putIfAbsent(
                                        m.id,
                                        GlobalKey.new,
                                      ),
                                      child: _SwipeToAct(
                                        enabled: _selected.isEmpty,
                                        right: ref
                                            .read(settingsProvider)
                                            .swipeRight,
                                        left: ref
                                            .read(settingsProvider)
                                            .swipeLeft,
                                        onAction: (a) => _gesture(a, m),
                                        child: _Bubble(
                                          m: m,
                                          radius: ref
                                              .read(settingsProvider)
                                              .bubbleRadius,
                                          ps: ref.read(settingsProvider),
                                          onDoubleTap: () => _gesture(
                                            ref
                                                .read(settingsProvider)
                                                .doubleTap,
                                            m,
                                          ),
                                          onJump: () => _jumpTo(m.replyToId),
                                          showSender:
                                              widget.chat.type ==
                                                  ChatType.group &&
                                              !m.outgoing,
                                          replied: m.replyToId != 0
                                              ? (byId[m.replyToId] ?? _replyFor(m.replyToId))
                                              : null,
                                          forwardLabel: _forwardLabel(
                                            l,
                                            m.forwardedFrom,
                                          ),
                                          onDownload: (id) =>
                                              _gateway.downloadFile(id),
                                          onCancel: (id) =>
                                              _gateway.cancelDownload(id),
                                          onOpen: () => _openMedia(m),
                                          onVote: (ids) => _gateway.votePoll(
                                            widget.chat.id,
                                            m.id,
                                            ids,
                                          ),
                                          onLongPress: () => _actions(m),
                                          selected:
                                              _selected.contains(m.id) ||
                                              _highlight == m.id,
                                          selecting: _selected.isNotEmpty,
                                          onTapSelect: () => setState(() {
                                            _selected.contains(m.id)
                                                ? _selected.remove(m.id)
                                                : _selected.add(m.id);
                                          }),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                      if (_showJump)
                        PositionedDirectional(
                          end: 12,
                          bottom: 12,
                          child: FloatingActionButton.small(
                            tooltip: l.jumpToLatest,
                            onPressed: () => _scroll.animateTo(
                              0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            ),
                            child: const SIcon(Icons.keyboard_arrow_down),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                  child: Column(
                    children: [
                      if (_parts > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            l.splitNotice('$_parts'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: GlassTokens.textSecondary,
                            ),
                          ),
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
                                    avatar: AvatarCircle(
                                      title: c.name,
                                      size: 24,
                                    ),
                                    label: Text(
                                      c.name.isEmpty
                                          ? '@${c.username}'
                                          : c.name,
                                    ),
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
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                SIcon(
                                  _editing != null ? Icons.edit : Icons.reply,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_editing != null ? l.editingMessage : l.replyingTo}: ${(_editing ?? _replyTo)!.text}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                IconButton(
                                  icon: const SIcon(Icons.close, size: 18),
                                  onPressed: () => setState(() {
                                    if (_editing != null) _c.clear();
                                    _editing = null;
                                    _replyTo = null;
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (widget.chat.canSend &&
                          !_recording &&
                          _focus.hasFocus &&
                          !_c.selection.isCollapsed)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FormatBar(controller: _c),
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
                            horizontal: 14,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              if (!_recording)
                                IconButton(
                                  tooltip: l.attach,
                                  icon: const SIcon(Icons.attach_file),
                                  onPressed: _attachSheet,
                                ),
                              if (!_recording)
                                IconButton(
                                  tooltip: l.stickers,
                                  icon: SIcon(
                                    _emojiOpen
                                        ? Icons.keyboard_alt_outlined
                                        : Icons.emoji_emotions_outlined,
                                  ),
                                  onPressed: _toggleEmoji,
                                ),
                              if (!_recording)
                                Expanded(
                                  child: TextField(
                                    controller: _c,
                                    focusNode: _focus,
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
                                )
                              else
                                Expanded(
                                  child: Row(
                                    children: [
                                      if (_recLocked)
                                        IconButton(
                                          icon: const SIcon(
                                            Icons.delete_outline,
                                            color: GlassTokens.ringDanger,
                                          ),
                                          onPressed: () =>
                                              _stopRecording(send: false),
                                        )
                                      else
                                        const SizedBox(width: 12),
                                      const SIcon(
                                        Icons.fiber_manual_record,
                                        size: 14,
                                        color: GlassTokens.ringDanger,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_recSeconds ~/ 60}:${(_recSeconds % 60).toString().padLeft(2, '0')}',
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _recLocked
                                              ? l.recordingLocked
                                              : _recCancel
                                              ? l.releaseToCancel
                                              : l.slideToCancel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: _recCancel
                                                ? GlassTokens.ringDanger
                                                : GlassTokens.textSecondary,
                                          ),
                                        ),
                                      ),
                                      if (!_recLocked)
                                        const SIcon(
                                          Icons.lock_outline,
                                          size: 16,
                                          color: GlassTokens.textSecondary,
                                        ),
                                    ],
                                  ),
                                ),
                              if (_recLocked)
                                IconButton(
                                  tooltip: l.send,
                                  icon: const SIcon(Icons.send_rounded),
                                  onPressed: () => _stopRecording(send: true),
                                )
                              else if (_c.text.trim().isEmpty &&
                                  _editing == null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!_recording)
                                      IconButton(
                                        tooltip: context.t('Voice changer', 'مغيّر الصوت'),
                                        onPressed: _fxSheet,
                                        icon: SIcon(
                                          Icons.graphic_eq,
                                          color: voiceFxFrom(ref.watch(settingsProvider).voiceFx) ==
                                                  VoiceFx.none
                                              ? null
                                              : GlassScope.of(context).accent,
                                        ),
                                      ),
                                    GestureDetector(
                                  key: const ValueKey('mic'),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        SnackBar(
                                          content: Text(l.holdToRecord),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      ),
                                  onLongPressStart: (_) => _micDown(),
                                  onLongPressMoveUpdate: _micMove,
                                  onLongPressEnd: (_) => _micUp(),
                                  onLongPressCancel: () => _micUp(cancel: true),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: _recording ? 54 : 44,
                                    height: _recording ? 54 : 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _recording
                                          ? (_recCancel
                                                ? GlassTokens.ringDanger
                                                : GlassScope.of(context).accent)
                                          : Colors.transparent,
                                    ),
                                    child: SIcon(
                                      _recording ? Icons.mic : Icons.mic_none,
                                    ),
                                  ),
                                ),
                                  ],
                                )
                              else
                                GestureDetector(
                                  onLongPress: _scheduleSend,
                                  child: IconButton(
                                    tooltip: l.send,
                                    icon: const SIcon(Icons.send_rounded),
                                    onPressed: () => _safe(_send),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (_emojiOpen && widget.chat.canSend)
                        SizedBox(
                          height: 300,
                          child: EmojiPanel(
                            gw: _gateway,
                            controller: _c,
                            onChanged: () {
                              if (mounted) setState(() {});
                            },
                            onPick: (st) {
                              setState(() => _emojiOpen = false);
                              _safe(
                                () => st.gif
                                    ? _gateway.sendGif(widget.chat.id, st)
                                    : _gateway.sendSticker(widget.chat.id, st),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
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
    this.onDoubleTap,
    this.radius = 18,
    this.ps = const AppSettings(),
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
  final VoidCallback? onDoubleTap;
  final double radius;
  final AppSettings ps;
  final bool selected;
  final bool selecting;

  BoxDecoration _decoration(Color accent) {
    final r = Radius.circular(radius);
    const tail = Radius.circular(4);
    final shape = ps.chatTail
        ? BorderRadiusDirectional.only(
            topStart: r,
            topEnd: r,
            bottomStart: m.outgoing ? r : tail,
            bottomEnd: m.outgoing ? tail : r,
          )
        : BorderRadiusDirectional.circular(radius);
    final line = selected
        ? accent
        : m.deletedByPeer
        ? GlassTokens.ringDanger.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: GlassTokens.border);
    final bw = selected ? 2.5 : 1.0;
    switch (ps.bubbleStyle) {
      case 'solid':
        return BoxDecoration(
          borderRadius: shape,
          color: m.outgoing
              ? accent.withValues(alpha: .9)
              : const Color(0xFF1F2745),
          border: Border.all(
            width: bw,
            color: selected ? accent : Colors.transparent,
          ),
        );
      case 'gradient':
        return BoxDecoration(
          borderRadius: shape,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: m.outgoing
                ? [accent.withValues(alpha: .75), accent.withValues(alpha: .35)]
                : [
                    Colors.white.withValues(alpha: .16),
                    Colors.white.withValues(alpha: .04),
                  ],
          ),
          border: Border.all(width: bw, color: line),
        );
      case 'outline':
        return BoxDecoration(
          borderRadius: shape,
          border: Border.all(
            width: selected ? 2.5 : 1.4,
            color: selected ? accent : (m.outgoing ? accent : Colors.white38),
          ),
        );
      default:
        return BoxDecoration(
          borderRadius: shape,
          color: m.outgoing
              ? accent.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: GlassTokens.fill),
          border: Border.all(width: bw, color: line),
        );
    }
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accent = GlassScope.of(context).accent;
    final isVisual =
        m.kind == MessageKind.photo ||
        m.kind == MessageKind.sticker ||
        m.kind == MessageKind.video;
    String? previewPath;
    for (final a in [m.thumb, if (m.kind == MessageKind.photo) m.file]) {
      final lp = a?.localPath;
      if (a != null && lp != null && lp.isNotEmpty && (a.downloaded || File(lp).existsSync() && File(lp).lengthSync() > 0)) {
        previewPath = lp;
        break;
      }
    }
    final contact = contactOf(m);
    final locData = m.loc ?? (m.kind == MessageKind.other ? parseLocation(m.text) : null);
    final showText = contact == null &&
        locData == null &&
        (m.text.isNotEmpty || (m.file == null && !isVisual));
    final text = m.text.isNotEmpty ? m.text : kindLabel(l, m.kind);
    final sticker = m.kind == MessageKind.sticker;
    return Align(
      alignment: m.outgoing
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: GestureDetector(
        onTap: selecting ? onTapSelect : null,
        onDoubleTap: selecting ? null : onDoubleTap,
        onLongPress: selecting ? onTapSelect : onLongPress,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: ps.chatSpacing * 0.75),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: sticker
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: sticker ? null : _decoration(accent),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                MediaQuery.of(context).textScaler.scale(1) * ps.chatFontScale,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSender && ps.chatShowNames && m.senderName.isNotEmpty)
                  Text(
                    m.senderName,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                if (forwardLabel != null)
                  Text(
                    forwardLabel!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: GlassTokens.ghost,
                    ),
                  ),
                if (m.replyToId != 0)
                  GestureDetector(
                    onTap: onJump,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4, top: 2),
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      decoration: BoxDecoration(
                        border: BorderDirectional(
                          start: BorderSide(color: accent, width: 2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (replied != null)
                            Text(
                              replied!.outgoing
                                  ? context.t('You', 'أنت')
                                  : (replied!.senderName.isNotEmpty ? replied!.senderName : ''),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          Text(
                            replied == null
                                ? '…'
                                : (replied!.text.isNotEmpty
                                      ? replied!.text
                                      : kindLabel(l, replied!.kind)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: GlassTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isVisual)
                  GestureDetector(
                    onTap: onOpen,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(sticker ? 0 : 12),
                      child:
                          (sticker &&
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
                          ? TgsView(path: m.file!.localPath!, emoji: m.emoji)
                          : previewPath != null
                          ? Image.file(
                              File(previewPath),
                              width: sticker ? 150 : 220,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox(width: 150, height: 100),
                            )
                          : SizedBox(
                              width: sticker ? 120 : 220,
                              height: sticker ? 120 : 160,
                              child: Stack(fit: StackFit.expand, children: [
                                if (m.mini != null && !sticker)
                                  Image.memory(m.mini!,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                      filterQuality: FilterQuality.low),
                                if (m.kind == MessageKind.video &&
                                    m.file?.localPath != null &&
                                    File(m.file!.localPath!).existsSync())
                                  _VideoFrame(path: m.file!.localPath!),
                                Center(
                                  child: sticker && m.emoji.isNotEmpty
                                      ? Text(
                                          m.emoji,
                                          style: const TextStyle(fontSize: 56),
                                        )
                                      : (m.mini != null ||
                                              (m.kind == MessageKind.video &&
                                                  m.file?.localPath != null))
                                          ? Icon(
                                              m.kind == MessageKind.video
                                                  ? Icons.play_circle_fill
                                                  : Icons.image_outlined,
                                              size: 40,
                                              color: Colors.white70,
                                            )
                                          : (m.sendState == 1
                                              ? const CircularProgressIndicator(strokeWidth: 2)
                                              : Text(l.photoLoading)),
                                ),
                              ]),
                            ),
                    ),
                  ),
                if (showText && !(sticker && m.text.isEmpty))
                  (m.kind == MessageKind.text && _emojiOnly(m.text))
                      ? Text(m.text, style: const TextStyle(fontSize: 46))
                      : _body(m, text, accent),
                if (m.file != null && m.kind == MessageKind.voice)
                  VoicePlayer(
                    title: m.outgoing
                        ? context.t('You', 'أنت')
                        : (m.senderName.isEmpty ? context.t('Voice message', 'رسالة صوتية') : m.senderName),
                    file: m.file!,
                    onDownload: () => onDownload(m.file!.fileId),
                  )
                else if (m.file != null && !isVisual)
                  FileCard(
                    file: m.file!,
                    onDownload: () => onDownload(m.file!.fileId),
                    onCancel: () => onCancel(m.file!.fileId),
                  ),
                if (contact != null) ContactCardView(card: contact),
                if (locData != null) LocationCard(m: m),
                if (m.poll != null)
                  _PollView(poll: m.poll!, onVote: (ids) => onVote(ids)),
                if (m.link != null)
                  GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse(m.link!.url),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      decoration: BoxDecoration(
                        border: BorderDirectional(
                          start: BorderSide(color: accent, width: 2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (m.link!.site.isNotEmpty)
                            Text(
                              m.link!.site,
                              style: TextStyle(fontSize: 12, color: accent),
                            ),
                          if (m.link!.title.isNotEmpty)
                            Text(
                              m.link!.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          if (m.link!.description.isNotEmpty)
                            Text(
                              m.link!.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: GlassTokens.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (m.reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final e in m.reactions.entries)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: m.myReactions.contains(e.key)
                                  ? accent.withValues(alpha: 0.5)
                                  : Colors.white12,
                            ),
                            child: Text(
                              '${e.key} ${e.value}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (m.deletedByPeer || m.edited)
                        Flexible(
                          child: Text(
                            '${[if (m.deletedByPeer) l.deletedByPeer, if (m.edited) l.edited].join(' · ')}  ',
                            style: const TextStyle(
                              fontSize: 11,
                              color: GlassTokens.textTertiary,
                            ),
                          ),
                        ),
                      if (ps.chatShowTime)
                        Text(
                          _hm(m.time),
                          style: const TextStyle(
                            fontSize: 11,
                            color: GlassTokens.textTertiary,
                          ),
                        ),
                      if (m.outgoing && ps.chatShowTicks) ...[
                        const SizedBox(width: 3),
                        SIcon(
                          m.sendState == 2
                              ? Icons.error_outline
                              : m.sendState == 1
                              ? Icons.schedule
                              : (m.read ? Icons.done_all : Icons.done),
                          size: 14,
                          color: m.sendState == 2
                              ? GlassTokens.ringDanger
                              : (m.read ? accent : GlassTokens.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Looping, muted WebM sticker.
/// First frame of a local video, used while no thumbnail exists yet.
class _VideoFrame extends StatefulWidget {
  const _VideoFrame({required this.path});
  final String path;

  @override
  State<_VideoFrame> createState() => _VideoFrameState();
}

class _VideoFrameState extends State<_VideoFrame> {
  VideoPlayerController? _c;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.file(File(widget.path));
    _c = c;
    c.setVolume(0);
    c.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null || !c.value.isInitialized) return const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
      ),
    );
  }
}

class _WebmSticker extends StatefulWidget {
  const _WebmSticker({required this.path});
  final String path;

  @override
  State<_WebmSticker> createState() => _WebmStickerState();
}

class _WebmStickerState extends State<_WebmSticker> {
  late final VideoPlayerController _c =
      VideoPlayerController.file(File(widget.path))
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
Widget _body(ChatMessage m, String text, Color accent) {
  var t = text;
  var ents = m.ents;
  if (ents.isEmpty && text.contains('`')) {
    final p = parseCode(text);
    t = p.text;
    ents = p.ents;
  }
  if (ents.isEmpty) {
    return _LinkText(text: t, color: accent);
  }
  final parts = codeAwareBody(
    t,
    ents,
    (piece, inline) => _LinkText(text: piece, color: accent, inline: inline),
  );
  if (parts.isEmpty) return _LinkText(text: t, color: accent);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: parts,
  );
}

class _LinkText extends StatefulWidget {
  const _LinkText({required this.text, required this.color, this.inline = const []});
  final String text;
  final Color color;
  final List<TextEnt> inline;

  @override
  State<_LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<_LinkText> {
  final _recognizers = <TapGestureRecognizer>[];
  final _revealed = <int>{};

  List<InlineSpan> _styledSpans(String text, RegExp re) {
    final out = <InlineSpan>[];
    final bounds = <int>{0, text.length};
    for (final e in widget.inline) {
      bounds.add(e.offset.clamp(0, text.length));
      bounds.add((e.offset + e.length).clamp(0, text.length));
    }
    final cuts = bounds.toList()..sort();
    for (var i = 0; i + 1 < cuts.length; i++) {
      final a = cuts[i], b = cuts[i + 1];
      final run = text.substring(a, b);
      if (run.isEmpty) continue;
      final here = [
        for (final e in widget.inline)
          if (e.offset <= a && e.offset + e.length >= b) e,
      ];
      final isCode = here.any((e) => e.style.isEmpty);
      if (isCode) {
        out.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: run));
              notice(context, context.t('Copied', 'تم النسخ'), kind: NoticeKind.success);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(run,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 13, color: Color(0xFFCE9178))),
            ),
          ),
        ));
        continue;
      }
      var style = const TextStyle();
      var spoilerId = -1;
      final deco = <TextDecoration>[];
      for (final e in here) {
        switch (e.style) {
          case 'bold':
            style = style.copyWith(fontWeight: FontWeight.w700);
          case 'italic':
            style = style.copyWith(fontStyle: FontStyle.italic);
          case 'strike':
            deco.add(TextDecoration.lineThrough);
          case 'underline':
            deco.add(TextDecoration.underline);
          case 'spoiler':
            spoilerId = e.offset;
        }
      }
      if (deco.isNotEmpty) style = style.copyWith(decoration: TextDecoration.combine(deco));
      if (spoilerId >= 0 && !_revealed.contains(spoilerId)) {
        final r = TapGestureRecognizer()..onTap = () => setState(() => _revealed.add(spoilerId));
        _recognizers.add(r);
        out.add(TextSpan(
          text: run,
          recognizer: r,
          style: style.copyWith(
            color: Colors.transparent,
            backgroundColor: Colors.white.withValues(alpha: 0.28),
          ),
        ));
        continue;
      }
      // links / mentions inside this run
      var last = 0;
      for (final m in re.allMatches(run)) {
        if (m.start > last) out.add(TextSpan(text: run.substring(last, m.start), style: style));
        final url = m.group(1);
        if (url != null) {
          final r = TapGestureRecognizer()
            ..onTap = () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          _recognizers.add(r);
          out.add(TextSpan(
              text: url,
              recognizer: r,
              style: style.copyWith(color: widget.color, decoration: TextDecoration.underline)));
        } else {
          out.add(TextSpan(text: m.group(0), style: style.copyWith(color: widget.color)));
        }
        last = m.end;
      }
      if (last < run.length) out.add(TextSpan(text: run.substring(last), style: style));
    }
    return out;
  }

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
    if (widget.inline.isNotEmpty) {
      return Text.rich(TextSpan(children: _styledSpans(text, re)));
    }
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        out.add(TextSpan(text: text.substring(last, m.start)));
      }
      final url = m.group(1);
      final style = TextStyle(
        color: widget.color,
        decoration: url != null ? TextDecoration.underline : null,
      );
      if (url != null) {
        final r = TapGestureRecognizer()
          ..onTap = () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < poll.options.length; i++)
            InkWell(
              onTap: poll.closed || voted ? null : () => onVote([i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SIcon(
                          poll.options[i].chosen
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(poll.options[i].text)),
                        if (voted || poll.closed)
                          Text(
                            poll.total == 0
                                ? '0%'
                                : '${(poll.options[i].votes * 100 / poll.total).round()}%',
                          ),
                      ],
                    ),
                    if (voted || poll.closed)
                      LinearProgressIndicator(
                        value: poll.total == 0
                            ? 0
                            : poll.options[i].votes / poll.total,
                        color: accent,
                      ),
                  ],
                ),
              ),
            ),
          Text(
            poll.closed ? l.pollClosed : l.votesCount('${poll.total}'),
            style: const TextStyle(
              fontSize: 11,
              color: GlassTokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Drag a message sideways to run a configurable action (reply, forward…).
class _SwipeToAct extends StatefulWidget {
  const _SwipeToAct({
    required this.child,
    required this.right,
    required this.left,
    required this.onAction,
    this.enabled = true,
  });

  final Widget child;
  final String right;
  final String left;
  final void Function(String) onAction;
  final bool enabled;

  @override
  State<_SwipeToAct> createState() => _SwipeToActState();
}

class _SwipeToActState extends State<_SwipeToAct> {
  double _dx = 0;
  bool _fired = false;
  bool _snap = false;
  static const _trigger = 56.0;

  static IconData _icon(String a) => switch (a) {
    'reply' => Icons.reply,
    'forward' => Icons.shortcut,
    'copy' => Icons.copy,
    'translate' => Icons.translate,
    'react' => Icons.thumb_up_outlined,
    'heart' => Icons.favorite_border,
    'pin' => Icons.push_pin_outlined,
    'select' => Icons.check_circle_outline,
    'delete' => Icons.delete_outline,
    'share' => Icons.ios_share,
    'save' => Icons.bookmark_add_outlined,
    'menu' => Icons.more_horiz,
    _ => Icons.block,
  };

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || (widget.right == 'none' && widget.left == 'none')) {
      return widget.child;
    }
    final progress = (_dx.abs() / _trigger).clamp(0.0, 1.0);
    final act = _dx > 0 ? widget.right : widget.left;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => setState(() => _snap = false),
      onHorizontalDragUpdate: (d) {
        var next = _dx + d.delta.dx;
        if (next > 0 && widget.right == 'none') next = 0;
        if (next < 0 && widget.left == 'none') next = 0;
        next = next.clamp(-90.0, 90.0);
        if (next.abs() >= _trigger && !_fired) {
          _fired = true;
          HapticFeedback.selectionClick();
        } else if (next.abs() < _trigger) {
          _fired = false;
        }
        setState(() => _dx = next);
      },
      onHorizontalDragEnd: (_) {
        final a = _dx >= _trigger
            ? widget.right
            : _dx <= -_trigger
            ? widget.left
            : null;
        setState(() {
          _snap = true;
          _dx = 0;
          _fired = false;
        });
        if (a != null && a != 'none') widget.onAction(a);
      },
      onHorizontalDragCancel: () => setState(() {
        _dx = 0;
        _fired = false;
      }),
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          if (_dx != 0)
            Positioned.fill(
              child: Align(
                alignment: _dx > 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Opacity(
                  opacity: progress,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _fired
                          ? GlassScope.of(context).accent.withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.15),
                    ),
                    child: SIcon(_icon(act), size: 20),
                  ),
                ),
              ),
            ),
          AnimatedContainer(
            duration: _snap ? const Duration(milliseconds: 180) : Duration.zero,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}


/// Up to three emoji and nothing else → shown big, like Telegram.
bool _emojiOnly(String t) {
  final c = t.trim().characters;
  if (c.isEmpty || c.length > 3) return false;
  return c.every((g) {
    final r = g.runes.first;
    return r >= 0x1F000 || (r >= 0x2190 && r <= 0x2BFF) || r == 0x00A9 || r == 0x00AE || r == 0x203C || r == 0x2049;
  });
}
