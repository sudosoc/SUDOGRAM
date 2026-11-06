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
    _contactSub = _inner.contactChanges().listen((c) => archive
        .logContactChange(c.userId, c.displayName, c.field, c.oldValue, c.newValue));
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
  Future<void> sendMedia(int chatId, List<String> paths, {String caption = ''}) =>
      _inner.sendMedia(chatId, paths, caption: caption);
  @override
  Future<bool> loadOlder(int chatId) => _inner.loadOlder(chatId);
  @override
  Future<void> editText(int chatId, int messageId, String text) =>
      _inner.editText(chatId, messageId, text);
  @override
  Future<void> deleteMessages(int chatId, List<int> ids, {bool forAll = false}) {
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
  Future<void> forwardMessages(int toChatId, int fromChatId, List<int> ids) =>
      _inner.forwardMessages(toChatId, fromChatId, ids);
  @override
  Stream<ChatStatus> watchChatStatus(int chatId) => _inner.watchChatStatus(chatId);
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
