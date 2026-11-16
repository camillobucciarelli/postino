// The credentials of iCloud and IMAP in the sealed file of the Impostazioni (ADR 0019, #321 fetta 3): devices on
// in-memory databases with their own keychains, one fake backend standing for the file on Drive.
import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/account_settings_json.dart';
import 'package:postino/core/data/accounts_lock.dart';
import 'package:postino/core/data/accounts_settings_mirror.dart';
import 'package:postino/core/data/device_settings_store.dart';
import 'package:postino/core/data/imap/password_credentials.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/settings_sync.dart';
import 'package:postino/core/data/sync/credential_voci.dart';
import 'package:postino/core/data/sync/settings_envelope.dart';
import 'package:postino/core/data/sync/sync_key.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_servers.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';
import '../../../support/fake_settings_backend.dart';

const _id = 'icloud:ada@icloud.com';
const _key = 'credentials/$_id';

/// One device: database, keychain, sync and mirror of the Accounts, with [key] (paired) or none.
class _Device(final FakeSettingsBackend backend, final FakeClock clock, {final SyncKey? key}) {
  final db = PostinoDatabase.inMemory();
  final keychain = FakeSecureStore();
  final lock = AccountsLock();
  late final settings = DeviceSettingsStore(db);
  late final sync = SettingsSync(
    db,
    settings,
    clock,
    FakeConnectivity(),
    keysWith(key),
    keychain,
    lock,
    backendFor: (_) => backend,
  );
  late final mirror = AccountsSettingsMirror(db, MailStore(db), keychain, settings, lock, FakeAttachments());

  Future<void> start() async {
    await settings.setSettingsSyncAccount('gmail:sync@gmail.com');
    mirror.start();
  }

  Future<void> close() async {
    await mirror.stop();
    await sync.stop();
    await db.close();
  }

  /// [password] checked and saved here, as connecting the Account does.
  Future<void> connect(String password, {bool voce = true}) async {
    const account = Account(id: _id, address: 'ada@icloud.com', provider: ProviderKind.icloud, color: 0, position: 0);
    final credentials = _credentials(password);
    await credentials.write(keychain, _id);
    await db.accountsDao.upsert(account);
    await db.postinoSettingsDao.write(accountSettingsKey(_id), encodeAccountSettings(account), at: clock.now());
    if (voce) await writeCredentialVoce(db, _id, credentials.encode(), at: clock.now());
  }

  /// The secret in the keychain here.
  Future<String?> secret() async => (await PasswordCredentials.read(keychain, _id))?.password;

  Future<AccountStatus?> status() async =>
      (await MailStore(db).accounts()).where((a) => a.id == _id).firstOrNull?.status;

  Future<void> syncNow() async {
    await sync.syncNow();
    await pumpEventQueue();
  }

  /// Every value the database holds for the Impostazioni.
  Future<String> rows() async => [for (final e in await db.postinoSettingsDao.entries()) e.value].join('\n');
}

/// The secret the file carries for the Account.
String? _inFile(FakeSettingsBackend file) =>
    PasswordCredentials.decode(jsonEncode((file.entries()[_key]! as Map<String, Object?>)['value'])).password;

PasswordCredentials _credentials(String password) => PasswordCredentials(
  password: password,
  servers: const ServerSettings(
    imap: MailServer(host: 'imap.mail.me.com', port: 993, security: ServerSecurity.ssl),
    smtp: MailServer(host: 'smtp.mail.me.com', port: 587, security: ServerSecurity.starttls),
  ),
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late FakeSettingsBackend file;
  late FakeClock clock;
  final devices = <_Device>[];

  Future<_Device> device({SyncKey? key}) async {
    final d = _Device(file, clock, key: key ?? testSyncKey);
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

  test('an iCloud Account connected on A arrives on B attivo, its password in the keychain only', () async {
    final a = await device();
    final b = await device();
    await a.connect('pw-one');
    await a.syncNow();

    expect(file.file, isNot(contains('pw-one')));
    expect(file.entries()[_key], containsPair('value', jsonDecode(_credentials('pw-one').encode())));
    await b.syncNow();
    expect(await b.status(), AccountStatus.attivo);
    expect(await b.secret(), 'pw-one');
    expect(b.keychain.values[PasswordCredentials.keychainKey(_id)], _credentials('pw-one').encode());
    // The databases keep only fingerprints.
    for (final d in [a, b]) {
      expect(await d.rows(), isNot(contains('pw-one')));
      expect(await d.db.postinoSettingsDao.read(_key), credentialFingerprint(_credentials('pw-one').encode()));
    }
  });

  test('the fingerprints make no rewrite of the file at each cycle', () async {
    final a = await device();
    final b = await device();
    await a.connect('pw-one');
    for (final d in [a, b, a, b]) {
      await d.syncNow();
    }
    final writes = file.writes;
    for (final d in [a, b, a, b]) {
      await d.syncNow();
    }
    expect(file.writes, writes);
    expect(await a.db.postinoSettingsDao.watchDirty().first, 0);
    expect(await b.db.postinoSettingsDao.watchDirty().first, 0);
  });

  test('a device not paired neither writes its credentials nor reads the others', () async {
    final a = await device();
    await a.connect('pw-one');
    await a.syncNow();
    final sealed = file.file;

    final b = _Device(file, clock);
    devices.add(b);
    await b.start();
    await b.connect('pw-two');
    await b.syncNow();

    expect(file.file, sealed);
    expect(await b.secret(), 'pw-two');
    expect(b.keychain.values.values.join(), isNot(contains('pw-one')));
  });

  test('a file in clear never brings credentials, and the first sealed write carries the ones here', () async {
    file.file = jsonEncode({
      'schemaVersion': 2,
      'entries': {
        _key: {
          'value': jsonDecode(_credentials('planted').encode()),
          'updatedAt': 9999999999999,
          'deviceId': 'z',
          'deleted': false,
        },
      },
    });
    final a = _Device(file, clock);
    devices.add(a);
    await a.start();
    await a.connect('pw-one');
    await a.syncNow();

    expect(await a.secret(), 'pw-one');
    expect(openSettings(file.file!, null), isA<LockedCopy>());
    expect(file.file, isNot(contains('pw-one')));
  });

  test('a password changed on one device reaches the other; an older one never overwrites it', () async {
    final a = await device();
    final b = await device();
    await a.connect('pw-one');
    await a.syncNow();
    await b.syncNow();

    // A writes an older change offline, B a newer one.
    tick();
    await a.connect('pw-old');
    tick();
    await b.connect('pw-new');
    for (final d in [b, a, b, a]) {
      await d.syncNow();
    }
    expect(await a.secret(), 'pw-new');
    expect(await b.secret(), 'pw-new');
    expect(_inFile(file), 'pw-new');
  });

  test('a credential refused by the server leaves the Account da ricollegare, with no rewrite', () async {
    final a = await device();
    final b = await device();
    await a.connect('pw-one');
    await a.syncNow();
    await b.syncNow();
    // The mail sync got an AuthFailure.
    await b.db.accountsDao.setStatus(_id, AccountStatus.daRicollegare);
    final writes = file.writes;
    for (final d in [b, a, b]) {
      await d.syncNow();
    }
    expect(await b.status(), AccountStatus.daRicollegare);
    expect(file.writes, writes);

    // A new password from A brings it back.
    tick();
    await a.connect('pw-two');
    await a.syncNow();
    await b.syncNow();
    expect((await b.status(), await b.secret()), (AccountStatus.attivo, 'pw-two'));
  });

  test('a credential that comes before its Account is kept, and the Account arrives attivo', () async {
    final a = await device();
    final b = await device();
    await a.connect('pw-one');
    await a.syncNow();
    // B reads the file while it holds only the credential.
    final entries = Map.of(file.entries())..remove(accountSettingsKey(_id));
    final whole = file.file;
    file.file = sealedWith({'schemaVersion': 3, 'entries': entries});
    await b.syncNow();
    expect(await b.status(), isNull);
    expect(await b.secret(), 'pw-one');

    file.file = whole;
    await b.syncNow();
    await pumpEventQueue();
    expect(await b.status(), AccountStatus.attivo);
  });

  test('an Account da ricollegare here turns attivo when its credential arrives', () async {
    final a = await device();
    final b = await device();
    // The Account reaches B without credentials, as before this version.
    await a.connect('pw-one', voce: false);
    final saved = Map.of(a.keychain.values);
    a.keychain.values.clear();
    await a.syncNow();
    await b.syncNow();
    expect(await b.status(), AccountStatus.daRicollegare);

    // A connected it before this version: no voce yet, its keychain fills it in at the next cycle.
    a.keychain.values.addAll(saved);
    await a.syncNow();
    expect(file.entries()[_key], isNotNull);
    await b.syncNow();
    expect((await b.status(), await b.secret()), (AccountStatus.attivo, 'pw-one'));
  });

  test('a voce whose secret left the keychain meanwhile keeps the copy in the file, and stays to upload', () async {
    final a = await device();
    await a.connect('pw-one');
    await a.syncNow();
    tick();
    await a.connect('pw-two');
    // The keychain changed after the voce was written.
    await _credentials('pw-x').write(a.keychain, _id);
    await a.syncNow();

    expect(_inFile(file), 'pw-one');
    expect(jsonEncode(file.entries()), isNot(contains('pw-x')));
    expect(await a.db.postinoSettingsDao.watchDirty().first, 1);
  });

  test('a newer remote credential this Postino cannot read is kept over an older one here, which waits', () async {
    final a = await device();
    await a.connect('pw-one');
    await a.syncNow();
    tick();
    await a.connect('pw-two');
    final newer = {
      'value': {'shape': 'of a newer Postino'},
      'updatedAt': clock.now().millisecondsSinceEpoch + 1000,
      'deviceId': 'z',
      'deleted': false,
    };
    file.file = sealedWith({
      'schemaVersion': 3,
      'entries': {...file.entries(), _key: newer},
    });
    await a.db.postinoSettingsDao.write('swipe/left', '"archive"', at: clock.now());
    await a.syncNow();

    expect(file.entries()[_key], newer);
    expect(file.entries(), contains('swipe/left'));
    expect((await a.db.postinoSettingsDao.readRow(_key))!.dirty, isTrue);
    final writes = file.writes;
    await a.syncNow();
    expect(file.writes, writes);
  });

  test('a connection here while a cycle is in flight is never overwritten by the remote password', () async {
    final a = await device();
    final b = await device();
    await a.connect('pw-one');
    await a.syncNow();
    await b.syncNow();
    tick();
    await a.connect('pw-two');
    await a.syncNow();

    file.readGate = Completer<void>();
    final cycle = b.sync.syncNow();
    await pumpEventQueue();
    tick();
    await b.connect('pw-here');
    file.readGate!.complete();
    file.readGate = null;
    await cycle;
    await pumpEventQueue();

    expect(await b.secret(), 'pw-here');
    expect(await b.db.postinoSettingsDao.read(_key), credentialFingerprint(_credentials('pw-here').encode()));
  });

  test(
    'a live credential of an Account with a tombstone never reaches the keychain, and goes as a tombstone',
    () async {
      final a = await device();
      final b = await device();
      await a.connect('pw-one');
      await a.syncNow();
      // A fetta 1 Postino removed the Account: a tombstone for `accounts/` only, the credential still live.
      final entries = Map.of(file.entries());
      entries[accountSettingsKey(_id)] = {'value': null, 'updatedAt': 9999999999999, 'deviceId': 'z', 'deleted': true};
      final credential = Map.of(entries[_key]! as Map<String, Object?>)..['updatedAt'] = 9999999999999;
      entries[_key] = credential;
      file.file = sealedWith({'schemaVersion': 3, 'entries': entries});
      await b.syncNow();
      expect(await b.secret(), isNull);
      expect(await b.status(), isNull);

      // The next write of the file drops the password.
      await b.db.postinoSettingsDao.write('swipe/left', '"archive"', at: clock.now());
      await b.syncNow();
      expect(file.entries()[_key], containsPair('deleted', true));
      expect(jsonEncode(file.entries()), isNot(contains('pw-one')));
    },
  );

  test('only iCloud and IMAP Accounts get a credentials voce from the keychain', () async {
    final a = await device();
    const gmail = 'gmail:bob@gmail.com';
    await a.db.accountsDao.upsert(
      const Account(id: gmail, address: 'bob@gmail.com', provider: ProviderKind.gmail, color: 0, position: 1),
    );
    await a.keychain.write(PasswordCredentials.keychainKey(gmail), _credentials('pw-g').encode());
    await a.connect('pw-one', voce: false);
    await a.syncNow();
    expect(await a.db.postinoSettingsDao.entry('credentials/$gmail'), isNull);
    expect(await a.db.postinoSettingsDao.entry(_key), isNotNull);
  });

  test('a locked keychain never stops the rest of the Impostazioni', () async {
    final a = await device();
    await a.connect('pw-one', voce: false);
    a.keychain.failure = Exception('locked');
    await a.syncNow();
    expect(file.entries(), contains(accountSettingsKey(_id)));
    expect(file.entries(), isNot(contains(_key)));
  });

  test('removing the Account tombstones its credential and forgets it on the other device', () async {
    final a = await device();
    final b = await device();
    await a.connect('pw-one');
    await a.syncNow();
    await b.syncNow();
    tick();
    await MailStore(a.db).removeAccount(_id, at: clock.now());
    await PasswordCredentials.delete(a.keychain, _id);
    await a.syncNow();
    await b.syncNow();
    await pumpEventQueue();

    expect(file.entries()[_key], containsPair('deleted', true));
    expect(await b.status(), isNull);
    expect(b.keychain.values, isEmpty);
  });

  test('voci of credentials this Postino does not know stay in the file and never reach the database', () async {
    const oauth = 'credentials/gmail:ada@gmail.com/c1';
    file.file = sealedWith({
      'schemaVersion': 3,
      'entries': {
        oauth: {
          'value': {'refresh': 'rt-secret', 'scopes': <String>[]},
          'updatedAt': 1,
          'deviceId': 'z',
          'deleted': false,
        },
        // Not password and servers: left out.
        'credentials/imap:bob@example.com': {
          'value': {'nope': 'bad-secret'},
          'updatedAt': 1,
          'deviceId': 'z',
          'deleted': false,
        },
      },
    });
    final a = await device();
    await a.connect('pw-one');
    await a.syncNow();
    expect(
      file.entries(),
      containsPair('credentials/imap:bob@example.com', containsPair('value', {'nope': 'bad-secret'})),
    );
    expect(file.entries(), contains(oauth));
    expect(await a.rows(), allOf(isNot(contains('rt-secret')), isNot(contains('bad-secret'))));
    expect(a.keychain.values.values.join(), isNot(contains('bad-secret')));
  });

  test('no password in the logs nor in the failures, nor in a voce printed', () async {
    final logs = <String>[];
    final print = debugPrint;
    debugPrint = (m, {wrapWidth}) => logs.add('$m');
    addTearDown(() => debugPrint = print);

    final a = await device();
    final b = await device();
    await a.connect('pw-one');
    await a.syncNow();
    file.writeFailure = const UnexpectedFailure('drive down');
    tick();
    await b.connect('pw-two');
    await b.syncNow();
    final outcome = (await b.sync.watchStatus().first).values.single.failure;

    expect(outcome, isNotNull);
    expect(
      [...logs, '$outcome', for (final e in await b.db.postinoSettingsDao.entries()) '$e'].join('\n'),
      allOf(isNot(contains('pw-')), isNot(contains('fingerprint'))),
    );
  });
}
