import 'package:intl/intl.dart';

/// La data di una citazione o di un inoltro, come Gmail in italiano: `lun 2 nov 2026 alle ore 16:19`.
/// Sempre in italiano, come la frase che la circonda (non dipende dalla lingua dell'app né dalla piattaforma):
/// i simboli `it` vanno caricati prima (`initializeDateFormatting('it')`).
String quoteDateLabel(DateTime date) {
  final d = date.toLocal();
  return '${DateFormat('EEE d MMM yyyy', 'it').format(d)} alle ore '
      '${DateFormat.Hm('it').format(d)}';
}
