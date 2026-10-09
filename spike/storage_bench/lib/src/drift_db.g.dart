// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_db.dart';

// ignore_for_file: type=lint
class $CellCoverageTable extends CellCoverage
    with TableInfo<$CellCoverageTable, CellCoverageData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CellCoverageTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cellIdMeta = const VerificationMeta('cellId');
  @override
  late final GeneratedColumn<int> cellId = GeneratedColumn<int>(
    'cell_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _segmentIdMeta = const VerificationMeta(
    'segmentId',
  );
  @override
  late final GeneratedColumn<int> segmentId = GeneratedColumn<int>(
    'segment_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [cellId, segmentId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cell_coverage';
  @override
  VerificationContext validateIntegrity(
    Insertable<CellCoverageData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cell_id')) {
      context.handle(
        _cellIdMeta,
        cellId.isAcceptableOrUnknown(data['cell_id']!, _cellIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cellIdMeta);
    }
    if (data.containsKey('segment_id')) {
      context.handle(
        _segmentIdMeta,
        segmentId.isAcceptableOrUnknown(data['segment_id']!, _segmentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_segmentIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cellId, segmentId};
  @override
  CellCoverageData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CellCoverageData(
      cellId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cell_id'],
      )!,
      segmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment_id'],
      )!,
    );
  }

  @override
  $CellCoverageTable createAlias(String alias) {
    return $CellCoverageTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class CellCoverageData extends DataClass
    implements Insertable<CellCoverageData> {
  final int cellId;
  final int segmentId;
  const CellCoverageData({required this.cellId, required this.segmentId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cell_id'] = Variable<int>(cellId);
    map['segment_id'] = Variable<int>(segmentId);
    return map;
  }

  CellCoverageCompanion toCompanion(bool nullToAbsent) {
    return CellCoverageCompanion(
      cellId: Value(cellId),
      segmentId: Value(segmentId),
    );
  }

  factory CellCoverageData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CellCoverageData(
      cellId: serializer.fromJson<int>(json['cellId']),
      segmentId: serializer.fromJson<int>(json['segmentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cellId': serializer.toJson<int>(cellId),
      'segmentId': serializer.toJson<int>(segmentId),
    };
  }

  CellCoverageData copyWith({int? cellId, int? segmentId}) => CellCoverageData(
    cellId: cellId ?? this.cellId,
    segmentId: segmentId ?? this.segmentId,
  );
  CellCoverageData copyWithCompanion(CellCoverageCompanion data) {
    return CellCoverageData(
      cellId: data.cellId.present ? data.cellId.value : this.cellId,
      segmentId: data.segmentId.present ? data.segmentId.value : this.segmentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CellCoverageData(')
          ..write('cellId: $cellId, ')
          ..write('segmentId: $segmentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cellId, segmentId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CellCoverageData &&
          other.cellId == this.cellId &&
          other.segmentId == this.segmentId);
}

class CellCoverageCompanion extends UpdateCompanion<CellCoverageData> {
  final Value<int> cellId;
  final Value<int> segmentId;
  const CellCoverageCompanion({
    this.cellId = const Value.absent(),
    this.segmentId = const Value.absent(),
  });
  CellCoverageCompanion.insert({required int cellId, required int segmentId})
    : cellId = Value(cellId),
      segmentId = Value(segmentId);
  static Insertable<CellCoverageData> custom({
    Expression<int>? cellId,
    Expression<int>? segmentId,
  }) {
    return RawValuesInsertable({
      if (cellId != null) 'cell_id': cellId,
      if (segmentId != null) 'segment_id': segmentId,
    });
  }

  CellCoverageCompanion copyWith({Value<int>? cellId, Value<int>? segmentId}) {
    return CellCoverageCompanion(
      cellId: cellId ?? this.cellId,
      segmentId: segmentId ?? this.segmentId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cellId.present) {
      map['cell_id'] = Variable<int>(cellId.value);
    }
    if (segmentId.present) {
      map['segment_id'] = Variable<int>(segmentId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CellCoverageCompanion(')
          ..write('cellId: $cellId, ')
          ..write('segmentId: $segmentId')
          ..write(')'))
        .toString();
  }
}

class $CoverageSpansTable extends CoverageSpans
    with TableInfo<$CoverageSpansTable, CoverageSpan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoverageSpansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _segmentIdMeta = const VerificationMeta(
    'segmentId',
  );
  @override
  late final GeneratedColumn<int> segmentId = GeneratedColumn<int>(
    'segment_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<int> y = GeneratedColumn<int>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xStartMeta = const VerificationMeta('xStart');
  @override
  late final GeneratedColumn<int> xStart = GeneratedColumn<int>(
    'x_start',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xEndMeta = const VerificationMeta('xEnd');
  @override
  late final GeneratedColumn<int> xEnd = GeneratedColumn<int>(
    'x_end',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [segmentId, y, xStart, xEnd];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'coverage_spans';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoverageSpan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('segment_id')) {
      context.handle(
        _segmentIdMeta,
        segmentId.isAcceptableOrUnknown(data['segment_id']!, _segmentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_segmentIdMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    if (data.containsKey('x_start')) {
      context.handle(
        _xStartMeta,
        xStart.isAcceptableOrUnknown(data['x_start']!, _xStartMeta),
      );
    } else if (isInserting) {
      context.missing(_xStartMeta);
    }
    if (data.containsKey('x_end')) {
      context.handle(
        _xEndMeta,
        xEnd.isAcceptableOrUnknown(data['x_end']!, _xEndMeta),
      );
    } else if (isInserting) {
      context.missing(_xEndMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {segmentId, y, xStart};
  @override
  CoverageSpan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoverageSpan(
      segmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment_id'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}y'],
      )!,
      xStart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}x_start'],
      )!,
      xEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}x_end'],
      )!,
    );
  }

  @override
  $CoverageSpansTable createAlias(String alias) {
    return $CoverageSpansTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class CoverageSpan extends DataClass implements Insertable<CoverageSpan> {
  final int segmentId;
  final int y;
  final int xStart;
  final int xEnd;
  const CoverageSpan({
    required this.segmentId,
    required this.y,
    required this.xStart,
    required this.xEnd,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['segment_id'] = Variable<int>(segmentId);
    map['y'] = Variable<int>(y);
    map['x_start'] = Variable<int>(xStart);
    map['x_end'] = Variable<int>(xEnd);
    return map;
  }

  CoverageSpansCompanion toCompanion(bool nullToAbsent) {
    return CoverageSpansCompanion(
      segmentId: Value(segmentId),
      y: Value(y),
      xStart: Value(xStart),
      xEnd: Value(xEnd),
    );
  }

  factory CoverageSpan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoverageSpan(
      segmentId: serializer.fromJson<int>(json['segmentId']),
      y: serializer.fromJson<int>(json['y']),
      xStart: serializer.fromJson<int>(json['xStart']),
      xEnd: serializer.fromJson<int>(json['xEnd']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'segmentId': serializer.toJson<int>(segmentId),
      'y': serializer.toJson<int>(y),
      'xStart': serializer.toJson<int>(xStart),
      'xEnd': serializer.toJson<int>(xEnd),
    };
  }

  CoverageSpan copyWith({int? segmentId, int? y, int? xStart, int? xEnd}) =>
      CoverageSpan(
        segmentId: segmentId ?? this.segmentId,
        y: y ?? this.y,
        xStart: xStart ?? this.xStart,
        xEnd: xEnd ?? this.xEnd,
      );
  CoverageSpan copyWithCompanion(CoverageSpansCompanion data) {
    return CoverageSpan(
      segmentId: data.segmentId.present ? data.segmentId.value : this.segmentId,
      y: data.y.present ? data.y.value : this.y,
      xStart: data.xStart.present ? data.xStart.value : this.xStart,
      xEnd: data.xEnd.present ? data.xEnd.value : this.xEnd,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoverageSpan(')
          ..write('segmentId: $segmentId, ')
          ..write('y: $y, ')
          ..write('xStart: $xStart, ')
          ..write('xEnd: $xEnd')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(segmentId, y, xStart, xEnd);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoverageSpan &&
          other.segmentId == this.segmentId &&
          other.y == this.y &&
          other.xStart == this.xStart &&
          other.xEnd == this.xEnd);
}

class CoverageSpansCompanion extends UpdateCompanion<CoverageSpan> {
  final Value<int> segmentId;
  final Value<int> y;
  final Value<int> xStart;
  final Value<int> xEnd;
  const CoverageSpansCompanion({
    this.segmentId = const Value.absent(),
    this.y = const Value.absent(),
    this.xStart = const Value.absent(),
    this.xEnd = const Value.absent(),
  });
  CoverageSpansCompanion.insert({
    required int segmentId,
    required int y,
    required int xStart,
    required int xEnd,
  }) : segmentId = Value(segmentId),
       y = Value(y),
       xStart = Value(xStart),
       xEnd = Value(xEnd);
  static Insertable<CoverageSpan> custom({
    Expression<int>? segmentId,
    Expression<int>? y,
    Expression<int>? xStart,
    Expression<int>? xEnd,
  }) {
    return RawValuesInsertable({
      if (segmentId != null) 'segment_id': segmentId,
      if (y != null) 'y': y,
      if (xStart != null) 'x_start': xStart,
      if (xEnd != null) 'x_end': xEnd,
    });
  }

  CoverageSpansCompanion copyWith({
    Value<int>? segmentId,
    Value<int>? y,
    Value<int>? xStart,
    Value<int>? xEnd,
  }) {
    return CoverageSpansCompanion(
      segmentId: segmentId ?? this.segmentId,
      y: y ?? this.y,
      xStart: xStart ?? this.xStart,
      xEnd: xEnd ?? this.xEnd,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (segmentId.present) {
      map['segment_id'] = Variable<int>(segmentId.value);
    }
    if (y.present) {
      map['y'] = Variable<int>(y.value);
    }
    if (xStart.present) {
      map['x_start'] = Variable<int>(xStart.value);
    }
    if (xEnd.present) {
      map['x_end'] = Variable<int>(xEnd.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoverageSpansCompanion(')
          ..write('segmentId: $segmentId, ')
          ..write('y: $y, ')
          ..write('xStart: $xStart, ')
          ..write('xEnd: $xEnd')
          ..write(')'))
        .toString();
  }
}

class $CellStatsTable extends CellStats
    with TableInfo<$CellStatsTable, CellStat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CellStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cellIdMeta = const VerificationMeta('cellId');
  @override
  late final GeneratedColumn<int> cellId = GeneratedColumn<int>(
    'cell_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nMeta = const VerificationMeta('n');
  @override
  late final GeneratedColumn<int> n = GeneratedColumn<int>(
    'n',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [cellId, n];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cell_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<CellStat> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cell_id')) {
      context.handle(
        _cellIdMeta,
        cellId.isAcceptableOrUnknown(data['cell_id']!, _cellIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cellIdMeta);
    }
    if (data.containsKey('n')) {
      context.handle(_nMeta, n.isAcceptableOrUnknown(data['n']!, _nMeta));
    } else if (isInserting) {
      context.missing(_nMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cellId};
  @override
  CellStat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CellStat(
      cellId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cell_id'],
      )!,
      n: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}n'],
      )!,
    );
  }

  @override
  $CellStatsTable createAlias(String alias) {
    return $CellStatsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class CellStat extends DataClass implements Insertable<CellStat> {
  final int cellId;
  final int n;
  const CellStat({required this.cellId, required this.n});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cell_id'] = Variable<int>(cellId);
    map['n'] = Variable<int>(n);
    return map;
  }

  CellStatsCompanion toCompanion(bool nullToAbsent) {
    return CellStatsCompanion(cellId: Value(cellId), n: Value(n));
  }

  factory CellStat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CellStat(
      cellId: serializer.fromJson<int>(json['cellId']),
      n: serializer.fromJson<int>(json['n']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cellId': serializer.toJson<int>(cellId),
      'n': serializer.toJson<int>(n),
    };
  }

  CellStat copyWith({int? cellId, int? n}) =>
      CellStat(cellId: cellId ?? this.cellId, n: n ?? this.n);
  CellStat copyWithCompanion(CellStatsCompanion data) {
    return CellStat(
      cellId: data.cellId.present ? data.cellId.value : this.cellId,
      n: data.n.present ? data.n.value : this.n,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CellStat(')
          ..write('cellId: $cellId, ')
          ..write('n: $n')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cellId, n);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CellStat && other.cellId == this.cellId && other.n == this.n);
}

class CellStatsCompanion extends UpdateCompanion<CellStat> {
  final Value<int> cellId;
  final Value<int> n;
  const CellStatsCompanion({
    this.cellId = const Value.absent(),
    this.n = const Value.absent(),
  });
  CellStatsCompanion.insert({required int cellId, required int n})
    : cellId = Value(cellId),
      n = Value(n);
  static Insertable<CellStat> custom({
    Expression<int>? cellId,
    Expression<int>? n,
  }) {
    return RawValuesInsertable({
      if (cellId != null) 'cell_id': cellId,
      if (n != null) 'n': n,
    });
  }

  CellStatsCompanion copyWith({Value<int>? cellId, Value<int>? n}) {
    return CellStatsCompanion(cellId: cellId ?? this.cellId, n: n ?? this.n);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cellId.present) {
      map['cell_id'] = Variable<int>(cellId.value);
    }
    if (n.present) {
      map['n'] = Variable<int>(n.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CellStatsCompanion(')
          ..write('cellId: $cellId, ')
          ..write('n: $n')
          ..write(')'))
        .toString();
  }
}

abstract class _$BenchDb extends GeneratedDatabase {
  _$BenchDb(QueryExecutor e) : super(e);
  $BenchDbManager get managers => $BenchDbManager(this);
  late final $CellCoverageTable cellCoverage = $CellCoverageTable(this);
  late final $CoverageSpansTable coverageSpans = $CoverageSpansTable(this);
  late final $CellStatsTable cellStats = $CellStatsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cellCoverage,
    coverageSpans,
    cellStats,
  ];
}

typedef $$CellCoverageTableCreateCompanionBuilder =
    CellCoverageCompanion Function({
      required int cellId,
      required int segmentId,
    });
typedef $$CellCoverageTableUpdateCompanionBuilder =
    CellCoverageCompanion Function({Value<int> cellId, Value<int> segmentId});

class $$CellCoverageTableFilterComposer
    extends Composer<_$BenchDb, $CellCoverageTable> {
  $$CellCoverageTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get cellId => $composableBuilder(
    column: $table.cellId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CellCoverageTableOrderingComposer
    extends Composer<_$BenchDb, $CellCoverageTable> {
  $$CellCoverageTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get cellId => $composableBuilder(
    column: $table.cellId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CellCoverageTableAnnotationComposer
    extends Composer<_$BenchDb, $CellCoverageTable> {
  $$CellCoverageTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get cellId =>
      $composableBuilder(column: $table.cellId, builder: (column) => column);

  GeneratedColumn<int> get segmentId =>
      $composableBuilder(column: $table.segmentId, builder: (column) => column);
}

class $$CellCoverageTableTableManager
    extends
        RootTableManager<
          _$BenchDb,
          $CellCoverageTable,
          CellCoverageData,
          $$CellCoverageTableFilterComposer,
          $$CellCoverageTableOrderingComposer,
          $$CellCoverageTableAnnotationComposer,
          $$CellCoverageTableCreateCompanionBuilder,
          $$CellCoverageTableUpdateCompanionBuilder,
          (
            CellCoverageData,
            BaseReferences<_$BenchDb, $CellCoverageTable, CellCoverageData>,
          ),
          CellCoverageData,
          PrefetchHooks Function()
        > {
  $$CellCoverageTableTableManager(_$BenchDb db, $CellCoverageTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CellCoverageTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CellCoverageTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CellCoverageTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> cellId = const Value.absent(),
            Value<int> segmentId = const Value.absent(),
          }) => CellCoverageCompanion(cellId: cellId, segmentId: segmentId),
          createCompanionCallback:
              ({required int cellId, required int segmentId}) =>
                  CellCoverageCompanion.insert(
                    cellId: cellId,
                    segmentId: segmentId,
                  ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CellCoverageTable, CellCoverageData>(table),
                  BaseReferences<
                    _$BenchDb,
                    $CellCoverageTable,
                    CellCoverageData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CellCoverageTableProcessedTableManager =
    ProcessedTableManager<
      _$BenchDb,
      $CellCoverageTable,
      CellCoverageData,
      $$CellCoverageTableFilterComposer,
      $$CellCoverageTableOrderingComposer,
      $$CellCoverageTableAnnotationComposer,
      $$CellCoverageTableCreateCompanionBuilder,
      $$CellCoverageTableUpdateCompanionBuilder,
      (
        CellCoverageData,
        BaseReferences<_$BenchDb, $CellCoverageTable, CellCoverageData>,
      ),
      CellCoverageData,
      PrefetchHooks Function()
    >;
typedef $$CoverageSpansTableCreateCompanionBuilder =
    CoverageSpansCompanion Function({
      required int segmentId,
      required int y,
      required int xStart,
      required int xEnd,
    });
typedef $$CoverageSpansTableUpdateCompanionBuilder =
    CoverageSpansCompanion Function({
      Value<int> segmentId,
      Value<int> y,
      Value<int> xStart,
      Value<int> xEnd,
    });

class $$CoverageSpansTableFilterComposer
    extends Composer<_$BenchDb, $CoverageSpansTable> {
  $$CoverageSpansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get xStart => $composableBuilder(
    column: $table.xStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get xEnd => $composableBuilder(
    column: $table.xEnd,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CoverageSpansTableOrderingComposer
    extends Composer<_$BenchDb, $CoverageSpansTable> {
  $$CoverageSpansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get xStart => $composableBuilder(
    column: $table.xStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get xEnd => $composableBuilder(
    column: $table.xEnd,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoverageSpansTableAnnotationComposer
    extends Composer<_$BenchDb, $CoverageSpansTable> {
  $$CoverageSpansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get segmentId =>
      $composableBuilder(column: $table.segmentId, builder: (column) => column);

  GeneratedColumn<int> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<int> get xStart =>
      $composableBuilder(column: $table.xStart, builder: (column) => column);

  GeneratedColumn<int> get xEnd =>
      $composableBuilder(column: $table.xEnd, builder: (column) => column);
}

class $$CoverageSpansTableTableManager
    extends
        RootTableManager<
          _$BenchDb,
          $CoverageSpansTable,
          CoverageSpan,
          $$CoverageSpansTableFilterComposer,
          $$CoverageSpansTableOrderingComposer,
          $$CoverageSpansTableAnnotationComposer,
          $$CoverageSpansTableCreateCompanionBuilder,
          $$CoverageSpansTableUpdateCompanionBuilder,
          (
            CoverageSpan,
            BaseReferences<_$BenchDb, $CoverageSpansTable, CoverageSpan>,
          ),
          CoverageSpan,
          PrefetchHooks Function()
        > {
  $$CoverageSpansTableTableManager(_$BenchDb db, $CoverageSpansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoverageSpansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoverageSpansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoverageSpansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> segmentId = const Value.absent(),
                Value<int> y = const Value.absent(),
                Value<int> xStart = const Value.absent(),
                Value<int> xEnd = const Value.absent(),
              }) => CoverageSpansCompanion(
                segmentId: segmentId,
                y: y,
                xStart: xStart,
                xEnd: xEnd,
              ),
          createCompanionCallback:
              ({
                required int segmentId,
                required int y,
                required int xStart,
                required int xEnd,
              }) => CoverageSpansCompanion.insert(
                segmentId: segmentId,
                y: y,
                xStart: xStart,
                xEnd: xEnd,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CoverageSpansTable, CoverageSpan>(table),
                  BaseReferences<_$BenchDb, $CoverageSpansTable, CoverageSpan>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CoverageSpansTableProcessedTableManager =
    ProcessedTableManager<
      _$BenchDb,
      $CoverageSpansTable,
      CoverageSpan,
      $$CoverageSpansTableFilterComposer,
      $$CoverageSpansTableOrderingComposer,
      $$CoverageSpansTableAnnotationComposer,
      $$CoverageSpansTableCreateCompanionBuilder,
      $$CoverageSpansTableUpdateCompanionBuilder,
      (
        CoverageSpan,
        BaseReferences<_$BenchDb, $CoverageSpansTable, CoverageSpan>,
      ),
      CoverageSpan,
      PrefetchHooks Function()
    >;
typedef $$CellStatsTableCreateCompanionBuilder = CellStatsCompanion Function({
  required int cellId,
  required int n,
});
typedef $$CellStatsTableUpdateCompanionBuilder = CellStatsCompanion Function({
  Value<int> cellId,
  Value<int> n,
});

class $$CellStatsTableFilterComposer
    extends Composer<_$BenchDb, $CellStatsTable> {
  $$CellStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get cellId => $composableBuilder(
    column: $table.cellId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get n => $composableBuilder(
    column: $table.n,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CellStatsTableOrderingComposer
    extends Composer<_$BenchDb, $CellStatsTable> {
  $$CellStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get cellId => $composableBuilder(
    column: $table.cellId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get n => $composableBuilder(
    column: $table.n,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CellStatsTableAnnotationComposer
    extends Composer<_$BenchDb, $CellStatsTable> {
  $$CellStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get cellId =>
      $composableBuilder(column: $table.cellId, builder: (column) => column);

  GeneratedColumn<int> get n =>
      $composableBuilder(column: $table.n, builder: (column) => column);
}

class $$CellStatsTableTableManager
    extends
        RootTableManager<
          _$BenchDb,
          $CellStatsTable,
          CellStat,
          $$CellStatsTableFilterComposer,
          $$CellStatsTableOrderingComposer,
          $$CellStatsTableAnnotationComposer,
          $$CellStatsTableCreateCompanionBuilder,
          $$CellStatsTableUpdateCompanionBuilder,
          (CellStat, BaseReferences<_$BenchDb, $CellStatsTable, CellStat>),
          CellStat,
          PrefetchHooks Function()
        > {
  $$CellStatsTableTableManager(_$BenchDb db, $CellStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CellStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CellStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CellStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> cellId = const Value.absent(),
            Value<int> n = const Value.absent(),
          }) => CellStatsCompanion(cellId: cellId, n: n),
          createCompanionCallback: ({required int cellId, required int n}) =>
              CellStatsCompanion.insert(cellId: cellId, n: n),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CellStatsTable, CellStat>(table),
                  BaseReferences<_$BenchDb, $CellStatsTable, CellStat>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CellStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$BenchDb,
      $CellStatsTable,
      CellStat,
      $$CellStatsTableFilterComposer,
      $$CellStatsTableOrderingComposer,
      $$CellStatsTableAnnotationComposer,
      $$CellStatsTableCreateCompanionBuilder,
      $$CellStatsTableUpdateCompanionBuilder,
      (CellStat, BaseReferences<_$BenchDb, $CellStatsTable, CellStat>),
      CellStat,
      PrefetchHooks Function()
    >;

class $BenchDbManager {
  final _$BenchDb _db;
  $BenchDbManager(this._db);
  $$CellCoverageTableTableManager get cellCoverage =>
      $$CellCoverageTableTableManager(_db, _db.cellCoverage);
  $$CoverageSpansTableTableManager get coverageSpans =>
      $$CoverageSpansTableTableManager(_db, _db.coverageSpans);
  $$CellStatsTableTableManager get cellStats =>
      $$CellStatsTableTableManager(_db, _db.cellStats);
}
