import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/main.dart';

import 'fake_mail_provider.dart';

/// Seam of the widget tests: real DB (in-memory SQLite), sync engine and DI wiring; fake Providers.
class Harness {
  Harness._();

  static Future<Harness> create() async {
    await getIt.reset();
    getIt.registerSingleton<PostinoDatabase>(
      PostinoDatabase.inMemory(),
      dispose: (db) => db.close(),
    );
    await configureDependencies(environment: 'test');
    return Harness._();
  }

  int _next = 0;

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
    final provider = FakeMailProvider();
    getIt.registerSingleton<MailProvider>(provider, instanceName: id);
    return provider;
  }
}
