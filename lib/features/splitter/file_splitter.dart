import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Result of splitting one file: the parts in order plus a small manifest.
class SplitResult {
  const SplitResult(this.parts, this.manifest);
  final List<File> parts;
  final File manifest;
}

/// Splits big files into fixed-size parts (to get past Telegram's per-file
/// limit) and joins them back, verifying SHA-256 of the whole file.
class FileSplitter {
  const FileSplitter._();

  static String partName(String name, int index) =>
      '$name.part${(index + 1).toString().padLeft(3, '0')}';

  static String manifestName(String name) => '$name.manifest.json';

  static Future<String> _sha256(File f) async =>
      (await sha256.bind(f.openRead()).first).toString();

  /// Writes parts and manifest into [outDir]. Memory use is one chunk.
  static Future<SplitResult> split(File source, Directory outDir,
      {required int partSize, int chunk = 1 << 20}) async {
    if (partSize <= 0) throw ArgumentError('partSize must be > 0');
    await outDir.create(recursive: true);
    final name = source.uri.pathSegments.last;
    final total = await source.length();
    final raf = await source.open();
    final parts = <File>[];
    final partHashes = <String>[];
    try {
      var offset = 0;
      var index = 0;
      while (offset < total || (total == 0 && index == 0)) {
        final out = File('${outDir.path}/${partName(name, index)}');
        final sink = out.openWrite();
        final h = AccumulatorSink<Digest>();
        final hs = sha256.startChunkedConversion(h);
        var written = 0;
        final want = total - offset < partSize ? total - offset : partSize;
        while (written < want) {
          final n = want - written < chunk ? want - written : chunk;
          final bytes = await raf.read(n);
          if (bytes.isEmpty) break;
          sink.add(bytes);
          hs.add(bytes);
          written += bytes.length;
        }
        hs.close();
        await sink.close();
        partHashes.add(h.events.single.toString());
        parts.add(out);
        offset += written;
        index++;
        if (total == 0) break;
      }
    } finally {
      await raf.close();
    }
    final manifest = File('${outDir.path}/${manifestName(name)}');
    await manifest.writeAsString(jsonEncode({
      'name': name,
      'size': total,
      'sha256': await _sha256(source),
      'parts': [
        for (var i = 0; i < parts.length; i++)
          {'file': partName(name, i), 'sha256': partHashes[i]}
      ],
    }));
    return SplitResult(parts, manifest);
  }

  /// Joins the parts listed in [manifest] (looked up next to it) into
  /// [output]. Throws [FormatException] on a missing part or hash mismatch.
  static Future<File> join(File manifest, File output) async {
    final m = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    final dir = manifest.parent.path;
    final parts = (m['parts'] as List).cast<Map<String, dynamic>>();
    final sink = output.openWrite();
    try {
      for (final p in parts) {
        final f = File('$dir/${p['file']}');
        if (!await f.exists()) {
          throw FormatException('missing part ${p['file']}');
        }
        if (await _sha256(f) != p['sha256']) {
          throw FormatException('corrupt part ${p['file']}');
        }
        await sink.addStream(f.openRead());
      }
    } catch (_) {
      await sink.close();
      if (await output.exists()) await output.delete();
      rethrow;
    }
    await sink.close();
    if (await _sha256(output) != m['sha256']) {
      await output.delete();
      throw const FormatException('whole-file checksum mismatch');
    }
    return output;
  }
}

/// Collects the single event of a chunked hash conversion.
class AccumulatorSink<T> implements Sink<T> {
  final events = <T>[];
  @override
  void add(T data) => events.add(data);
  @override
  void close() {}
}
