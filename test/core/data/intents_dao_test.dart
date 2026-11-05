// Etichettatura automatica (#109): l'Etichetta si accoda solo se il messaggio non ha un'Etichetta dell'utente,
// controllato nella stessa transazione della scrittura.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';

import '../../support/fake_mail_provider.dart';

const _viaggi = Label(id: 'Label_12', name: 'Viaggi', kind: LabelKind.etichetta);
const _lavoro = Label(id: 'Label_7', name: 'Lavoro', kind: LabelKind.etichetta);

void main() {
  late PostinoDatabase db;
  setUp(() async {
    db = PostinoDatabase.inMemory();
    await db.messagesDao.applySync(
      'a1',
      SyncBatch(
        cursor: '1',
        labels: const [_viaggi, _lavoro],
        messages: [
          msg('plain', labelIds: const [inboxLabelId, 'UNREAD', 'CATEGORY_UPDATES']),
          msg('mine', labelIds: [inboxLabelId, _lavoro.id]),
        ],
      ),
    );
  });
  tearDown(() => db.close());

  test('system labels are not Etichette dell\'utente: the Etichetta is put on and queued', () async {
    expect(await db.intentsDao.queueAutoLabel('a1', 'plain', _viaggi.id), isTrue);
    final intent = (await db.intentsDao.pendingLabels('a1')).single;
    expect((intent.messageId, intent.labelId, intent.added), ('plain', _viaggi.id, true));
  });

  test("a message with an Etichetta dell'utente, or gone, is skipped: nothing written", () async {
    expect(await db.intentsDao.queueAutoLabel('a1', 'mine', _viaggi.id), isFalse);
    expect(await db.intentsDao.queueAutoLabel('a1', 'gone', _viaggi.id), isFalse);
    expect(await db.intentsDao.pendingLabels('a1'), isEmpty);
    final rows = await (db.select(db.messageLabels)..where((t) => t.labelId.equals(_viaggi.id))).get();
    expect(rows, isEmpty);
  });
}
