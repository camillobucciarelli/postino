// The OAuth credentials of Gmail and Microsoft in the sealed file of the Impostazioni (ADR 0019, #321 fetta 4):
// devices on in-memory databases with their own keychains and OAuth clients, one fake backend for the file on Drive.
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/account_settings_json.dart';
import 'package:postino/core/data/accounts_lock.dart';
import 'package:postino/core/data/accounts_settings_mirror.dart';
import 'package:postino/core/data/device_settings_store.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/oauth/oauth_tokens.dart';
import 'package:postino/core/data/oauth/oauth_voce.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/settings_sync.dart';
import 'package:postino/core/data/sync/credential_voci.dart';
import 'package:postino/core/domain/account.dart';

import '../../../support/fake_platform.dart';
import '../../../support/fake_settings_backend.dart';

const _gmail = 'gmail:ada@gmail.com';
const _microsoft = 'microsoft:ada@outlook.com';

/// The Google client of iOS, macOS and Android, and the «App desktop» one of Windows and Linux.
const _apple = 'apple-client.apps.googleusercontent.com';
const _desktop = 'desktop-client.apps.googleusercontent.com';
const _ms = 'ms-client';

const _mail = ['https://mail.google.com/', 'openid', 'email'];
const _drive = [..._mail, 'https://www.googleapis.com/auth/drive.appdata'];

/// One device: database, keychain, sync and mirror of the Accounts, with its own Google client.
class _Device(final FakeSettingsBackend backend, final FakeClock clock, {final String google = _apple}) {
  final db = PostinoDatabase.inMemory();
  final keychain = FakeSecureStore();
  final lock = AccountsLock();
  late final settings = DeviceSettingsStore(db);
  late final sync = SettingsSync(
    db,
    settings,
    clock,
    FakeConnectivity(),
    keysWith(testSyncKey),
    keychain,
    lock,
    backendFor: (_) => backend,
    oauthClientOf: _clientOf,
  );
  late final mirror = AccountsSettingsMirror(db, MailStore(db), keychain, settings, lock, FakeAttachments());

  String _clientOf(ProviderKind p) => switch (p) {
    ProviderKind.gmail => google,
    ProviderKind.microsoft => _ms,
    _ => '',
  };

  Future<void> start() async {
    await settings.setSettingsSyncAccount('gmail:sync@gmail.com');
    mirror.start();
  }

  Future<void> close() async {
    await mirror.stop();
    await sync.stop();
    await db.close();
  }

  /// The consent to [id] given here, as connecting the Account does: [refresh] with [scopes] for this client.
  Future<void> connect(String id, String refresh, {List<String> scopes = _mail}) async {
    final provider = id.startsWith('gmail') ? ProviderKind.gmail : ProviderKind.microsoft;
    final account = Account(id: id, address: id.split(':').last, provider: provider, color: 0, position: 0);
    await OAuthTokens(
      access: 'a-$refresh',
      refresh: refresh,
      expiresAt: clock.now().add(const Duration(hours: 1)),
      scopes: scopes,
    ).write(keychain, id);
    await db.accountsDao.upsert(account);
    await db.postinoSettingsDao.write(accountSettingsKey(id), encodeAccountSettings(account), at: clock.now());
    // A grant without scopes is a token saved before they were kept: no voce until its refresh tells them.
    if (scopes.isEmpty) return;
    await writeCredentialVoce(
      db,
      oauthCredentialsKey(id, _clientOf(provider)),
      OAuthVoce(refresh: refresh, scopes: scopes).encode(),
      at: clock.now(),
    );
  }

  /// The tokens in use here for [id].
  Future<OAuthTokens?> inUse([String id = _gmail]) => OAuthTokens.read(keychain, id);

  Future<AccountStatus?> status([String id = _gmail]) async =>
      (await MailStore(db).accounts()).where((a) => a.id == id).firstOrNull?.status;

  Future<void> syncNow() async {
    await sync.syncNow();
    await pumpEventQueue();
  }

  Future<String> rows() async => [for (final e in await db.postinoSettingsDao.entries()) e.value].join('\n');
}

/// The refresh token the file carries for [id] and [client].
String? _inFile(FakeSettingsBackend file, String id, String client) =>
    switch (file.entries()[oauthCredentialsKey(id, client)]) {
      {'value': final Map<String, Object?> v} => OAuthVoce.decode(jsonEncode(v)).refresh,
      _ => null,
    };

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late FakeSettingsBackend file;
  late FakeClock clock;
  final devices = <_Device>[];

  Future<_Device> device({String google = _apple}) async {
    final d = _Device(file, clock, google: google);
    devices.add(d);
    await d.start();
    return d;
  }

  setUp(() {
    file = FakeSettingsBackend();
    clock = FakeClock(DateTime.utc(2026, 11, 16, 9));
  });
  tearDown(() async {
    for (final d in devices) {
      await d.close();
    }
    devices.clear();
  });

  void tick() => clock.advance(const Duration(seconds: 1));

  Future<void> rounds(List<_Device> ds) async {
    for (final d in [...ds, ...ds]) {
      await d.syncNow();
    }
  }

  test('a Gmail Account connected on A arrives on B attivo; the refresh token only in the file and keychain', () async {
    final a = await device();
    final b = await device();
    await a.connect(_gmail, 'r-one');
    await a.syncNow();

    expect(file.file, isNot(contains('r-one')));
    expect(_inFile(file, _gmail, _apple), 'r-one');
    // Never the access token.
    expect(jsonEncode(file.entries()), isNot(contains('a-r-one')));
    await b.syncNow();
    expect(await b.status(), AccountStatus.attivo);
    expect((await b.inUse())!.refresh, 'r-one');
    for (final d in [a, b]) {
      expect(await d.rows(), isNot(contains('r-one')));
    }

    // No rewrite of the file at each cycle.
    await rounds([a, b]);
    final writes = file.writes;
    await rounds([a, b]);
    expect(file.writes, writes);
  });

  test(
    'on Windows a Gmail Account from iOS stays da ricollegare; once connected there both clients keep theirs',
    () async {
      final a = await device();
      final w = await device(google: _desktop);
      await a.connect(_gmail, 'r-apple');
      await a.syncNow();
      await w.syncNow();
      expect(await w.status(), AccountStatus.daRicollegare);
      expect(await w.inUse(), isNull);
      // The other client's voce waits in the keychain, to write the file again without losing it.
      expect(w.keychain.values[oauthVoceKeychainKey(oauthCredentialsKey(_gmail, _apple))], contains('r-apple'));

      // Reconnected on Windows while A connects again too: both write, neither voce is lost.
      tick();
      await w.connect(_gmail, 'r-desktop');
      await a.connect(_gmail, 'r-apple-2');
      await rounds([w, a]);
      expect(_inFile(file, _gmail, _apple), 'r-apple-2');
      expect(_inFile(file, _gmail, _desktop), 'r-desktop');
      expect((await a.inUse())!.refresh, 'r-apple-2');
      expect((await w.inUse())!.refresh, 'r-desktop');

      // The file written by a device that read it before the other's voce: the other client's comes back.
      final entries = Map.of(file.entries())..remove(oauthCredentialsKey(_gmail, _desktop));
      file.file = sealedWith({'schemaVersion': 3, 'entries': entries});
      await a.db.postinoSettingsDao.write('swipe/left', '"archive"', at: clock.now());
      await a.syncNow();
      expect(_inFile(file, _gmail, _desktop), 'r-desktop');
    },
  );

  test('a token with fewer scopes never replaces the one with Drive, here nor in the file', () async {
    final a = await device();
    final b = await device();
    await a.connect(_gmail, 'r-drive', scopes: _drive);
    await a.syncNow();
    await b.syncNow();

    // B connects the Account again without Drive, later.
    tick();
    await b.connect(_gmail, 'r-mail');
    await rounds([b, a, b]);

    expect((await a.inUse())!.refresh, 'r-drive');
    expect(_inFile(file, _gmail, _apple), 'r-drive');
    expect((await b.inUse())!.refresh, 'r-drive');
    final writes = file.writes;
    await rounds([a, b]);
    expect(file.writes, writes);
  });

  test('an Account da ricollegare takes a remote token with fewer scopes, and turns attivo', () async {
    final a = await device();
    final b = await device();
    await a.connect(_gmail, 'r-drive', scopes: _drive);
    await a.syncNow();
    await b.syncNow();
    // The Provider refused A's token.
    await a.db.accountsDao.setStatus(_gmail, AccountStatus.daRicollegare);

    tick();
    await b.connect(_gmail, 'r-mail');
    await rounds([b, a]);
    expect((await a.status(), (await a.inUse())!.refresh), (AccountStatus.attivo, 'r-mail'));
  });

  test('a Microsoft token rotated on A reaches B, which keeps its access token; no ping-pong', () async {
    final a = await device();
    final b = await device();
    const scopes = ['openid', 'offline_access', 'Mail.ReadWrite', 'Mail.Send'];
    await a.connect(_microsoft, 'm-one', scopes: scopes);
    await rounds([a, b]);
    final access = (await b.inUse(_microsoft))!.access;

    // A refresh on A: Microsoft rotated the refresh token (OAuthAuth writes the tokens in use).
    tick();
    await OAuthTokens(
      access: 'a-new',
      refresh: 'm-two',
      expiresAt: clock.now().add(const Duration(hours: 1)),
      scopes: scopes,
    ).write(a.keychain, _microsoft);
    await a.syncNow();
    expect(_inFile(file, _microsoft, _ms), 'm-two');
    await b.syncNow();
    final there = (await b.inUse(_microsoft))!;
    expect((there.refresh, there.access), ('m-two', access));

    final writes = file.writes;
    await rounds([a, b, a, b]);
    expect(file.writes, writes);
    expect(await b.db.postinoSettingsDao.watchDirty().first, 0);
  });

  test('tokens saved before the scopes were kept stay here until a refresh tells them', () async {
    final a = await device();
    final b = await device();
    await a.connect(_gmail, 'r-new');
    await a.syncNow();
    // B connected the Account before this version: tokens without scopes, no voce.
    await b.connect(_gmail, 'r-old', scopes: const []);
    await rounds([b, a]);

    expect((await b.inUse())!.refresh, 'r-old');
    expect(_inFile(file, _gmail, _apple), 'r-new');
  });

  test('removing the Account tombstones every voce of its credentials and forgets them on the other device', () async {
    final a = await device();
    final b = await device();
    final w = await device(google: _desktop);
    await a.connect(_gmail, 'r-apple');
    await w.connect(_gmail, 'r-desktop');
    await rounds([a, w, b]);
    expect((await b.inUse())!.refresh, 'r-apple');

    tick();
    await MailStore(a.db).removeAccount(_gmail, at: clock.now());
    await rounds([a, b, w]);

    for (final client in [_apple, _desktop]) {
      expect(file.entries()[oauthCredentialsKey(_gmail, client)], containsPair('deleted', true));
    }
    expect(await b.status(), isNull);
    expect(b.keychain.values.keys.where((k) => k.startsWith('oauth:')), isEmpty);
    expect(w.keychain.values.keys.where((k) => k.startsWith('oauth:')), isEmpty);
  });

  test('no OAuth token in the logs, in a voce printed or in the tokens printed', () async {
    final logs = <String>[];
    final print = debugPrint;
    debugPrint = (m, {wrapWidth}) => logs.add('$m');
    addTearDown(() => debugPrint = print);

    final a = await device();
    final b = await device();
    await a.connect(_gmail, 'r-one');
    await rounds([a, b]);
    expect(
      [
        ...logs,
        for (final e in await b.db.postinoSettingsDao.entries()) '$e',
        '${await b.inUse()}',
        '${const OAuthVoce(refresh: 'r-one', scopes: _mail)}',
      ].join('\n'),
      isNot(contains('r-one')),
    );
  });
}
