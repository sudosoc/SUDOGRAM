import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Random keys kept in the Android Keystore (via flutter_secure_storage).
class KeyStore {
  KeyStore([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  static String _random() {
    final r = Random.secure();
    return base64.encode([for (var i = 0; i < 32; i++) r.nextInt(256)]);
  }

  Future<String?> read(String name) => _s.read(key: name);
  Future<void> write(String name, String value) =>
      _s.write(key: name, value: value);

  /// Returns the stored key, creating one on first use.
  Future<String> getOrCreate(String name) async {
    final existing = await _s.read(key: name);
    if (existing != null) return existing;
    final k = _random();
    await _s.write(key: name, value: k);
    return k;
  }

  String generate() => _random();
}
