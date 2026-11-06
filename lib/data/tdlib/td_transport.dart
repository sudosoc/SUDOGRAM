/// Thin abstraction over a TDLib JSON client, so the gateway can be tested
/// with a scripted fake instead of the native library.
abstract class TdTransport {
  /// Every object TDLib sends that is not the answer to a [request].
  Stream<Map<String, dynamic>> get updates;

  /// Sends [req] and completes with TDLib's answer. Completes with a
  /// [TdError] when TDLib answers with an `error` object.
  Future<Map<String, dynamic>> request(
    Map<String, dynamic> req, {
    Duration timeout = const Duration(seconds: 60),
  });

  /// Sends [req] and ignores the answer.
  void fire(Map<String, dynamic> req);

  Future<void> close();
}

class TdError implements Exception {
  TdError(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'TdError($code): $message';
}

/// TDLib serializes int64 as a JSON string and smaller ints as numbers.
int asInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}
