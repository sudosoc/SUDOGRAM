import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';

/// Header status line: typing, online, last seen, or the chat kind.
String chatStatusText(AppLocalizations l, ChatStatus s, ChatType type) {
  if (s.typing) return l.typing;
  switch (s.seen) {
    case SeenKind.online:
      return l.online;
    case SeenKind.recently:
      return l.seenRecently;
    case SeenKind.lastWeek:
      return l.seenWeek;
    case SeenKind.lastMonth:
      return l.seenMonth;
    case SeenKind.at:
      final t = s.lastSeen;
      if (t == null) return '';
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      return l.seenAt('${t.day}/${t.month} $hh:$mm');
    case SeenKind.unknown:
      return type == ChatType.secret
          ? l.secretChat
          : type == ChatType.group
              ? l.groupLabel
              : type == ChatType.channel
                  ? l.channelLabel
                  : '';
  }
}
