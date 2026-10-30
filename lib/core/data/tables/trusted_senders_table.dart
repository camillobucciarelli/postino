import 'package:drift/drift.dart';

/// Mittenti fidati: their remote images always load. The exact address, normalized (trim, lowercase).
@DataClassName('TrustedSenderRow')
class TrustedSenders extends Table {
  TextColumn get address => text()();

  @override
  Set<Column> get primaryKey => {address};
}
