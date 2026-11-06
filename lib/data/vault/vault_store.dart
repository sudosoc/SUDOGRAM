import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

class VaultItem {
  const VaultItem(this.id, this.title, this.body, this.time);
  final int id;
  final String title;
  final String body;
  final DateTime time;
}

/// Two encrypted databases with neutral names. Which one a passcode opens is
/// decided only by the key derived from it, so nothing on disk says which one
/// is real and which is the decoy (plausible deniability).
class VaultService {
  VaultService(this.dir, this.salt);

  final String dir;

  /// Random per-install salt (kept in the Keystore).
  final String salt;

  File _file(int i) => File('$dir/v$i.db');

  bool get isSetUp => _file(1).existsSync() && _file(2).existsSync();

  String _key(String pass) => sha256
      .convert(utf8.encode('$salt|sudogram-vault|$pass'))
      .toString();

  Database _open(File f, String key) {
    final db = sqlite3.open(f.path);
    try {
      db.execute("PRAGMA key = '$key';");
      db.execute(
          'CREATE TABLE IF NOT EXISTS items(id INTEGER PRIMARY KEY, '
          'title TEXT NOT NULL, body TEXT NOT NULL, time INTEGER NOT NULL)');
      return db;
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  /// Creates both databases. [decoyItems] are shown when [decoyPass] is used.
  void setUp(String realPass, String decoyPass,
      {List<(String, String)> decoyItems = const []}) {
    if (realPass == decoyPass) {
      throw ArgumentError('real and decoy passcodes must differ');
    }
    Directory(dir).createSync(recursive: true);
    _open(_file(1), _key(realPass)).close();
    final decoy = _open(_file(2), _key(decoyPass));
    for (final (t, b) in decoyItems) {
      decoy.execute('INSERT INTO items(title,body,time) VALUES(?,?,?)',
          [t, b, DateTime.now().millisecondsSinceEpoch]);
    }
    decoy.close();
  }

  /// Returns an open vault if [pass] matches either passcode, else null.
  VaultSession? unlock(String pass) {
    final key = _key(pass);
    for (final i in [1, 2]) {
      final f = _file(i);
      if (!f.existsSync()) continue;
      try {
        final db = _open(f, key);
        db.select('SELECT count(*) FROM items'); // fails on a wrong key
        return VaultSession._(db);
      } catch (_) {}
    }
    return null;
  }
}

class VaultSession {
  VaultSession._(this._db);
  final Database _db;

  List<VaultItem> items() => [
        for (final r in _db.select('SELECT * FROM items ORDER BY time DESC'))
          VaultItem(r['id'] as int, r['title'] as String, r['body'] as String,
              DateTime.fromMillisecondsSinceEpoch(r['time'] as int)),
      ];

  void add(String title, String body) => _db.execute(
      'INSERT INTO items(title,body,time) VALUES(?,?,?)',
      [title, body, DateTime.now().millisecondsSinceEpoch]);

  void remove(int id) => _db.execute('DELETE FROM items WHERE id=?', [id]);

  void close() => _db.close();
}
