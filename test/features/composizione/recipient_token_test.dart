// The address being written in A, Cc or Ccn (#216): after the last comma outside quotes and <...>.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/features/composizione/domain/recipient_token.dart';

void main() {
  test('the token is what follows the last separating comma, trimmed', () {
    expect(recipientToken('mar'), 'mar');
    expect(recipientToken('ada@example.com, mar'), 'mar');
    expect(recipientToken('ada@example.com, '), '');
    expect(recipientToken('"Rossi, Maria" <maria@example.com>, lu'), 'lu');
    expect(recipientToken('"Rossi, Ma'), '"Rossi, Ma');
  });

  test('completing replaces the token with the Contatto and leaves «, » for the next one', () {
    const maria = (name: 'Maria Rossi', address: 'maria@example.com');
    expect(completeRecipient('mar', maria), 'Maria Rossi <maria@example.com>, ');
    expect(completeRecipient('ada@example.com,  mar', maria), 'ada@example.com, Maria Rossi <maria@example.com>, ');
    expect(completeRecipient('lu', (name: null, address: 'luca@example.com')), 'luca@example.com, ');
    expect(
      completeRecipient('ro', (name: 'Rossi, Maria', address: 'maria@example.com')),
      '"Rossi, Maria" <maria@example.com>, ',
    );
  });
}
