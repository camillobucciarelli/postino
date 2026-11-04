import 'package:intl/intl.dart';

/// The time of a row as the design writes it: `09:42` today, [yesterday], `lun` within a week,
/// `12 mar` this year, `12 mar 2025` before.
String messageTime(
  DateTime date,
  DateTime now,
  String locale,
  String yesterday,
) {
  final d = date.toLocal();
  final n = now.toLocal();
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
