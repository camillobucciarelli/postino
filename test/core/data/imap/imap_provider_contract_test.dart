// The IMAP adapter against GreenMail (#161): the contract groups it already honours.
@Tags(['imap'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../../../support/greenmail_server.dart';
import '../../../support/imap_harness.dart';
import '../../domain/mail_provider_contract.dart';

/// What the adapter does not do yet, by the ticket bringing it.
const _pending = {'body': 'T4 (#164)', 'conversation': 'T4 (#164)', 'action': 'T5 (#165)'};

void main() {
  if (imapSkipReason case final reason?) {
    test('IMAP contract', () {}, skip: reason);
    return;
  }
  tearDownAll(ImapHarness.stopServer);
  mailProviderAuthContract('ImapProvider', ImapHarness.create, pending: _pending);
  mailProviderSyncContract('ImapProvider', ImapHarness.create, pending: _pending);
  mailProviderLabelContract('ImapProvider', ImapHarness.create, pending: _pending);
}
