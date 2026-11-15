import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/result.dart';
import '../../../core/domain/settings_repository.dart';
import '../../../core/domain/settings_sync_account_use_case.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'sync_account_chooser.dart';

/// The «Sincronizza su…» group (ADR 0016): the entry with the current choice, what it does, and the progress or
/// the error of the incremental consent to Drive. It offers the Accounts that can keep the file, and shows nothing
/// without one.
class const SyncAccountSection({super.key}) extends StatefulWidget {
  @override
  State<SyncAccountSection> createState() => _SyncAccountSectionState();
}

class _SyncAccountSectionState() extends State<SyncAccountSection> {
  late final _current = streamSignal(() => GetIt.I<SettingsRepository>().watchSettingsSyncAccount());
  late final _hosts = streamSignal(() => GetIt.I<SettingsSyncAccountUseCase>().watchHosts());
  var _busy = false;
  Failure? _failure;

  @override
  void dispose() {
    _current.dispose();
    _hosts.dispose();
    super.dispose();
  }

  List<Account> get _hostList => _hosts.value.value ?? const [];

  Future<void> _open() async {
    if (_busy) return;
    final choice = await showSyncAccountChooser(context, _hostList, _current.value.value);
    if (choice == null || !mounted) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final result = await GetIt.I<SettingsSyncAccountUseCase>().choose(choice.accountId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      // Backing out of Google's page is not an error.
      _failure = switch (result) {
        Err(:final failure) when failure is! CancelledFailure => failure,
        _ => null,
      };
    });
  }

  String _error(Failure failure) {
    final t = context.t.impostazioni;
    return switch (failure) {
      DriveScopeFailure() || MissingPermissionFailure() => t.syncDenied,
      WrongAccountFailure(:final expected) => t.syncWrongAccount(address: expected),
      OfflineFailure() => t.syncOffline,
      _ => t.syncFailed,
    };
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final t = context.t.impostazioni;
      final id = _current.value.value;
      final address = _hostList.where((a) => a.id == id).firstOrNull?.address;
      if (_hostList.isEmpty) return const SizedBox.shrink();
      final banner = switch ((_busy, _failure)) {
        (true, _) => PostinoBanner(
          key: const ValueKey('sync-busy'),
          tone: PostinoBannerTone.info,
          title: t.syncBusy,
          leading: PostinoSpinner(label: t.syncBusy),
        ),
        (false, final f?) => PostinoBanner(
          key: const ValueKey('sync-error'),
          tone: PostinoBannerTone.danger,
          title: _error(f),
        ),
        _ => null,
      };
      return PostinoSettingsSection(
        title: t.syncSection,
        children: [
          PostinoSettingsItem(
            key: const ValueKey('settings-sync-account'),
            title: t.syncTitle,
            subtitle: address ?? t.syncNone,
            onTap: () => unawaited(_open()),
          ),
          // The banner (in progress, or why it failed) opens and closes under the text, its gap inside (#283).
          // The note in line with the rows' text (#312).
          Padding(
            padding: const EdgeInsets.fromLTRB(PostinoSpacing.s4, PostinoSpacing.s2, PostinoSpacing.s4, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PostinoSelectable(
                  child: Text(t.syncBody, style: PostinoText.caption.copyWith(color: context.pc.inkMuted)),
                ),
                PostinoReveal(
                  contentKey: _busy,
                  child: banner == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(top: PostinoSpacing.s2),
                          child: banner,
                        ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
