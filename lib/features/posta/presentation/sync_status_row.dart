import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/platform_services.dart';
import '../../../core/domain/sync_status.dart';
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'refresh_mail.dart';
import 'synced_time.dart';

/// The sync status under the bar of a list (#251), of the Account [accountId] (an Account or one of its folders) or,
/// with null, of every Account (the Posta unificata). In order: running, offline, failed (with «Riprova»), an
/// Account Da ricollegare, the last update; nothing before the first sync.
class const SyncStatusRow({super.key, final String? accountId}) extends StatefulWidget {
  @override
  State<SyncStatusRow> createState() => _SyncStatusRowState();
}

class _SyncStatusRowState() extends State<SyncStatusRow> with AccountsSignal {
  final _connectivity = GetIt.I<Connectivity>();
  final _clock = GetIt.I<Clock>();
  late final _status = streamSignal(() => GetIt.I<MailSync>().watchSyncStatus());
  late final _online = streamSignal(
    () => _connectivity.onChanged,
    options: AsyncSignalOptions(initialValue: _connectivity.isOnline),
  );

  /// «N minuti fa» moves on by itself.
  late final _tick = streamSignal(() => _clock.every(const Duration(seconds: 30)));

  @override
  void dispose() {
    _status.dispose();
    _online.dispose();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      _tick.value;
      final t = context.t;
      final all = _status.value.value ?? const <String, SyncStatus>{};
      final scope = [
        for (final a in accounts.value.value ?? const <Account>[])
          if (widget.accountId == null || a.id == widget.accountId) a,
      ];
      final s = SyncStatus.merge([
        for (final a in scope)
          if (a.status == AccountStatus.attivo) all[a.id] ?? const SyncStatus(),
      ]);
      final locale = Localizations.localeOf(context).languageCode;
      final now = _clock.now();
      final at = s.syncedAt;
      final (state, label) = switch (s) {
        _ when s.running => (PostinoSyncState.syncing, t.syncStatus.running),
        _ when !(_online.value.value ?? true) => (
          PostinoSyncState.offline,
          at == null ? t.syncStatus.offline : syncedText(t, at, now, locale, offline: true),
        ),
        _ when s.failed => (PostinoSyncState.error, t.syncStatus.failed),
        _ when scope.any((a) => a.status == AccountStatus.daRicollegare) => (
          PostinoSyncState.reconnect,
          t.daRicollegare.status,
        ),
        SyncStatus(syncedAt: final at?) => (PostinoSyncState.ok, syncedText(t, at, now, locale)),
        _ => (null, ''),
      };
      if (state == null) return const SizedBox.shrink();
      return PostinoSyncStatus(
        key: const ValueKey('sync-status'),
        state: state,
        label: label,
        retryLabel: t.syncStatus.retry,
        onRetry: state == PostinoSyncState.error ? () => unawaited(refreshMail(context)) : null,
      );
    },
  );
}
