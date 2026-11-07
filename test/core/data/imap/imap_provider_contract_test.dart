// The IMAP adapter against GreenMail (#161): the contract groups it already honours.
@Tags(['imap'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../../../support/greenmail_server.dart';
import '../../../support/imap_harness.dart';
import '../../domain/mail_provider_contract.dart';

void main() {
  if (imapSkipReason case final reason?) {
    test('IMAP contract', () {}, skip: reason);
    return;
  }
  tearDownAll(ImapHarness.stopServer);
  mailProviderAuthContract('ImapProvider', ImapHarness.create);
  mailProviderSyncContract('ImapProvider', ImapHarness.create);
  mailProviderLabelContract('ImapProvider', ImapHarness.create);
  mailProviderActionContract('ImapProvider', ImapHarness.create);
  mailProviderAttachmentContract('ImapProvider', ImapHarness.create);
  mailProviderDraftContract('ImapProvider', ImapHarness.create);
  mailProviderSendContract('ImapProvider', ImapHarness.create);
}
