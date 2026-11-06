import 'dart:async';

import '../core/live_value.dart';
import '../domain/models.dart';
import '../domain/telegram_gateway.dart';

/// In-memory gateway for demo mode and tests. Needs no network or API keys.
class MockGateway implements TelegramGateway {
  final _auth = LiveValue<AuthState>(AuthState.ready);
  late final LiveValue<List<ChatSummary>> _chats;
  final _msgs = <int, LiveValue<List<ChatMessage>>>{};
  int _nextId = 1000;

  @override
  bool get isDemo => true;

  @override
  Stream<AuthState> get authState => _auth.stream;

  @override
  Future<void> start() async {
    final now = DateTime.now();
    ChatSummary c(int id, String t, String last, int mins, int unread,
            [RiskLevel r = RiskLevel.none]) =>
        ChatSummary(
          id: id,
          title: t,
          lastText: last,
          lastKind: MessageKind.text,
          lastTime: now.subtract(Duration(minutes: mins)),
          unread: unread,
          order: 1000 - id,
          risk: r,
        );
    _chats = LiveValue([
      c(1, 'أحمد', 'تمام، هبعتلك الملف النهارده', 3, 2, RiskLevel.safe),
      c(2, 'Team SOC', 'Alert triage done ✅', 25, 0, RiskLevel.caution),
      c(3, 'ماما', 'ماتنساش تتصل بيا', 90, 1),
      c(4, 'Unknown sender', 'Click here to claim…', 300, 4, RiskLevel.danger),
      c(5, 'مجموعة الكلية', 'المحاضرة اتأجلت', 720, 0),
    ]);
    for (final chat in _chats.value) {
      _msgs[chat.id] = LiveValue([
        ChatMessage(
          id: chat.id * 10 + 2,
          chatId: chat.id,
          text: chat.lastText,
          kind: MessageKind.text,
          outgoing: false,
          time: chat.lastTime!,
        ),
        ChatMessage(
          id: chat.id * 10 + 1,
          chatId: chat.id,
          text: 'Hello / أهلا',
          kind: MessageKind.text,
          outgoing: true,
          time: chat.lastTime!.subtract(const Duration(minutes: 5)),
        ),
      ]);
    }
  }

  @override
  Future<void> submitPhone(String phone) async {}
  @override
  Future<void> submitCode(String code) async {}
  @override
  Future<void> submitPassword(String password) async {}

  @override
  Stream<List<ChatSummary>> watchChats() => _chats.stream;

  @override
  Stream<List<ChatMessage>> watchMessages(int chatId) =>
      (_msgs[chatId] ??= LiveValue(const [])).stream;

  @override
  Future<void> openChat(int chatId) async {}
  @override
  Future<void> closeChat(int chatId) async {}

  @override
  Future<void> sendText(int chatId, String text, {int replyTo = 0}) async {
    final live = _msgs[chatId] ??= LiveValue(const []);
    live.value = [
      ChatMessage(
        id: _nextId++,
        chatId: chatId,
        text: text,
        kind: MessageKind.text,
        outgoing: true,
        time: DateTime.now(),
      ),
      ...live.value,
    ];
  }

  @override
  Future<int> messageTextLimit() async => 4096;

  @override
  Future<void> markRead(int chatId, List<int> messageIds) async {}
  @override
  Future<void> sendTyping(int chatId) async {}
  @override
  Future<void> setOnline(bool online) async {}

  @override
  Future<void> downloadFile(int fileId) async {}
  @override
  Future<void> cancelDownload(int fileId) async {}
  @override
  Future<void> sendFile(int chatId, String path, {String caption = ''}) =>
      sendText(chatId, caption.isEmpty ? path.split('/').last : caption);

  @override
  Future<void> sendMedia(int chatId, List<String> paths, {String caption = ''}) async {
    for (final p in paths) {
      await sendText(chatId, p.split('/').last);
    }
  }

  @override
  Future<bool> loadOlder(int chatId) async => false;
  @override
  Future<void> editText(int chatId, int messageId, String text) async {
    final live = _msgs[chatId];
    if (live == null) return;
    live.value = [
      for (final m in live.value)
        m.id == messageId ? m.copyWith(text: text, edited: true) : m
    ];
  }

  @override
  Future<void> deleteMessages(int chatId, List<int> ids, {bool forAll = false}) async {
    final live = _msgs[chatId];
    if (live == null) return;
    live.value = [for (final m in live.value) if (!ids.contains(m.id)) m];
  }

  @override
  Future<List<ChatSummary>> contacts() async => const [];

  @override
  Future<ChatSummary?> openPrivateChat(int userId) async => null;

  @override
  Future<ChatSummary?> savedMessages() async => null;

  @override
  Future<List<ChatMessage>> searchChat(int chatId, String query) async => [
        for (final m in await watchMessages(chatId).first)
          if (m.text.contains(query)) m
      ];

  @override
  Future<ChatMessage?> pinnedMessage(int chatId) async => null;

  @override
  Future<void> toggleReaction(int chatId, int messageId, String emoji,
      {required bool on}) async {}

  @override
  Future<ChatInfo?> chatInfo(int chatId) async => const ChatInfo();

  @override
  Stream<List<ChatSummary>> watchArchived() => const Stream.empty();
  @override
  Future<void> setArchived(int chatId, bool archived) async {}
  @override
  Future<void> votePoll(int chatId, int messageId, List<int> options) async {}
  @override
  Future<List<DeviceSession>> sessions() async => const [];
  @override
  Future<void> terminateSession(int id) async {}
  @override
  Future<ChatSummary?> createGroup(String title, List<int> userIds) async => null;

  @override
  Future<void> forwardMessages(int toChatId, int fromChatId, List<int> ids) async {}
  @override
  Stream<ChatStatus> watchChatStatus(int chatId) =>
      Stream.value(const ChatStatus(seen: SeenKind.recently));

  @override
  Stream<ContactChange> contactChanges() => const Stream.empty();

  @override
  Future<void> dispose() async {}
}
