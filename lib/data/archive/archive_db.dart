import 'package:sqlite3/sqlite3.dart';

import '../../domain/models.dart';
import 'arabic_normalize.dart';

class EditRecord {
  const EditRecord(this.oldText, this.at);
  final String oldText;
  final DateTime at;
}

class SearchHit {
  const SearchHit(this.message, this.deleted);
  final ChatMessage message;
  final bool deleted;
}

/// Local, encrypted archive of everything we have seen: used for Anti-Delete,
/// edit history and offline full-text search (FTS5, Arabic-normalized).
class ArchiveDb {
  ArchiveDb._(this._db);

  final Database _db;

  /// Opens (or creates) the archive. [key] is the raw encryption key; pass
  /// null only in tests (unencrypted in-memory database).
  static ArchiveDb open(String path, {String? key}) {
    final db = sqlite3.open(path);
    if (key != null) {
      final escaped = key.replaceAll("'", "''");
      db.execute("PRAGMA key = '$escaped';");
    }
    final a = ArchiveDb._(db);
    a._migrate();
    return a;
  }

  static ArchiveDb inMemory() => ArchiveDb.open(':memory:');

  void _migrate() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS messages(
        chat_id INTEGER NOT NULL,
        msg_id INTEGER NOT NULL,
        text TEXT NOT NULL,
        kind INTEGER NOT NULL,
        outgoing INTEGER NOT NULL,
        time INTEGER NOT NULL,
        edited INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        PRIMARY KEY(chat_id, msg_id)
      );
      CREATE TABLE IF NOT EXISTS edits(
        chat_id INTEGER NOT NULL,
        msg_id INTEGER NOT NULL,
        old_text TEXT NOT NULL,
        at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS edits_msg ON edits(chat_id, msg_id);
      CREATE VIRTUAL TABLE IF NOT EXISTS fts USING fts5(
        norm, chat_id UNINDEXED, msg_id UNINDEXED, tokenize='unicode61'
      );
      CREATE TABLE IF NOT EXISTS contact_log(
        user_id INTEGER NOT NULL,
        field TEXT NOT NULL,
        old_value TEXT,
        new_value TEXT,
        at INTEGER NOT NULL
      );
    ''');
  }

  int _now() => DateTime.now().millisecondsSinceEpoch;

  ChatMessage _row(Row r) => ChatMessage(
        id: r['msg_id'] as int,
        chatId: r['chat_id'] as int,
        text: r['text'] as String,
        kind: MessageKind.values[r['kind'] as int],
        outgoing: (r['outgoing'] as int) == 1,
        time: DateTime.fromMillisecondsSinceEpoch(r['time'] as int),
        edited: (r['edited'] as int) == 1,
        deletedByPeer: r['deleted_at'] != null,
      );

  /// Stores a message. If its text changed since last seen, the previous text
  /// goes to the edit history. Returns true if an edit was recorded.
  bool upsert(ChatMessage m) {
    final existing = _db.select(
        'SELECT text FROM messages WHERE chat_id=? AND msg_id=?',
        [m.chatId, m.id]);
    var edited = false;
    if (existing.isEmpty) {
      _db.execute(
        'INSERT INTO messages(chat_id,msg_id,text,kind,outgoing,time,edited) '
        'VALUES(?,?,?,?,?,?,?)',
        [
          m.chatId,
          m.id,
          m.text,
          m.kind.index,
          m.outgoing ? 1 : 0,
          m.time.millisecondsSinceEpoch,
          m.edited ? 1 : 0,
        ],
      );
      _index(m.chatId, m.id, m.text);
      return false;
    }
    final old = existing.first['text'] as String;
    if (old != m.text && m.text.isNotEmpty) {
      _db.execute(
          'INSERT INTO edits(chat_id,msg_id,old_text,at) VALUES(?,?,?,?)',
          [m.chatId, m.id, old, _now()]);
      _db.execute(
          'UPDATE messages SET text=?, edited=1 WHERE chat_id=? AND msg_id=?',
          [m.text, m.chatId, m.id]);
      _db.execute('DELETE FROM fts WHERE chat_id=? AND msg_id=?',
          [m.chatId, m.id]);
      _index(m.chatId, m.id, m.text);
      edited = true;
    }
    return edited;
  }

  void _index(int chatId, int msgId, String text) {
    if (text.isEmpty) return;
    _db.execute('INSERT INTO fts(norm,chat_id,msg_id) VALUES(?,?,?)',
        [normalizeForSearch(text), chatId, msgId]);
  }

  void markDeleted(int chatId, int msgId) => _db.execute(
      'UPDATE messages SET deleted_at=? WHERE chat_id=? AND msg_id=? '
      'AND deleted_at IS NULL',
      [_now(), chatId, msgId]);

  List<EditRecord> editsFor(int chatId, int msgId) => [
        for (final r in _db.select(
            'SELECT old_text, at FROM edits WHERE chat_id=? AND msg_id=? '
            'ORDER BY at',
            [chatId, msgId]))
          EditRecord(r['old_text'] as String,
              DateTime.fromMillisecondsSinceEpoch(r['at'] as int)),
      ];

  /// Messages the peer deleted, kept for [chatId].
  List<ChatMessage> deletedIn(int chatId) => [
        for (final r in _db.select(
            'SELECT * FROM messages WHERE chat_id=? AND deleted_at IS NOT NULL',
            [chatId]))
          _row(r),
      ];

  /// Full-text search over everything archived. Every word is a prefix match.
  List<SearchHit> search(String query, {int limit = 50}) {
    final words = normalizeForSearch(query)
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.isNotEmpty);
    if (words.isEmpty) return const [];
    final match = words.map((w) => '"$w"*').join(' ');
    final rows = _db.select(
      'SELECT m.* FROM fts JOIN messages m '
      'ON m.chat_id=fts.chat_id AND m.msg_id=fts.msg_id '
      'WHERE fts MATCH ? ORDER BY m.time DESC LIMIT ?',
      [match, limit],
    );
    return [
      for (final r in rows) SearchHit(_row(r), r['deleted_at'] != null),
    ];
  }

  void logContactChange(int userId, String field, String? from, String? to) =>
      _db.execute(
          'INSERT INTO contact_log(user_id,field,old_value,new_value,at) '
          'VALUES(?,?,?,?,?)',
          [userId, field, from, to, _now()]);

  void close() => _db.close();
}
