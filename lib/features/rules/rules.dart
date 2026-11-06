import 'dart:convert';

import '../../data/archive/arabic_normalize.dart';
import '../../domain/models.dart';

enum RuleAction { pin, hide, ghostOn, ghostOff, addToFolder }

/// "When a new message arrives in a chat that matches, do [action]".
/// Every empty condition matches anything. Text matching ignores case,
/// Arabic diacritics and alef/yaa/taa-marbuta variants.
class Rule {
  const Rule({
    required this.id,
    required this.name,
    required this.action,
    this.enabled = true,
    this.chatContains = '',
    this.textContains = '',
    this.kind,
    this.folder = '',
  });

  final String id;
  final String name;
  final bool enabled;
  final String chatContains;
  final String textContains;
  final MessageKind? kind;
  final RuleAction action;
  final String folder; // for addToFolder

  Rule copyWith({bool? enabled}) => Rule(
        id: id,
        name: name,
        action: action,
        enabled: enabled ?? this.enabled,
        chatContains: chatContains,
        textContains: textContains,
        kind: kind,
        folder: folder,
      );

  bool matches(ChatSummary chat) {
    if (!enabled) return false;
    if (chatContains.isNotEmpty &&
        !normalizeForSearch(chat.title).contains(normalizeForSearch(chatContains))) {
      return false;
    }
    if (textContains.isNotEmpty &&
        !normalizeForSearch(chat.lastText)
            .contains(normalizeForSearch(textContains))) {
      return false;
    }
    if (kind != null && chat.lastKind != kind) return false;
    return true;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'chatContains': chatContains,
        'textContains': textContains,
        'kind': kind?.name,
        'action': action.name,
        'folder': folder,
      };

  static Rule fromJson(Map<String, dynamic> j) => Rule(
        id: j['id'] as String,
        name: j['name'] as String,
        enabled: j['enabled'] as bool? ?? true,
        chatContains: j['chatContains'] as String? ?? '',
        textContains: j['textContains'] as String? ?? '',
        kind: j['kind'] == null
            ? null
            : MessageKind.values.byName(j['kind'] as String),
        action: RuleAction.values.byName(j['action'] as String),
        folder: j['folder'] as String? ?? '',
      );

  static String encodeAll(List<Rule> rules) =>
      jsonEncode({'sudogramRules': 1, 'rules': [for (final r in rules) r.toJson()]});

  /// Parses a rule pack. Throws [FormatException] on anything unexpected, so a
  /// pasted file can never run anything but these fixed, local actions.
  static List<Rule> decodeAll(String text) {
    final j = jsonDecode(text);
    if (j is! Map || j['sudogramRules'] != 1 || j['rules'] is! List) {
      throw const FormatException('not a SUDOGRAM rule pack');
    }
    try {
      return [
        for (final r in j['rules'] as List) Rule.fromJson(r as Map<String, dynamic>)
      ];
    } catch (_) {
      throw const FormatException('invalid rule');
    }
  }
}

class RuleHit {
  const RuleHit(this.chatId, this.rule);
  final int chatId;
  final Rule rule;
}

/// Compares the chat list with the previous one and returns the rules that
/// fire for chats that got a NEW incoming message (unread went up, or a new
/// last message arrived while unread > 0).
List<RuleHit> findHits(
  List<Rule> rules,
  Map<int, ChatSummary> previous,
  List<ChatSummary> current,
) {
  final hits = <RuleHit>[];
  for (final c in current) {
    final before = previous[c.id];
    if (before == null) continue; // first sight: don't act on history
    final isNew = c.unread > before.unread ||
        (c.unread > 0 && c.lastTime != before.lastTime);
    if (!isNew) continue;
    for (final r in rules) {
      if (r.matches(c)) hits.add(RuleHit(c.id, r));
    }
  }
  return hits;
}
