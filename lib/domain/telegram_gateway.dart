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

  Future<void> sendText(int chatId, String text, {int replyTo = 0});

  /// Maximum text length of one message, as reported by the server.
  Future<int> messageTextLimit();

  // --- Calls that leak presence. Ghost Mode must be able to block these. ---

  /// Marks messages as read (sends a read receipt to the peer).
  Future<void> markRead(int chatId, List<int> messageIds);

  /// Shows "typing…" to the peer.
  Future<void> sendTyping(int chatId);

  /// Sets our online status.
  Future<void> setOnline(bool online);

  /// Loads an older page of history. Returns false when nothing older exists.
  Future<bool> loadOlder(int chatId);

  Future<void> editText(int chatId, int messageId, String text);

  /// [forAll] removes it for everyone where Telegram allows it.
  Future<void> deleteMessages(int chatId, List<int> ids, {bool forAll = false});

  Future<void> forwardMessages(int toChatId, int fromChatId, List<int> ids);

  /// Header status of a chat: someone typing, online, last seen.
  Stream<ChatStatus> watchChatStatus(int chatId);

  /// Starts (or resumes) downloading a file. Progress arrives through
  /// [watchMessages] as updated [Attachment]s.
  Future<void> downloadFile(int fileId);

  Future<void> cancelDownload(int fileId);

  /// Sends a local file as a document.
  Future<void> sendFile(int chatId, String path, {String caption = ''});

  /// Sends photos/videos. One item is a normal message; several become
  /// albums of up to 10 items each, sent in order.
  Future<void> sendMedia(int chatId, List<String> paths, {String caption = ''});

  /// Profile changes of contacts (name, username, phone) as they happen.
  Stream<ContactChange> contactChanges();

  /// Saved contacts, alphabetical.
  Future<List<ChatSummary>> contacts();

  /// Opens (creating if needed) the private chat with [userId].
  Future<ChatSummary?> openPrivateChat(int userId);

  /// The "Saved Messages" chat.
  Future<ChatSummary?> savedMessages();

  /// Server-side search inside one chat, newest first.
  Future<List<ChatMessage>> searchChat(int chatId, String query);

  /// The currently pinned message of a chat, if any.
  Future<ChatMessage?> pinnedMessage(int chatId);

  /// Adds or removes our emoji reaction on a message.
  Future<void> toggleReaction(int chatId, int messageId, String emoji,
      {required bool on});

  /// Profile / group details for the info page.
  Future<ChatInfo?> chatInfo(int chatId);

  /// Chats in the Archive folder.
  Stream<List<ChatSummary>> watchArchived();
  Future<void> setArchived(int chatId, bool archived);

  Future<void> votePoll(int chatId, int messageId, List<int> options);

  /// Logged-in devices (Telegram "Devices" page).
  Future<List<DeviceSession>> sessions();
  Future<void> terminateSession(int id);

  Future<ChatSummary?> createGroup(String title, List<int> userIds);

  /// Group members matching [query] for @mention suggestions.
  Future<List<MentionCandidate>> searchMembers(int chatId, String query);

  /// Privacy setting: [key] is phone|seen|photo|calls|invites|forwards,
  /// value is everybody|contacts|nobody.
  Future<String> getPrivacy(String key);
  Future<void> setPrivacy(String key, String value);

  /// Starts an end-to-end encrypted secret chat with [userId].
  Future<ChatSummary?> createSecretChat(int userId);

  /// Self-destruct timer for new messages (0 = off).
  Future<void> setAutoDelete(int chatId, int seconds);

  Future<void> dispose();
}
