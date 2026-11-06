import 'dart:async';

import '../../core/live_value.dart';
import '../../domain/models.dart';
import '../../domain/telegram_gateway.dart';
import 'td_transport.dart';

typedef TdTransportFactory = Future<TdTransport> Function();

class _Chat {
  _Chat(this.id);

  final int id;
  String title = '';
  int order = 0; // position in the main chat list; 0 = not listed
  int archiveOrder = 0;
  int unread = 0;
  Map<String, dynamic>? last;
  ChatType type = ChatType.private;
  int userId = 0; // for private chats
  int groupId = 0; // basic group / supergroup id
  bool supergroup = false;
  Attachment? avatar;
  bool muted = false;
  bool canSend = true;
  int readOutbox = 0;
}

/// [TelegramGateway] on top of TDLib.
///
/// Ads: this class never calls `getChatSponsoredMessages`, so sponsored
/// messages are never requested and never shown.
class TdlibGateway implements TelegramGateway {
  TdlibGateway({
    required this.transportFactory,
    required this.apiId,
    required this.apiHash,
    required this.databaseDirectory,
    required this.filesDirectory,
    this.languageCode = 'en',
    this.encryptionKey = '',
    this.newEncryptionKey,
    this.onEncryptionKeyApplied,
    this.chatListDebounce = const Duration(milliseconds: 60),
  });

  final TdTransportFactory transportFactory;
  final int apiId;
  final String apiHash;
  final String databaseDirectory;
  final String filesDirectory;
  final String languageCode;

  /// Key the TDLib database is currently encrypted with ('' = not encrypted).
  final String encryptionKey;

  /// When set, the database is re-keyed to this after login, then
  /// [onEncryptionKeyApplied] is called so the caller can persist it.
  final String? newEncryptionKey;
  final Future<void> Function(String key)? onEncryptionKeyApplied;
  final Duration chatListDebounce;

  late final TdTransport _td;
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _started = false;

  final _auth = LiveValue<AuthState>(AuthState.initializing);
  final _chats = <int, _Chat>{};
  final _chatList = LiveValue<List<ChatSummary>>(const []);
  final _archiveList = LiveValue<List<ChatSummary>>(const []);
  final _messages = <int, LiveValue<List<ChatMessage>>>{};
  Timer? _chatDebounce;
  int? _textLimit;
  final _users = <int, Map<String, String>>{};
  /// Messages the user deleted on purpose: they really disappear (the
  /// anti-delete memory only covers deletions made by the other side).
  final _selfDeleted = <int>{};
  final _fileOwner = <int, (int, int)>{};
  final _avatarOwner = <int, int>{}; // file id -> chat id
  final _seen = <int, (SeenKind, DateTime?)>{}; // user id -> last seen
  final _typing = <int, Map<int, Timer>>{}; // chat -> sender -> expiry
  final _statuses = <int, LiveValue<ChatStatus>>{};
  final _contactChanges = StreamController<ContactChange>.broadcast();

  @override
  bool get isDemo => false;

  @override
  Stream<AuthState> get authState => _auth.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _td = await transportFactory();
    _sub = _td.updates.listen(_onUpdate);
  }

  // ------------------------------------------------------------ updates

  void _onUpdate(Map<String, dynamic> u) {
    switch (u['@type']) {
      case 'updateAuthorizationState':
        _onAuthState(Map<String, dynamic>.from(u['authorization_state'] as Map));
      case 'updateFile':
        _onFile(Map<String, dynamic>.from(u['file'] as Map));
      case 'updateUser':
        _onUser(Map<String, dynamic>.from(u['user'] as Map));
      case 'updateNewChat':
        _applyChat(Map<String, dynamic>.from(u['chat'] as Map));
      case 'updateChatLastMessage':
        final chat = _chat(asInt(u['chat_id']));
        chat.last = (u['last_message'] as Map?)?.cast<String, dynamic>();
        _applyPositions(chat, u['positions']);
        _scheduleChatEmit();
      case 'updateChatPosition':
        final chat = _chat(asInt(u['chat_id']));
        final pos = u['position'];
        if (pos is Map && _isMainList(pos)) {
          chat.order = asInt(pos['order']);
        }
        if (pos is Map && _isArchiveList(pos)) {
          chat.archiveOrder = asInt(pos['order']);
        }
        _scheduleChatEmit();
      case 'updateChatReadOutbox':
        final chat = _chat(asInt(u['chat_id']));
        chat.readOutbox = asInt(u['last_read_outbox_message_id']);
        final live = _messages[chat.id];
        if (live != null) {
          _setMessages(chat.id, [
            for (final m in live.value)
              m.outgoing && m.id <= chat.readOutbox && !m.read
                  ? m.copyWith(read: true)
                  : m
          ]);
        }
      case 'updateChatAction':
        _onChatAction(u);
      case 'updateUserStatus':
        _setSeen(asInt(u['user_id']), u['status']);
      case 'updateChatNotificationSettings':
        _chat(asInt(u['chat_id'])).muted =
            asInt((u['notification_settings'] as Map?)?['mute_for']) > 0;
        _scheduleChatEmit();
      case 'updateChatPhoto':
        _applyPhoto(_chat(asInt(u['chat_id'])), u['photo']);
        _scheduleChatEmit();
      case 'updateChatReadInbox':
        _chat(asInt(u['chat_id'])).unread = asInt(u['unread_count']);
        _scheduleChatEmit();
      case 'updateChatTitle':
        _chat(asInt(u['chat_id'])).title = (u['title'] ?? '').toString();
        _scheduleChatEmit();
      case 'updateNewMessage':
        final m = Map<String, dynamic>.from(u['message'] as Map);
        _upsertMessage(asInt(m['chat_id']), _parseMessage(m));
      case 'updateMessageInteractionInfo':
        final (counts, mine) = _reactions(u['interaction_info']);
        _patchMessage(asInt(u['chat_id']), asInt(u['message_id']),
            (m) => m.copyWith(reactions: counts, myReactions: mine));
      case 'updateMessageContent':
        _onMessageContent(u);
      case 'updateMessageEdited':
        _patchMessage(
          asInt(u['chat_id']),
          asInt(u['message_id']),
          (m) => m.copyWith(edited: true),
        );
      case 'updateDeleteMessages':
        _onDeleted(u);
      case 'updateMessageSendSucceeded':
        final m = Map<String, dynamic>.from(u['message'] as Map);
        final chatId = asInt(m['chat_id']);
        _removeMessage(chatId, asInt(u['old_message_id']));
        _upsertMessage(chatId, _parseMessage(m));
    }
  }

  // ------------------------------------------------------------- files

  void _onFile(Map<String, dynamic> f) {
    final avatarChat = _avatarOwner[asInt(f['id'])];
    if (avatarChat != null) {
      _chat(avatarChat).avatar = _fileToAttachment(f, 'avatar');
      _scheduleChatEmit();
    }
    final owner = _fileOwner[asInt(f['id'])];
    if (owner == null) return;
    final fid = asInt(f['id']);
    _patchMessage(owner.$1, owner.$2, (m) {
      var out = m;
      if (m.file?.fileId == fid) {
        out = out.copyWith(file: _fileToAttachment(f, m.file!.name));
      }
      if (m.thumb?.fileId == fid) {
        out = out.copyWith(thumb: _fileToAttachment(f, m.thumb!.name));
      }
      return out;
    });
  }

  @override
  Future<void> downloadFile(int fileId) async {
    try {
      await _td.request({
        '@type': 'downloadFile',
        'file_id': fileId,
        'priority': 16,
        'offset': 0,
        'limit': 0,
        'synchronous': false,
      });
    } on TdError {
      // Surfaces as unchanged progress; the queue retries on next start.
    }
  }

  @override
  Future<void> cancelDownload(int fileId) async => _td.fire({
        '@type': 'cancelDownloadFile',
        'file_id': fileId,
        'only_if_pending': false,
      });

  @override
  Future<void> sendFile(int chatId, String path, {String caption = ''}) async {
    await _td.request({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageDocument',
        'document': {'@type': 'inputFileLocal', 'path': path},
        'caption': {'@type': 'formattedText', 'text': caption},
      },
    });
  }

  static const _videoExt = {'mp4', 'mov', 'mkv', 'webm', 'avi', 'm4v', '3gp'};

  Map<String, dynamic> _mediaContent(String path, String caption) {
    final ext = path.split('.').last.toLowerCase();
    final file = {'@type': 'inputFileLocal', 'path': path};
    final cap = {'@type': 'formattedText', 'text': caption};
    if (_videoExt.contains(ext)) {
      return {
        '@type': 'inputMessageVideo',
        'video': file,
        'supports_streaming': true,
        'caption': cap,
      };
    }
    return {'@type': 'inputMessagePhoto', 'photo': file, 'caption': cap};
  }

  @override
  Future<void> sendMedia(int chatId, List<String> paths,
      {String caption = ''}) async {
    if (paths.isEmpty) return;
    if (paths.length == 1) {
      await _td.request({
        '@type': 'sendMessage',
        'chat_id': chatId,
        'input_message_content': _mediaContent(paths.first, caption),
      });
      return;
    }
    for (var i = 0; i < paths.length; i += 10) {
      final group = paths.sublist(i, i + 10 > paths.length ? paths.length : i + 10);
      await _td.request({
        '@type': 'sendMessageAlbum',
        'chat_id': chatId,
        'input_message_contents': [
          for (var j = 0; j < group.length; j++)
            _mediaContent(group[j], i == 0 && j == 0 ? caption : ''),
        ],
      });
    }
  }

  // ----------------------------------------------------------- contacts

  void _onUser(Map<String, dynamic> u) {
    final id = asInt(u['id']);
    final names = [u['first_name'], u['last_name']]
        .map((e) => (e ?? '').toString())
        .where((e) => e.isNotEmpty)
        .join(' ');
    final usernames = (u['usernames'] as Map?)?['active_usernames'] as List?;
    final now = <String, String>{
      'name': names,
      'username': (usernames == null || usernames.isEmpty)
          ? ''
          : usernames.first.toString(),
      'phone': (u['phone_number'] ?? '').toString(),
    };
    final before = _users[id];
    _users[id] = now;
    if (u['status'] != null) _setSeen(id, u['status']);
    if (names.isNotEmpty) {
      // Messages loaded before we knew the sender's name get it now.
      for (final entry in _messages.entries) {
        if (entry.value.value.any((m) => m.senderId == id && m.senderName != names)) {
          _setMessages(entry.key, [
            for (final m in entry.value.value)
              m.senderId == id ? m.copyWith(senderName: names) : m
          ]);
        }
      }
    }
    if (before == null) return; // first sight: nothing to compare
    for (final f in now.keys) {
      if (before[f] != now[f]) {
        _contactChanges.add(ContactChange(
          userId: id,
          displayName: now['name']!.isNotEmpty ? now['name']! : before['name']!,
          field: f,
          oldValue: before[f],
          newValue: now[f],
          at: DateTime.now(),
        ));
      }
    }
  }

  @override
  Stream<ContactChange> contactChanges() => _contactChanges.stream;

  // --------------------------------------------------------------- auth

  void _onAuthState(Map<String, dynamic> s) {
    switch (s['@type']) {
      case 'authorizationStateWaitTdlibParameters':
        _td.fire({
          '@type': 'setTdlibParameters',
          'use_test_dc': false,
          'database_directory': databaseDirectory,
          'files_directory': filesDirectory,
          'database_encryption_key': encryptionKey,
          'use_file_database': true,
          'use_chat_info_database': true,
          'use_message_database': true,
          'use_secret_chats': true,
          'api_id': apiId,
          'api_hash': apiHash,
          'system_language_code': languageCode,
          'device_model': 'SUDOGRAM',
          'system_version': '',
          'application_version': '0.1.0',
        });
      case 'authorizationStateWaitPhoneNumber':
        _auth.value = const AuthState(AuthStep.waitPhone);
      case 'authorizationStateWaitCode':
        _auth.value = const AuthState(AuthStep.waitCode);
      case 'authorizationStateWaitPassword':
        _auth.value = const AuthState(AuthStep.waitPassword);
      case 'authorizationStateReady':
        _auth.value = AuthState.ready;
        _rekey();
        _td
            .request({
              '@type': 'loadChats',
              'chat_list': {'@type': 'chatListMain'},
              'limit': 200,
            })
            .then<void>((_) {}, onError: (Object _) {}); // 404 = all loaded
        _td
            .request({
              '@type': 'loadChats',
              'chat_list': {'@type': 'chatListArchive'},
              'limit': 100,
            })
            .then<void>((_) {}, onError: (Object _) {});
      case 'authorizationStateClosed':
        _auth.value = const AuthState(AuthStep.closed);
      default:
        // Registration, e-mail login and QR flows are not supported yet.
        _auth.value = AuthState(
          AuthStep.waitPhone,
          error: 'Unsupported login step: ${s['@type']}',
        );
    }
  }

  Future<void> _rekey() async {
    final next = newEncryptionKey;
    if (next == null) return;
    try {
      await _td.request(
          {'@type': 'setDatabaseEncryptionKey', 'new_encryption_key': next});
      await onEncryptionKeyApplied?.call(next);
    } on TdError {
      // Keep the old key; try again on the next start.
    }
  }

  Future<void> _authCall(Map<String, dynamic> req) async {
    try {
      await _td.request(req);
    } on TdError catch (e) {
      _auth.value = AuthState(_auth.value.step, error: e.message);
    }
  }

  @override
  Future<void> submitPhone(String phone) => _authCall({
        '@type': 'setAuthenticationPhoneNumber',
        'phone_number': phone,
      });

  @override
  Future<void> submitCode(String code) => _authCall({
        '@type': 'checkAuthenticationCode',
        'code': code,
      });

  @override
  Future<void> submitPassword(String password) => _authCall({
        '@type': 'checkAuthenticationPassword',
        'password': password,
      });

  // -------------------------------------------------------------- chats

  _Chat _chat(int id) => _chats.putIfAbsent(id, () => _Chat(id));

  bool _isArchiveList(Map pos) {
    final list = pos['list'];
    return list is Map && list['@type'] == 'chatListArchive';
  }

  bool _isMainList(Map pos) {
    final list = pos['list'];
    return list is Map && list['@type'] == 'chatListMain';
  }

  void _applyChat(Map<String, dynamic> c) {
    final chat = _chat(asInt(c['id']));
    chat.title = (c['title'] ?? chat.title).toString();
    chat.unread = asInt(c['unread_count'], chat.unread);
    if (c.containsKey('last_message')) {
      chat.last = (c['last_message'] as Map?)?.cast<String, dynamic>();
    }
    _applyPositions(chat, c['positions']);
    _applyType(chat, c['type']);
    _applyPhoto(chat, c['photo']);
    chat.muted = asInt((c['notification_settings'] as Map?)?['mute_for']) > 0;
    chat.readOutbox = asInt(c['last_read_outbox_message_id'], chat.readOutbox);
    final perms = c['permissions'] as Map?;
    chat.canSend = chat.type == ChatType.channel
        ? false
        : (perms?['can_send_basic_messages'] ?? true) == true;
    _scheduleChatEmit();
  }

  void _applyType(_Chat chat, Object? type) {
    final t = type as Map?;
    switch (t?['@type']) {
      case 'chatTypePrivate':
        chat.type = ChatType.private;
        chat.userId = asInt(t!['user_id']);
      case 'chatTypeSecret':
        chat.type = ChatType.secret;
        chat.userId = asInt(t!['user_id']);
      case 'chatTypeBasicGroup':
        chat.type = ChatType.group;
        chat.groupId = asInt(t!['basic_group_id']);
        chat.supergroup = false;
      case 'chatTypeSupergroup':
        chat.groupId = asInt(t!['supergroup_id']);
        chat.supergroup = true;
        chat.type =
            t['is_channel'] == true ? ChatType.channel : ChatType.group;
    }
  }

  void _applyPhoto(_Chat chat, Object? photo) {
    final small = (photo as Map?)?['small'] as Map?;
    if (small == null) {
      chat.avatar = null;
      return;
    }
    final att = _fileToAttachment(small, 'avatar');
    chat.avatar = att;
    _avatarOwner[att.fileId] = chat.id;
    _autoDownload(att);
  }

  /// Small images (avatars, thumbnails) are fetched without being asked.
  void _autoDownload(Attachment a) {
    if (a.downloaded || a.downloading) return;
    _td.fire({
      '@type': 'downloadFile',
      'file_id': a.fileId,
      'priority': 1,
      'offset': 0,
      'limit': 0,
      'synchronous': false,
    });
  }

  // -------------------------------------------------- typing and last seen

  void _setSeen(int userId, Object? status) {
    final st = status as Map?;
    switch (st?['@type']) {
      case 'userStatusOnline':
        _seen[userId] = (SeenKind.online, null);
      case 'userStatusOffline':
        _seen[userId] = (SeenKind.at, _time(st!['was_online']));
      case 'userStatusRecently':
        _seen[userId] = (SeenKind.recently, null);
      case 'userStatusLastWeek':
        _seen[userId] = (SeenKind.lastWeek, null);
      case 'userStatusLastMonth':
        _seen[userId] = (SeenKind.lastMonth, null);
      default:
        _seen[userId] = (SeenKind.unknown, null);
    }
    for (final c in _chats.values) {
      if ((c.type == ChatType.private || c.type == ChatType.secret) &&
          c.userId == userId) {
        _emitStatus(c.id);
      }
    }
  }

  void _onChatAction(Map<String, dynamic> u) {
    final chatId = asInt(u['chat_id']);
    final sender = u['sender_id'] as Map?;
    final who = asInt(sender?['user_id'] ?? sender?['chat_id']);
    final map = _typing.putIfAbsent(chatId, () => {});
    map.remove(who)?.cancel();
    final type = (u['action'] as Map?)?['@type'];
    if (type != null && type != 'chatActionCancel') {
      // Telegram stops sending the action; expire it ourselves.
      map[who] = Timer(const Duration(seconds: 6), () {
        map.remove(who);
        _emitStatus(chatId);
      });
    }
    _emitStatus(chatId);
  }

  void _emitStatus(int chatId) {
    final live = _statuses[chatId];
    if (live == null) return;
    final chat = _chats[chatId];
    final seen = chat == null ? null : _seen[chat.userId];
    live.value = ChatStatus(
      typing: (_typing[chatId]?.isNotEmpty ?? false),
      seen: seen?.$1 ?? SeenKind.unknown,
      lastSeen: seen?.$2,
    );
  }

  @override
  Stream<ChatStatus> watchChatStatus(int chatId) {
    final live = _statuses.putIfAbsent(chatId, () => LiveValue(ChatStatus.none));
    _emitStatus(chatId);
    return live.stream;
  }

  void _applyPositions(_Chat chat, Object? positions) {
    if (positions is! List) return;
    var order = 0;
    var archiveOrder = 0;
    for (final p in positions) {
      if (p is Map && _isMainList(p)) order = asInt(p['order']);
      if (p is Map && _isArchiveList(p)) archiveOrder = asInt(p['order']);
    }
    chat.order = order;
    chat.archiveOrder = archiveOrder;
  }

  void _scheduleChatEmit() {
    if (_chatDebounce?.isActive ?? false) return;
    _chatDebounce = Timer(chatListDebounce, () {
      final listed = _chats.values.where((c) => c.order > 0).toList()
        ..sort((a, b) => b.order.compareTo(a.order));
      _chatList.value = [for (final c in listed) _summary(c)];
      final arch = _chats.values.where((c) => c.archiveOrder > 0).toList()
        ..sort((a, b) => b.archiveOrder.compareTo(a.archiveOrder));
      _archiveList.value = [
        for (final c in arch) _summary(c, archived: true)
      ];
    });
  }

  ChatSummary _summary(_Chat c, {bool archived = false}) {
    final content = _content(c.last?['content'] as Map?);
    return ChatSummary(
      id: c.id,
      title: c.title,
      lastText: content.text,
      lastKind: content.kind,
      lastTime: c.last == null ? null : _time(c.last!['date']),
      unread: c.unread,
      order: c.order,
      type: c.type,
      avatar: c.avatar,
      muted: c.muted,
      canSend: c.canSend,
      lastOutgoing: c.last?['is_outgoing'] == true,
      archived: archived,
    );
  }

  @override
  Stream<List<ChatSummary>> watchChats() => _chatList.stream;

  // ----------------------------------------------------------- messages

  DateTime _time(Object? seconds) =>
      DateTime.fromMillisecondsSinceEpoch(asInt(seconds) * 1000);

  ({MessageKind kind, String text}) _content(Map? content) {
    if (content == null) return (kind: MessageKind.other, text: '');
    String caption() =>
        ((content['caption'] as Map?)?['text'] ?? '').toString();
    switch (content['@type']) {
      case 'messageText':
        return (
          kind: MessageKind.text,
          text: ((content['text'] as Map?)?['text'] ?? '').toString(),
        );
      case 'messagePhoto':
        return (kind: MessageKind.photo, text: caption());
      case 'messageVideo':
      case 'messageVideoNote':
      case 'messageAnimation':
        return (kind: MessageKind.video, text: caption());
      case 'messageVoiceNote':
      case 'messageAudio':
        return (kind: MessageKind.voice, text: caption());
      case 'messageDocument':
        return (kind: MessageKind.document, text: caption());
      case 'messageSticker':
        return (kind: MessageKind.sticker, text: '');
      case 'messageLocation':
        final loc = content['location'] as Map?;
        return (
          kind: MessageKind.other,
          text: '📍 https://maps.google.com/?q=${loc?['latitude']},${loc?['longitude']}',
        );
      case 'messageContact':
        final c = content['contact'] as Map?;
        final name = '${c?['first_name'] ?? ''} ${c?['last_name'] ?? ''}'.trim();
        return (kind: MessageKind.other, text: '👤 $name +${c?['phone_number'] ?? ''}');
      case 'messagePoll':
        return (
          kind: MessageKind.poll,
          text: (((content['poll'] as Map?)?['question'] as Map?)?['text'] ??
                  (content['poll'] as Map?)?['question'] ??
                  '')
              .toString(),
        );
      default:
        return (kind: MessageKind.other, text: '');
    }
  }

  /// Finds the main file of a message content, if it has one.
  Attachment? _attachment(Map? content) {
    if (content == null) return null;
    Map? file;
    var name = '';
    switch (content['@type']) {
      case 'messageDocument':
        final d = content['document'] as Map?;
        file = d?['document'] as Map?;
        name = (d?['file_name'] ?? '').toString();
      case 'messageVideo':
        final v = content['video'] as Map?;
        file = v?['video'] as Map?;
        name = (v?['file_name'] ?? 'video.mp4').toString();
      case 'messageAudio':
        final a = content['audio'] as Map?;
        file = a?['audio'] as Map?;
        name = (a?['file_name'] ?? 'audio').toString();
      case 'messageVoiceNote':
        file = (content['voice_note'] as Map?)?['voice'] as Map?;
        name = 'voice.ogg';
      case 'messageAnimation':
        final a = content['animation'] as Map?;
        file = a?['animation'] as Map?;
        name = (a?['file_name'] ?? 'animation.mp4').toString();
      case 'messageSticker':
        final st = content['sticker'] as Map?;
        final isTgs = (st?['format'] as Map?)?['@type'] == 'stickerFormatTgs';
        if (isTgs) {
          file = st?['sticker'] as Map?;
          name = 'sticker.tgs';
        }
      case 'messagePhoto':
        final sizes = ((content['photo'] as Map?)?['sizes'] as List?) ?? const [];
        if (sizes.isNotEmpty) {
          file = (sizes.last as Map)['photo'] as Map?;
          name = 'photo.jpg';
        }
    }
    if (file == null) return null;
    return _fileToAttachment(file, name);
  }

  Attachment _fileToAttachment(Map file, String name) {
    final local = (file['local'] as Map?) ?? const {};
    final size = asInt(file['size']) > 0
        ? asInt(file['size'])
        : asInt(file['expected_size']);
    final path = (local['path'] ?? '').toString();
    return Attachment(
      fileId: asInt(file['id']),
      name: name,
      size: size,
      localPath: path.isEmpty ? null : path,
      downloaded: local['is_downloading_completed'] == true,
      downloading: local['is_downloading_active'] == true,
      downloadedBytes: asInt(local['downloaded_size']),
    );
  }

  /// Where a forwarded message came from (the first hop TDLib reports).
  String? _forwardOrigin(Object? info) {
    final origin = (info as Map?)?['origin'] as Map?;
    if (origin == null) return null;
    switch (origin['@type']) {
      case 'messageOriginUser':
        return 'user:${asInt(origin['sender_user_id'])}';
      case 'messageOriginHiddenUser':
        return (origin['sender_name'] ?? '').toString();
      case 'messageOriginChat':
        return 'chat:${asInt(origin['sender_chat_id'])}';
      case 'messageOriginChannel':
        return 'chat:${asInt(origin['chat_id'])}';
    }
    return null;
  }

  /// Preview image of a message: photo thumbnail, webp sticker, video cover.
  (Attachment?, String) _preview(Map? content) {
    if (content == null) return (null, '');
    switch (content['@type']) {
      case 'messagePhoto':
        final sizes = ((content['photo'] as Map?)?['sizes'] as List?) ?? const [];
        if (sizes.isEmpty) return (null, '');
        final pick = sizes.cast<Map>().firstWhere((e) => e['type'] == 'm',
            orElse: () => sizes[sizes.length > 1 ? 1 : 0] as Map);
        final f = pick['photo'] as Map?;
        return (f == null ? null : _fileToAttachment(f, 'thumb.jpg'), '');
      case 'messageSticker':
        final st = content['sticker'] as Map?;
        if (st == null) return (null, '');
        final emoji = (st['emoji'] ?? '').toString();
        final webp = (st['format'] as Map?)?['@type'] == 'stickerFormatWebp';
        final f = webp ? st['sticker'] as Map? : (st['thumbnail'] as Map?)?['file'] as Map?;
        return (f == null ? null : _fileToAttachment(f, 'sticker.webp'), emoji);
      case 'messageVideo':
      case 'messageAnimation':
      case 'messageVideoNote':
        final v = (content['video'] ?? content['animation'] ?? content['video_note']) as Map?;
        final f = (v?['thumbnail'] as Map?)?['file'] as Map?;
        return (f == null ? null : _fileToAttachment(f, 'thumb.jpg'), '');
    }
    return (null, '');
  }

  ChatMessage _parseMessage(Map<String, dynamic> m) {
    final content = _content(m['content'] as Map?);
    final att = _attachment(m['content'] as Map?);
    final chatId = asInt(m['chat_id']);
    final id = asInt(m['id']);
    if (att != null) _fileOwner[att.fileId] = (chatId, id);
    if (att != null && att.name.endsWith('.tgs')) _autoDownload(att);
    final (thumb, emoji) = _preview(m['content'] as Map?);
    if (thumb != null) {
      _fileOwner[thumb.fileId] = (chatId, id);
      _autoDownload(thumb);
    }
    final sender = m['sender_id'] as Map?;
    final senderId = asInt(sender?['user_id'] ?? sender?['chat_id']);
    final name = sender?['@type'] == 'messageSenderUser'
        ? (_users[senderId]?['name'] ?? '')
        : (_chats[senderId]?.title ?? '');
    final outgoing = m['is_outgoing'] == true;
    final reply = m['reply_to'] as Map?;
    return ChatMessage(
      id: id,
      chatId: chatId,
      text: content.text,
      kind: content.kind,
      outgoing: outgoing,
      time: _time(m['date']),
      edited: asInt(m['edit_date']) > 0,
      file: att,
      forwardedFrom: _forwardOrigin(m['forward_info']),
      senderId: senderId,
      senderName: name,
      replyToId: reply?['@type'] == 'messageReplyToMessage'
          ? asInt(reply!['message_id'])
          : 0,
      thumb: thumb,
      emoji: emoji,
      read: outgoing && id <= (_chats[chatId]?.readOutbox ?? 0),
      poll: _poll(m['content'] as Map?),
      link: _link(m['content'] as Map?),
      reactions: _reactions(m['interaction_info']).$1,
      myReactions: _reactions(m['interaction_info']).$2,
    );
  }

  String _txt(Object? v) => v is Map ? (v['text'] ?? '').toString() : (v ?? '').toString();

  PollData? _poll(Map? content) {
    if (content?['@type'] != 'messagePoll') return null;
    final p = content!['poll'] as Map?;
    if (p == null) return null;
    final type = p['type'] as Map?;
    return PollData(
      question: _txt(p['question']),
      total: asInt(p['total_voter_count']),
      closed: p['is_closed'] == true,
      multiple: type?['allow_multiple_answers'] == true,
      options: [
        for (final o in (p['options'] as List? ?? const []).whereType<Map>())
          PollOption(_txt(o['text']), asInt(o['voter_count']), o['is_chosen'] == true)
      ],
    );
  }

  LinkPreview? _link(Map? content) {
    if (content?['@type'] != 'messageText') return null;
    final w = (content!['link_preview'] ?? content['web_page']) as Map?;
    if (w == null) return null;
    final title = (w['title'] ?? '').toString();
    final desc = _txt(w['description']);
    if (title.isEmpty && desc.isEmpty) return null;
    return LinkPreview(
      url: (w['url'] ?? '').toString(),
      site: (w['site_name'] ?? '').toString(),
      title: title,
      description: desc,
    );
  }

  (Map<String, int>, Set<String>) _reactions(Object? info) {
    final list = ((info as Map?)?['reactions'] as Map?)?['reactions'] as List?;
    final counts = <String, int>{};
    final mine = <String>{};
    for (final r in (list ?? const []).whereType<Map>()) {
      final type = r['type'] as Map?;
      if (type?['@type'] != 'reactionTypeEmoji') continue;
      final e = (type!['emoji'] ?? '').toString();
      counts[e] = asInt(r['total_count']);
      if (r['is_chosen'] == true) mine.add(e);
    }
    return (counts, mine);
  }

  LiveValue<List<ChatMessage>> _live(int chatId) =>
      _messages.putIfAbsent(chatId, () {
        final live = LiveValue<List<ChatMessage>>(const []);
        _loadHistory(chatId, live);
        return live;
      });

  Future<void> _loadHistory(int chatId, LiveValue<List<ChatMessage>> live) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final r = await _td.request({
          '@type': 'getChatHistory',
          'chat_id': chatId,
          'from_message_id': 0,
          'offset': 0,
          'limit': 40,
          'only_local': false,
        });
        final raw = (r['messages'] as List?) ?? const [];
        if (raw.length >= 2 || attempt == 1) {
          for (final m in raw.whereType<Map>()) {
            _upsertMessage(chatId, _parseMessage(Map<String, dynamic>.from(m)));
          }
          return;
        }
      } on TdError {
        return;
      }
      // TDLib may answer from the local cache first; ask once more.
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  void _setMessages(int chatId, List<ChatMessage> list) {
    final live = _messages[chatId];
    if (live == null) return;
    list.sort((a, b) => b.id.compareTo(a.id));
    live.value = list;
  }

  void _upsertMessage(int chatId, ChatMessage message) {
    final live = _messages[chatId];
    if (live == null) return;
    final list = List<ChatMessage>.of(live.value);
    final i = list.indexWhere((m) => m.id == message.id);
    if (i >= 0) {
      list[i] = message;
    } else {
      list.add(message);
    }
    _setMessages(chatId, list);
  }

  void _removeMessage(int chatId, int messageId) {
    final live = _messages[chatId];
    if (live == null) return;
    _setMessages(chatId,
        live.value.where((m) => m.id != messageId).toList());
  }

  void _patchMessage(
      int chatId, int messageId, ChatMessage Function(ChatMessage) patch) {
    final live = _messages[chatId];
    if (live == null) return;
    _setMessages(chatId, [
      for (final m in live.value) m.id == messageId ? patch(m) : m,
    ]);
  }

  void _onMessageContent(Map<String, dynamic> u) {
    final content = _content(u['new_content'] as Map?);
    _patchMessage(
      asInt(u['chat_id']),
      asInt(u['message_id']),
      (m) => m.copyWith(text: content.text, kind: content.kind),
    );
  }

  void _onDeleted(Map<String, dynamic> u) {
    if (u['is_permanent'] != true) return; // from_cache: not a real deletion
    final chatId = asInt(u['chat_id']);
    final live = _messages[chatId];
    if (live == null) return;
    final ids = {
      for (final id in (u['message_ids'] as List? ?? const [])) asInt(id),
    };
    // Messages we sent are removed. Messages from others are kept and marked,
    // so the reader still sees what was deleted (anti-delete).
    _setMessages(chatId, [
      for (final m in live.value)
        if (!ids.contains(m.id))
          m
        else if (!m.outgoing && !_selfDeleted.contains(m.id))
          m.copyWith(deletedByPeer: true),
    ]);
  }

  @override
  Stream<List<ChatMessage>> watchMessages(int chatId) => _live(chatId).stream;

  @override
  Future<void> openChat(int chatId) async =>
      _td.fire({'@type': 'openChat', 'chat_id': chatId});

  @override
  Future<void> closeChat(int chatId) async =>
      _td.fire({'@type': 'closeChat', 'chat_id': chatId});

  @override
  Future<void> sendText(int chatId, String text, {int replyTo = 0}) async {
    await _td.request({
      '@type': 'sendMessage',
      'chat_id': chatId,
      if (replyTo != 0)
        'reply_to': {
          '@type': 'inputMessageReplyToMessage',
          'message_id': replyTo,
        },
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': text},
      },
    });
  }

  @override
  Future<bool> loadOlder(int chatId) async {
    final live = _live(chatId);
    final known = live.value.where((m) => m.id > 0).toList();
    if (known.isEmpty) return false;
    final oldest = known.map((m) => m.id).reduce((a, b) => a < b ? a : b);
    try {
      final r = await _td.request({
        '@type': 'getChatHistory',
        'chat_id': chatId,
        'from_message_id': oldest,
        'offset': 0,
        'limit': 40,
        'only_local': false,
      });
      final raw = ((r['messages'] as List?) ?? const []).whereType<Map>();
      var added = 0;
      for (final m in raw) {
        final msg = _parseMessage(Map<String, dynamic>.from(m));
        if (!live.value.any((e) => e.id == msg.id)) added++;
        _upsertMessage(chatId, msg);
      }
      return added > 0;
    } on TdError {
      return false;
    }
  }

  @override
  Future<void> editText(int chatId, int messageId, String text) async {
    await _td.request({
      '@type': 'editMessageText',
      'chat_id': chatId,
      'message_id': messageId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': text},
      },
    });
  }

  @override
  Future<void> deleteMessages(int chatId, List<int> ids,
      {bool forAll = false}) async {
    _selfDeleted.addAll(ids);
    await _td.request({
      '@type': 'deleteMessages',
      'chat_id': chatId,
      'message_ids': ids,
      'revoke': forAll,
    });
  }

  @override
  Future<List<ChatSummary>> contacts() async {
    try {
      final r = await _td.request({'@type': 'getContacts'});
      final ids = [for (final x in (r['user_ids'] as List? ?? const [])) asInt(x)];
      final out = <ChatSummary>[];
      for (final id in ids) {
        if (_users[id] == null) {
          try {
            _onUser(Map<String, dynamic>.from(
                await _td.request({'@type': 'getUser', 'user_id': id})));
          } on TdError {
            continue;
          }
        }
        out.add(ChatSummary(
          id: id, // user id; resolve with openPrivateChat
          title: _users[id]?['name'] ?? '',
          lastText: _users[id]?['username'] ?? '',
          lastKind: MessageKind.text,
          lastTime: null,
          unread: 0,
        ));
      }
      out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      return out;
    } on TdError {
      return const [];
    }
  }

  Future<ChatSummary?> _chatFor(Map<String, dynamic> req) async {
    try {
      final r = await _td.request(req);
      _applyChat(Map<String, dynamic>.from(r));
      return _summary(_chat(asInt(r['id'])));
    } on TdError {
      return null;
    }
  }

  @override
  Future<ChatSummary?> openPrivateChat(int userId) => _chatFor(
      {'@type': 'createPrivateChat', 'user_id': userId, 'force': false});

  @override
  Future<ChatSummary?> savedMessages() async {
    try {
      final me = await _td.request({'@type': 'getMe'});
      return await openPrivateChat(asInt(me['id']));
    } on TdError {
      return null;
    }
  }

  @override
  Future<List<ChatMessage>> searchChat(int chatId, String query) async {
    if (query.trim().isEmpty) return const [];
    try {
      final r = await _td.request({
        '@type': 'searchChatMessages',
        'chat_id': chatId,
        'query': query,
        'from_message_id': 0,
        'offset': 0,
        'limit': 50,
      });
      return [
        for (final m in (r['messages'] as List? ?? const []).whereType<Map>())
          _parseMessage(Map<String, dynamic>.from(m))
      ];
    } on TdError {
      return const [];
    }
  }

  @override
  Future<ChatMessage?> pinnedMessage(int chatId) async {
    try {
      final r = await _td.request(
          {'@type': 'getChatPinnedMessage', 'chat_id': chatId});
      return _parseMessage(Map<String, dynamic>.from(r));
    } on TdError {
      return null;
    }
  }

  @override
  Future<void> toggleReaction(int chatId, int messageId, String emoji,
      {required bool on}) async {
    try {
      await _td.request({
        '@type': on ? 'addMessageReaction' : 'removeMessageReaction',
        'chat_id': chatId,
        'message_id': messageId,
        'reaction_type': {'@type': 'reactionTypeEmoji', 'emoji': emoji},
        if (on) 'is_big': false,
        if (on) 'update_recent_reactions': true,
      });
    } on TdError {
      // reaction rejected by the server (e.g. not allowed in this chat)
    }
  }

  @override
  Future<ChatInfo?> chatInfo(int chatId) async {
    final c = _chats[chatId];
    if (c == null) return null;
    try {
      if (c.type == ChatType.private || c.type == ChatType.secret) {
        final u = _users[c.userId];
        String about = '';
        try {
          final f = await _td.request(
              {'@type': 'getUserFullInfo', 'user_id': c.userId});
          final bio = f['bio'];
          about = bio is Map ? (bio['text'] ?? '').toString() : (bio ?? '').toString();
        } on TdError {
          // optional
        }
        return ChatInfo(
            username: u?['username'] ?? '', phone: u?['phone'] ?? '', about: about);
      }
      if (c.supergroup) {
        final f = await _td.request(
            {'@type': 'getSupergroupFullInfo', 'supergroup_id': c.groupId});
        String username = '';
        try {
          final sg = await _td
              .request({'@type': 'getSupergroup', 'supergroup_id': c.groupId});
          final names = (sg['usernames'] as Map?)?['active_usernames'] as List?;
          if (names != null && names.isNotEmpty) username = names.first.toString();
        } on TdError {
          // optional
        }
        return ChatInfo(
            username: username,
            about: (f['description'] ?? '').toString(),
            members: asInt(f['member_count']));
      }
      final f = await _td.request(
          {'@type': 'getBasicGroupFullInfo', 'basic_group_id': c.groupId});
      return ChatInfo(
          about: (f['description'] ?? '').toString(),
          members: (f['members'] as List?)?.length ?? 0);
    } on TdError {
      return null;
    }
  }

  @override
  Stream<List<ChatSummary>> watchArchived() => _archiveList.stream;

  @override
  Future<void> setArchived(int chatId, bool archived) async {
    try {
      await _td.request({
        '@type': 'addChatToList',
        'chat_id': chatId,
        'chat_list': {
          '@type': archived ? 'chatListArchive' : 'chatListMain'
        },
      });
    } on TdError {
      // ignored: the list refreshes from server updates
    }
  }

  @override
  Future<void> votePoll(int chatId, int messageId, List<int> options) async {
    try {
      await _td.request({
        '@type': 'setPollAnswer',
        'chat_id': chatId,
        'message_id': messageId,
        'option_ids': options,
      });
    } on TdError {
      // closed or already voted
    }
  }

  @override
  Future<List<DeviceSession>> sessions() async {
    try {
      final r = await _td.request({'@type': 'getActiveSessions'});
      return [
        for (final x in (r['sessions'] as List? ?? const []).whereType<Map>())
          DeviceSession(
            id: asInt(x['id']),
            app: '${x['application_name'] ?? ''} ${x['application_version'] ?? ''}'.trim(),
            device: '${x['device_model'] ?? ''} · ${x['platform'] ?? ''} ${x['system_version'] ?? ''}'.trim(),
            location: '${x['country'] ?? ''} ${x['ip_address'] ?? ''}'.trim(),
            lastActive: _time(x['last_active_date']),
            current: x['is_current'] == true,
          )
      ];
    } on TdError {
      return const [];
    }
  }

  @override
  Future<void> terminateSession(int id) async {
    try {
      await _td.request({'@type': 'terminateSession', 'session_id': id});
    } on TdError {
      // not allowed (e.g. a very new session)
    }
  }

  @override
  Future<ChatSummary?> createGroup(String title, List<int> userIds) async {
    try {
      final r = await _td.request({
        '@type': 'createNewBasicGroupChat',
        'user_ids': userIds,
        'title': title,
        'message_auto_delete_time': 0,
      });
      final id = asInt(r['chat_id'] ?? (r['id']));
      if (!_chats.containsKey(id)) {
        final c = await _td.request({'@type': 'getChat', 'chat_id': id});
        _applyChat(Map<String, dynamic>.from(c));
      }
      return _summary(_chat(id));
    } on TdError {
      return null;
    }
  }

  @override
  Future<List<MentionCandidate>> searchMembers(int chatId, String query) async {
    try {
      final r = await _td.request({
        '@type': 'searchChatMembers',
        'chat_id': chatId,
        'query': query,
        'limit': 8,
        'filter': {'@type': 'chatMembersFilterMembers'},
      });
      final out = <MentionCandidate>[];
      for (final m in (r['members'] as List? ?? const []).whereType<Map>()) {
        final id = asInt((m['member_id'] as Map?)?['user_id']);
        if (id == 0) continue;
        if (_users[id] == null) {
          try {
            _onUser(Map<String, dynamic>.from(
                await _td.request({'@type': 'getUser', 'user_id': id})));
          } on TdError {
            continue;
          }
        }
        final u = _users[id]!;
        if ((u['username'] ?? '').isEmpty) continue; // plain @mention needs one
        out.add(MentionCandidate(id, u['name'] ?? '', u['username']!));
      }
      return out;
    } on TdError {
      return const [];
    }
  }

  static const _privacyKinds = {
    'phone': 'userPrivacySettingShowPhoneNumber',
    'seen': 'userPrivacySettingShowStatus',
    'photo': 'userPrivacySettingShowProfilePicture',
    'calls': 'userPrivacySettingAllowCalls',
    'invites': 'userPrivacySettingAllowChatInvitations',
    'forwards': 'userPrivacySettingShowLinkInForwardedMessages',
  };

  @override
  Future<String> getPrivacy(String key) async {
    final type = _privacyKinds[key];
    if (type == null) return 'everybody';
    try {
      final r = await _td.request({
        '@type': 'getUserPrivacySettingRules',
        'setting': {'@type': type},
      });
      for (final rule in (r['rules'] as List? ?? const []).whereType<Map>()) {
        switch (rule['@type']) {
          case 'userPrivacySettingRuleAllowAll':
            return 'everybody';
          case 'userPrivacySettingRuleAllowContacts':
            return 'contacts';
          case 'userPrivacySettingRuleRestrictAll':
            return 'nobody';
        }
      }
      return 'nobody';
    } on TdError {
      return 'everybody';
    }
  }

  @override
  Future<void> setPrivacy(String key, String value) async {
    final type = _privacyKinds[key];
    if (type == null) return;
    final rule = switch (value) {
      'contacts' => 'userPrivacySettingRuleAllowContacts',
      'nobody' => 'userPrivacySettingRuleRestrictAll',
      _ => 'userPrivacySettingRuleAllowAll',
    };
    try {
      await _td.request({
        '@type': 'setUserPrivacySettingRules',
        'setting': {'@type': type},
        'rules': {
          '@type': 'userPrivacySettingRules',
          'rules': [
            {'@type': rule}
          ],
        },
      });
    } on TdError {
      // rejected by the server
    }
  }

  @override
  Future<ChatSummary?> createSecretChat(int userId) =>
      _chatFor({'@type': 'createNewSecretChat', 'user_id': userId});

  @override
  Future<void> setAutoDelete(int chatId, int seconds) async {
    try {
      await _td.request({
        '@type': 'setChatMessageAutoDeleteTime',
        'chat_id': chatId,
        'message_auto_delete_time': seconds,
      });
    } on TdError {
      // not allowed in this chat
    }
  }

  @override
  Future<ProfileInfo?> me() async {
    try {
      final u = await _td.request({'@type': 'getMe'});
      final id = asInt(u['id']);
      String bio = '';
      try {
        final f = await _td.request({'@type': 'getUserFullInfo', 'user_id': id});
        final b = f['bio'];
        bio = b is Map ? (b['text'] ?? '').toString() : (b ?? '').toString();
      } on TdError {
        // optional
      }
      final names = (u['usernames'] as Map?)?['active_usernames'] as List?;
      final small = (u['profile_photo'] as Map?)?['small'] as Map?;
      return ProfileInfo(
        id: id,
        firstName: (u['first_name'] ?? '').toString(),
        lastName: (u['last_name'] ?? '').toString(),
        username: names == null || names.isEmpty ? '' : names.first.toString(),
        phone: (u['phone_number'] ?? '').toString(),
        bio: bio,
        avatar: small == null ? null : _fileToAttachment(small, 'me.jpg'),
      );
    } on TdError {
      return null;
    }
  }

  @override
  Future<void> updateProfile(
      {String? firstName, String? lastName, String? bio}) async {
    if (firstName != null || lastName != null) {
      await _td.request({
        '@type': 'setName',
        'first_name': firstName ?? '',
        'last_name': lastName ?? '',
      });
    }
    if (bio != null) await _td.request({'@type': 'setBio', 'bio': bio});
  }

  @override
  Future<bool> setUsername(String username) async {
    try {
      await _td.request({'@type': 'setUsername', 'username': username});
      return true;
    } on TdError {
      return false;
    }
  }

  @override
  Future<void> setProfilePhoto(String path) async {
    await _td.request({
      '@type': 'setProfilePhoto',
      'photo': {
        '@type': 'inputChatPhotoStatic',
        'photo': {'@type': 'inputFileLocal', 'path': path},
      },
      'is_public': false,
    });
  }

  @override
  Future<void> logOut() async {
    await _td.request({'@type': 'logOut'});
  }

  @override
  Future<void> setMuted(int chatId, bool muted) async {
    await _td.request({
      '@type': 'setChatNotificationSettings',
      'chat_id': chatId,
      'notification_settings': {
        '@type': 'chatNotificationSettings',
        'use_default_mute_for': false,
        'mute_for': muted ? 2147483647 : 0,
        'use_default_sound': true,
        'use_default_show_preview': true,
        'use_default_mute_stories': true,
        'use_default_story_sound': true,
        'use_default_show_story_poster': true,
        'use_default_disable_pinned_message_notifications': true,
        'use_default_disable_mention_notifications': true,
      },
    });
  }

  @override
  Future<void> clearHistory(int chatId) async {
    await _td.request({
      '@type': 'deleteChatHistory',
      'chat_id': chatId,
      'remove_from_chat_list': false,
      'revoke': false,
    });
  }

  @override
  Future<void> leaveChat(int chatId) async {
    final c = _chats[chatId];
    if (c != null && (c.type == ChatType.group || c.type == ChatType.channel)) {
      try {
        await _td.request({'@type': 'leaveChat', 'chat_id': chatId});
      } on TdError {
        // already left
      }
    }
    await _td.request({
      '@type': 'deleteChatHistory',
      'chat_id': chatId,
      'remove_from_chat_list': true,
      'revoke': false,
    });
  }

  @override
  Future<void> blockUser(int userId, bool blocked) async {
    await _td.request({
      '@type': 'setMessageSenderBlockList',
      'sender_id': {'@type': 'messageSenderUser', 'user_id': userId},
      if (blocked) 'block_list': {'@type': 'blockListMain'},
    });
  }

  @override
  Future<void> sendVoice(int chatId, String path, int seconds) async {
    await _td.request({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageVoiceNote',
        'voice_note': {'@type': 'inputFileLocal', 'path': path},
        'duration': seconds,
        'waveform': '',
        'caption': {'@type': 'formattedText', 'text': ''},
      },
    });
  }

  @override
  Future<ChatSummary?> joinByLink(String link) async {
    final c = await _td.request(
        {'@type': 'joinChatByInviteLink', 'invite_link': link.trim()});
    _applyChat(Map<String, dynamic>.from(c));
    return _summary(_chat(asInt(c['id'])));
  }

  @override
  Future<List<ChatSummary>> blockedUsers() async {
    try {
      final r = await _td.request({
        '@type': 'getBlockedMessageSenders',
        'block_list': {'@type': 'blockListMain'},
        'offset': 0,
        'limit': 100,
      });
      final out = <ChatSummary>[];
      for (final x in (r['senders'] as List? ?? const []).whereType<Map>()) {
        final sender = (x['sender_id'] ?? x) as Map;
        final id = asInt(sender['user_id']);
        if (id == 0) continue;
        if (_users[id] == null) {
          try {
            _onUser(Map<String, dynamic>.from(
                await _td.request({'@type': 'getUser', 'user_id': id})));
          } on TdError {
            continue;
          }
        }
        out.add(ChatSummary(
          id: id,
          title: _users[id]?['name'] ?? '$id',
          lastText: '',
          lastKind: MessageKind.text,
          lastTime: null,
          unread: 0,
        ));
      }
      return out;
    } on TdError {
      return const [];
    }
  }

  @override
  Future<List<ChatMessage>> searchGlobal(String query) async {
    if (query.trim().length < 2) return const [];
    try {
      final r = await _td.request({
        '@type': 'searchMessages',
        'chat_list': {'@type': 'chatListMain'},
        'query': query,
        'offset': '',
        'limit': 30,
        'min_date': 0,
        'max_date': 0,
      });
      return [
        for (final m in (r['messages'] as List? ?? const []).whereType<Map>())
          _parseMessage(Map<String, dynamic>.from(m))
      ];
    } on TdError {
      return const [];
    }
  }

  @override
  Future<bool> hasCloudPassword() async {
    try {
      final r = await _td.request({'@type': 'getPasswordState'});
      return r['has_password'] == true;
    } on TdError {
      return false;
    }
  }

  @override
  Future<bool> setCloudPassword(
      {String oldPassword = '', String newPassword = '', String hint = ''}) async {
    try {
      await _td.request({
        '@type': 'setPassword',
        'old_password': oldPassword,
        'new_password': newPassword,
        'new_hint': hint,
        'set_recovery_email_address': false,
        'new_recovery_email_address': '',
      });
      return true;
    } on TdError {
      return false;
    }
  }

  @override
  Future<List<StickerSetInfo>> stickerSets() async {
    try {
      final r = await _td.request({
        '@type': 'getInstalledStickerSets',
        'sticker_type': {'@type': 'stickerTypeRegular'},
      });
      return [
        for (final x in (r['sets'] as List? ?? const []).whereType<Map>())
          StickerSetInfo(asInt(x['id']), (x['title'] ?? '').toString())
      ];
    } on TdError {
      return const [];
    }
  }

  @override
  Future<List<StickerItem>> stickerSetItems(int setId) async {
    try {
      final r = await _td.request({'@type': 'getStickerSet', 'set_id': setId});
      return [
        for (final x in (r['stickers'] as List? ?? const []).whereType<Map>())
          StickerItem(
            asInt((x['sticker'] as Map?)?['id']),
            asInt(((x['thumbnail'] as Map?)?['file'] as Map?)?['id']),
            (x['emoji'] ?? '').toString(),
          )
      ];
    } on TdError {
      return const [];
    }
  }

  @override
  Future<String?> fetchFile(int fileId) async {
    if (fileId == 0) return null;
    try {
      final f = await _td.request({
        '@type': 'downloadFile',
        'file_id': fileId,
        'priority': 8,
        'offset': 0,
        'limit': 0,
        'synchronous': true,
      });
      final local = f['local'] as Map?;
      final path = (local?['path'] ?? '').toString();
      return local?['is_downloading_completed'] == true && path.isNotEmpty
          ? path
          : null;
    } on TdError {
      return null;
    }
  }

  @override
  Future<void> sendSticker(int chatId, StickerItem sticker) async {
    await _td.request({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageSticker',
        'sticker': {'@type': 'inputFileId', 'id': sticker.fileId},
        'width': 0,
        'height': 0,
        'emoji': sticker.emoji,
      },
    });
  }

  Future<MentionCandidate?> _member(int id) async {
    if (_users[id] == null) {
      try {
        _onUser(Map<String, dynamic>.from(
            await _td.request({'@type': 'getUser', 'user_id': id})));
      } on TdError {
        return null;
      }
    }
    final u = _users[id]!;
    return MentionCandidate(id, u['name'] ?? '', u['username'] ?? '');
  }

  @override
  Future<List<MentionCandidate>> members(int chatId) async {
    final c = _chats[chatId];
    if (c == null) return const [];
    try {
      final ids = <int>[];
      if (c.supergroup) {
        final r = await _td.request({
          '@type': 'getSupergroupMembers',
          'supergroup_id': c.groupId,
          'filter': {'@type': 'supergroupMembersFilterRecent'},
          'offset': 0,
          'limit': 200,
        });
        for (final m in (r['members'] as List? ?? const []).whereType<Map>()) {
          ids.add(asInt((m['member_id'] as Map?)?['user_id']));
        }
      } else {
        final r = await _td.request(
            {'@type': 'getBasicGroupFullInfo', 'basic_group_id': c.groupId});
        for (final m in (r['members'] as List? ?? const []).whereType<Map>()) {
          ids.add(asInt((m['member_id'] as Map?)?['user_id']));
        }
      }
      final out = <MentionCandidate>[];
      for (final id in ids.where((e) => e != 0)) {
        final m = await _member(id);
        if (m != null) out.add(m);
      }
      return out;
    } on TdError {
      return const [];
    }
  }

  @override
  Future<void> addMember(int chatId, int userId) async {
    await _td.request({
      '@type': 'addChatMember',
      'chat_id': chatId,
      'user_id': userId,
      'forward_limit': 0,
    });
  }

  @override
  Future<void> removeMember(int chatId, int userId) async {
    await _td.request({
      '@type': 'setChatMemberStatus',
      'chat_id': chatId,
      'member_id': {'@type': 'messageSenderUser', 'user_id': userId},
      'status': {'@type': 'chatMemberStatusLeft'},
    });
  }

  @override
  Future<void> pinMessage(int chatId, int messageId, {required bool pin}) async {
    await _td.request({
      '@type': pin ? 'pinChatMessage' : 'unpinChatMessage',
      'chat_id': chatId,
      'message_id': messageId,
      if (pin) 'disable_notification': false,
      if (pin) 'only_for_self': false,
    });
  }

  @override
  Future<void> sendPoll(int chatId, String question, List<String> options,
      {bool multiple = false, bool anonymous = true}) async {
    await _td.request({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessagePoll',
        'question': {'@type': 'formattedText', 'text': question},
        'options': [
          for (final o in options)
            {'@type': 'inputPollOption', 'text': {'@type': 'formattedText', 'text': o}}
        ],
        'is_anonymous': anonymous,
        'type': {'@type': 'pollTypeRegular', 'allow_multiple_answers': multiple},
        'open_period': 0,
        'close_date': 0,
        'is_closed': false,
      },
    });
  }

  @override
  Future<void> sendLocation(int chatId, double lat, double lon) async {
    await _td.request({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageLocation',
        'location': {
          '@type': 'location',
          'latitude': lat,
          'longitude': lon,
          'horizontal_accuracy': 0,
        },
        'live_period': 0,
        'heading': 0,
        'proximity_alert_radius': 0,
      },
    });
  }

  @override
  Future<void> sendContact(int chatId, int userId) async {
    final u = _users[userId] ?? const <String, String>{};
    final parts = (u['name'] ?? '').split(' ');
    await _td.request({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageContact',
        'contact': {
          '@type': 'contact',
          'phone_number': u['phone'] ?? '',
          'first_name': parts.first,
          'last_name': parts.skip(1).join(' '),
          'user_id': userId,
        },
      },
    });
  }

  @override
  Future<List<StickerItem>> savedGifs() async {
    try {
      final r = await _td.request({'@type': 'getSavedAnimations'});
      return [
        for (final x in (r['animations'] as List? ?? const []).whereType<Map>())
          StickerItem(
            asInt((x['animation'] as Map?)?['id']),
            asInt(((x['thumbnail'] as Map?)?['file'] as Map?)?['id']),
            '',
            gif: true,
          )
      ];
    } on TdError {
      return const [];
    }
  }

  @override
  Future<void> sendGif(int chatId, StickerItem gif) async {
    await _td.request({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageAnimation',
        'animation': {'@type': 'inputFileId', 'id': gif.fileId},
        'duration': 0,
        'width': 0,
        'height': 0,
        'caption': {'@type': 'formattedText', 'text': ''},
      },
    });
  }

  @override
  Future<void> forwardMessages(
      int toChatId, int fromChatId, List<int> ids) async {
    await _td.request({
      '@type': 'forwardMessages',
      'chat_id': toChatId,
      'from_chat_id': fromChatId,
      'message_ids': ids,
    });
  }

  @override
  Future<int> messageTextLimit() async {
    final cached = _textLimit;
    if (cached != null) return cached;
    try {
      final r = await _td.request(
          {'@type': 'getOption', 'name': 'message_text_length_max'});
      _textLimit = asInt(r['value'], 4096);
    } on TdError {
      return 4096;
    }
    return _textLimit!;
  }

  // ----------------------------------------------- presence-leaking calls

  @override
  Future<void> markRead(int chatId, List<int> messageIds) async {
    if (messageIds.isEmpty) return;
    _td.fire({
      '@type': 'viewMessages',
      'chat_id': chatId,
      'message_ids': messageIds,
      'force_read': true,
    });
  }

  @override
  Future<void> sendTyping(int chatId) async => _td.fire({
        '@type': 'sendChatAction',
        'chat_id': chatId,
        'action': {'@type': 'chatActionTyping'},
      });

  @override
  Future<void> setOnline(bool online) async => _td.fire({
        '@type': 'setOption',
        'name': 'online',
        'value': {'@type': 'optionValueBoolean', 'value': online},
      });

  @override
  Future<void> dispose() async {
    _chatDebounce?.cancel();
    await _sub?.cancel();
    if (_started) await _td.close();
    for (final live in _messages.values) {
      await live.close();
    }
    for (final live in _statuses.values) {
      await live.close();
    }
    for (final t in _typing.values) {
      for (final timer in t.values) {
        timer.cancel();
      }
    }
    await _chatList.close();
    await _archiveList.close();
    await _contactChanges.close();
    await _auth.close();
  }
}
