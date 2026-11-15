// The bodies' text for the search index, made before the transaction and off the UI isolate when it is much (#221).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/search_index.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/html_text.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';

import '../../support/fake_mail_provider.dart';

void main() {
  test('the texts are those of searchableText, in order, also when made in another isolate', () async {
    final big = '<style>.x{}</style>${'<p>parola</p>' * 2000}';
    expect(big.length, greaterThan(offIsolateHtml));
    final bodies = [
      MessageBody(big, BodyKind.html),
      const MessageBody('<b>testo</b>', BodyKind.testo),
      const MessageBody('<p>Il <b>preventivo</b></p>', BodyKind.html),
    ];
    expect(await searchableTexts(bodies), [htmlText(big), '<b>testo</b>', htmlText('<p>Il <b>preventivo</b></p>')]);
    expect(await searchableTexts(bodies.sublist(1)), [for (final b in bodies.sublist(1)) searchableText(b)]);
  });

  test('a sync page, a body opened later and a sync with much HTML are indexed', () async {
    final db = PostinoDatabase.inMemory();
    addTearDown(db.close);
    final store = MailStore(db);
    await store.addAccount(
      const Account(id: 'a1', address: 'a1@example.test', provider: ProviderKind.gmail, color: 0, position: 0),
    );
    final filler = '<p>riempitivo</p>' * 2000;
    await store.applyPage('a1', [msg('m1')], {'m1': MessageBody('<p>preventivo</p>$filler', BodyKind.html)});
    await store.saveBody('a1', 'm1', MessageBody('<p>contratto</p>$filler', BodyKind.html));
    await store.applySync(
      'a1',
      SyncBatch(
        cursor: 'c',
        messages: [msg('m2')],
        bodies: {'m2': MessageBody('<p>fattura</p>$filler', BodyKind.html)},
      ),
    );
    final texts = {
      for (final r
          in await db
              .customSelect('SELECT m.id, s.body FROM search_index s JOIN messages m ON m.rowid = s.rowid')
              .get())
        r.read<String>('id'): r.read<String>('body'),
    };
    expect(texts['m1'], allOf(contains('contratto'), isNot(contains('preventivo')), isNot(contains('<p>'))));
    expect(texts['m2'], contains('fattura'));
  });
}
