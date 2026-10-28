import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/google_consent.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/platform_services.dart';
import 'package:postino/main.dart';

import 'fake_google_consent.dart';
import 'fake_mail_provider.dart';
import 'fake_platform.dart';

/// Seam of the widget tests: real DB (in-memory SQLite), sync engine and DI wiring; fake Providers, consent and keychain.
class Harness {
  Harness._();

  final consent = FakeGoogleConsent();
  final keychain = FakeSecureStore();

  static Future<Harness> create() async {
    await getIt.reset();
    final h = Harness._();
    getIt
      ..registerSingleton<PostinoDatabase>(
        PostinoDatabase.inMemory(),
        dispose: (db) => db.close(),
      )
      ..registerSingleton<GoogleConsent>(h.consent)
      ..registerSingleton<SecureStore>(h.keychain);
    await configureDependencies(environment: 'test');
    return h;
  }

  int _next = 0;

  /// Registers the fake Provider the Account [id] will sync from, without creating the Account.
  FakeMailProvider providerFor(String id) {
    final provider = FakeMailProvider();
    getIt.registerSingleton<MailProvider>(provider, instanceName: id);
    return provider;
  }

  /// Adds an Account backed by a fake Provider registered in get_it.
  Future<FakeMailProvider> addAccount(
    String id, {
    int color = 0xFF2196F3,
  }) async {
    await getIt<MailStore>().addAccount(
      Account(
        id: id,
        address: '$id@example.com',
        provider: ProviderKind.gmail,
        color: color,
        position: _next++,
      ),
    );
    return providerFor(id);
  }
}
