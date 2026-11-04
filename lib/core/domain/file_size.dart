import 'package:intl/intl.dart';

/// «980 B», «88 KB», «1,2 MB»: binary units, one decimal from MB, in the reader's [locale].
String fileSize(int bytes, String locale) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final f = NumberFormat.decimalPattern(locale)..maximumFractionDigits = unit >= 2 ? 1 : 0;
  return '${f.format(value)} ${units[unit]}';
}
