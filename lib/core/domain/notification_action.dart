import 'mail_action.dart';
import 'mail_notification.dart';

/// An Azione a button of a notification can run (#211): the Azioni v1 that need no other input. An Impostazione del
/// dispositivo: it is not synced.
enum NotificationAction() {
  /// Archivia.
  archive,

  /// Segna come letto.
  markRead,

  /// Stella.
  star,

  /// Elimina: to the Cestino, without asking (ADR 0008).
  delete;

  /// The Azione it applies to the messages of the Conversazione.
  MailAction get mailAction => switch (this) {
    archive => const Archive(),
    markRead => const MarkRead(),
    star => const Star(),
    delete => const Delete(),
  };
}

/// The first and the second button of a notification; null is «Nessuna».
typedef NotificationActions = ({NotificationAction? first, NotificationAction? second});

/// What the buttons are until the user chooses: Archivia and Segna come letto.
const notificationActionsDefault = (first: NotificationAction.archive, second: NotificationAction.markRead);

/// The buttons [actions] shows, in order: «Nessuna» leaves its place out, the same Azione twice is one button.
List<NotificationAction> buttonsOf(NotificationActions actions) => {?actions.first, ?actions.second}.toList();

/// A tap on the button of an Azione in the notification of a Conversazione.
typedef NotificationActionTap = ({ConversationKey conversation, NotificationAction action});
