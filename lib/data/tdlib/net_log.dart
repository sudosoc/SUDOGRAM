import 'dart:async';

import 'package:flutter/foundation.dart';

import 'td_transport.dart';

class NetEntry {
  NetEntry(this.type, this.at, this.ms, this.error);
  final String type;
  final DateTime at;
  final int ms;
  final String? error;
}

/// In-memory record of what the client is doing on the network: connection
/// state and recent TDLib requests with timing. Never stores payloads, so it
/// cannot leak message content.
class NetLog extends ChangeNotifier {
  final entries = <NetEntry>[];
  String connection = '—';
  int requests = 0;
  int errors = 0;

  void add(NetEntry e) {
    entries.insert(0, e);
    if (entries.length > 200) entries.removeLast();
    requests++;
    if (e.error != null) errors++;
    notifyListeners();
  }

  void setConnection(String s) {
    connection = s;
    notifyListeners();
  }
}

class LoggingTransport implements TdTransport {
  LoggingTransport(this._inner, this.log);

  final TdTransport _inner;
  final NetLog log;

  @override
  Stream<Map<String, dynamic>> get updates => _inner.updates.map((u) {
        if (u['@type'] == 'updateConnectionState') {
          final st = (u['state'] as Map?)?['@type']?.toString() ?? '';
          log.setConnection(st.replaceFirst('connectionState', ''));
        }
        return u;
      });

  @override
  Future<Map<String, dynamic>> request(Map<String, dynamic> req,
      {Duration timeout = const Duration(seconds: 60)}) async {
    final sw = Stopwatch()..start();
    final type = req['@type'].toString();
    try {
      final r = await _inner.request(req, timeout: timeout);
      log.add(NetEntry(type, DateTime.now(), sw.elapsedMilliseconds, null));
      return r;
    } catch (e) {
      log.add(NetEntry(
          type, DateTime.now(), sw.elapsedMilliseconds, e.toString()));
      rethrow;
    }
  }

  @override
  void fire(Map<String, dynamic> req) {
    log.add(NetEntry(req['@type'].toString(), DateTime.now(), 0, null));
    _inner.fire(req);
  }

  @override
  Future<void> close() => _inner.close();
}
