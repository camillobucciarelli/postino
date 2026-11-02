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

/// La data di una citazione o di un inoltro, come Gmail in italiano: `lun 2 nov 2026 alle ore 16:19`.
/// Sempre in italiano, come la frase che la circonda (non dipende dalla lingua dell'app né dalla piattaforma):
/// i simboli `it` vanno caricati prima (`initializeDateFormatting('it')`).
String quoteDateLabel(DateTime date) {
  final d = date.toLocal();
  return '${DateFormat('EEE d MMM yyyy', 'it').format(d)} alle ore '
      '${DateFormat.Hm('it').format(d)}';
}
