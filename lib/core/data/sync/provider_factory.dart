import 'package:get_it/get_it.dart';

import '../../domain/account.dart';
import '../../domain/mail_provider.dart';
import '../gmail/gmail_provider.dart';
import '../imap/imap_provider.dart';
import '../imap/imap_session.dart';
import '../imap/unsynced_provider.dart';

/// The Account's adapter, created on first use; tests register fakes by Account id beforehand.
/// The only place in core/data that names a concrete Provider (ADR 0002): the choice lives here, not in switches.
MailProvider providerFor(Account account) {
  final g = GetIt.I;
  if (!g.isRegistered<MailProvider>(instanceName: account.id)) {
    g.registerLazySingleton<MailProvider>(
      () => switch (account.provider) {
        ProviderKind.gmail => GmailProvider(account.id, g(), g(), g()),
        ProviderKind.icloud || ProviderKind.imap => ImapProvider(
          account.id,
          account.address,
          g(),
          g(),
          // Tests register one that never opens a socket: `flutter test` stops HTTP, not IMAP.
          connect: g.isRegistered<ImapConnector>() ? g<ImapConnector>() : connectImap,
        ),
        // ponytail: no Microsoft adapter before step 5: it syncs nothing meanwhile.
        ProviderKind.microsoft => const UnsyncedProvider(),
      },
      instanceName: account.id,
    );
  }
  return g<MailProvider>(instanceName: account.id);
}
