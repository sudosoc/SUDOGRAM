// ignore_for_file: library_private_types_in_public_api
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'td_transport.dart';

typedef _CreateClientIdNative = Int32 Function();
typedef _CreateClientIdDart = int Function();
typedef _SendNative = Void Function(Int32, Pointer<Utf8>);
typedef _SendDart = void Function(int, Pointer<Utf8>);
typedef _ReceiveNative = Pointer<Utf8> Function(Double);
typedef _ReceiveDart = Pointer<Utf8> Function(double);
typedef _ExecuteNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _ExecuteDart = Pointer<Utf8> Function(Pointer<Utf8>);

/// Bindings to the TDLib JSON interface (`libtdjson`).
class TdBindings {
  TdBindings._(DynamicLibrary lib)
      : createClientId = lib.lookupFunction<_CreateClientIdNative,
            _CreateClientIdDart>('td_create_client_id'),
        send = lib.lookupFunction<_SendNative, _SendDart>('td_send'),
        receive =
            lib.lookupFunction<_ReceiveNative, _ReceiveDart>('td_receive'),
        execute =
            lib.lookupFunction<_ExecuteNative, _ExecuteDart>('td_execute');

  final _CreateClientIdDart createClientId;
  final _SendDart send;
  final _ReceiveDart receive;
  final _ExecuteDart execute;

  static String get libraryName {
    if (Platform.isWindows) return 'tdjson.dll';
    if (Platform.isMacOS || Platform.isIOS) return 'libtdjson.dylib';
    return 'libtdjson.so'; // Android and Linux
  }

  /// Throws if the native library is not bundled with the app.
  static TdBindings open() => TdBindings._(DynamicLibrary.open(libraryName));

  /// True when `libtdjson` can be loaded on this build.
  static bool get isAvailable {
    try {
      open();
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Runs in ONE background isolate for the whole process: `td_receive` is
/// global (not per client), so several accounts must share a single loop and
/// route updates by `@client_id`.
Future<void> _receiveLoop(SendPort toMain) async {
  final bindings = TdBindings.open();
  while (true) {
    final ptr = bindings.receive(0.5);
    if (ptr.address != 0) {
      final raw = ptr.toDartString(); // copy before the next td_receive call
      try {
        toMain.send(jsonDecode(raw));
      } catch (_) {
        // Ignore a malformed object rather than killing the loop.
      }
    } else {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

class _Hub {
  _Hub._();
  static _Hub? _i;
  final routes = <int, NativeTdTransport>{};

  static Future<_Hub> instance() async {
    final existing = _i;
    if (existing != null) return existing;
    final hub = _Hub._();
    final port = ReceivePort();
    await Isolate.spawn(_receiveLoop, port.sendPort);
    port.listen((m) {
      if (m is! Map) return;
      final id = m['@client_id'];
      if (id is int) hub.routes[id]?._onMessage(m);
    });
    _i = hub;
    return hub;
  }
}

/// [TdTransport] backed by the real native library.
class NativeTdTransport implements TdTransport {
  NativeTdTransport._(this._bindings, this._clientId);

  final TdBindings _bindings;
  final int _clientId;

  final _updates = StreamController<Map<String, dynamic>>.broadcast();
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  final _closed = Completer<void>();
  int _nextExtra = 1;

  static Future<NativeTdTransport> start() async {
    final bindings = TdBindings.open();

    final level =
        '{"@type":"setLogVerbosityLevel","new_verbosity_level":1}'.toNativeUtf8();
    bindings.execute(level);
    malloc.free(level);

    final hub = await _Hub.instance();
    final clientId = bindings.createClientId();
    final transport = NativeTdTransport._(bindings, clientId);
    hub.routes[clientId] = transport;
    // TDLib only starts producing updates after the first request.
    transport.fire({'@type': 'getOption', 'name': 'version'});
    return transport;
  }

  void _onMessage(dynamic message) {
    if (message is! Map) return;
    final map = Map<String, dynamic>.from(message);
    final extra = map['@extra'];
    if (extra is int) {
      final completer = _pending.remove(extra);
      if (completer != null) {
        if (map['@type'] == 'error') {
          completer.completeError(TdError(
            asInt(map['code']),
            (map['message'] ?? 'unknown error').toString(),
          ));
        } else {
          completer.complete(map);
        }
        return;
      }
    }
    if (map['@type'] == 'updateAuthorizationState' &&
        (map['authorization_state'] as Map?)?['@type'] ==
            'authorizationStateClosed' &&
        !_closed.isCompleted) {
      _closed.complete();
    }
    if (!_updates.isClosed) _updates.add(map);
  }

  @override
  Stream<Map<String, dynamic>> get updates => _updates.stream;

  @override
  void fire(Map<String, dynamic> req) {
    final ptr = jsonEncode(req).toNativeUtf8();
    _bindings.send(_clientId, ptr);
    malloc.free(ptr); // td_send copies the request
  }

  @override
  Future<Map<String, dynamic>> request(
    Map<String, dynamic> req, {
    Duration timeout = const Duration(seconds: 60),
  }) {
    final extra = _nextExtra++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[extra] = completer;
    fire({...req, '@extra': extra});
    return completer.future.timeout(timeout, onTimeout: () {
      _pending.remove(extra);
      throw TdError(408, 'request timed out: ${req['@type']}');
    });
  }

  @override
  Future<void> close() async {
    fire({'@type': 'close'});
    // Wait until TDLib has released its database before another client may
    // open the same folder (switching back to this account).
    await _closed.future.timeout(const Duration(seconds: 4), onTimeout: () {});
    (await _Hub.instance()).routes.remove(_clientId);
    await _updates.close();
  }
}
