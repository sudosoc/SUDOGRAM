import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/models.dart';

/// Local notifications for new incoming messages. Works while the app
/// process is alive (the foreground service keeps it so); there is no push
/// from Google, so nothing arrives after the system kills the process.
class MessageNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _lastUnread = <int, int>{};
  bool _ready = false;

  /// Chat currently on screen: never notified.
  int? openChat;

  Future<void> init() async {
    try {
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ));
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('notifications init failed: $e');
    }
  }

  /// Call on every chat-list emission. [privateIds] get a generic body
  /// (hidden chats must not leak previews onto the lock screen).
  void onChats(
    List<ChatSummary> chats, {
    required bool enabled,
    required Set<int> privateIds,
    required String hiddenBody,
    Set<int> silentIds = const {},
    bool sound = true,
    bool vibrate = true,
    bool preview = true,
  }) {
    final first = _lastUnread.isEmpty;
    for (final c in chats) {
      final before = _lastUnread[c.id];
      _lastUnread[c.id] = c.unread;
      if (first || before == null || !enabled || !_ready) continue;
      if (c.unread <= before || c.muted || c.lastOutgoing) continue;
      if (c.id == openChat || silentIds.contains(c.id)) continue;
      final hidden = privateIds.contains(c.id);
      _plugin.show(
        c.id.abs() % 2000000000,
        hidden ? 'SUDOGRAM' : c.title,
        hidden || !preview
            ? hiddenBody
            : (c.lastText.isEmpty ? '…' : c.lastText),
        NotificationDetails(
          android: AndroidNotificationDetails(
            // Channel settings are fixed once created, so each combination
            // of sound / vibration gets its own channel.
            'sudogram_messages_${sound ? 1 : 0}${vibrate ? 1 : 0}',
            'Messages',
            importance: Importance.high,
            priority: Priority.high,
            playSound: sound,
            enableVibration: vibrate,
          ),
        ),
      );
    }
  }
}
