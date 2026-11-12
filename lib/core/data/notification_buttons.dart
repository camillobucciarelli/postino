import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/mail_notification.dart';
import '../domain/notification_action.dart';
import 'notification_payload.dart';

/// The buttons of a notification on each OS (#211), titled by their label. None opens the app (iOS and Android run
/// them in a background isolate); the OS dismisses the notification on a tap.
typedef ActionLabel = String Function(NotificationAction action);

/// Android: the button's id is the Azione's name.
List<AndroidNotificationAction> androidButtons(List<NotificationAction> actions, ActionLabel label) => [
  for (final a in actions)
    AndroidNotificationAction(
      a.name,
      label(a),
      semanticAction: switch (a) {
        NotificationAction.archive => SemanticAction.archive,
        NotificationAction.markRead => SemanticAction.markAsRead,
        NotificationAction.delete => SemanticAction.delete,
        NotificationAction.star => SemanticAction.none,
      },
    ),
];

/// Linux: the action's key is the Azione's name.
List<LinuxNotificationAction> linuxButtons(List<NotificationAction> actions, ActionLabel label) => [
  for (final a in actions) LinuxNotificationAction(key: a.name, label: label(a)),
];

/// Windows hands back only the button's arguments: they carry the Conversazione too ([encodeAction]).
List<WindowsAction> windowsButtons(ConversationKey conversation, List<NotificationAction> actions, ActionLabel label) =>
    [
      for (final a in actions)
        WindowsAction(content: label(a), arguments: encodeAction((conversation: conversation, action: a))),
    ];

/// iOS and macOS: the category of a notification with [actions]; null without buttons.
String? darwinCategoryOf(List<NotificationAction> actions) =>
    actions.isEmpty ? null : 'postino:${actions.map((a) => a.name).join(',')}';

/// iOS and macOS register their categories once, at start: every choice of the Impostazione has its own, so a change
/// holds from the next notification, without a restart.
List<DarwinNotificationCategory> darwinCategories(ActionLabel label) {
  final choices = <NotificationAction?>[null, ...NotificationAction.values];
  final byId = <String, List<NotificationAction>>{
    for (final first in choices)
      for (final second in choices)
        if (buttonsOf((first: first, second: second)) case final buttons when buttons.isNotEmpty)
          darwinCategoryOf(buttons)!: buttons,
  };
  return [
    for (final MapEntry(key: id, value: buttons) in byId.entries)
      DarwinNotificationCategory(
        id,
        actions: [
          for (final a in buttons)
            DarwinNotificationAction.plain(
              a.name,
              label(a),
              options: {if (a == NotificationAction.delete) DarwinNotificationActionOption.destructive},
            ),
        ],
      ),
  ];
}
