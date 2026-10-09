import 'package:drift/drift.dart';

part 'drift_db.g.dart';

// Mirrors schema.dart. Drift does not create these tables: onCreate runs the
// shared DDL so both drivers measure the same on-disk schema.

class CellCoverage extends Table {
  IntColumn get cellId => integer()();
  IntColumn get segmentId => integer()();

  @override
  Set<Column> get primaryKey => {cellId, segmentId};

  @override
  bool get withoutRowId => true;
}

class CoverageSpans extends Table {
  IntColumn get segmentId => integer()();
  IntColumn get y => integer()();
  IntColumn get xStart => integer()();
  IntColumn get xEnd => integer()();

  @override
  Set<Column> get primaryKey => {segmentId, y, xStart};

  @override
  bool get withoutRowId => true;
}

class CellStats extends Table {
  IntColumn get cellId => integer()();
  IntColumn get n => integer()();

  @override
  Set<Column> get primaryKey => {cellId};

  @override
  bool get withoutRowId => true;
}

@DriftDatabase(tables: [CellCoverage, CoverageSpans, CellStats])
class BenchDb extends _$BenchDb {
  BenchDb(super.e, this.ddl);

  final List<String> ddl;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final s in ddl) {
        await customStatement(s);
      }
    },
  );
}
