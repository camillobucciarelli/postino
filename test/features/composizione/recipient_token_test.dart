// The address the caret is in, in A, Cc or Ccn (#216): between the commas around it, outside quotes and <...>.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/features/composizione/domain/recipient_token.dart';

/// [text] with the caret at its `|`.
(String, int) _at(String text) => (text.replaceFirst('|', ''), text.indexOf('|'));

String _token(String s) {
  final (text, caret) = _at(s);
  return recipientToken(text, caret);
}

String? _complete(String s, ({String? name, String address}) c) {
  final (text, caret) = _at(s);
  final r = completeRecipient(text, caret, c);
  return r == null ? null : '${r.text.substring(0, r.caret)}|${r.text.substring(r.caret)}';
}

void main() {
  const maria = (name: 'Maria Rossi', address: 'maria@example.com');

  test('the token is the address the caret is in, trimmed', () {
    expect(_token('mar|'), 'mar');
    expect(_token('ada@example.com, mar|'), 'mar');
    expect(_token('ada@example.com, |'), '');
    expect(_token('"Rossi, Maria" <maria@example.com>, lu|'), 'lu');
    expect(_token('"Rossi, Ma|'), '"Rossi, Ma');
    // The caret on the first, on one in the middle, on the last.
    expect(_token('ad|a, bo, cy'), 'ada');
    expect(_token('ada, b|o, cy'), 'bo');
    expect(_token('ada, bo, cy|'), 'cy');
    // No caret (a selection, or none): no token.
    expect(recipientToken('ada', -1), '');
    expect(recipientToken('ada', 9), '');
  });

  test('completing replaces the address the caret is in and leaves «, » for the next one', () {
    expect(_complete('mar|', maria), 'Maria Rossi <maria@example.com>, |');
    expect(_complete('ada@example.com,  mar|', maria), 'ada@example.com, Maria Rossi <maria@example.com>, |');
    expect(_complete('lu|', (name: null, address: 'luca@example.com')), 'luca@example.com, |');
    expect(
      _complete('ro|', (name: 'Rossi, Maria', address: 'maria@example.com')),
      '"Rossi, Maria" <maria@example.com>, |',
    );
    // The caret on the first and on one in the middle: the others stay.
    expect(_complete('mar|, lu', maria), 'Maria Rossi <maria@example.com>, |lu');
    expect(_complete('ada, ma|r, lu', maria), 'ada, Maria Rossi <maria@example.com>, |lu');
    expect(completeRecipient('mar', -1, maria), isNull);
  });
}
