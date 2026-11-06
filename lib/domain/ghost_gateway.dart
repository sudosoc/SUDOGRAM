import 'models.dart';
import 'telegram_gateway.dart';

/// Decides whether Ghost Mode is active for a chat. A per-chat override wins
/// over the global switch.
typedef GhostPolicy = bool Function(int chatId);

/// Wraps a [TelegramGateway] and blocks every call that would reveal that we
/// read a chat, are typing, or are online, whenever Ghost Mode is active.
///
/// Everything else is forwarded untouched. There is deliberately no ad or
/// sponsored-message API in [TelegramGateway], so nothing here can fetch them.
class GhostGateway implements TelegramGateway {
  GhostGateway(this._inner, {required this.isGhost, required this.globalGhost});

  final TelegramGateway _inner;

  /// Per-chat decision (already combines override and global setting).
  final GhostPolicy isGhost;

  /// True when Ghost Mode is on globally (controls online status).
  final bool Function() globalGhost;

  @override
  bool get isDemo => _inner.isDemo;

  @override
  Stream<AuthState> get authState => _inner.authState;

  @override
  Future<void> start() => _inner.start();

  @override
  Future<void> submitPhone(String phone) => _inner.submitPhone(phone);

  @override
  Future<void> submitCode(String code) => _inner.submitCode(code);

  @override
  Future<void> submitPassword(String password) =>
      _inner.submitPassword(password);

  @override
  Stream<List<ChatSummary>> watchChats() => _inner.watchChats();

  @override
  Stream<List<ChatMessage>> watchMessages(int chatId) =>
      _inner.watchMessages(chatId);

  @override
  Future<void> openChat(int chatId) => _inner.openChat(chatId);

  @override
  Future<void> closeChat(int chatId) => _inner.closeChat(chatId);

  @override
  Future<void> sendText(int chatId, String text, {int replyTo = 0}) =>
      _inner.sendText(chatId, text, replyTo: replyTo);

  @override
  Future<int> messageTextLimit() => _inner.messageTextLimit();

  @override
  Future<void> markRead(int chatId, List<int> messageIds) async {
    if (isGhost(chatId)) return;
    await _inner.markRead(chatId, messageIds);
  }

  @override
  Future<void> sendTyping(int chatId) async {
    if (isGhost(chatId)) return;
    await _inner.sendTyping(chatId);
  }

  @override
  Future<void> setOnline(bool online) async {
    // While ghost is on globally we never appear online.
    if (online && globalGhost()) {
      await _inner.setOnline(false);
      return;
    }
    await _inner.setOnline(online);
  }

  @override
  Future<void> downloadFile(int id) => _inner.downloadFile(id);
  @override
  Future<void> cancelDownload(int id) => _inner.cancelDownload(id);
  @override
  Future<void> sendFile(int chatId, String path, {String caption = ''}) =>
      _inner.sendFile(chatId, path, caption: caption);
  @override
  Future<void> sendMedia(int chatId, List<String> paths, {String caption = ''}) =>
      _inner.sendMedia(chatId, paths, caption: caption);
  @override
  Future<bool> loadOlder(int chatId) => _inner.loadOlder(chatId);
  @override
  Future<void> editText(int chatId, int messageId, String text) =>
      _inner.editText(chatId, messageId, text);
  @override
  Future<void> deleteMessages(int chatId, List<int> ids, {bool forAll = false}) =>
      _inner.deleteMessages(chatId, ids, forAll: forAll);
  @override
  Future<void> forwardMessages(int toChatId, int fromChatId, List<int> ids) =>
      _inner.forwardMessages(toChatId, fromChatId, ids);
  @override
  Stream<ChatStatus> watchChatStatus(int chatId) => _inner.watchChatStatus(chatId);
  @override
  Stream<ContactChange> contactChanges() => _inner.contactChanges();

  @override
  Future<void> dispose() => _inner.dispose();
}
