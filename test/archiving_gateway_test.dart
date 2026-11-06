import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudogram/data/archive/archive_db.dart';
import 'package:sudogram/data/archive/archiving_gateway.dart';
import 'package:sudogram/data/mock_gateway.dart';
import 'package:sudogram/domain/models.dart';

class _Fake extends MockGateway {
  final c = StreamController<List<ChatMessage>>();
  @override
  Stream<List<ChatMessage>> watchMessages(int chatId) => c.stream;
}

ChatMessage m(int id, String t, {bool deleted = false}) => ChatMessage(
      id: id,
      chatId: 7,
      text: t,
      kind: MessageKind.text,
      outgoing: false,
      time: DateTime(2026),
      deletedByPeer: deleted,
    );

void main() {
  test('deleted peer message survives a restart via the archive', () async {
    final db = ArchiveDb.inMemory();
    final fake = _Fake();
    final g = ArchivingGateway(fake, db);
    final out = <List<ChatMessage>>[];
    g.watchMessages(7).listen(out.add);
    fake.c.add([m(1, 'hello')]);
    fake.c.add([m(1, 'hello', deleted: true)]);
    await Future<void>.delayed(Duration.zero);

    // "Restart": a new gateway whose live list no longer has the message.
    final fake2 = _Fake();
    final g2 = ArchivingGateway(fake2, db);
    final out2 = <List<ChatMessage>>[];
    g2.watchMessages(7).listen(out2.add);
    fake2.c.add([m(2, 'new')]);
    await Future<void>.delayed(Duration.zero);

    expect(out2.last.map((e) => e.id), [2, 1]);
    expect(out2.last.last.deletedByPeer, isTrue);
  });
}
