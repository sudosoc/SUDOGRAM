import 'dart:async';

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

  @override
  Future<void> start() async {
    await _inner.start();
    _contactSub = _inner.contactChanges().listen((c) => archive
        .logContactChange(c.userId, c.displayName, c.field, c.oldValue, c.newValue));
  }

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
  Future<void> sendText(int id, String t) => _inner.sendText(id, t);
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
    await _inner.dispose();
  }

  @override
  Stream<List<ChatMessage>> watchMessages(int chatId) =>
      _inner.watchMessages(chatId).map((list) {
        final ids = <int>{};
        for (final m in list) {
          ids.add(m.id);
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
