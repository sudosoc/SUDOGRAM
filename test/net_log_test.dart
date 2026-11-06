import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudogram/data/tdlib/net_log.dart';
import 'package:sudogram/data/tdlib/td_transport.dart';

class _T implements TdTransport {
  final c = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  @override
  Stream<Map<String, dynamic>> get updates => c.stream;
  @override
  Future<Map<String, dynamic>> request(Map<String, dynamic> req,
      {Duration timeout = const Duration(seconds: 60)}) async {
    if (req['@type'] == 'bad') throw TdError(400, 'nope');
    return {'@type': 'ok'};
  }

  @override
  void fire(Map<String, dynamic> req) {}
  @override
  Future<void> close() async {}
}

void main() {
  test('logs requests, errors and connection state without payloads', () async {
    final log = NetLog();
    final t = LoggingTransport(_T(), log);
    t.updates.listen((_) {});
    await t.request({'@type': 'getMe', 'secret': 'x'});
    await t.request({'@type': 'bad'}).then((_) {}, onError: (_) {});
    expect(log.requests, 2);
    expect(log.errors, 1);
    expect(log.entries.first.type, 'bad');
  });
}
