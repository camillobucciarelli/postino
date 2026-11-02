import 'package:intl/intl.dart';

/// The time of a row as the design writes it: `09:42` today, [yesterday], `lun` within a week,
/// `12 mar` this year, `12 mar 2025` before.
String messageTime(
  DateTime date,
  DateTime now,
  String locale,
  String yesterday,
) {
  final d = date.toLocal(), n = now.toLocal();
  // Calendar days, in UTC so a DST change does not shorten one.
  final days = DateTime.utc(
    n.year,
    n.month,
    n.day,
  ).difference(DateTime.utc(d.year, d.month, d.day)).inDays;
  if (days == 0) return DateFormat.Hm(locale).format(d);
  if (days == 1) return yesterday;
  if (days > 1 && days < 7) return DateFormat.E(locale).format(d);
  if (d.year == n.year) return DateFormat.MMMd(locale).format(d);
  return DateFormat.yMMMd(locale).format(d);
}

/// La data di una citazione o di un inoltro, nella lingua del testo che la circonda: come Gmail,
/// `lun 2 nov 2026 alle ore 16:19` in italiano, `Mon, Nov 2, 2026 4:19 PM` altrimenti.
/// I simboli di [lang] vanno caricati prima (`initializeDateFormatting`): il locale della piattaforma
/// può essere un altro.
String quoteDateLabel(DateTime date, String lang) {
  final d = date.toLocal();
  if (lang == 'it') {
    return '${DateFormat('EEE d MMM yyyy', lang).format(d)} alle ore '
        '${DateFormat.Hm(lang).format(d)}';
  }
  return DateFormat('EEE, MMM d, yyyy', lang).add_jm().format(d);
}
