import 'package:flutter_test/flutter_test.dart';
import 'package:sudogram/domain/models.dart';
import 'package:sudogram/features/rules/rules.dart';

ChatSummary chat(int id, String title, String text, int unread, int minute,
        [MessageKind k = MessageKind.text]) =>
    ChatSummary(
      id: id,
      title: title,
      lastText: text,
      lastKind: k,
      lastTime: DateTime(2026, 1, 1, 0, minute),
      unread: unread,
    );

void main() {
  const pin = Rule(
      id: '1', name: 'p', action: RuleAction.pin, textContains: 'الأحد');

  test('text match is Arabic-normalized and only fires on new messages', () {
    final before = {1: chat(1, 'كلية', 'x', 0, 1)};
    expect(findHits([pin], before, [chat(1, 'كلية', 'x', 0, 1)]), isEmpty);
    final hits = findHits([pin], before, [chat(1, 'كلية', 'محاضرة الاحد', 1, 2)]);
    expect(hits.single.rule.id, '1');
    // Same state again: nothing new.
    expect(findHits([pin], {1: chat(1, 'كلية', 'محاضرة الاحد', 1, 2)},
        [chat(1, 'كلية', 'محاضرة الاحد', 1, 2)]), isEmpty);
  });

  test('first sight of a chat never triggers; disabled rules never match', () {
    expect(findHits([pin], {}, [chat(1, 'a', 'الأحد', 5, 1)]), isEmpty);
    expect(pin.copyWith(enabled: false).matches(chat(1, 'a', 'الأحد', 1, 1)),
        isFalse);
  });

  test('kind and chat-title conditions', () {
    const r = Rule(
        id: '2',
        name: 'k',
        action: RuleAction.hide,
        kind: MessageKind.photo,
        chatContains: 'unknown');
    expect(r.matches(chat(1, 'Unknown sender', '', 1, 1, MessageKind.photo)),
        isTrue);
    expect(r.matches(chat(1, 'Unknown sender', '', 1, 1)), isFalse);
    expect(r.matches(chat(1, 'Ali', '', 1, 1, MessageKind.photo)), isFalse);
  });

  test('rule packs round trip and reject foreign JSON', () {
    final text = Rule.encodeAll([pin]);
    expect(Rule.decodeAll(text).single.textContains, 'الأحد');
    expect(() => Rule.decodeAll('{"x":1}'), throwsFormatException);
    expect(() => Rule.decodeAll('{"sudogramRules":1,"rules":[{"id":1}]}'),
        throwsFormatException);
  });
}
