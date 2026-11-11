import '../../../core/domain/account.dart';
import '../../../core/domain/accounts_repository.dart';
import '../../../core/domain/result.dart';

/// The Providers that connect with their own consent in the browser, and how: the choice per Provider in one place.
/// Null for the Providers that connect with a password. [loginHint] is the address of the Account being reconnected.
Future<Result<Account>>? connectWithConsent(AccountsRepository accounts, ProviderKind provider, {String? loginHint}) =>
    switch (provider) {
      ProviderKind.gmail => accounts.connectGmail(loginHint: loginHint),
      ProviderKind.microsoft => accounts.connectMicrosoft(loginHint: loginHint),
      ProviderKind.icloud || ProviderKind.imap => null,
    };
