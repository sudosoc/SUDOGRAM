import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unsent message text per chat, kept on this device only.
class DraftStore {
  static final _drafts = <int, String>{};
  static final changes = ValueNotifier<int>(0);
  static const _key = 'drafts_v1';

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    for (final e in p.getStringList(_key) ?? const <String>[]) {
      final i = e.indexOf(':');
      if (i > 0) {
        final id = int.tryParse(e.substring(0, i));
        if (id != null) _drafts[id] = Uri.decodeComponent(e.substring(i + 1));
      }
    }
    changes.value++;
  }

  static String get(int chatId) => _drafts[chatId] ?? '';

  static Future<void> set(int chatId, String text) async {
    if (text.trim().isEmpty) {
      _drafts.remove(chatId);
    } else {
      _drafts[chatId] = text;
    }
    changes.value++;
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, [
      for (final e in _drafts.entries) '${e.key}:${Uri.encodeComponent(e.value)}'
    ]);
  }
}
