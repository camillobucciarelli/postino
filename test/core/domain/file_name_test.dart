import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/file_name.dart';

void main() {
  test('an attachment name never leaves its folder', () {
    expect(safeFileName('CON.txt'), '_CON.txt');
    expect(safeFileName('lpt1'), '_lpt1');
    expect(safeFileName('console.txt'), 'console.txt');
    expect(safeFileName('report. . '), 'report');
    // Cut at 150 bytes, no trailing dot or space left by the cut.
    expect(safeFileName('${'a' * 149} xxxxx'), 'a' * 149);
    // Bytes, not characters: 100 CJK characters are 300 bytes, over the file system's 255.
    final cjk = safeFileName('${'漢' * 100}.pdf');
    expect(cjk, '${'漢' * 48}.pdf');
    expect(utf8.encode(cjk).length, lessThanOrEqualTo(maxFileNameBytes));
    // 142 + 4 bytes fit the 146 left by «.txt»: the first emoji stays whole, the second goes whole.
    final emoji = safeFileName('${'a' * 142}😀😀.txt');
    expect(emoji, '${'a' * 142}😀.txt');
    expect(utf8.encode(emoji).length, maxFileNameBytes);
    expect(safeFileName('a?b*c<d>|"e.pdf'), 'a_b_c_d___e.pdf');
    final long = safeFileName('${'x' * 300}.pdf');
    expect(long, hasLength(maxFileNameBytes));
    expect(long, endsWith('x.pdf'));
    expect(safeFileName('../../etc/passwd'), '.._.._etc_passwd');
    expect(safeFileName('..'), 'allegato');
    expect(safeFileName('  '), 'allegato');
    expect(safeFileName('Fattura 03.pdf'), 'Fattura 03.pdf');
  });

  test('invisible and bidi characters go, C1 controls become _ (#75)', () {
    // U+202E right-to-left override: «fattura\u202Efdp.exe» is displayed as «fatturaexe.pdf».
    expect(safeFileName('fattura\u202Efdp.exe'), 'fatturafdp.exe');
    expect(safeFileName('a\u200Eb\u200Fc\u2066d\u2069e\uFEFFf\u200Bg.pdf'), 'abcdefg.pdf');
    expect(safeFileName('a\u007Fb.pdf'), 'a_b.pdf');
  });
}
