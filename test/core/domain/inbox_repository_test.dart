import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/message.dart';

import '../../support/fake_mail_provider.dart' show msg;
import '../../support/value_equality.dart';

const _account = Account(id: 'a1', address: 'a@x.it', provider: ProviderKind.gmail, color: 0, position: 0);

OutgoingMessage _outgoing({List<String> to = const ['b@x.it']}) =>
    OutgoingMessage(messageId: '<2@x.it>', from: 'a@x.it', to: [...to], subject: 's', body: '<p>ok</p>');

void main() {
  test('InboxEntry compares by value (#94)', () {
    InboxEntry entry({
      Message? message,
      Account account = _account,
      int count = 2,
      bool unread = true,
      String? status,
    }) => InboxEntry(message: message ?? msg('1'), account: account, count: count, unread: unread, status: status);
    expectValueEquality(entry, [
      entry(message: msg('1', to: ['c@x.it'])),
      entry(
        account: const Account(id: 'a2', address: 'a@x.it', provider: ProviderKind.gmail, color: 0, position: 0),
      ),
      entry(count: 3),
      entry(unread: false),
      entry(status: 'In coda'),
    ]);
  });

  test('OutgoingEntry compares by value (#94)', () {
    OutgoingEntry entry({OutgoingMessage? message, int sendAfter = 1, bool failed = false}) =>
        OutgoingEntry(message: message ?? _outgoing(), sendAfter: sendAfter, failed: failed);
    expectValueEquality(entry, [
      entry(message: _outgoing(to: ['c@x.it'])),
      entry(sendAfter: 2),
      entry(failed: true),
    ]);
  });
}
