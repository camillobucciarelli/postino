// Etichettatura automatica (#109): il motore, con un modello di embedding finto.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync/auto_labeler.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/auto_labels_repository.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/main.dart';

import '../../../support/fake_mail_provider.dart';
import '../../../support/harness.dart';

const _viaggi = 'Label_12';
const _fatture = Label(id: 'Label_9', name: 'Fatture', kind: LabelKind.etichetta);
const _lavoro = Label(id: 'Label_7', name: 'Lavoro', kind: LabelKind.etichetta);

void main() {
  late Harness h;
  late PostinoDatabase db;
  late AutoLabeler labeler;

  /// After the activation, which is at the clock's time.
  final after = DateTime.utc(2026, 10, 28, 13);

  /// Puts [m] in the database, as the sync does before calling the engine.
  Future<Message> stored(Message m) async {
    await db.messagesDao.applySync('a', SyncBatch(cursor: '2', messages: [m]));
    return m;
  }

  Future<List<(String, String)>> queued() async => [
    for (final r in await db.intentsDao.pendingLabels('a')) (r.messageId, r.labelId),
  ];

  setUp(() async {
    h = await Harness.create();
    final a = await h.addAccount('a');
    a.labels.addAll([_fatture, _lavoro]);
    await getIt<SyncEngine>().syncAll();
    db = getIt<PostinoDatabase>();
    labeler = getIt<AutoLabeler>();
    final config = getIt<AutoLabelsRepository>();
    await config.setAutomatic('a', _viaggi, automatic: true);
    await config.setDescription('a', _viaggi, 'voli e alberghi');
    await config.setAutomatic('a', _fatture.id, automatic: true);
    // Each Etichetta on its own axis; the mail in between, closer to Fatture.
    h.embedder.vectorOf = (text) => switch (text) {
      'Viaggi: voli e alberghi' => [1, 0],
      'Fatture' => [0, 1],
      _ when text.startsWith('Oggetto: Lisbona') => [0.4, 1],
      _ when text.startsWith('Oggetto: Nulla') => [-1, -1],
      _ => [0, 0],
    };
  });

  test('without examples the name and description win: the mail goes to the closer, one Etichetta', () async {
    final m = await stored(msg('1', subject: 'Lisbona', date: after));
    expect(await labeler.queueAutoLabels('a', [m], const {}), isTrue);
    expect(await queued(), [('1', _fatture.id)]);
    expect(h.embedder.texts, contains('Viaggi: voli e alberghi'));
  });

  test('with three examples the centroid wins over the name', () async {
    for (final id in ['e1', 'e2', 'e3']) {
      await stored(msg(id, labelIds: const [inboxLabelId, _viaggi]));
      await db.messageEmbeddingsDao.save('a', id, 'fake', [0.4, 1]);
    }
    final m = await stored(msg('1', subject: 'Lisbona', date: after));
    await labeler.queueAutoLabels('a', [m], const {});
    expect(await queued(), [('1', _viaggi)]);
    expect(h.embedder.texts, isNot(contains('Viaggi: voli e alberghi')));
  });

  test('below the threshold no Etichetta', () async {
    final m = await stored(msg('1', subject: 'Nulla', date: after));
    expect(await labeler.queueAutoLabels('a', [m], const {}), isFalse);
    expect(await queued(), isEmpty);
  });

  test("a mail with an Etichetta dell'utente is skipped", () async {
    final m = await stored(msg('1', subject: 'Lisbona', date: after, labelIds: [inboxLabelId, _lavoro.id]));
    await labeler.queueAutoLabels('a', [m], const {});
    expect(await queued(), isEmpty);
  });

  test("an Etichetta dell'utente put on between the classification and the write wins", () async {
    final m = await stored(msg('1', subject: 'Lisbona', date: after));
    final vectorOf = h.embedder.vectorOf;
    h.embedder.vectorOf = (text) async {
      // The prototypes come after the check on the mail: the user labels it meanwhile.
      if (text == 'Fatture') {
        await db
            .into(db.messageLabels)
            .insert(MessageLabelsCompanion.insert(accountId: 'a', messageId: '1', labelId: _lavoro.id));
      }
      return vectorOf(text);
    };
    expect(await labeler.queueAutoLabels('a', [m], const {}), isFalse);
    expect(await queued(), isEmpty);
  });

  test('a mail older than the activation is not classified', () async {
    final m = await stored(msg('1', subject: 'Lisbona', date: DateTime.utc(2026, 10, 28, 11)));
    await labeler.queueAutoLabels('a', [m], const {});
    expect(await queued(), isEmpty);
  });

  test('an Etichetta automatica without activation takes no part', () async {
    await db.postinoSettingsDao.write('auto_labels/a', '{"$_viaggi": {"automatic": true}}', at: h.clock.now());
    final m = await stored(msg('1', subject: 'Lisbona', date: after));
    await labeler.queueAutoLabels('a', [m], const {});
    expect(await queued(), isEmpty);
  });

  test('the model not ready: nothing classified, nothing saved', () async {
    h.embedder.vectorOf = (_) => null;
    final m = await stored(msg('1', subject: 'Lisbona', date: after));
    expect(await labeler.queueAutoLabels('a', [m], const {}), isFalse);
    expect(await queued(), isEmpty);
    expect(await db.select(db.messageEmbeddings).get(), isEmpty);
  });

  test('the embedding of each new mail is saved, with the body as text', () async {
    final m = await stored(msg('1', subject: 'Lisbona', date: after));
    await labeler.queueAutoLabels('a', [m], {'1': const MessageBody('<p>Volo</p>', BodyKind.html)});
    expect(h.embedder.texts.first, 'Oggetto: Lisbona\nDa: ada@example.com\n\n\nVolo\n');
    final row = await db.select(db.messageEmbeddings).getSingle();
    expect((row.messageId, row.modelId), ('1', 'fake'));
  });

  test('the mail already in an Etichetta before its activation is its examples: the centroid wins', () async {
    for (final id in ['o1', 'o2', 'o3']) {
      await stored(msg(id, subject: 'Vecchio', labelIds: const [inboxLabelId, _viaggi]));
    }
    final vectorOf = h.embedder.vectorOf;
    h.embedder.vectorOf = (text) => text.startsWith('Oggetto: Vecchio') ? [0.4, 1] : vectorOf(text);
    final m = await stored(msg('1', subject: 'Lisbona', date: after));
    await labeler.queueAutoLabels('a', [m], const {});
    expect(await queued(), [('1', _viaggi)]);
    // Their vectors are saved; the old mail gets no Etichetta.
    final saved = [for (final r in await db.select(db.messageEmbeddings).get()) r.messageId];
    expect(saved, containsAll(['o1', 'o2', 'o3']));
  });

  test('a mail that fails is in the error log; the others are still labelled', () async {
    final vectorOf = h.embedder.vectorOf;
    h.embedder.vectorOf = (text) => text.startsWith('Oggetto: Rotto') ? throw StateError('modello') : vectorOf(text);
    final broken = await stored(msg('1', subject: 'Rotto', date: after));
    final m = await stored(msg('2', subject: 'Lisbona', date: after));
    expect(await labeler.queueAutoLabels('a', [broken, m], const {}), isTrue);
    expect(await queued(), [('2', _fatture.id)]);
    expect(await h.errorLog.read(), contains('etichettatura a'));
  });

  test('an Etichetta automatica gone from the Account takes no part', () async {
    final config = getIt<AutoLabelsRepository>();
    await config.setAutomatic('a', _viaggi, automatic: false);
    await config.setAutomatic('a', _fatture.id, automatic: false);
    await config.setAutomatic('a', 'Label_99', automatic: true);
    final m = await stored(msg('1', subject: 'Lisbona', date: after));
    expect(await labeler.queueAutoLabels('a', [m], const {}), isFalse);
    expect(h.embedder.texts, isEmpty);
  });
}
