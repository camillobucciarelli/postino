// Etichettatura automatica (#109): il testo che il modello di embedding legge, nel formato dello spike #103.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/embedding_text.dart';
import 'package:postino/core/domain/message.dart';

import '../../support/fake_mail_provider.dart';

void main() {
  final m = msg('1', subject: 'Volo per Lisbona');

  test('subject, sender and the plain text of the body', () {
    expect(
      emailEmbeddingText(m, const MessageBody('<p>Il tuo <b>volo</b></p><p>parte alle 9</p>', BodyKind.html)),
      'Oggetto: Volo per Lisbona\nDa: ada@example.com\n\n\nIl tuo volo\n\nparte alle 9\n',
    );
    expect(emailEmbeddingText(m, const MessageBody('Ciao', BodyKind.testo)), endsWith('\n\nCiao'));
  });

  test('without a body the snippet; a long body is cut', () {
    expect(emailEmbeddingText(m, null), 'Oggetto: Volo per Lisbona\nDa: ada@example.com\n\nAnteprima');
    final long = emailEmbeddingText(m, MessageBody('x' * 5000, BodyKind.testo));
    expect(long.length, 'Oggetto: Volo per Lisbona\nDa: ada@example.com\n\n'.length + maxEmbeddedBody);
  });

  test('an Etichetta reads as its name and description, or the name alone', () {
    expect(labelEmbeddingText('Viaggi', 'voli e alberghi'), 'Viaggi: voli e alberghi');
    expect(labelEmbeddingText('Viaggi', null), 'Viaggi');
  });
}
