import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/audio_hub.dart';
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

  /// Called with the chat id when a message notification is tapped.
  void Function(int chatId)? onOpen;

  /// Chats that must never be opened from a notification tap.
  Set<int> noOpen = const {};

  Future<void> init() async {
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (r) {
          if ((r.actionId ?? '').startsWith('audio_')) {
            AudioHub.instance.handleAction(r.actionId!);
            return;
          }
          final id = int.tryParse(r.payload ?? '');
          if (id != null) onOpen?.call(id);
        },
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      AudioHub.instance.onNotify = showAudio;
      AudioHub.instance.onClearNotify = () => _plugin.cancel(_audioId);
      _ready = true;
    } catch (e) {
      debugPrint('notifications init failed: $e');
    }
  }

  static const _audioId = 1999999990;

  void showAudio(String title, bool playing) {
    if (!_ready) return;
    _plugin.show(
      _audioId,
      title,
      playing ? 'Playing' : 'Paused',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'sudogram_audio',
          'Voice playback',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: playing,
          playSound: false,
          enableVibration: false,
          onlyAlertOnce: true,
          category: AndroidNotificationCategory.transport,
          actions: [
            AndroidNotificationAction('audio_toggle', playing ? 'Pause' : 'Play'),
            const AndroidNotificationAction('audio_stop', 'Stop', cancelNotification: true),
          ],
        ),
      ),
    );
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
    String content = 'full',
    Map<String, Map<String, dynamic>> perChat = const {},
    bool locked = false,
    String Function(int n)? countBody,
    Set<int> noOpen = const {},
  }) {
    this.noOpen = noOpen;
    final first = _lastUnread.isEmpty;
    for (final c in chats) {
      final before = _lastUnread[c.id];
      _lastUnread[c.id] = c.unread;
      if (first || before == null || !enabled || !_ready) continue;
      if (c.unread <= before || c.muted || c.lastOutgoing) continue;
      if (c.id == openChat || silentIds.contains(c.id)) continue;
      final hidden = privateIds.contains(c.id);
      final pc = perChat['${c.id}'] ?? const <String, dynamic>{};
      if (pc['mute'] == true) continue;
      var mode = !preview ? 'generic' : content;
      if (locked) mode = 'generic';
      if (hidden) mode = 'generic';
      final title = hidden || mode == 'generic' || mode == 'count'
          ? 'SUDOGRAM'
          : c.title;
      final body = switch (mode) {
        'nameOnly' => hiddenBody,
        'count' => (countBody ?? (n) => '$n')(c.unread),
        'generic' => hiddenBody,
        _ => c.lastText.isEmpty ? '…' : c.lastText,
      };
      final snd = (pc['sound'] as String?) ?? (sound ? 'default' : 'silent');
      final vib = (pc['vib'] as String?) ?? (vibrate ? 'default' : 'none');
      _plugin.show(
        c.id.abs() % 2000000000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            // Channel settings are fixed once created, so each combination
            // of sound / vibration gets its own channel.
            'sudogram_m_${snd}_$vib',
            'Messages ($snd / $vib)',
            importance: Importance.high,
            priority: Priority.high,
            playSound: snd != 'silent',
            sound: _sound(snd),
            enableVibration: vib != 'none',
            vibrationPattern: _pattern(vib),
          ),
        ),
        payload: noOpen.contains(c.id) ? null : '${c.id}',
      );
    }
  }

  static AndroidNotificationSound? _sound(String k) => switch (k) {
    'notification' => const UriAndroidNotificationSound(
      'content://settings/system/notification_sound',
    ),
    'ringtone' => const UriAndroidNotificationSound(
      'content://settings/system/ringtone',
    ),
    'alarm' => const UriAndroidNotificationSound(
      'content://settings/system/alarm_alert',
    ),
    _ => null,
  };

  static Int64List? _pattern(String k) => switch (k) {
    'short' => Int64List.fromList([0, 120]),
    'long' => Int64List.fromList([0, 900]),
    'double' => Int64List.fromList([0, 150, 120, 150]),
    'triple' => Int64List.fromList([0, 120, 100, 120, 100, 120]),
    _ => null,
  };

  /// Plays a one-off notification so the user can feel/hear a combination.
  Future<void> preview(
    String snd,
    String vib,
    String title,
    String body,
  ) async {
    if (!_ready) return;
    await _plugin.show(
      1999999999,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'sudogram_m_${snd}_$vib',
          'Messages ($snd / $vib)',
          importance: Importance.high,
          priority: Priority.high,
          playSound: snd != 'silent',
          sound: _sound(snd),
          enableVibration: vib != 'none',
          vibrationPattern: _pattern(vib),
        ),
      ),
    );
  }
}
