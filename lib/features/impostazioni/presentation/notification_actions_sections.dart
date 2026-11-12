import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/notification_action.dart';
import '../../../core/domain/settings_repository.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'notification_action_label.dart';

/// Impostazioni del dispositivo › the two Azioni of a notification (#211): each Archivia, Segna come letto, Stella,
/// Elimina or «Nessuna»; saved on this device, the next notification has them. Each choice reads to a screen reader
/// with its place: «Prima Azione della notifica, Archivia».
class const NotificationActionsSections({super.key}) extends StatefulWidget {
  @override
  State<NotificationActionsSections> createState() => _NotificationActionsSectionsState();
}

class _NotificationActionsSectionsState() extends State<NotificationActionsSections> {
  final _settings = GetIt.I<SettingsRepository>();

  /// Null while read.
  NotificationActions? _chosen;

  @override
  void initState() {
    super.initState();
    unawaited(_settings.notificationActions().then((a) => mounted ? setState(() => _chosen = a) : null));
  }

  void _choose(NotificationActions actions) {
    setState(() => _chosen = actions);
    unawaited(_settings.setNotificationActions(actions));
  }

  Widget _section(
    BuildContext context, {
    required String place,
    required String title,
    required NotificationAction? chosen,
    required NotificationActions Function(NotificationAction? a) choice,
  }) => PostinoSettingsSection(
    title: title,
    children: [
      for (final a in [...NotificationAction.values, null])
        PostinoChoiceRow(
          key: ValueKey('notification-action-$place-${a?.name ?? 'none'}'),
          label: notificationActionLabel(context.t, a),
          group: title,
          selected: a == chosen,
          onSelected: () => _choose(choice(a)),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final chosen = _chosen;
    if (chosen == null) return const SizedBox.shrink();
    final t = context.t.impostazioni;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          context,
          place: 'first',
          title: t.notificationActionFirst,
          chosen: chosen.first,
          choice: (a) => (first: a, second: chosen.second),
        ),
        _section(
          context,
          place: 'second',
          title: t.notificationActionSecond,
          chosen: chosen.second,
          choice: (a) => (first: chosen.first, second: a),
        ),
      ],
    );
  }
}
