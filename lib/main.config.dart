// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:get_it/get_it.dart' as _i174;
import 'package:http/http.dart' as _i519;
import 'package:injectable/injectable.dart' as _i526;
import 'package:postino/core/data/accounts_service.dart' as _i413;
import 'package:postino/core/data/attachment_cache.dart' as _i696;
import 'package:postino/core/data/auto_labels_store.dart' as _i452;
import 'package:postino/core/data/desktop/launch_at_login_module.dart' as _i377;
import 'package:postino/core/data/desktop/native_app_window.dart' as _i634;
import 'package:postino/core/data/desktop/native_system_tray.dart' as _i586;
import 'package:postino/core/data/device_settings_store.dart' as _i207;
import 'package:postino/core/data/error_log/error_log_module.dart' as _i907;
import 'package:postino/core/data/gmail/google_consent.dart' as _i1009;
import 'package:postino/core/data/local_notifications.dart' as _i102;
import 'package:postino/core/data/mail_store.dart' as _i385;
import 'package:postino/core/data/model_module.dart' as _i260;
import 'package:postino/core/data/outbox_store.dart' as _i37;
import 'package:postino/core/data/platform_services.dart' as _i524;
import 'package:postino/core/data/postino_database.dart' as _i1028;
import 'package:postino/core/data/report_sharer_module.dart' as _i439;
import 'package:postino/core/data/settings_sync.dart' as _i311;
import 'package:postino/core/data/simulated_model_download.dart' as _i29;
import 'package:postino/core/data/simulated_network_type.dart' as _i614;
import 'package:postino/core/data/sync/new_mail_notifier.dart' as _i26;
import 'package:postino/core/data/sync_engine.dart' as _i893;
import 'package:postino/core/data/trusted_senders_store.dart' as _i412;
import 'package:postino/core/domain/accounts_repository.dart' as _i382;
import 'package:postino/core/domain/app_window.dart' as _i853;
import 'package:postino/core/domain/attachment_repository.dart' as _i278;
import 'package:postino/core/domain/auto_labels_repository.dart' as _i205;
import 'package:postino/core/domain/error_log.dart' as _i346;
import 'package:postino/core/domain/google_consent.dart' as _i902;
import 'package:postino/core/domain/inbox_repository.dart' as _i845;
import 'package:postino/core/domain/launch_at_login.dart' as _i462;
import 'package:postino/core/domain/launch_at_login_use_case.dart' as _i166;
import 'package:postino/core/domain/mail_sync.dart' as _i705;
import 'package:postino/core/domain/model_download.dart' as _i96;
import 'package:postino/core/domain/model_manager.dart' as _i689;
import 'package:postino/core/domain/network_type.dart' as _i421;
import 'package:postino/core/domain/notifications.dart' as _i184;
import 'package:postino/core/domain/open_conversation.dart' as _i350;
import 'package:postino/core/domain/outbox_repository.dart' as _i700;
import 'package:postino/core/domain/platform_services.dart' as _i398;
import 'package:postino/core/domain/report_sharer.dart' as _i325;
import 'package:postino/core/domain/settings_repository.dart' as _i307;
import 'package:postino/core/domain/settings_sync_account_use_case.dart'
    as _i114;
import 'package:postino/core/domain/system_tray.dart' as _i739;
import 'package:postino/core/domain/trusted_senders_repository.dart' as _i359;
import 'package:postino/features/impostazioni/domain/auto_label_switch_use_case.dart'
    as _i320;
import 'package:postino/features/posta/domain/conversation_label_intents.dart'
    as _i812;
import 'package:postino/features/posta/domain/reply_draft_use_case.dart'
    as _i510;
import 'package:postino/features/segnalazione/domain/report_problem_use_case.dart'
    as _i802;

const String _prod = 'prod';

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final attachmentModule = _$AttachmentModule();
    final httpModule = _$HttpModule();
    final launchAtLoginModule = _$LaunchAtLoginModule();
    final modelModule = _$ModelModule();
    final errorLogModule = _$ErrorLogModule();
    final reportSharerModule = _$ReportSharerModule();
    final databaseModule = _$DatabaseModule();
    final mailStoreModule = _$MailStoreModule();
    final syncModule = _$SyncModule();
    gh.lazySingleton<_i350.OpenConversation>(() => _i350.OpenConversation());
    gh.lazySingleton<_i421.NetworkType>(() => _i614.SimulatedNetworkType());
    gh.singleton<_i398.Clock>(() => _i524.SystemClock(), registerFor: {_prod});
    gh.lazySingleton<_i398.BackgroundSender>(
      () => _i524.SystemBackgroundSender(),
      registerFor: {_prod},
    );
    gh.singleton<_i398.Connectivity>(
      () => _i524.SystemConnectivity(),
      registerFor: {_prod},
    );
    await gh.singletonAsync<_i696.AttachmentStorage>(
      () => attachmentModule.attachmentStorage(),
      registerFor: {_prod},
      preResolve: true,
    );
    gh.singleton<_i519.Client>(() => httpModule.client(), registerFor: {_prod});
    gh.lazySingleton<_i462.LaunchAtLogin>(
      () => launchAtLoginModule.launchAtLogin(),
      registerFor: {_prod},
    );
    gh.singleton<_i398.SecureStore>(
      () => _i524.KeychainStore(),
      registerFor: {_prod},
    );
    gh.lazySingleton<_i739.SystemTray>(
      () => _i586.NativeSystemTray(),
      registerFor: {_prod},
    );
    gh.singleton<_i398.FileSaver>(
      () => _i524.SystemFileSaver(),
      registerFor: {_prod},
    );
    gh.lazySingleton<_i853.AppWindow>(
      () => _i634.NativeAppWindow(),
      registerFor: {_prod},
    );
    gh.singleton<_i902.GoogleConsent>(
      () => _i1009.GoogleWebConsent(gh<_i519.Client>(), gh<_i398.Clock>()),
      registerFor: {_prod},
    );
    gh.lazySingleton<_i184.Notifications>(
      () => _i102.LocalNotifications(),
      registerFor: {_prod},
    );
    gh.singleton<_i398.LinkOpener>(
      () => _i524.SystemLinkOpener(),
      registerFor: {_prod},
    );
    gh.lazySingleton<_i96.ModelDownload>(
      () => _i29.SimulatedModelDownload(gh<_i421.NetworkType>()),
    );
    await gh.singletonAsync<_i689.ModelManager>(
      () => modelModule.modelManager(
        gh<_i519.Client>(),
        gh<_i398.Connectivity>(),
      ),
      registerFor: {_prod},
      preResolve: true,
    );
    await gh.singletonAsync<_i346.ErrorLog>(
      () => errorLogModule.errorLog(gh<_i398.SecureStore>(), gh<_i398.Clock>()),
      registerFor: {_prod},
      preResolve: true,
    );
    await gh.singletonAsync<_i325.ReportSharer>(
      () => reportSharerModule.reportSharer(gh<_i398.FileSaver>()),
      registerFor: {_prod},
      preResolve: true,
    );
    await gh.singletonAsync<_i1028.PostinoDatabase>(
      () => databaseModule.database(
        gh<_i398.SecureStore>(),
        gh<_i346.ErrorLog>(),
      ),
      registerFor: {_prod},
      preResolve: true,
    );
    gh.lazySingleton<_i385.MailStore>(
      () => _i385.MailStore(gh<_i1028.PostinoDatabase>()),
    );
    gh.lazySingleton<_i37.OutboxStore>(
      () => _i37.OutboxStore(gh<_i1028.PostinoDatabase>()),
    );
    gh.lazySingleton<_i700.OutboxRepository>(
      () => mailStoreModule.outboxRepository(gh<_i37.OutboxStore>()),
    );
    gh.lazySingleton<_i359.TrustedSendersRepository>(
      () => _i412.TrustedSendersStore(gh<_i1028.PostinoDatabase>()),
    );
    gh.lazySingleton<_i307.SettingsRepository>(
      () => _i207.DeviceSettingsStore(gh<_i1028.PostinoDatabase>()),
    );
    gh.lazySingleton<_i845.InboxRepository>(
      () => mailStoreModule.inboxRepository(gh<_i385.MailStore>()),
    );
    gh.lazySingleton<_i205.AutoLabelsRepository>(
      () => _i452.AutoLabelsStore(
        gh<_i1028.PostinoDatabase>(),
        gh<_i398.Clock>(),
      ),
    );
    gh.factory<_i320.AutoLabelSwitchUseCase>(
      () => _i320.AutoLabelSwitchUseCase(
        gh<_i205.AutoLabelsRepository>(),
        gh<_i96.ModelDownload>(),
      ),
    );
    gh.lazySingleton<_i26.NewMailNotifier>(
      () => _i26.NewMailNotifier(
        gh<_i385.MailStore>(),
        gh<_i184.Notifications>(),
        gh<_i350.OpenConversation>(),
      ),
    );
    gh.lazySingleton<_i311.SettingsSync>(
      () => _i311.SettingsSync(
        gh<_i1028.PostinoDatabase>(),
        gh<_i307.SettingsRepository>(),
        gh<_i398.Clock>(),
        gh<_i398.Connectivity>(),
      ),
    );
    gh.factory<_i166.LaunchAtLoginUseCase>(
      () => _i166.LaunchAtLoginUseCase(
        gh<_i462.LaunchAtLogin>(),
        gh<_i307.SettingsRepository>(),
      ),
    );
    gh.lazySingleton<_i893.SyncEngine>(
      () => _i893.SyncEngine(
        gh<_i385.MailStore>(),
        gh<_i700.OutboxRepository>(),
        gh<_i398.Clock>(),
        gh<_i398.Connectivity>(),
        gh<_i398.BackgroundSender>(),
        gh<_i26.NewMailNotifier>(),
        gh<_i346.ErrorLog>(),
      ),
    );
    gh.lazySingleton<_i705.MailSync>(
      () => syncModule.mailSync(gh<_i893.SyncEngine>()),
    );
    gh.lazySingleton<_i812.ConversationLabelIntents>(
      () => _i812.ConversationLabelIntents(
        gh<_i705.MailSync>(),
        gh<_i845.InboxRepository>(),
      ),
    );
    gh.factory<_i510.ReplyDraftUseCase>(
      () => _i510.ReplyDraftUseCase(
        gh<_i705.MailSync>(),
        gh<_i845.InboxRepository>(),
      ),
    );
    gh.lazySingleton<_i382.AccountsRepository>(
      () => _i413.AccountsService(
        gh<_i385.MailStore>(),
        gh<_i902.GoogleConsent>(),
        gh<_i398.SecureStore>(),
        gh<_i893.SyncEngine>(),
      ),
    );
    gh.lazySingleton<_i278.AttachmentRepository>(
      () => _i696.AttachmentCache(
        gh<_i705.MailSync>(),
        gh<_i398.SecureStore>(),
        gh<_i398.Clock>(),
        gh<_i696.AttachmentStorage>(),
      ),
    );
    gh.factory<_i802.ReportProblemUseCase>(
      () => _i802.ReportProblemUseCase(
        gh<_i346.ErrorLog>(),
        gh<_i382.AccountsRepository>(),
        gh<_i705.MailSync>(),
        gh<_i325.ReportSharer>(),
      ),
    );
    gh.factory<_i114.SettingsSyncAccountUseCase>(
      () => _i114.SettingsSyncAccountUseCase(
        gh<_i382.AccountsRepository>(),
        gh<_i307.SettingsRepository>(),
      ),
    );
    return this;
  }
}

class _$AttachmentModule extends _i524.AttachmentModule {}

class _$HttpModule extends _i524.HttpModule {}

class _$LaunchAtLoginModule extends _i377.LaunchAtLoginModule {}

class _$ModelModule extends _i260.ModelModule {}

class _$ErrorLogModule extends _i907.ErrorLogModule {}

class _$ReportSharerModule extends _i439.ReportSharerModule {}

class _$DatabaseModule extends _i524.DatabaseModule {}

class _$MailStoreModule extends _i385.MailStoreModule {}

class _$SyncModule extends _i893.SyncModule {}
