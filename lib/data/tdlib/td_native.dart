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

/// Runs in a background isolate: blocks on `td_receive` so the UI isolate
/// never waits, decodes JSON there and forwards plain maps.
Future<void> _receiveLoop(SendPort toMain) async {
  final commands = ReceivePort();
  toMain.send(commands.sendPort);
  var running = true;
  commands.listen((message) {
    if (message == 'stop') running = false;
  });

  final bindings = TdBindings.open();
  while (running) {
    final ptr = bindings.receive(0.5);
    if (ptr.address != 0) {
      final raw = ptr.toDartString(); // copy before the next td_receive call
      try {
        toMain.send(jsonDecode(raw));
      } catch (_) {
        // Ignore a malformed object rather than killing the loop.
      }
    }
    await Future<void>.delayed(Duration.zero); // let 'stop' be processed
  }
  commands.close();
}

/// [TdTransport] backed by the real native library.
class NativeTdTransport implements TdTransport {
  NativeTdTransport._(
      this._bindings, this._clientId, this._isolate, this._fromIsolate);

  final TdBindings _bindings;
  final int _clientId;
  final Isolate _isolate;
  final ReceivePort _fromIsolate;
  SendPort? _commands;

  final _updates = StreamController<Map<String, dynamic>>.broadcast();
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _nextExtra = 1;

  static Future<NativeTdTransport> start() async {
    final bindings = TdBindings.open();

    final level =
        '{"@type":"setLogVerbosityLevel","new_verbosity_level":1}'.toNativeUtf8();
    bindings.execute(level);
    malloc.free(level);

    final clientId = bindings.createClientId();
    final fromIsolate = ReceivePort();
    final isolate = await Isolate.spawn(_receiveLoop, fromIsolate.sendPort);
    final transport =
        NativeTdTransport._(bindings, clientId, isolate, fromIsolate);
    fromIsolate.listen(transport._onMessage);
    // TDLib only starts producing updates after the first request.
    transport.fire({'@type': 'getOption', 'name': 'version'});
    return transport;
  }

  void _onMessage(dynamic message) {
    if (message is SendPort) {
      _commands = message;
      return;
    }
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
    _updates.add(map);
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
    _commands?.send('stop');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _isolate.kill(priority: Isolate.beforeNextEvent);
    _fromIsolate.close();
    await _updates.close();
  }
}
