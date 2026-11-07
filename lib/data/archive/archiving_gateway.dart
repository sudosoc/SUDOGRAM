import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models.dart';
import '../../domain/telegram_gateway.dart';
import 'archive_db.dart';

/// Records everything the UI sees into the local archive and merges
/// peer-deleted messages back into the message list (Anti-Delete).
/// All other calls pass straight through.
class ArchivingGateway implements TelegramGateway {
  ArchivingGateway(this._inner, this.archive);

  final TelegramGateway _inner;
  final ArchiveDb archive;

  @override
  bool get isDemo => _inner.isDemo;
  @override
  Stream<AuthState> get authState => _inner.authState;
  StreamSubscription<ContactChange>? _contactSub;
  StreamSubscription<AuthState>? _authSub;
  final _files = <int, ChatMessage>{};

  /// Number of downloads still unfinished; drives the Android foreground
  /// service that keeps the app alive while files download.
  final ValueNotifier<int> pendingDownloads = ValueNotifier(0);

  @override
  Future<void> start() async {
    await _inner.start();
    pendingDownloads.value = archive.pendingDownloads().length;
    _authSub = _inner.authState.listen((a) {
      if (a.step == AuthStep.ready) {
        // Resume everything that was queued before the app was closed.
        for (final id in archive.pendingDownloads()) {
          _inner.downloadFile(id);
        }
      }
    });
    _contactSub = _inner.contactChanges().listen(
      (c) => archive.logContactChange(
        c.userId,
        c.displayName,
        c.field,
        c.oldValue,
        c.newValue,
      ),
    );
  }

  @override
  Future<void> downloadFile(int id) {
    final m = _files[id];
    if (m != null && m.file != null) {
      archive.enqueueDownload(id, m.chatId, m.id, m.file!.name, m.file!.size);
      pendingDownloads.value = archive.pendingDownloads().length;
    }
    return _inner.downloadFile(id);
  }

  @override
  Future<void> cancelDownload(int id) {
    archive.dropDownload(id);
    pendingDownloads.value = archive.pendingDownloads().length;
    return _inner.cancelDownload(id);
  }

  @override
  Future<void> sendFile(int chatId, String path, {String caption = ''}) =>
      _inner.sendFile(chatId, path, caption: caption);
  @override
  Future<void> sendMedia(
    int chatId,
    List<String> paths, {
    String caption = '',
  }) => _inner.sendMedia(chatId, paths, caption: caption);
  @override
  Future<bool> loadOlder(int chatId) => _inner.loadOlder(chatId);
  @override
  Future<void> editText(int chatId, int messageId, String text) =>
      _inner.editText(chatId, messageId, text);
  @override
  Future<void> deleteMessages(
    int chatId,
    List<int> ids, {
    bool forAll = false,
  }) {
    archive.forget(chatId, ids);
    return _inner.deleteMessages(chatId, ids, forAll: forAll);
  }

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
  Future<void> toggleReaction(
    int chatId,
    int messageId,
    String emoji, {
    required bool on,
  }) => _inner.toggleReaction(chatId, messageId, emoji, on: on);

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
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
  }) =>
      _inner.updateProfile(firstName: firstName, lastName: lastName, bio: bio);

  @override
  Future<bool> setUsername(String username) => _inner.setUsername(username);

  @override
  Future<void> setProfilePhoto(String path) => _inner.setProfilePhoto(path);

  @override
  Future<void> logOut() => _inner.logOut();

  @override
  Future<void> setMuted(int chatId, bool muted) =>
      _inner.setMuted(chatId, muted);

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
  Future<bool> setCloudPassword({
    String oldPassword = '',
    String newPassword = '',
    String hint = '',
  }) => _inner.setCloudPassword(
    oldPassword: oldPassword,
    newPassword: newPassword,
    hint: hint,
  );

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
  Future<void> sendPoll(
    int chatId,
    String question,
    List<String> options, {
    bool multiple = false,
    bool anonymous = true,
  }) => _inner.sendPoll(
    chatId,
    question,
    options,
    multiple: multiple,
    anonymous: anonymous,
  );

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
  Future<void> resend(int chatId, int messageId) =>
      _inner.resend(chatId, messageId);

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
  Future<List<ChatMessage>> pinnedMessages(int chatId) =>
      _inner.pinnedMessages(chatId);

  @override
  Future<List<String>> availableReactions(int chatId, int messageId) =>
      _inner.availableReactions(chatId, messageId);

  @override
  Future<void> markReadManual(int chatId, List<int> messageIds) =>
      _inner.markReadManual(chatId, messageIds);

  @override
  Future<void> terminateOtherSessions() => _inner.terminateOtherSessions();

  @override
  Future<int> sessionTtlDays() => _inner.sessionTtlDays();

  @override
  Future<void> setSessionTtlDays(int days) => _inner.setSessionTtlDays(days);

  @override
  Future<void> requestQrLogin() => _inner.requestQrLogin();

  @override
  Future<void> confirmQrLink(String link) => _inner.confirmQrLink(link);

  @override
  Future<ChatSummary?> resolveUsername(String username) =>
      _inner.resolveUsername(username);

  @override
  Future<void> resendCode() => _inner.resendCode();

  @override
  Future<PrivacyRule> getPrivacyRule(String key) => _inner.getPrivacyRule(key);

  @override
  Future<void> setPrivacyRule(String key, PrivacyRule rule) => _inner.setPrivacyRule(key, rule);

  @override
  Future<int> accountTtlDays() => _inner.accountTtlDays();

  @override
  Future<void> setAccountTtlDays(int days) => _inner.setAccountTtlDays(days);

  @override
  Future<int> autoDeleteSeconds() => _inner.autoDeleteSeconds();

  @override
  Future<void> setAutoDeleteSeconds(int seconds) => _inner.setAutoDeleteSeconds(seconds);

  @override
  Future<bool> archiveNewFromUnknown() => _inner.archiveNewFromUnknown();

  @override
  Future<void> setArchiveNewFromUnknown(bool on) => _inner.setArchiveNewFromUnknown(on);

  @override
  Future<void> markChatRead(int chatId) => _inner.markChatRead(chatId);

  @override
  Future<String?> bigProfilePhoto(int chatId) => _inner.bigProfilePhoto(chatId);

  @override
  Future<List<ChatSummary>> commonGroups(int userId) =>
      _inner.commonGroups(userId);

  @override
  Future<void> forwardMessages(int toChatId, int fromChatId, List<int> ids) =>
      _inner.forwardMessages(toChatId, fromChatId, ids);
  @override
  Stream<ChatStatus> watchChatStatus(int chatId) =>
      _inner.watchChatStatus(chatId);
  @override
  Stream<ContactChange> contactChanges() => _inner.contactChanges();
  @override
  Future<void> submitPhone(String p) => _inner.submitPhone(p);
  @override
  Future<void> submitCode(String c) => _inner.submitCode(c);
  @override
  Future<void> submitPassword(String p) => _inner.submitPassword(p);
  @override
  Stream<List<ChatSummary>> watchChats() => _inner.watchChats();
  @override
  Future<void> openChat(int id) => _inner.openChat(id);
  @override
  Future<void> closeChat(int id) => _inner.closeChat(id);
  @override
  Future<void> sendText(int id, String t, {int replyTo = 0}) =>
      _inner.sendText(id, t, replyTo: replyTo);
  @override
  Future<int> messageTextLimit() => _inner.messageTextLimit();
  @override
  Future<void> markRead(int c, List<int> ids) => _inner.markRead(c, ids);
  @override
  Future<void> sendTyping(int c) => _inner.sendTyping(c);
  @override
  Future<void> setOnline(bool o) => _inner.setOnline(o);
  @override
  Future<void> dispose() async {
    await _contactSub?.cancel();
    await _authSub?.cancel();
    await _inner.dispose();
  }

  @override
  Stream<List<ChatMessage>> watchMessages(int chatId) =>
      _inner.watchMessages(chatId).map((list) {
        final ids = <int>{};
        for (final m in list) {
          ids.add(m.id);
          final f = m.file;
          if (f != null) {
            _files[f.fileId] = m;
            if (f.downloaded) {
              archive.finishDownload(f.fileId);
              pendingDownloads.value = archive.pendingDownloads().length;
            }
          }
          if (m.deletedByPeer) {
            archive.upsert(m);
            archive.markDeleted(m.chatId, m.id);
          } else {
            archive.upsert(m);
          }
        }
        final kept = [
          for (final d in archive.deletedIn(chatId))
            if (!ids.contains(d.id)) d,
        ];
        if (kept.isEmpty) return list;
        return [...list, ...kept]..sort((a, b) => b.id.compareTo(a.id));
      });
}
