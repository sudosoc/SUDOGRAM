import 'package:flutter_test/flutter_test.dart';
import 'package:sudogram/domain/ghost_gateway.dart';
import 'package:sudogram/domain/models.dart';
import 'package:sudogram/domain/telegram_gateway.dart';

class _Recorder implements TelegramGateway {
  final calls = <String>[];

  @override
  Future<List<ChatSummary>> contacts() async => const [];
  @override
  Future<ChatSummary?> openPrivateChat(int userId) async => null;
  @override
  Future<ChatSummary?> savedMessages() async => null;
  @override
  Future<List<ChatMessage>> searchChat(int chatId, String query) async => const [];
  @override
  Future<ChatMessage?> pinnedMessage(int chatId) async => null;
  @override
  Future<void> toggleReaction(int chatId, int messageId, String emoji,
      {required bool on}) async {}
  @override
  Future<ChatInfo?> chatInfo(int chatId) async => null;
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
  Future<List<MentionCandidate>> searchMembers(int chatId, String query) async => const [];
  @override
  Future<String> getPrivacy(String key) async => 'everybody';
  @override
  Future<void> setPrivacy(String key, String value) async {}
  @override
  Future<ChatSummary?> createSecretChat(int userId) async => null;
  @override
  Future<void> setAutoDelete(int chatId, int seconds) async {}
  @override
  Future<ProfileInfo?> me() async => const ProfileInfo(id: 0);
  @override
  Future<void> updateProfile({String? firstName, String? lastName, String? bio}) async {}
  @override
  Future<bool> setUsername(String username) async => true;
  @override
  Future<void> setProfilePhoto(String path) async {}
  @override
  Future<void> logOut() async {}
  @override
  Future<void> setMuted(int chatId, bool muted) async {}
  @override
  Future<void> clearHistory(int chatId) async {}
  @override
  Future<void> leaveChat(int chatId) async {}
  @override
  Future<void> blockUser(int userId, bool blocked) async {}
  @override
  Future<void> sendVoice(int chatId, String path, int seconds) async {}
  @override
  Future<ChatSummary?> joinByLink(String link) async => null;
  @override
  Future<List<ChatSummary>> blockedUsers() async => const [];
  @override
  Future<List<ChatMessage>> searchGlobal(String query) async => const [];
  @override
  Future<bool> hasCloudPassword() async => false;
  @override
  Future<bool> setCloudPassword(
          {String oldPassword = '', String newPassword = '', String hint = ''}) async => true;
  @override
  Future<List<StickerSetInfo>> stickerSets() async => const [];
  @override
  Future<List<StickerItem>> stickerSetItems(int setId) async => const [];
  @override
  Future<String?> fetchFile(int fileId) async => null;
  @override
  Future<void> sendSticker(int chatId, StickerItem sticker) async {}
  @override
  Future<List<MentionCandidate>> members(int chatId) async => const [];
  @override
  Future<void> addMember(int chatId, int userId) async {}
  @override
  Future<void> removeMember(int chatId, int userId) async {}
  @override
  bool get isDemo => true;
  @override
  Stream<AuthState> get authState => const Stream.empty();
  @override
  Future<void> start() async => calls.add('start');
  @override
  Future<void> submitPhone(String phone) async {}
  @override
  Future<void> submitCode(String code) async {}
  @override
  Future<void> submitPassword(String password) async {}
  @override
  Stream<List<ChatSummary>> watchChats() => const Stream.empty();
  @override
  Stream<List<ChatMessage>> watchMessages(int chatId) => const Stream.empty();
  @override
  Future<void> openChat(int chatId) async => calls.add('open:$chatId');
  @override
  Future<void> closeChat(int chatId) async => calls.add('close:$chatId');
  @override
  Future<void> sendText(int chatId, String text, {int replyTo = 0}) async =>
      calls.add('send:$chatId:$text');
  @override
  Future<int> messageTextLimit() async => 4096;
  @override
  Future<void> markRead(int chatId, List<int> messageIds) async =>
      calls.add('read:$chatId:${messageIds.join(",")}');
  @override
  Future<void> sendTyping(int chatId) async => calls.add('typing:$chatId');
  @override
  Future<void> setOnline(bool online) async => calls.add('online:$online');
  @override
  Future<void> downloadFile(int fileId) async {}
  @override
  Future<void> cancelDownload(int fileId) async {}
  @override
  Future<void> sendFile(int chatId, String path, {String caption = ''}) async {}
  @override
  Future<void> sendMedia(int chatId, List<String> paths, {String caption = ''}) async {}
  @override
  Future<bool> loadOlder(int chatId) async => false;
  @override
  Future<void> editText(int chatId, int messageId, String text) async {}
  @override
  Future<void> deleteMessages(int chatId, List<int> ids, {bool forAll = false}) async {}
  @override
  Future<void> forwardMessages(int toChatId, int fromChatId, List<int> ids) async {}
  @override
  Stream<ChatStatus> watchChatStatus(int chatId) => const Stream.empty();
  @override
  Stream<ContactChange> contactChanges() => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

void main() {
  group('GhostGateway', () {
    test('blocks read receipts and typing while ghost is on', () async {
      final inner = _Recorder();
      final ghost = GhostGateway(inner, isGhost: (_) => true, globalGhost: () => true);

      await ghost.markRead(1, [10, 11]);
      await ghost.sendTyping(1);

      expect(inner.calls, isEmpty);
    });

    test('forwards read receipts and typing when ghost is off', () async {
      final inner = _Recorder();
      final ghost = GhostGateway(inner, isGhost: (_) => false, globalGhost: () => false);

      await ghost.markRead(1, [10]);
      await ghost.sendTyping(1);

      expect(inner.calls, ['read:1:10', 'typing:1']);
    });

    test('per-chat policy only affects that chat', () async {
      final inner = _Recorder();
      final ghost =
          GhostGateway(inner, isGhost: (id) => id == 1, globalGhost: () => false);

      await ghost.markRead(1, [5]);
      await ghost.markRead(2, [6]);

      expect(inner.calls, ['read:2:6']);
    });

    test('never goes online while global ghost is on', () async {
      final inner = _Recorder();
      final ghost = GhostGateway(inner, isGhost: (_) => true, globalGhost: () => true);

      await ghost.setOnline(true);
      await ghost.setOnline(false);

      expect(inner.calls, ['online:false', 'online:false']);
    });

    test('online status passes through when ghost is off', () async {
      final inner = _Recorder();
      final ghost = GhostGateway(inner, isGhost: (_) => false, globalGhost: () => false);

      await ghost.setOnline(true);

      expect(inner.calls, ['online:true']);
    });

    test('sending and opening chats still work in ghost mode', () async {
      final inner = _Recorder();
      final ghost = GhostGateway(inner, isGhost: (_) => true, globalGhost: () => true);

      await ghost.openChat(3);
      await ghost.sendText(3, 'hi');
      await ghost.closeChat(3);

      expect(inner.calls, ['open:3', 'send:3:hi', 'close:3']);
    });
  });
}
