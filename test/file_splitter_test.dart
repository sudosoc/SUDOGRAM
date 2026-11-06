import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudogram/features/splitter/file_splitter.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('fs'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<File> make(int size) async {
    final f = File('${tmp.path}/data.bin');
    final r = Random(1);
    await f.writeAsBytes(Uint8List.fromList(
        List.generate(size, (_) => r.nextInt(256))));
    return f;
  }

  test('split then join gives the identical file', () async {
    final src = await make(1000003);
    final res = await FileSplitter.split(src, Directory('${tmp.path}/out'),
        partSize: 300000, chunk: 70001);
    expect(res.parts.length, 4);
    expect(await res.parts.first.length(), 300000);
    expect(await res.parts.last.length(), 100003);
    final joined = await FileSplitter.join(
        res.manifest, File('${tmp.path}/joined.bin'));
    expect(await joined.readAsBytes(), await src.readAsBytes());
  });

  test('exact multiple of part size has no empty tail part', () async {
    final src = await make(600);
    final res = await FileSplitter.split(src, Directory('${tmp.path}/o2'),
        partSize: 200);
    expect(res.parts.length, 3);
  });

  test('corrupt or missing part is detected', () async {
    final src = await make(5000);
    final res = await FileSplitter.split(src, Directory('${tmp.path}/o3'),
        partSize: 2000);
    final bytes = await res.parts[1].readAsBytes();
    bytes[10] ^= 0xFF;
    await res.parts[1].writeAsBytes(bytes);
    expect(
        FileSplitter.join(res.manifest, File('${tmp.path}/j.bin')),
        throwsA(isA<FormatException>()));
    await res.parts[2].delete();
    expect(
        FileSplitter.join(res.manifest, File('${tmp.path}/j2.bin')),
        throwsA(isA<FormatException>()));
  });

  test('empty file produces one empty part', () async {
    final src = await make(0);
    final res = await FileSplitter.split(src, Directory('${tmp.path}/o4'),
        partSize: 100);
    expect(res.parts.length, 1);
    final j = await FileSplitter.join(res.manifest, File('${tmp.path}/e.bin'));
    expect(await j.length(), 0);
  });
}
