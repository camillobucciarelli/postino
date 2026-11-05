// Etichettatura automatica (#109): gli embedding dei messaggi, locali, e gli esempi delle Etichette.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';

import '../../support/fake_mail_provider.dart';

const _viaggi = Label(id: 'Label_12', name: 'Viaggi', kind: LabelKind.etichetta);

void main() {
  late PostinoDatabase db;
  setUp(() => db = PostinoDatabase.inMemory());
  tearDown(() => db.close());

  Future<void> deliver(List<Message> messages) =>
      db.messagesDao.applySync('a1', SyncBatch(cursor: '1', messages: messages, labels: const [_viaggi]));

  test('the examples are the vectors of the current model among the newest messages with the Etichetta', () async {
    await deliver([
      for (var i = 0; i < 4; i++) msg('v$i', date: DateTime.utc(2026, 1, 1 + i), labelIds: [_viaggi.id]),
      msg('other'),
    ]);
    await db.messageEmbeddingsDao.save('a1', 'v0', 'm', [0.25, -1]);
    await db.messageEmbeddingsDao.save('a1', 'v1', 'old', [1, 1]);
    await db.messageEmbeddingsDao.save('a1', 'v3', 'm', [3, 0]);
    await db.messageEmbeddingsDao.save('a1', 'other', 'm', [9, 9]);

    expect(
      await db.messageEmbeddingsDao.examples('a1', _viaggi.id, 'm'),
      unorderedEquals([
        [0.25, -1],
        [3, 0],
      ]),
    );
    // Only the newest: v3 and v2, of which v2 has no vector.
    expect(await db.messageEmbeddingsDao.examples('a1', _viaggi.id, 'm', limit: 2), [
      [3, 0],
    ]);
  });

  test("a newer model's vector replaces the older one", () async {
    await deliver([
      msg('v0', labelIds: [_viaggi.id]),
    ]);
    await db.messageEmbeddingsDao.save('a1', 'v0', 'old', [1, 1]);
    await db.messageEmbeddingsDao.save('a1', 'v0', 'new', [2, 0]);
    expect(await db.messageEmbeddingsDao.examples('a1', _viaggi.id, 'old'), isEmpty);
    expect(await db.messageEmbeddingsDao.examples('a1', _viaggi.id, 'new'), [
      [2, 0],
    ]);
  });
}
