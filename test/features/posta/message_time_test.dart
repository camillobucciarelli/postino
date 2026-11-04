import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:postino/features/posta/presentation/message_time.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it');
    await initializeDateFormatting('en');
  });

  // Wednesday 28 October 2026, local time.
  final now = DateTime(2026, 10, 28, 12);
  String time(DateTime d) => messageTime(d, now, 'it', 'Ieri');

  test('the row time follows the design', () {
    expect(time(DateTime(2026, 10, 28, 9, 42)), '09:42');
    expect(time(DateTime(2026, 10, 27, 23, 59)), 'Ieri');
    expect(time(DateTime(2026, 10, 26, 8)), 'lun');
    expect(time(DateTime(2026, 10, 22, 8)), 'gio');
    expect(time(DateTime(2026, 10, 21, 8)), '21 ott');
    expect(time(DateTime(2026, 3, 12, 8)), '12 mar');
    expect(time(DateTime(2025, 3, 12, 8)), '12 mar 2025');
  });
}
