import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/file_name.dart';
import 'package:postino/core/domain/message.dart';

void main() {
  test('newMessageId is <24 alphanumerics@domain of the address>', () {
    final id = newMessageId('ada@example.com');
    expect(id, matches(r'^<[A-Za-z0-9]{24}@example\.com>$'));
  });

  test('newMessageId falls back to postino.local without a domain', () {
    expect(newMessageId('ada'), endsWith('@postino.local>'));
  });

  test('newMessageId never repeats', () {
    final ids = {for (var i = 0; i < 1000; i++) newMessageId('a@b.it')};
    expect(ids, hasLength(1000));
  });

  test('isExecutableName goes by the last extension only (#75)', () {
    expect(isExecutableName('fattura.pdf.exe'), isTrue);
    expect(isExecutableName('Fattura.PDF'), isFalse);
    expect(isExecutableName('setup.Exe'), isTrue);
    // macOS disk images beyond .dmg (Copilot on #77).
    expect(isExecutableName('invoice.sparseimage'), isTrue);
    expect(isExecutableName('invoice.cdr'), isTrue);
    expect(isExecutableName('invoice.sparsebundle'), isTrue);
    expect(isExecutableName('invoice.toast'), isTrue);
    expect(isExecutableName('invoice.asif'), isTrue);
    expect(isExecutableName('README'), isFalse);
    expect(isExecutableName('archivio.zip'), isFalse);
    expect(isExecutableName('run.command'), isTrue);
    expect(isExecutableName('setup.exe. '), isTrue);
    expect(isExecutableName('fattura\u202Efdp.exe'), isTrue);
    expect(isExecutableName(safeFileName('fattura\u202Efdp.exe')), isTrue);
    expect(isExecutableName(safeFileName('setup.exe\u200B')), isTrue);
    expect(isExecutableName('setup.msix'), isTrue);
    expect(isExecutableName('setup.appinstaller'), isTrue);
    expect(isExecutableName('link.webloc'), isTrue);
  });
}
