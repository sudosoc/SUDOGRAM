/// Risk level shown as a colored ring around a chat avatar.
/// `none` means no assessment exists (the ring is not drawn).
enum RiskLevel { none, safe, caution, danger }

enum MessageKind { text, photo, video, voice, document, sticker, other }

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.title,
    required this.lastText,
    required this.lastKind,
    required this.lastTime,
    required this.unread,
    this.order = 0,
    this.risk = RiskLevel.none,
  });

  final int id;
  final String title;
  final String lastText;
  final MessageKind lastKind;
  final DateTime? lastTime;
  final int unread;

  /// Position in the main chat list (larger = higher).
  final int order;
  final RiskLevel risk;

  ChatSummary copyWith({
    String? title,
    String? lastText,
    MessageKind? lastKind,
    DateTime? lastTime,
    int? unread,
    int? order,
    RiskLevel? risk,
  }) {
    return ChatSummary(
      id: id,
      title: title ?? this.title,
      lastText: lastText ?? this.lastText,
      lastKind: lastKind ?? this.lastKind,
      lastTime: lastTime ?? this.lastTime,
      unread: unread ?? this.unread,
      order: order ?? this.order,
      risk: risk ?? this.risk,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.text,
    required this.kind,
    required this.outgoing,
    required this.time,
    this.edited = false,
    this.deletedByPeer = false,
  });

  final int id;
  final int chatId;
  final String text;
  final MessageKind kind;
  final bool outgoing;
  final DateTime time;
  final bool edited;

  /// Set when the sender deleted the message but we kept it locally.
  final bool deletedByPeer;

  ChatMessage copyWith({
    int? id,
    String? text,
    MessageKind? kind,
    bool? edited,
    bool? deletedByPeer,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId,
      text: text ?? this.text,
      kind: kind ?? this.kind,
      outgoing: outgoing,
      time: time,
      edited: edited ?? this.edited,
      deletedByPeer: deletedByPeer ?? this.deletedByPeer,
    );
  }
}

enum AuthStep {
  initializing,
  waitPhone,
  waitCode,
  waitPassword,
  ready,
  closed,
}

class AuthState {
  const AuthState(this.step, {this.error});

  final AuthStep step;
  final String? error;

  static const initializing = AuthState(AuthStep.initializing);
  static const ready = AuthState(AuthStep.ready);
}

/// A change to a contact's profile (name, username, phone) seen via TDLib.
class ContactChange {
  const ContactChange({
    required this.userId,
    required this.displayName,
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.at,
  });

  final int userId;
  final String displayName;
  final String field; // name | username | phone
  final String? oldValue;
  final String? newValue;
  final DateTime at;
}
