import 'models.dart';

/// Everything the UI needs from Telegram. Implementations: the real TDLib
/// gateway, an in-memory mock for demos and tests, and [GhostGateway], a
/// decorator that blocks presence-leaking calls.
abstract class TelegramGateway {
  /// True for the in-memory demo gateway.
  bool get isDemo;

  Stream<AuthState> get authState;

  /// Starts the client. Safe to call once.
  Future<void> start();

  Future<void> submitPhone(String phone);
  Future<void> submitCode(String code);
  Future<void> submitPassword(String password);

  /// Emits the full, ordered chat list on every change.
  Stream<List<ChatSummary>> watchChats();

  /// Emits messages for a chat, newest first, on every change.
  Stream<List<ChatMessage>> watchMessages(int chatId);

  Future<void> openChat(int chatId);
  Future<void> closeChat(int chatId);

  Future<void> sendText(int chatId, String text);

  /// Maximum text length of one message, as reported by the server.
  Future<int> messageTextLimit();

  // --- Calls that leak presence. Ghost Mode must be able to block these. ---

  /// Marks messages as read (sends a read receipt to the peer).
  Future<void> markRead(int chatId, List<int> messageIds);

  /// Shows "typing…" to the peer.
  Future<void> sendTyping(int chatId);

  /// Sets our online status.
  Future<void> setOnline(bool online);

  Future<void> dispose();
}
