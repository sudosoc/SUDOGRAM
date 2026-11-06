import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudogram/features/splitter/file_splitter.dart';
import 'package:sudogram/features/splitter/reed_solomon.dart';

void main() {
  test('codec recovers any m missing shards', () {
    final r = Random(7);
    for (final (k, m) in [(1, 1), (3, 1), (4, 2), (5, 3), (10, 4)]) {
      final codec = CauchyCodec(k, m);
      final data = [
        for (var i = 0; i < k; i++)
          Uint8List.fromList(List.generate(37, (_) => r.nextInt(256)))
      ];
      final parity = codec.encode(data);
      for (var trial = 0; trial < 25; trial++) {
        final lose = (List.generate(k, (i) => i)..shuffle(r)).take(r.nextInt(m + 1)).toSet();
        final d = [for (var i = 0; i < k; i++) lose.contains(i) ? null : data[i]];
        final out = codec.decode(d, parity);
        for (var i = 0; i < k; i++) {
          expect(out[i], data[i], reason: 'k=$k m=$m lose=$lose');
        }
      }
    }
  });

  test('too many missing shards is an error', () {
    final c = CauchyCodec(3, 1);
    final data = [for (var i = 0; i < 3; i++) Uint8List(4)..fillRange(0, 4, i + 1)];
    final p = c.encode(data);
    expect(() => c.decode([null, null, data[2]], p), throwsStateError);
  });

  group('file splitter with parity', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('rs'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<File> make(int size) async {
      final f = File('${tmp.path}/data.bin');
      final r = Random(3);
      await f.writeAsBytes(Uint8List.fromList(List.generate(size, (_) => r.nextInt(256))));
      return f;
    }

    test('a deleted and a corrupted part are rebuilt exactly', () async {
      final src = await make(1000003);
      final res = await FileSplitter.split(src, Directory('${tmp.path}/o'),
          partSize: 250000, chunk: 60001, parityParts: 2);
      expect(res.parts.length, 5);
      expect(res.parity.length, 2);
      await res.parts[1].delete();
      final b = await res.parts[4].readAsBytes(); // the short last part
      b[1] ^= 0x55;
      await res.parts[4].writeAsBytes(b);
      final j = await FileSplitter.join(res.manifest, File('${tmp.path}/j.bin'), chunk: 50000);
      expect(await j.readAsBytes(), await src.readAsBytes());
    });

    test('losing more parts than parity fails cleanly', () async {
      final src = await make(10000);
      final res = await FileSplitter.split(src, Directory('${tmp.path}/o2'),
          partSize: 3000, parityParts: 1);
      await res.parts[0].delete();
      await res.parts[1].delete();
      expect(FileSplitter.join(res.manifest, File('${tmp.path}/x.bin')),
          throwsA(isA<FormatException>()));
    });

    test('a corrupt parity part is ignored when nothing is missing', () async {
      final src = await make(9000);
      final res = await FileSplitter.split(src, Directory('${tmp.path}/o3'),
          partSize: 3000, parityParts: 1);
      await res.parity.first.writeAsBytes([1, 2, 3]);
      final j = await FileSplitter.join(res.manifest, File('${tmp.path}/y.bin'));
      expect(await j.length(), 9000);
    });
  });
}
