// The Azioni of a Conversazione opened from a view reach only the messages that view shows: one in the Cestino stays
// there when the Conversazione is archived from the inbox.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/features/posta/presentation/act_on_conversation.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

void main() {
  late SyncEngine engine;

  setUp(() async {
    final h = await Harness.create();
    (await h.addAccount('a'))
      ..deliver(msg('1'))
      ..deliver(msg('3', conversationId: 't-1', date: DateTime.utc(2026, 3)));
    engine = getIt<SyncEngine>();
    await engine.syncAll();
    await engine.act('a', ['3'], const Delete());
  });

  test('from the inbox, the messages here are the ones shown: not the one in the Cestino', () async {
    expect(await idsHere('a', 't-1', view: inboxLabelId), ['1']);
    expect(await idsHere('a', 't-1', view: trashLabelId), ['1', '3']);
  });

  test('Archivia from the inbox reaching the older messages leaves the one in the Cestino there', () async {
    await reachOlder('a', 't-1', ['1'], const Archive(), null, view: inboxLabelId);
    final labels = (await getIt<InboxRepository>().watchMessage('a', '3').first)!.labelIds;
    expect(labels, contains(trashLabelId));
  });
}
