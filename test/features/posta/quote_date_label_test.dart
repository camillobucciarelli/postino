import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:postino/features/posta/domain/quote_date_label.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it'));

  test('quote date label is Italian like the sentence around it', () {
    expect(
      quoteDateLabel(DateTime(2026, 11, 2, 16, 19)),
      'lun 2 nov 2026 alle ore 16:19',
    );
  });
}
