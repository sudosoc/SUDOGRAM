import 'package:flutter_test/flutter_test.dart';
import 'package:sudogram/domain/ghost_gateway.dart';
import 'package:sudogram/domain/models.dart';
import 'package:sudogram/domain/telegram_gateway.dart';

class _Recorder implements TelegramGateway {
  final calls = <String>[];

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
  Future<void> sendText(int chatId, String text) async =>
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
