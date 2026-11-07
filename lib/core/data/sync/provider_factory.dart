import 'package:get_it/get_it.dart';

import '../../domain/account.dart';
import '../../domain/mail_provider.dart';
import '../gmail/gmail_provider.dart';
import '../imap/imap_provider.dart';
import '../imap/imap_session.dart';
import '../imap/unsynced_provider.dart';
import '../mail_store.dart';

/// Whether Postino APPENDs a sent message to Inviati on [provider] (#166): the generic IMAP servers do not file
/// SMTP submissions themselves.
// Decision to confirm with the manual check on the iCloud test Account (#28): Apple does not document whether
// iCloud files SMTP submissions in «Sent Messages»; until then Postino APPENDs, and Inviati is searched by
// Message-ID first, so a retry never adds a second copy.
bool appendsToSent(ProviderKind provider) => switch (provider) {
  ProviderKind.icloud => true,
  _ => true,
};

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
          messageIdOf: (id) => g<MailStore>().rfcMessageId(account.id, id),
          // Tests register one that never opens a socket: `flutter test` stops HTTP, not IMAP.
          connect: g.isRegistered<ImapConnector>() ? g<ImapConnector>() : connectImap,
          appendToSent: appendsToSent(account.provider),
        ),
        // ponytail: no Microsoft adapter before step 5: it syncs nothing meanwhile.
        ProviderKind.microsoft => const UnsyncedProvider(),
      },
      instanceName: account.id,
    );
  }
  return g<MailProvider>(instanceName: account.id);
}

/// Forgets the adapter of a removed Account, closing its IMAP session if it has one: the next [providerFor] of an
/// Account with that id makes a new one.
Future<void> releaseProvider(String accountId) async {
  final g = GetIt.I;
  if (!g.isRegistered<MailProvider>(instanceName: accountId)) return;
  await g.unregister<MailProvider>(
    instanceName: accountId,
    disposingFunction: (p) => p is ImapProvider ? p.close() : null,
  );
}
