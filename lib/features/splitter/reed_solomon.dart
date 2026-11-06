import 'dart:typed_data';

/// Arithmetic in GF(2^8) with the polynomial 0x11D.
class Gf256 {
  Gf256._();

  static final Uint8List _exp = Uint8List(512);
  static final Uint8List _log = Uint8List(256);
  static bool _ready = false;

  static void _init() {
    if (_ready) return;
    var x = 1;
    for (var i = 0; i < 255; i++) {
      _exp[i] = x;
      _log[x] = i;
      x <<= 1;
      if (x & 0x100 != 0) x ^= 0x11D;
    }
    for (var i = 255; i < 512; i++) {
      _exp[i] = _exp[i - 255];
    }
    _ready = true;
  }

  static int mul(int a, int b) {
    _init();
    if (a == 0 || b == 0) return 0;
    return _exp[_log[a] + _log[b]];
  }

  static int inv(int a) {
    _init();
    if (a == 0) throw ArgumentError('zero has no inverse');
    return _exp[255 - _log[a]];
  }
}

/// Systematic erasure code over GF(256) using a Cauchy matrix: [k] data
/// shards plus [m] parity shards; any [k] of the [k]+[m] shards rebuild the
/// data. Shards are treated byte-by-byte, so it works on arbitrarily big files
/// when fed in chunks.
class CauchyCodec {
  CauchyCodec(this.k, this.m) {
    if (k < 1 || m < 0 || k + m > 256) {
      throw ArgumentError('need 1 <= k and k + m <= 256');
    }
  }

  final int k;
  final int m;

  /// Coefficient of data shard [j] in parity shard [i].
  int coef(int i, int j) => Gf256.inv((k + i) ^ j);

  /// Computes the [m] parity chunks for [k] equally long data chunks.
  List<Uint8List> encode(List<Uint8List> data) {
    final len = data.first.length;
    final out = [for (var i = 0; i < m; i++) Uint8List(len)];
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < k; j++) {
        final c = coef(i, j);
        final d = data[j];
        final o = out[i];
        for (var b = 0; b < len; b++) {
          o[b] ^= Gf256.mul(c, d[b]);
        }
      }
    }
    return out;
  }

  /// Rebuilds the missing data chunks. [data] holds the data chunks that are
  /// present (null = missing); [parity] the parity chunks that are present.
  /// Returns the full list of [k] data chunks. Throws [StateError] if too
  /// many shards are missing.
  List<Uint8List> decode(List<Uint8List?> data, List<Uint8List?> parity) {
    final missing = [for (var j = 0; j < k; j++) if (data[j] == null) j];
    if (missing.isEmpty) return [for (final d in data) d!];
    final usable = [for (var i = 0; i < m; i++) if (parity[i] != null) i];
    if (usable.length < missing.length) {
      throw StateError('not enough parity to recover ${missing.length} parts');
    }
    final t = missing.length;
    final rows = usable.take(t).toList();
    final len = parity[rows.first]!.length;

    // Matrix A (t×t): parity rows × missing columns, then invert it.
    final a = [
      for (final r in rows) [for (final c in missing) coef(r, c)]
    ];
    final inv = _invert(a);

    // Right-hand side: parity minus the contribution of the known data.
    final rhs = [for (final r in rows) Uint8List.fromList(parity[r]!)];
    for (var ri = 0; ri < t; ri++) {
      for (var j = 0; j < k; j++) {
        final d = data[j];
        if (d == null) continue;
        final c = coef(rows[ri], j);
        for (var b = 0; b < len; b++) {
          rhs[ri][b] ^= Gf256.mul(c, d[b]);
        }
      }
    }
    final result = List<Uint8List?>.from(data);
    for (var mi = 0; mi < t; mi++) {
      final out = Uint8List(len);
      for (var ri = 0; ri < t; ri++) {
        final c = inv[mi][ri];
        final src = rhs[ri];
        for (var b = 0; b < len; b++) {
          out[b] ^= Gf256.mul(c, src[b]);
        }
      }
      result[missing[mi]] = out;
    }
    return [for (final d in result) d!];
  }

  static List<List<int>> _invert(List<List<int>> a) {
    final n = a.length;
    final m = [
      for (var i = 0; i < n; i++)
        [...a[i], for (var j = 0; j < n; j++) i == j ? 1 : 0]
    ];
    for (var col = 0; col < n; col++) {
      var p = col;
      while (p < n && m[p][col] == 0) {
        p++;
      }
      if (p == n) throw StateError('singular matrix');
      final tmp = m[col];
      m[col] = m[p];
      m[p] = tmp;
      final iv = Gf256.inv(m[col][col]);
      for (var j = 0; j < 2 * n; j++) {
        m[col][j] = Gf256.mul(m[col][j], iv);
      }
      for (var r = 0; r < n; r++) {
        if (r == col || m[r][col] == 0) continue;
        final f = m[r][col];
        for (var j = 0; j < 2 * n; j++) {
          m[r][j] ^= Gf256.mul(f, m[col][j]);
        }
      }
    }
    return [for (var i = 0; i < n; i++) m[i].sublist(n)];
  }
}
