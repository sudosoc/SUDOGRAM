import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// No-op handler: the service only exists so Android keeps the process (and
/// therefore TDLib's downloads) alive while the app is in the background.
class _IdleHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

@pragma('vm:entry-point')
void keepAliveCallback() => FlutterForegroundTask.setTaskHandler(_IdleHandler());

/// Starts a foreground service while [pending] > 0 and stops it at 0.
class DownloadKeepAlive {
  DownloadKeepAlive(this.pending,
      {required this.title,
      required this.text,
      this.keepConnected = _no,
      this.idleText = ''});

  static bool _no() => false;
  final bool Function() keepConnected;
  final String idleText;

  final ValueListenable<int> pending;
  final String title;
  final String Function(int count) text;
  bool _inited = false;

  void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sudogram_downloads',
        channelName: 'Downloads',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _inited = true;
    pending.addListener(_sync);
    _sync();
  }

  Future<void> refresh() => _sync();

  Future<void> _sync() async {
    if (!_inited) return;
    try {
      final n = pending.value;
      final running = await FlutterForegroundTask.isRunningService;
      final want = n > 0 || keepConnected();
      final label = n > 0 ? text(n) : idleText;
      if (want) {
        if (await FlutterForegroundTask.checkNotificationPermission() !=
            NotificationPermission.granted) {
          await FlutterForegroundTask.requestNotificationPermission();
        }
        if (running) {
          await FlutterForegroundTask.updateService(
              notificationTitle: title, notificationText: label);
        } else {
          await FlutterForegroundTask.startService(
            serviceId: 4711,
            notificationTitle: title,
            notificationText: label,
            callback: keepAliveCallback,
          );
        }
      } else if (running) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('keep-alive failed: $e');
    }
  }

  void dispose() => pending.removeListener(_sync);
}
