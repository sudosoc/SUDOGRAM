import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudogram/data/archive/archive_db.dart';
import 'package:sudogram/data/archive/arabic_normalize.dart';
import 'package:sudogram/domain/models.dart';

ChatMessage msg(int id, String text, {bool out = false}) => ChatMessage(
      id: id,
      chatId: 1,
      text: text,
      kind: MessageKind.text,
      outgoing: out,
      time: DateTime(2026, 1, 1),
    );

void main() {
  encryptionTest();
  test('normalization folds Arabic variants and digits', () {
    expect(normalizeForSearch('أَحْمَد'), normalizeForSearch('احمد'));
    expect(normalizeForSearch('مدرسة'), normalizeForSearch('مدرسه'));
    expect(normalizeForSearch('على'), normalizeForSearch('علي'));
    expect(normalizeForSearch('١٢٣ ABC'), '123 abc');
  });

  test('archive keeps edit history and deleted messages', () {
    final a = ArchiveDb.inMemory();
    expect(a.upsert(msg(1, 'first')), isFalse);
    expect(a.upsert(msg(1, 'second')), isTrue);
    expect(a.upsert(msg(1, 'second')), isFalse);
    expect(a.editsFor(1, 1).single.oldText, 'first');
    a.markDeleted(1, 1);
    expect(a.deletedIn(1).single.text, 'second');
    expect(a.deletedIn(1).single.deletedByPeer, isTrue);
  });

  test('search is Arabic-normalized, prefix based, tracks edits', () {
    final a = ArchiveDb.inMemory();
    a.upsert(msg(1, 'هبعتلك الملف النهارده'));
    a.upsert(msg(2, 'Meeting at noon'));
    a.upsert(msg(3, 'محاضرة الأحد'));
    expect(a.search('الملف').single.message.id, 1);
    expect(a.search('الاحد').single.message.id, 3);
    expect(a.search('meet').single.message.id, 2);
    a.upsert(msg(2, 'Dinner'));
    expect(a.search('meeting'), isEmpty);
    expect(a.search('dinner').single.message.id, 2);
  });
}

void encryptionTest() {
  test('encrypted archive refuses a wrong key', () {
    final dir = Directory.systemTemp.createTempSync('arch');
    final path = '${dir.path}/a.db';
    final a = ArchiveDb.open(path, key: 'k1');
    a.upsert(msg(1, 'secret'));
    a.close();
    final b = ArchiveDb.open(path, key: 'k1');
    expect(b.search('secret'), isNotEmpty);
    b.close();
    expect(() => ArchiveDb.open(path, key: 'wrong'), throwsA(anything));
    dir.deleteSync(recursive: true);
  });
}
