/// Decodes the `xn--` labels of [host] (RFC 3492); other labels, and a label that does not decode, stay as they are.
String decodeHost(String host) => host.split('.').map(_decodeLabel).join('.');

/// Some label of [host] is punycode (`xn--`).
bool hasPunycode(String host) => host.toLowerCase().split('.').any((l) => l.startsWith('xn--'));

String _decodeLabel(String label) =>
    label.toLowerCase().startsWith('xn--') ? _decode(label.substring(4).toLowerCase()) ?? label : label;

const _base = 36;
const _tMin = 1;
const _tMax = 26;
const _skew = 38;
const _damp = 700;

int _adapt(int delta, int points, {required bool first}) {
  var d = first ? delta ~/ _damp : delta ~/ 2;
  d += d ~/ points;
  var k = 0;
  while (d > ((_base - _tMin) * _tMax) ~/ 2) {
    d ~/= _base - _tMin;
    k += _base;
  }
  return k + (_base - _tMin + 1) * d ~/ (d + _skew);
}

/// The Unicode form of a punycode [input], null if malformed.
String? _decode(String input) {
  final split = input.lastIndexOf('-');
  final out = <int>[if (split > 0) ...input.substring(0, split).codeUnits];
  var n = 128;
  var i = 0;
  var bias = 72;
  var pos = split > 0 ? split + 1 : 0;
  while (pos < input.length) {
    final old = i;
    var w = 1;
    for (var k = _base; ; k += _base) {
      if (pos >= input.length) return null;
      final c = input.codeUnitAt(pos++);
      final digit = switch (c) {
        >= 0x30 && <= 0x39 => c - 0x16,
        >= 0x61 && <= 0x7a => c - 0x61,
        >= 0x41 && <= 0x5a => c - 0x41,
        _ => -1,
      };
      if (digit < 0) return null;
      i += digit * w;
      final t = k <= bias ? _tMin : (k >= bias + _tMax ? _tMax : k - bias);
      if (digit < t) break;
      w *= _base - t;
    }
    bias = _adapt(i - old, out.length + 1, first: old == 0);
    n += i ~/ (out.length + 1);
    i %= out.length + 1;
    if (n > 0x10ffff) return null;
    out.insert(i++, n);
  }
  return String.fromCharCodes(out);
}
