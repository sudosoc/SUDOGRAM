import 'package:flutter/material.dart';

import '../theme/glass.dart';
import 'icon_styles.dart';

/// Turns raw TDLib / platform errors into short readable text.
String friendlyError(Object e, {bool ar = false}) {
  final s = '$e';
  String pick(String en, String arabic) => ar ? arabic : en;
  final low = s.toLowerCase();
  if (low.contains('reaction') && low.contains('available')) {
    return pick('This reaction isn\'t allowed on this message',
        'التفاعل ده مش متاح على الرسالة دي');
  }
  if (low.contains('timeout') || low.contains('timed out')) {
    return pick('Request timed out, try again', 'انتهت المهلة، حاول تاني');
  }
  if (low.contains('network') || low.contains('socket')) {
    return pick('No connection', 'مفيش اتصال بالإنترنت');
  }
  if (low.contains('chat_write_forbidden') ||
      low.contains('not enough rights')) {
    return pick('You can\'t do that in this chat', 'مش مسموحلك بده في الشات ده');
  }
  if (low.contains('flood') || low.contains('too many requests')) {
    return pick('Too many requests, wait a moment', 'طلبات كتير، استنى شوية');
  }
  if (low.contains('message to edit not found') ||
      low.contains('message not found')) {
    return pick('Message no longer exists', 'الرسالة دي مبقتش موجودة');
  }
  final m = RegExp(r'TdError\((\d+)\):\s*(.*)').firstMatch(s);
  if (m != null) return m.group(2) ?? s;
  return s.replaceFirst('Exception: ', '').replaceFirst('StateError: ', '');
}

enum NoticeKind { info, success, error, premium }

/// Pretty floating notice used instead of plain SnackBars.
void notice(BuildContext context, String text,
    {NoticeKind kind = NoticeKind.info, Duration? duration}) {
  final (icon, color) = switch (kind) {
    NoticeKind.success => (Icons.check_circle_rounded, const Color(0xFF34C759)),
    NoticeKind.error => (Icons.error_rounded, const Color(0xFFFF453A)),
    NoticeKind.premium => (Icons.auto_awesome_rounded, const Color(0xFFFFC53D)),
    NoticeKind.info => (Icons.info_rounded, const Color(0xFF64B5F6)),
  };
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    duration: duration ?? const Duration(seconds: 3),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    padding: EdgeInsets.zero,
    content: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: [
          color.withValues(alpha: 0.28),
          const Color(0xEE1C1C22),
        ]),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
      ),
      child: Row(children: [
        SIcon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: GlassTokens.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
    ),
  ));
}
