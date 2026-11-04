import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';

import '../../support/fake_mail_provider.dart' show msg;
import '../../support/value_equality.dart';

void main() {
  test('SyncBatch compares by value, collections included (#94)', () {
    SyncBatch batch({
      String cursor = '9',
      String subject = 'Oggetto',
      String labelName = 'Lavoro',
      String removed = '0',
      String body = 'x',
    }) => SyncBatch(
      cursor: cursor,
      messages: [msg('1', subject: subject)],
      labels: [Label(id: 'L1', name: labelName, kind: LabelKind.etichetta)],
      removedMessageIds: [removed],
      bodies: {'1': MessageBody(body, BodyKind.testo)},
    );
    expectValueEquality(() => batch(), [
      batch(cursor: '10'),
      batch(subject: 'Salve'),
      batch(labelName: 'Casa'),
      batch(removed: '5'),
      batch(body: 'y'),
    ]);
  });
}
