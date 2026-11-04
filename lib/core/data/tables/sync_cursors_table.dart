import 'package:drift/drift.dart';

/// Where each Account's incremental sync starts from: opaque to the core (ADR 0008).
@DataClassName('SyncCursorRow')
class SyncCursors() extends Table {
  TextColumn get accountId => text()();
  TextColumn get cursor => text()();

  @override
  Set<Column> get primaryKey => {accountId};
}
