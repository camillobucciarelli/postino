// The IMAP adapter against GreenMail (#161): the contract groups it already honours.
@Tags(['imap'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../../../support/greenmail_server.dart';
import '../../../support/imap_harness.dart';
import '../../domain/mail_provider_contract.dart';

/// What the adapter does not do yet, by the ticket bringing it.
const _pending = {'action': 'T5 (#165)'};

void main() {
  if (imapSkipReason case final reason?) {
    test('IMAP contract', () {}, skip: reason);
    return;
  }
  tearDownAll(ImapHarness.stopServer);
  mailProviderAuthContract('ImapProvider', ImapHarness.create, pending: _pending);
  mailProviderSyncContract('ImapProvider', ImapHarness.create, pending: _pending);
  mailProviderLabelContract('ImapProvider', ImapHarness.create, pending: _pending);
  mailProviderAttachmentContract('ImapProvider', ImapHarness.create);
  mailProviderDraftContract('ImapProvider', ImapHarness.create, pending: _pending);
  mailProviderSendContract('ImapProvider', ImapHarness.create);
}
