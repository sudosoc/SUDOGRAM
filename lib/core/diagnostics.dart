import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Tiny persistent error log so a crash can be diagnosed later.
class CrashLog {
  static File? _f;

  static Future<void> init() async {
    try {
      final d = await getApplicationSupportDirectory();
      _f = File('${d.path}/errors.log');
      if (_f!.existsSync() && _f!.lengthSync() > 200 * 1024) {
        final t = _f!.readAsStringSync();
        _f!.writeAsStringSync(t.substring(t.length - 100 * 1024));
      }
      _f!.writeAsStringSync('--- start ${DateTime.now().toIso8601String()}\n',
          mode: FileMode.append);
    } catch (_) {}
  }

  static void write(String kind, Object e, StackTrace? st) {
    try {
      final s = st?.toString().split('\n').take(8).join('\n') ?? '';
      _f?.writeAsStringSync(
          '[${DateTime.now().toIso8601String()}] $kind: $e\n$s\n',
          mode: FileMode.append);
    } catch (_) {}
  }

  static String read() {
    try {
      final t = _f?.readAsStringSync() ?? '';
      return t.length > 20000 ? t.substring(t.length - 20000) : t;
    } catch (_) {
      return '';
    }
  }

  static void clear() {
    try {
      _f?.writeAsStringSync('');
    } catch (_) {}
  }
}

const _ch = MethodChannel('sudogram/window');

const _reasons = {
  0: 'UNKNOWN', 1: 'EXIT_SELF', 2: 'SIGNALED (killed)', 3: 'LOW_MEMORY',
  4: 'CRASH (Java/Dart)', 5: 'CRASH_NATIVE', 6: 'ANR (not responding)',
  7: 'INITIALIZATION_FAILURE', 8: 'PERMISSION_CHANGE', 9: 'EXCESSIVE_RESOURCE_USAGE',
  10: 'USER_REQUESTED', 11: 'USER_STOPPED', 12: 'DEPENDENCY_DIED', 13: 'OTHER',
  14: 'FREEZER', 15: 'PACKAGE_STATE_CHANGE', 16: 'PACKAGE_UPDATED',
};

class ExitInfo {
  ExitInfo(this.time, this.reason, this.desc, this.status);
  final DateTime time;
  final String reason;
  final String desc;
  final int status;
}

/// Why Android ended the app process recently (Android 11+).
Future<List<ExitInfo>> recentExits() async {
  try {
    final r = await _ch.invokeMethod<List<Object?>>('exitReasons') ?? const [];
    return [
      for (final e in r.whereType<Map>())
        ExitInfo(
          DateTime.fromMillisecondsSinceEpoch((e['time'] as num).toInt()),
          _reasons[(e['reason'] as num).toInt()] ?? 'reason ${e['reason']}',
          (e['desc'] ?? '').toString(),
          (e['status'] as num?)?.toInt() ?? 0,
        ),
    ];
  } catch (_) {
    return const [];
  }
}

Future<bool> openBatterySettings() async {
  try {
    return await _ch.invokeMethod<bool>('openBatterySettings') ?? false;
  } catch (_) {
    return false;
  }
}
