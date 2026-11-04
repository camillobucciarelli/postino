import 'package:get_it/get_it.dart';

import '../../domain/account.dart';
import '../../domain/mail_provider.dart';
import '../gmail/gmail_provider.dart';

/// The Account's adapter, created on first use; tests register fakes by Account id beforehand.
/// The only place in core/data that names a concrete Provider (ADR 0002): the choice lives here, not in switches.
MailProvider providerFor(Account account) {
  final g = GetIt.I;
  if (!g.isRegistered<MailProvider>(instanceName: account.id)) {
    // ponytail: Gmail is the only Provider of step 1; Microsoft and IMAP adapters branch on account.provider at steps 4-5.
    g.registerLazySingleton<MailProvider>(
      () => GmailProvider(account.id, g(), g(), g()),
      instanceName: account.id,
    );
  }
  return g<MailProvider>(instanceName: account.id);
}
