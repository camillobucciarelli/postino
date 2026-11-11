import 'package:get_it/get_it.dart';

import '../../domain/account.dart';
import '../../domain/mail_provider.dart';
import '../gmail/gmail_provider.dart';
import '../imap/imap_provider.dart';
import '../imap/imap_session.dart';
import '../mail_store.dart';
import '../microsoft/microsoft_provider.dart';

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
          storedIds: () => g<MailStore>().messageIds(account.id),
          // Tests register one that never opens a socket: `flutter test` stops HTTP, not IMAP.
          connect: g.isRegistered<ImapConnector>() ? g<ImapConnector>() : connectImap,
          appendToSent: appendsToSent(account.provider),
        ),
        ProviderKind.microsoft => MicrosoftProvider(account.id, g(), g(), g()),
      },
      instanceName: account.id,
      // An IMAP adapter holds a connection (and IDLE): logged out when the Account is removed.
      dispose: (p) => p is ImapProvider ? p.close() : null,
    );
  }
  return g<MailProvider>(instanceName: account.id);
}

/// Drops the adapter of the removed Account [accountId] (#174), closing its connection; the same Account connected
/// again gets a new one.
Future<void> forgetProvider(String accountId) async {
  final g = GetIt.I;
  if (g.isRegistered<MailProvider>(instanceName: accountId)) await g.unregister<MailProvider>(instanceName: accountId);
}
