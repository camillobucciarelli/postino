import 'package:flutter/widgets.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/result.dart';
import '../../../i18n/strings.g.dart';

/// What to tell the user when connecting an Account of [provider] fails; null when they backed out.
String? connectError(BuildContext context, Result<Object> result, {ProviderKind provider = ProviderKind.gmail}) =>
    switch (result) {
      Ok() || Err(failure: CancelledFailure()) => null,
      Err(failure: ConfigurationFailure(:final setting)) => context.t.connect.missingSetting(setting: setting),
      Err(failure: OfflineFailure()) => context.t.connect.offline,
      Err(failure: MissingPermissionFailure()) =>
        provider == ProviderKind.microsoft
            ? context.t.connect.missingPermissionMicrosoft
            : context.t.connect.missingPermission,
      Err(failure: WorkAccountFailure()) => context.t.connect.workAccount,
      Err(failure: WrongAccountFailure(:final expected)) => context.t.connect.wrongAccount(address: expected),
      Err(failure: AlreadyConnectedFailure()) => context.t.connect.alreadyConnected,
      Err() => context.t.connect.failed,
    };
