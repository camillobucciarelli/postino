import 'dart:async';
import 'dart:io' show SocketException;
import 'dart:ui' show IsolateNameServer;

import 'package:file/memory.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/attachment_cache.dart';
import 'package:postino/core/data/error_log/encrypted_error_log.dart';
import 'package:postino/core/data/error_log/log_keys.dart';
import 'package:postino/core/data/imap/imap_session.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/managed_model_download.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync/sync_owner.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/app_updater.dart';
import 'package:postino/core/domain/connection_tester.dart';
import 'package:postino/core/domain/embedding_models.dart';
import 'package:postino/core/domain/error_log.dart';
import 'package:postino/core/domain/google_consent.dart';
import 'package:postino/core/domain/launch_at_login.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/microsoft_consent.dart';
import 'package:postino/core/domain/model_download.dart';
import 'package:postino/core/domain/model_manager.dart';
import 'package:postino/core/domain/notifications.dart';
import 'package:postino/core/domain/platform_services.dart';
import 'package:postino/core/domain/report_sharer.dart';
import 'package:postino/core/domain/server_discovery.dart';
import 'package:postino/core/domain/text_embedder.dart';
import 'package:postino/main.dart';

import 'fake_google_consent.dart';
import 'fake_mail_provider.dart';
import 'fake_mail_servers.dart';
import 'fake_microsoft_consent.dart';
import 'fake_model_manager.dart';
import 'fake_notifications.dart';
import 'fake_platform.dart';
import 'fake_report_sharer.dart';
import 'fake_text_embedder.dart';

/// Seam of the widget tests: real DB (in-memory SQLite), sync engine and DI wiring; fake Providers (an IMAP Account
/// without one is offline), consent, autodiscovery, test connection, HTTP client, keychain, clock, network,
/// links, Save As, report sharing, background sender, periodic sync, avvio al login, notifications, model manager, embedding model and file system (the model download is the real one on the GGUF); the error log is the real
/// one on that file system.
class Harness._() {
  final consent = FakeGoogleConsent();
  final microsoft = FakeMicrosoftConsent();
  final keychain = FakeSecureStore();
  final clock = FakeClock(DateTime.utc(2026, 10, 28, 12));
  final connectivity = FakeConnectivity();
  final links = FakeLinkOpener();
  final saver = FakeFileSaver();
  final background = FakeBackgroundSender();
  final periodic = FakePeriodicSync();
  final launchAtLogin = FakeLaunchAtLogin();
  final updater = FakeAppUpdater();
  final notifications = FakeNotifications();
  final sharer = FakeReportSharer();
  final embedder = FakeTextEmbedder();
  final models = FakeModelManager();
  final discovery = FakeServerDiscovery();
  final connection = FakeConnectionTester();

  /// Every HTTP request the app sends outside the Providers (the Google token revocation); each gets a 200, or
  /// throws [httpFailure] while it is set (no network).
  final httpRequests = <http.Request>[];
  Exception? httpFailure;

  /// While set, each HTTP request waits for it before answering: a slow network.
  Completer<void>? httpHold;

  /// The app's folders, in memory: the attachment cache and its temporary copies.
  /// [onFileOp] sees (and may fail, by throwing) every operation on them.
  late final fs = MemoryFileSystem(opHandle: (path, op) => onFileOp?.call(path, op));
  void Function(String path, FileSystemOp op)? onFileOp;

  /// The real error log, on [fs] under a test key.
  late final errorLog = EncryptedErrorLog(fs.directory('/support/logs'), logKeysFrom('0f' * 32), clock);

  /// [attachmentCap]: the attachment cache's cap in bytes, small to test eviction.
  static Future<Harness> create({int? attachmentCap}) async {
    await getIt.reset();
    // An engine a previous test started and never stopped still owns the sync (#212): its port would answer.
    IsolateNameServer.removePortNameMapping(syncOwnerName);
    final h = Harness._();
    getIt
      ..registerSingleton<PostinoDatabase>(PostinoDatabase.inMemory(), dispose: (db) => db.close())
      ..registerSingleton<GoogleConsent>(h.consent)
      ..registerSingleton<MicrosoftConsent>(h.microsoft)
      ..registerSingleton<SecureStore>(h.keychain)
      ..registerSingleton<Clock>(h.clock)
      ..registerSingleton<Connectivity>(h.connectivity)
      ..registerSingleton<LinkOpener>(h.links)
      ..registerSingleton<FileSaver>(h.saver)
      ..registerSingleton<BackgroundSender>(h.background)
      ..registerSingleton<PeriodicSync>(h.periodic)
      ..registerSingleton<LaunchAtLogin>(h.launchAtLogin)
      ..registerSingleton<AppUpdater>(h.updater)
      ..registerSingleton<Notifications>(h.notifications)
      ..registerSingleton<ErrorLog>(h.errorLog)
      ..registerSingleton<ReportSharer>(h.sharer)
      ..registerSingleton<TextEmbedder>(h.embedder)
      ..registerSingleton<ModelManager>(h.models)
      ..registerSingleton<ServerDiscovery>(h.discovery)
      ..registerSingleton<ConnectionTester>(h.connection)
      ..registerSingleton<http.Client>(
        MockClient((r) async {
          h.httpRequests.add(r);
          await h.httpHold?.future;
          if (h.httpFailure case final f?) throw f;
          return http.Response('', 200);
        }),
      )
      // An IMAP Account without a fake Provider gets the real adapter, offline: never a real server.
      ..registerSingleton<ImapConnector>((_, s) async => throw const SocketException('no network in tests'))
      ..registerSingleton<ModelDownload>(ManagedModelDownload(h.models, embeddingGemmaGguf))
      ..registerSingleton<AttachmentStorage>(
        await AttachmentStorage.open(
          h.fs.directory('/support/attachments'),
          h.fs.directory('/tmp/postino-attachments'),
          cap: attachmentCap ?? 500 * 1024 * 1024,
        ),
      );
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
  Future<FakeMailProvider> addAccount(String id, {int color = 0, ProviderKind provider = ProviderKind.gmail}) async {
    await getIt<MailStore>().addAccount(
      Account(id: id, address: '$id@example.com', provider: provider, color: color, position: _next++),
    );
    return providerFor(id);
  }
}
