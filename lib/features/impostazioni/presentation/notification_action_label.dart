import '../../../core/domain/notification_action.dart';
import '../../../i18n/strings.g.dart';

/// The name of an Azione delle notifiche (#211): the title of its button and of its choice in the Impostazioni
/// del dispositivo, the same verb in both; null is «Nessuna».
String notificationActionLabel(Translations t, NotificationAction? action) => switch (action) {
  NotificationAction.archive => t.azioni.archive,
  NotificationAction.markRead => t.azioni.markRead,
  NotificationAction.star => t.azioni.star,
  NotificationAction.delete => t.azioni.delete,
  null => t.impostazioni.notificationActionNone,
};
