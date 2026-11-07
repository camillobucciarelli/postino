// The one place that picks an Account's adapter (ADR 0002) and its per-Provider choices (#166).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/imap/imap_provider.dart';
import 'package:postino/core/data/sync/provider_factory.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/platform_services.dart';

import '../../../support/fake_platform.dart';

void main() {
  final g = GetIt.I;
  setUp(() {
    g
      ..registerSingleton<SecureStore>(FakeSecureStore())
      ..registerSingleton<Clock>(FakeClock(DateTime.utc(2026, 11, 7)));
  });
  tearDown(g.reset);

  ImapProvider imapOf(ProviderKind kind) =>
      providerFor(Account(id: '${kind.name}:a', address: 'a@example.com', provider: kind, color: 0, position: 0))
          as ImapProvider;

  test('a generic IMAP Account APPENDs its sent messages to Inviati', () {
    expect(imapOf(ProviderKind.imap).appendToSent, isTrue);
  });

  // To confirm with the manual check on the iCloud test Account (#28): flip it if iCloud files SMTP submissions.
  test('iCloud APPENDs its sent messages to Inviati too, until the manual check says otherwise', () {
    expect(imapOf(ProviderKind.icloud).appendToSent, isTrue);
  });
}
