import 'package:intl/intl.dart';

import '../../../i18n/strings.g.dart';

/// What the sync status row says of the last sync at [at] (#251): «adesso» within a minute, «N minuti fa» within
/// the hour, «alle HH:MM» the same day, the date before. [offline]: «Offline ·» and always the time, or the date.
String syncedText(Translations t, DateTime at, DateTime now, String locale, {bool offline = false}) {
  final s = t.syncStatus;
  final d = at.toLocal();
  final n = now.toLocal();
  final today = d.year == n.year && d.month == n.month && d.day == n.day;
  final time = DateFormat.Hm(locale).format(d);
  final date = DateFormat.MMMd(locale).format(d);
  if (offline) return today ? s.offlineAt(time: time) : s.offlineOn(date: date);
  final minutes = n.difference(d).inMinutes;
  if (minutes < 1) return s.now;
  if (minutes < 60) return s.minutesAgo(n: minutes);
  return today ? s.at(time: time) : s.on(date: date);
}
