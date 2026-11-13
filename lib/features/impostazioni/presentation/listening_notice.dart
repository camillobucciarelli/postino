import '../../../core/domain/immediate_notifications.dart';
import '../../../i18n/strings.g.dart';

/// The texts of the fixed notification «Postino in ascolto» of the Notifiche immediate (#214) in [t]'s language: the
/// same from the switch and from the start of the app.
ListeningNotice listeningNotice(Translations t) =>
    (channel: t.notifiche.listeningChannel, title: t.notifiche.listeningTitle, text: t.notifiche.listeningText);
