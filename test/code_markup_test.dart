import 'package:flutter_test/flutter_test.dart';
import 'package:sudogram/core/code_markup.dart';

void main() {
  styleTests();
  test('fenced block becomes a pre-code entity', () {
    final p = parseCode('hi\n```dart\nvoid main() {}\n```\nbye');
    expect(p.text, 'hi\nvoid main() {}\nbye');
    expect(p.ents.single.block, true);
    expect(p.ents.single.lang, 'dart');
    expect(p.text.substring(p.ents.single.offset, p.ents.single.offset + p.ents.single.length), 'void main() {}');
  });

  test('inline code and plain text', () {
    final p = parseCode('run `ls -la` now');
    expect(p.text, 'run ls -la now');
    expect(p.ents.single.block, false);
    expect(p.ents.single.length, 6);
    expect(parseCode('no code').ents, isEmpty);
  });

  test('toFormattedText emits TD entity types', () {
    final f = toFormattedText('```py\nprint(1)\n```');
    expect((f['entities'] as List).single['type']['@type'], 'textEntityTypePreCode');
  });
}

void styleTests() {
  test('styles nest and strip markers', () {
    final p = parseCode('a **bold __it__** ~~x~~ ||sp||');
    expect(p.text, 'a bold it x sp');
    final styles = p.ents.map((e) => e.style).toSet();
    expect(styles, {'bold', 'italic', 'strike', 'spoiler'});
    final bold = p.ents.firstWhere((e) => e.style == 'bold');
    expect(p.text.substring(bold.offset, bold.offset + bold.length), 'bold it');
  });
}
