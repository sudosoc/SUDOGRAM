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
  int unread = 0;
  Map<String, dynamic>? last;
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
  final _messages = <int, LiveValue<List<ChatMessage>>>{};
  Timer? _chatDebounce;
  int? _textLimit;
  final _users = <int, Map<String, String>>{};
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
    _scheduleChatEmit();
  }

  void _applyPositions(_Chat chat, Object? positions) {
    if (positions is! List) return;
    var order = 0;
    for (final p in positions) {
      if (p is Map && _isMainList(p)) order = asInt(p['order']);
    }
    chat.order = order;
  }

  void _scheduleChatEmit() {
    if (_chatDebounce?.isActive ?? false) return;
    _chatDebounce = Timer(chatListDebounce, () {
      final listed = _chats.values.where((c) => c.order > 0).toList()
        ..sort((a, b) => b.order.compareTo(a.order));
      _chatList.value = [for (final c in listed) _summary(c)];
    });
  }

  ChatSummary _summary(_Chat c) {
    final content = _content(c.last?['content'] as Map?);
    return ChatSummary(
      id: c.id,
      title: c.title,
      lastText: content.text,
      lastKind: content.kind,
      lastTime: c.last == null ? null : _time(c.last!['date']),
      unread: c.unread,
      order: c.order,
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
      default:
        return (kind: MessageKind.other, text: '');
    }
  }

  ChatMessage _parseMessage(Map<String, dynamic> m) {
    final content = _content(m['content'] as Map?);
    return ChatMessage(
      id: asInt(m['id']),
      chatId: asInt(m['chat_id']),
      text: content.text,
      kind: content.kind,
      outgoing: m['is_outgoing'] == true,
      time: _time(m['date']),
      edited: asInt(m['edit_date']) > 0,
    );
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
        else if (!m.outgoing)
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
  Future<void> sendText(int chatId, String text) async {
    await _td.request({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': text},
      },
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
    await _chatList.close();
    await _contactChanges.close();
    await _auth.close();
  }
}
