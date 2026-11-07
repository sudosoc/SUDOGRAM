import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/telegram_gateway.dart';

/// Shares a live location: sends the message, then pushes position updates
/// until the period ends (works while the app is running).
class LiveLocation {
  LiveLocation._();
  static final Map<int, Timer> _subs = {};
  static final Map<int, Timer> _ends = {};

  static bool isActive(int chatId) => _subs.containsKey(chatId);

  static Future<void> stop(int chatId) async {
    _subs.remove(chatId)?.cancel();
    _ends.remove(chatId)?.cancel();
  }

  static Future<void> start(
    TelegramGateway g,
    int chatId,
    int minutes,
  ) async {
    await stop(chatId);
    final pos = await Geolocator.getCurrentPosition();
    final period = minutes * 60;
    Map<String, dynamic> loc(Position p) => {
      '@type': 'location',
      'latitude': p.latitude,
      'longitude': p.longitude,
      'horizontal_accuracy': p.accuracy,
    };
    await g.tdRaw({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageLocation',
        'location': loc(pos),
        'live_period': period,
        'heading': 0,
        'proximity_alert_radius': 0,
      },
    });
    // The sent message gets its final id a moment later.
    int? msgId;
    for (var i = 0; i < 25 && msgId == null; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final h = await g.tdRaw({
        '@type': 'getChatHistory',
        'chat_id': chatId,
        'from_message_id': 0,
        'offset': 0,
        'limit': 8,
        'only_local': true,
      });
      for (final m in (h['messages'] as List? ?? const []).whereType<Map>()) {
        final c = m['content'] as Map?;
        final sending = m['sending_state'] != null;
        if (m['is_outgoing'] == true &&
            c?['@type'] == 'messageLocation' &&
            ((c?['live_period'] as num?) ?? 0) > 0 &&
            !sending) {
          msgId = (m['id'] as num).toInt();
          break;
        }
      }
    }
    if (msgId == null) return;
    final id = msgId;
    // Telegram only shows movement when we keep editing the message, so
    // push a fresh fix every 10 s (moving or not).
    _subs[chatId] = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 8));
        await g.tdRaw({
          '@type': 'editMessageLiveLocation',
          'chat_id': chatId,
          'message_id': id,
          'location': loc(p),
          'live_period': 0,
          'heading': p.heading.isNaN ? 0 : p.heading.round().clamp(0, 360),
          'proximity_alert_radius': 0,
        });
      } catch (_) {}
    });
    _ends[chatId] = Timer(Duration(seconds: period), () => stop(chatId));
  }
}
