import 'dart:convert';
import 'dart:io';

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'reed_solomon.dart';

/// Result of splitting one file: the parts in order plus a small manifest.
class SplitResult {
  const SplitResult(this.parts, this.manifest, [this.parity = const []]);
  final List<File> parts;

  /// Reed-Solomon parity parts (may be empty).
  final List<File> parity;
  final File manifest;
}

/// Splits big files into fixed-size parts (to get past Telegram's per-file
/// limit) and joins them back, verifying SHA-256 of the whole file.
class FileSplitter {
  const FileSplitter._();

  static String partName(String name, int index) =>
      '$name.part${(index + 1).toString().padLeft(3, '0')}';

  static String parityName(String name, int index) =>
      '$name.par${(index + 1).toString().padLeft(3, '0')}';

  static String manifestName(String name) => '$name.manifest.json';

  static Future<String> _sha256(File f) async =>
      (await sha256.bind(f.openRead()).first).toString();

  /// Writes parts and manifest into [outDir]. Memory use is one chunk.
  static Future<SplitResult> split(File source, Directory outDir,
      {required int partSize, int chunk = 1 << 20, int parityParts = 0}) async {
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
    final shardLen = await parts.first.length();
    final partSizes = [for (final p in parts) await p.length()];
    final parity = <File>[];
    final parityHashes = <String>[];
    if (parityParts > 0) {
      final codec = CauchyCodec(parts.length, parityParts);
      final raf2 = [for (final p in parts) await p.open()];
      final sinks = <IOSink>[];
      final hashSinks = <AccumulatorSink<Digest>>[];
      final hashers = <ByteConversionSink>[];
      for (var i = 0; i < parityParts; i++) {
        final f = File('${outDir.path}/${parityName(name, i)}');
        parity.add(f);
        sinks.add(f.openWrite());
        final h = AccumulatorSink<Digest>();
        hashSinks.add(h);
        hashers.add(sha256.startChunkedConversion(h));
      }
      try {
        for (var off = 0; off < shardLen; off += chunk) {
          final n = shardLen - off < chunk ? shardLen - off : chunk;
          final data = <Uint8List>[];
          for (final r in raf2) {
            final b = await r.read(n);
            final padded = Uint8List(n)..setRange(0, b.length, b);
            data.add(padded);
          }
          final par = codec.encode(data);
          for (var i = 0; i < parityParts; i++) {
            sinks[i].add(par[i]);
            hashers[i].add(par[i]);
          }
        }
      } finally {
        for (final r in raf2) {
          await r.close();
        }
        for (var i = 0; i < parityParts; i++) {
          hashers[i].close();
          await sinks[i].close();
          parityHashes.add(hashSinks[i].events.single.toString());
        }
      }
    }
    final manifest = File('${outDir.path}/${manifestName(name)}');
    await manifest.writeAsString(jsonEncode({
      'partSize': partSize,
      'shardLen': shardLen,
      'partSizes': partSizes,
      'parity': [
        for (var i = 0; i < parity.length; i++)
          {'file': parityName(name, i), 'sha256': parityHashes[i]}
      ],
      'name': name,
      'size': total,
      'sha256': await _sha256(source),
      'parts': [
        for (var i = 0; i < parts.length; i++)
          {'file': partName(name, i), 'sha256': partHashes[i]}
      ],
    }));
    return SplitResult(parts, manifest, parity);
  }

  static Future<bool> _good(File f, String hash) async =>
      await f.exists() && await _sha256(f) == hash;

  /// Joins the parts listed in [manifest] (looked up next to it) into
  /// [output]. Missing or corrupt data parts are rebuilt from the parity parts
  /// when the manifest has enough of them. Throws [FormatException] otherwise.
  static Future<File> join(File manifest, File output, {int chunk = 1 << 20}) async {
    final m = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    final dir = manifest.parent.path;
    final parts = (m['parts'] as List).cast<Map<String, dynamic>>();
    final parityInfo = ((m['parity'] as List?) ?? const []).cast<Map<String, dynamic>>();

    final okData = [
      for (final p in parts) await _good(File('$dir/${p['file']}'), p['sha256'] as String)
    ];
    final missing = [for (var i = 0; i < parts.length; i++) if (!okData[i]) i];
    final work = <int, File>{}; // rebuilt parts
    Directory? tmp;

    if (missing.isNotEmpty) {
      final okParity = [
        for (final p in parityInfo)
          await _good(File('$dir/${p['file']}'), p['sha256'] as String)
      ];
      final usable = [for (var i = 0; i < okParity.length; i++) if (okParity[i]) i];
      if (parityInfo.isEmpty || usable.length < missing.length) {
        final first = parts[missing.first]['file'];
        throw FormatException('missing or corrupt part $first');
      }
      tmp = await Directory.systemTemp.createTemp('sg_rs');
      final k = parts.length;
      final codec = CauchyCodec(k, parityInfo.length);
      final shardLen = m['shardLen'] as int;
      final sizes = (m['partSizes'] as List).cast<int>();
      final dataRaf = <int, RandomAccessFile>{
        for (var i = 0; i < k; i++)
          if (okData[i]) i: await File('$dir/${parts[i]['file']}').open()
      };
      final parRaf = <int, RandomAccessFile>{
        for (final i in usable.take(missing.length))
          i: await File('$dir/${parityInfo[i]['file']}').open()
      };
      final sinks = {
        for (final i in missing)
          i: (work[i] = File('${tmp.path}/p$i')).openWrite()
      };
      try {
        for (var off = 0; off < shardLen; off += chunk) {
          final n = shardLen - off < chunk ? shardLen - off : chunk;
          Future<Uint8List> read(RandomAccessFile r) async {
            final b = await r.read(n);
            return Uint8List(n)..setRange(0, b.length, b);
          }

          final data = <Uint8List?>[
            for (var i = 0; i < k; i++) okData[i] ? await read(dataRaf[i]!) : null
          ];
          final par = <Uint8List?>[
            for (var i = 0; i < parityInfo.length; i++)
              parRaf.containsKey(i) ? await read(parRaf[i]!) : null
          ];
          final full = codec.decode(data, par);
          for (final i in missing) {
            sinks[i]!.add(full[i]);
          }
        }
      } finally {
        for (final r in [...dataRaf.values, ...parRaf.values]) {
          await r.close();
        }
        for (final s in sinks.values) {
          await s.close();
        }
      }
      // Rebuilt shards are padded to shardLen; cut them to their real size.
      for (final i in missing) {
        final f = work[i]!;
        final raf = await f.open(mode: FileMode.append);
        await raf.truncate(sizes[i]);
        await raf.close();
        if (await _sha256(f) != parts[i]['sha256']) {
          await tmp.delete(recursive: true);
          throw FormatException('could not rebuild part ${parts[i]['file']}');
        }
      }
    }

    final sink = output.openWrite();
    try {
      for (var i = 0; i < parts.length; i++) {
        final f = work[i] ?? File('$dir/${parts[i]['file']}');
        await sink.addStream(f.openRead());
      }
    } catch (_) {
      await sink.close();
      if (await output.exists()) await output.delete();
      rethrow;
    } finally {
      if (tmp != null && await tmp.exists()) await tmp.delete(recursive: true);
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
