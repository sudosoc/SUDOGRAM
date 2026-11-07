/// Risk level shown as a colored ring around a chat avatar.
/// `none` means no assessment exists (the ring is not drawn).
enum RiskLevel { none, safe, caution, danger }

enum MessageKind { text, photo, video, voice, document, sticker, poll, other }

enum ChatType { private, group, channel, secret }

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
    this.type = ChatType.private,
    this.avatar,
    this.muted = false,
    this.canSend = true,
    this.lastOutgoing = false,
    this.archived = false,
    this.markedUnread = false,
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
  final ChatType type;

  /// Small profile photo (downloaded automatically when available).
  final Attachment? avatar;
  final bool muted;

  /// False for channels and chats where we may not post.
  final bool canSend;
  final bool lastOutgoing;
  final bool archived;
  final bool markedUnread;

  ChatSummary copyWith({
    String? title,
    String? lastText,
    MessageKind? lastKind,
    DateTime? lastTime,
    int? unread,
    int? order,
    RiskLevel? risk,
    Attachment? avatar,
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
      type: type,
      avatar: avatar ?? this.avatar,
      muted: muted,
      canSend: canSend,
      lastOutgoing: lastOutgoing,
      archived: archived,
      markedUnread: markedUnread,
    );
  }
}

/// A file attached to a message (document, photo, video, voice…).
class Attachment {
  const Attachment({
    required this.fileId,
    required this.name,
    required this.size,
    this.localPath,
    this.downloaded = false,
    this.downloading = false,
    this.downloadedBytes = 0,
  });

  final int fileId;
  final String name;
  final int size;
  final String? localPath;
  final bool downloaded;
  final bool downloading;
  final int downloadedBytes;

  double get progress =>
      size <= 0 ? 0 : (downloadedBytes / size).clamp(0.0, 1.0);

  Attachment copyWith({
    String? localPath,
    bool? downloaded,
    bool? downloading,
    int? downloadedBytes,
    int? size,
  }) => Attachment(
    fileId: fileId,
    name: name,
    size: size ?? this.size,
    localPath: localPath ?? this.localPath,
    downloaded: downloaded ?? this.downloaded,
    downloading: downloading ?? this.downloading,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
  );
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
    this.file,
    this.forwardedFrom,
    this.senderId = 0,
    this.senderName = '',
    this.replyToId = 0,
    this.thumb,
    this.emoji = '',
    this.read = false,
    this.reactions = const {},
    this.myReactions = const {},
    this.poll,
    this.link,
    this.contact,
    this.sendState = 0,
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
  final Attachment? file;

  /// Origin of a forwarded message: a user id, a chat id or a hidden name.
  final String? forwardedFrom;

  /// Who sent it (user id, or chat id for channel posts) and their name.
  final int senderId;
  final String senderName;

  /// Id of the message this one replies to (0 = not a reply).
  final int replyToId;

  /// Preview image (photo thumbnail, sticker, video cover).
  final Attachment? thumb;

  /// Emoji of a sticker.
  final String emoji;

  /// For outgoing messages: the other side has read it.
  final bool read;

  /// Emoji reactions: emoji -> count, and the ones we chose.
  final Map<String, int> reactions;
  final Set<String> myReactions;

  final PollData? poll;
  final LinkPreview? link;

  /// Set for shared contacts (null otherwise; archived copies parse the text).
  final ContactCard? contact;

  /// 0 = delivered, 1 = sending, 2 = failed.
  final int sendState;

  ChatMessage copyWith({
    int? id,
    String? text,
    MessageKind? kind,
    bool? edited,
    bool? deletedByPeer,
    Attachment? file,
    Attachment? thumb,
    String? senderName,
    bool? read,
    Map<String, int>? reactions,
    Set<String>? myReactions,
    PollData? poll,
    int? sendState,
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
      file: file ?? this.file,
      forwardedFrom: forwardedFrom,
      senderId: senderId,
      senderName: senderName ?? this.senderName,
      replyToId: replyToId,
      thumb: thumb ?? this.thumb,
      emoji: emoji,
      read: read ?? this.read,
      reactions: reactions ?? this.reactions,
      myReactions: myReactions ?? this.myReactions,
      poll: poll ?? this.poll,
      link: link,
      contact: contact,
      sendState: sendState ?? this.sendState,
    );
  }
}

/// Live state of a chat's header line: typing, online, last seen.
enum SeenKind { unknown, online, recently, lastWeek, lastMonth, at }

class ChatStatus {
  const ChatStatus({
    this.typing = false,
    this.seen = SeenKind.unknown,
    this.lastSeen,
  });

  final bool typing;
  final SeenKind seen;
  final DateTime? lastSeen;

  static const none = ChatStatus();

  @override
  bool operator ==(Object other) =>
      other is ChatStatus &&
      other.typing == typing &&
      other.seen == seen &&
      other.lastSeen == lastSeen;

  @override
  int get hashCode => Object.hash(typing, seen, lastSeen);
}

enum AuthStep {
  initializing,
  waitPhone,
  waitCode,
  waitPassword,
  waitQr,
  ready,
  closed,
}

class AuthState {
  const AuthState(this.step, {this.error, this.qrLink, this.codeLength = 5});

  final AuthStep step;
  final String? error;

  /// tg://login?token=… while waiting for another device to confirm.
  final String? qrLink;
  final int codeLength;

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

/// Profile / group info shown on the chat info page.
class ContactCard {
  const ContactCard({required this.name, required this.phone, this.userId = 0});
  final String name;
  final String phone;
  final int userId;

  /// Rebuilds a card from the archived text form `👤 name +phone`.
  static ContactCard? parse(String text) {
    if (!text.startsWith('👤 ')) return null;
    final body = text.substring(3).trim();
    final i = body.lastIndexOf(' +');
    if (i < 0) return ContactCard(name: body, phone: '');
    return ContactCard(
      name: body.substring(0, i).trim(),
      phone: body.substring(i + 2).trim(),
    );
  }
}

class ChatInfo {
  const ChatInfo({
    this.username = '',
    this.phone = '',
    this.about = '',
    this.members = 0,
    this.userId = 0,
    this.isContact = false,
    this.isBot = false,
    this.blocked = false,
    this.commonGroups = 0,
    this.firstName = '',
    this.lastName = '',
  });

  final int userId;
  final bool isContact;
  final bool isBot;
  final bool blocked;
  final int commonGroups;
  final String firstName;
  final String lastName;

  final String username;
  final String phone;
  final String about;
  final int members;
}

class PollOption {
  const PollOption(this.text, this.votes, this.chosen);
  final String text;
  final int votes;
  final bool chosen;
}

class PollData {
  const PollData({
    required this.question,
    required this.options,
    required this.total,
    this.closed = false,
    this.multiple = false,
  });
  final String question;
  final List<PollOption> options;
  final int total;
  final bool closed;
  final bool multiple;
}

class LinkPreview {
  const LinkPreview({
    required this.url,
    this.site = '',
    this.title = '',
    this.description = '',
  });
  final String url;
  final String site;
  final String title;
  final String description;
}

class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.app,
    required this.device,
    required this.location,
    required this.lastActive,
    required this.current,
    this.ip = '',
    this.country = '',
    this.region = '',
    this.platform = '',
    this.official = false,
    this.passwordPending = false,
    this.canAcceptCalls = true,
    this.canAcceptSecret = true,
    this.loggedIn,
  });
  final String ip;
  final String country;
  final String region;
  final String platform;
  final bool official;
  final bool passwordPending;
  final bool canAcceptCalls;
  final bool canAcceptSecret;
  final DateTime? loggedIn;
  final int id;
  final String app;
  final String device;
  final String location;
  final DateTime lastActive;
  final bool current;
}

class MentionCandidate {
  const MentionCandidate(this.id, this.name, this.username);
  final int id;
  final String name;
  final String username;
}

/// The logged-in account's own profile.
class ProfileInfo {
  const ProfileInfo({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.username = '',
    this.phone = '',
    this.bio = '',
    this.avatar,
  });
  final int id;
  final String firstName;
  final String lastName;
  final String username;
  final String phone;
  final String bio;
  final Attachment? avatar;
}

class StickerSetInfo {
  const StickerSetInfo(this.id, this.title);
  final int id;
  final String title;
}

class StickerItem {
  const StickerItem(
    this.fileId,
    this.thumbFileId,
    this.emoji, {
    this.gif = false,
  });
  final bool gif;
  final int fileId;
  final int thumbFileId;
  final String emoji;
}
