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
  GhostGateway(
    this._inner, {
    required this.isGhost,
    required this.globalGhost,
    this.blocksRead,
    this.blocksTyping,
    this.blocksOnline,
  });

  /// Optional finer policies; default to [isGhost] / [globalGhost].
  final GhostPolicy? blocksRead;
  final GhostPolicy? blocksTyping;
  final bool Function()? blocksOnline;

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
    if ((blocksRead ?? isGhost)(chatId)) return;
    await _inner.markRead(chatId, messageIds);
  }

  @override
  Future<void> sendTyping(int chatId) async {
    if ((blocksTyping ?? isGhost)(chatId)) return;
    await _inner.sendTyping(chatId);
  }

  @override
  Future<void> setOnline(bool online) async {
    // While ghost is on globally we never appear online.
    if (online && (blocksOnline ?? globalGhost)()) {
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
  Future<List<ChatSummary>> contacts() => _inner.contacts();

  @override
  Future<ChatSummary?> openPrivateChat(int userId) =>
      _inner.openPrivateChat(userId);

  @override
  Future<ChatSummary?> savedMessages() => _inner.savedMessages();

  @override
  Future<List<ChatMessage>> searchChat(int chatId, String query) =>
      _inner.searchChat(chatId, query);

  @override
  Future<ChatMessage?> pinnedMessage(int chatId) =>
      _inner.pinnedMessage(chatId);

  @override
  Future<void> toggleReaction(int chatId, int messageId, String emoji,
          {required bool on}) =>
      _inner.toggleReaction(chatId, messageId, emoji, on: on);

  @override
  Future<ChatInfo?> chatInfo(int chatId) => _inner.chatInfo(chatId);

  @override
  Stream<List<ChatSummary>> watchArchived() => _inner.watchArchived();

  @override
  Future<void> setArchived(int chatId, bool archived) =>
      _inner.setArchived(chatId, archived);

  @override
  Future<void> votePoll(int chatId, int messageId, List<int> options) =>
      _inner.votePoll(chatId, messageId, options);

  @override
  Future<List<DeviceSession>> sessions() => _inner.sessions();

  @override
  Future<void> terminateSession(int id) => _inner.terminateSession(id);

  @override
  Future<ChatSummary?> createGroup(String title, List<int> userIds) =>
      _inner.createGroup(title, userIds);

  @override
  Future<List<MentionCandidate>> searchMembers(int chatId, String query) =>
      _inner.searchMembers(chatId, query);

  @override
  Future<String> getPrivacy(String key) => _inner.getPrivacy(key);

  @override
  Future<void> setPrivacy(String key, String value) =>
      _inner.setPrivacy(key, value);

  @override
  Future<ChatSummary?> createSecretChat(int userId) =>
      _inner.createSecretChat(userId);

  @override
  Future<void> setAutoDelete(int chatId, int seconds) =>
      _inner.setAutoDelete(chatId, seconds);

  @override
  Future<ProfileInfo?> me() => _inner.me();

  @override
  Future<void> updateProfile({String? firstName, String? lastName, String? bio}) =>
      _inner.updateProfile(firstName: firstName, lastName: lastName, bio: bio);

  @override
  Future<bool> setUsername(String username) => _inner.setUsername(username);

  @override
  Future<void> setProfilePhoto(String path) => _inner.setProfilePhoto(path);

  @override
  Future<void> logOut() => _inner.logOut();

  @override
  Future<void> setMuted(int chatId, bool muted) => _inner.setMuted(chatId, muted);

  @override
  Future<void> clearHistory(int chatId) => _inner.clearHistory(chatId);

  @override
  Future<void> leaveChat(int chatId) => _inner.leaveChat(chatId);

  @override
  Future<void> blockUser(int userId, bool blocked) =>
      _inner.blockUser(userId, blocked);

  @override
  Future<void> sendVoice(int chatId, String path, int seconds) =>
      _inner.sendVoice(chatId, path, seconds);

  @override
  Future<ChatSummary?> joinByLink(String link) => _inner.joinByLink(link);

  @override
  Future<List<ChatSummary>> blockedUsers() => _inner.blockedUsers();

  @override
  Future<List<ChatMessage>> searchGlobal(String query) =>
      _inner.searchGlobal(query);

  @override
  Future<bool> hasCloudPassword() => _inner.hasCloudPassword();

  @override
  Future<bool> setCloudPassword(
          {String oldPassword = '', String newPassword = '', String hint = ''}) =>
      _inner.setCloudPassword(
          oldPassword: oldPassword, newPassword: newPassword, hint: hint);

  @override
  Future<List<StickerSetInfo>> stickerSets() => _inner.stickerSets();

  @override
  Future<List<StickerItem>> stickerSetItems(int setId) =>
      _inner.stickerSetItems(setId);

  @override
  Future<String?> fetchFile(int fileId) => _inner.fetchFile(fileId);

  @override
  Future<void> sendSticker(int chatId, StickerItem sticker) =>
      _inner.sendSticker(chatId, sticker);

  @override
  Future<List<MentionCandidate>> members(int chatId) => _inner.members(chatId);

  @override
  Future<void> addMember(int chatId, int userId) =>
      _inner.addMember(chatId, userId);

  @override
  Future<void> removeMember(int chatId, int userId) =>
      _inner.removeMember(chatId, userId);

  @override
  Future<void> pinMessage(int chatId, int messageId, {required bool pin}) =>
      _inner.pinMessage(chatId, messageId, pin: pin);

  @override
  Future<void> sendPoll(int chatId, String question, List<String> options,
          {bool multiple = false, bool anonymous = true}) =>
      _inner.sendPoll(chatId, question, options,
          multiple: multiple, anonymous: anonymous);

  @override
  Future<void> sendLocation(int chatId, double lat, double lon) =>
      _inner.sendLocation(chatId, lat, lon);

  @override
  Future<void> sendContact(int chatId, int userId) =>
      _inner.sendContact(chatId, userId);

  @override
  Future<List<StickerItem>> savedGifs() => _inner.savedGifs();

  @override
  Future<void> sendGif(int chatId, StickerItem gif) =>
      _inner.sendGif(chatId, gif);

  @override
  Future<void> resend(int chatId, int messageId) => _inner.resend(chatId, messageId);

  @override
  Future<void> markUnread(int chatId, bool unread) =>
      _inner.markUnread(chatId, unread);

  @override
  Future<void> scheduleText(int chatId, String text, DateTime at) =>
      _inner.scheduleText(chatId, text, at);

  @override
  Future<List<ChatMessage>> scheduledMessages(int chatId) =>
      _inner.scheduledMessages(chatId);

  @override
  Future<void> loadAround(int chatId, int messageId) =>
      _inner.loadAround(chatId, messageId);

  @override
  Future<List<ChatMessage>> sharedMedia(int chatId, String filter) =>
      _inner.sharedMedia(chatId, filter);

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
