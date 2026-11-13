import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:postino/features/posta/presentation/synced_time.dart';
import 'package:postino/i18n/strings.g.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it');
    LocaleSettings.setLocaleSync(AppLocale.it);
  });

  final at = DateTime(2026, 11, 13, 9, 42);
  String text(Duration later, {bool offline = false}) => syncedText(t, at, at.add(later), 'it', offline: offline);

  test('within a minute: adesso', () {
    expect(text(Duration.zero), 'Aggiornato adesso');
    expect(text(const Duration(seconds: 59)), 'Aggiornato adesso');
  });

  test('within the hour: N minuti fa, moving on with the clock', () {
    expect(text(const Duration(minutes: 1)), 'Aggiornato 1 minuto fa');
    expect(text(const Duration(minutes: 2)), 'Aggiornato 2 minuti fa');
    expect(text(const Duration(minutes: 59)), 'Aggiornato 59 minuti fa');
  });

  test('later the same day: the time', () => expect(text(const Duration(hours: 1)), 'Aggiornato alle 09:42'));

  test('another day: the date', () => expect(text(const Duration(days: 1)), 'Aggiornato il 13 nov'));

  test('offline: always the time, or the date', () {
    expect(text(const Duration(minutes: 2), offline: true), 'Offline · aggiornato alle 09:42');
    expect(text(const Duration(days: 2), offline: true), 'Offline · aggiornato il 13 nov');
  });
}
