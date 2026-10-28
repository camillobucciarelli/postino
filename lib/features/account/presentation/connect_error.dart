import 'package:flutter/widgets.dart';

import '../../../core/domain/result.dart';
import '../../../i18n/strings.g.dart';

/// What to tell the user when connecting an Account fails; null when they backed out.
String? connectError(BuildContext context, Result<Object> result) =>
    switch (result) {
      Ok() || Err(failure: CancelledFailure()) => null,
      Err(failure: ConfigurationFailure(:final setting)) =>
        context.t.connect.missingSetting(setting: setting),
      Err(failure: OfflineFailure()) => context.t.connect.offline,
      Err() => context.t.connect.failed,
    };
