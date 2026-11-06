import 'dart:math';

import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudogram/features/splitter/smart_splitter.dart';

String _squash(String s) => s
    .replaceAll(RegExp(r'\s'), '')
    .replaceAll('‎', '')
    .replaceAll('‏', '');

void main() {
  group('SmartSplitter', () {
    test('short text is returned untouched', () {
      expect(SmartSplitter.split('hello'), ['hello']);
      final exact = 'a' * 4096;
      expect(SmartSplitter.split(exact), [exact]);
    });

    test('rejects tiny limits', () {
      expect(
        () => SmartSplitter.split('x' * 100, const SplitOptions(maxLength: 10)),
        throwsArgumentError,
      );
    });

    test('English paragraphs split at paragraph boundaries', () {
      final paragraph = '${'This is a sentence about testing. ' * 8}End.';
      final text = List.filled(12, paragraph).join('\n\n');
      final parts =
          SmartSplitter.split(text, const SplitOptions(maxLength: 1000));
      expect(parts.length, greaterThan(1));
      for (final p in parts) {
        expect(p.length, lessThanOrEqualTo(1000));
        expect(p.trimRight().endsWith('End.'), isTrue,
            reason: 'each part should end at a paragraph boundary');
      }
      expect(_squash(parts.join()), _squash(text));
    });

    test('Arabic sentences split at Arabic punctuation', () {
      final sentence = 'هل هذا اختبار جيد للتقسيم؟ نعم، هو كذلك جدًا. ';
      final text = sentence * 40;
      final parts =
          SmartSplitter.split(text, const SplitOptions(maxLength: 300));
      expect(parts.length, greaterThan(1));
      for (final p in parts) {
        expect(p.length, lessThanOrEqualTo(300));
      }
      for (final p in parts.take(parts.length - 1)) {
        final t = p.trimRight();
        expect(t.endsWith('.') || t.endsWith('؟'), isTrue,
            reason: 'cut should land on a sentence end, got: ...${t.substring(t.length - 6)}');
      }
      expect(_squash(parts.join()), _squash(text));
    });

    test('never separates a letter from its tashkeel on a hard cut', () {
      final text = 'بِسْمِ' * 200; // no spaces at all
      final parts =
          SmartSplitter.split(text, const SplitOptions(maxLength: 100));
      expect(parts.length, greaterThan(1));
      for (final p in parts) {
        expect(p.length, lessThanOrEqualTo(100));
        final first = p.runes.first;
        final isCombining =
            (first >= 0x064B && first <= 0x065F) || first == 0x0670;
        expect(isCombining, isFalse, reason: 'part starts with a combining mark');
      }
      expect(parts.join(), text);
    });

    test('never splits an emoji ZWJ sequence', () {
      const family = '\u{1F468}‍\u{1F469}‍\u{1F467}‍\u{1F466}';
      expect(family.length, 11);
      final text = family * 50;
      final parts =
          SmartSplitter.split(text, const SplitOptions(maxLength: 64));
      for (final p in parts) {
        expect(p.length, lessThanOrEqualTo(64));
        expect(p.length % 11, 0, reason: 'a cluster was cut in half');
        expect(p.characters.length, p.length ~/ 11);
      }
      expect(parts.join(), text);
    });

    test('hard cut for text without any whitespace', () {
      final text = 'a' * 500;
      final parts =
          SmartSplitter.split(text, const SplitOptions(maxLength: 100));
      for (final p in parts) {
        expect(p.length, lessThanOrEqualTo(100));
      }
      expect(parts.join(), text);
    });

    test('code fences are closed and reopened across parts', () {
      final code = List.generate(60, (i) => "print('line $i')").join('\n');
      final text = 'Intro text\n\n```python\n$code\n```\n\nOutro text';
      final parts =
          SmartSplitter.split(text, const SplitOptions(maxLength: 200));
      expect(parts.length, greaterThan(2));
      for (final p in parts) {
        expect(p.length, lessThanOrEqualTo(200));
        expect('```'.allMatches(p).length % 2, 0,
            reason: 'unbalanced fence in: $p');
      }
      for (final p in parts.skip(1).take(parts.length - 2)) {
        expect(p.contains('```python'), isTrue);
      }
    });

    test('parts keep the paragraph direction of an Arabic message', () {
      const s1 = 'هذه جملة عربية أولى للاختبار.';
      const s2 = 'This second sentence is written in English.';
      final parts = SmartSplitter.split(
        '$s1 $s2',
        const SplitOptions(maxLength: 40),
      );
      expect(parts.first.startsWith('‏'), isFalse);
      expect(parts[1].startsWith('‏'), isTrue,
          reason: 'English-first part of an Arabic message needs an RLM');
    });

    test('direction marks can be turned off', () {
      const s1 = 'هذه جملة عربية أولى للاختبار.';
      const s2 = 'This second sentence is written in English.';
      final parts = SmartSplitter.split(
        '$s1 $s2',
        const SplitOptions(maxLength: 40, keepDirection: false),
      );
      for (final p in parts) {
        expect(p.contains('‏'), isFalse);
      }
    });

    test('numbering fits inside the limit', () {
      final text = 'word ' * 600;
      final parts = SmartSplitter.split(
        text,
        const SplitOptions(maxLength: 200, numbering: true),
      );
      for (var i = 0; i < parts.length; i++) {
        expect(parts[i].length, lessThanOrEqualTo(200));
        expect(parts[i].endsWith('[${i + 1}/${parts.length}]'), isTrue);
      }
    });

    test('fuzz: limit respected and no content lost', () {
      final alphabet = [
        'a', 'b', 'cd', 'English ', 'مرحبا ', 'بِسْمِ', 'ك', '، ', '. ',
        '؟ ', '\n', '\n\n', ' ', '😀', 'x' * 30, 'https://example.com/a/b ',
      ];
      for (var seed = 0; seed < 60; seed++) {
        final rnd = Random(seed);
        final sb = StringBuffer();
        final target = 200 + rnd.nextInt(5000);
        while (sb.length < target) {
          sb.write(alphabet[rnd.nextInt(alphabet.length)]);
        }
        final text = sb.toString();
        for (final limit in [64, 200, 1000]) {
          final parts = SmartSplitter.split(
            text,
            SplitOptions(maxLength: limit, fenceAware: false),
          );
          for (final p in parts) {
            expect(p.length, lessThanOrEqualTo(limit),
                reason: 'seed $seed limit $limit');
          }
          expect(_squash(parts.join()), _squash(text),
              reason: 'content changed for seed $seed limit $limit');
        }
      }
    });
  });
}
