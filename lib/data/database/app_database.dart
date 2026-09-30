import 'package:drift/drift.dart';

import 'database_migrator.dart';

part 'app_database.g.dart';

/// Drift schema for the local PGN index and training history.
///
/// IDs are application generated strings. Timestamps and byte locators are
/// stored as integers (Unix microseconds and source byte offsets respectively).
/// Enum-like values are strings so newer application versions can inspect and
/// report values written by an older schema without lossy integer mapping.
@DriftDatabase(
  tables: <Type>[
    PgnSources,
    PgnBlocks,
    ImportJobs,
    ImportDiagnostics,
    TrainingSets,
    TrainingSetItems,
    Cycles,
    TrainingSessions,
    PuzzleAttempts,
    AttemptMoves,
    TimingSegments,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// The executor is supplied by the application composition root or a test.
  /// This class deliberately has no process-wide singleton or executor choice.
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => DatabaseMigrator(
    schemaVersion: schemaVersion,
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
    steps: <int, DatabaseMigrationStep>{
      1: DatabaseMigrationStep(
        migrate: (migrator) async {
          await migrator.addColumn(pgnBlocks, pgnBlocks.inferredClassification);
          await migrator.addColumn(pgnBlocks, pgnBlocks.authoredContentType);
          await migrator.addColumn(importJobs, importJobs.sourceFingerprint);
          await migrator.addColumn(importJobs, importJobs.scannerVersion);
          await migrator.addColumn(importJobs, importJobs.sourceSizeBytes);
        },
      ),
    },
  ).strategy;
}

/// A source is retained when unavailable or changed so its index and history
/// can be repaired instead of silently discarded.
class PgnSources extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get accessMode => text()();
  TextColumn get managedPath => text().nullable()();
  TextColumn get externalReference => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  IntColumn get modifiedAtMicros => integer().nullable()();
  TextColumn get fingerprint => text().nullable()();
  IntColumn get scannerVersion => integer()();
  TextColumn get importState => text()();
  IntColumn get safeCheckpoint => integer().withDefault(const Constant(0))();
  IntColumn get createdAtMicros => integer()();
  IntColumn get updatedAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (size_bytes IS NULL OR size_bytes >= 0)',
    'CHECK (safe_checkpoint >= 0)',
  ];
}

/// Searchable metadata and stable locator for one PGN block.
@TableIndex(name: 'pgn_blocks_source_order', columns: {#sourceId, #ordinal})
// Authored IDs stay non-unique in the index so conflicting source records can
// be retained and reported. Import reconciliation must not merge duplicates;
// it flags every colliding block for repair while generated block IDs remain
// independent and all references continue to identify the original rows.
@TableIndex(name: 'pgn_blocks_exercise_id', columns: {#sourceId, #exerciseId})
@TableIndex(name: 'pgn_blocks_content_type', columns: {#contentType})
@TableIndex(name: 'pgn_blocks_white', columns: {#white})
@TableIndex(name: 'pgn_blocks_black', columns: {#black})
@TableIndex(name: 'pgn_blocks_event', columns: {#event})
@TableIndex(name: 'pgn_blocks_result', columns: {#result})
@TableIndex(name: 'pgn_blocks_section', columns: {#section})
@TableIndex(name: 'pgn_blocks_theme', columns: {#theme})
@TableIndex(name: 'pgn_blocks_difficulty', columns: {#difficulty})
class PgnBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId => text().references(PgnSources, #id)();
  IntColumn get startOffset => integer()();
  IntColumn get endOffset => integer()();
  IntColumn get ordinal => integer()();
  TextColumn get event => text().nullable()();
  TextColumn get site => text().nullable()();
  TextColumn get date => text().nullable()();
  TextColumn get round => text().nullable()();
  TextColumn get white => text().nullable()();
  TextColumn get black => text().nullable()();
  TextColumn get result => text().nullable()();
  TextColumn get contentType => text()();
  TextColumn get exerciseId => text().nullable()();
  TextColumn get section => text().nullable()();
  IntColumn get sequence => integer().nullable()();
  TextColumn get theme => text().nullable()();
  TextColumn get difficulty => text().nullable()();
  TextColumn get parseStatus => text()();
  TextColumn get diagnosticSummary => text().nullable()();
  BoolColumn get inferredClassification =>
      boolean().withDefault(const Constant(false))();
  TextColumn get authoredContentType => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{sourceId, ordinal},
  ];

  @override
  List<String> get customConstraints => <String>[
    'CHECK (start_offset >= 0)',
    'CHECK (end_offset >= start_offset)',
    'CHECK (ordinal >= 0)',
  ];
}

/// Durable import state; the checkpoint is only advanced at safe boundaries.
@TableIndex(name: 'import_jobs_source', columns: {#sourceId})
@TableIndex(name: 'import_jobs_status', columns: {#status})
class ImportJobs extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId => text().references(PgnSources, #id)();
  TextColumn get status => text()();
  IntColumn get bytesProcessed => integer().withDefault(const Constant(0))();
  IntColumn get blocksScanned => integer().withDefault(const Constant(0))();
  IntColumn get blocksIndexed => integer().withDefault(const Constant(0))();
  IntColumn get blocksSkipped => integer().withDefault(const Constant(0))();
  IntColumn get diagnosticCount => integer().withDefault(const Constant(0))();
  IntColumn get safeCheckpoint => integer().withDefault(const Constant(0))();
  TextColumn get sourceFingerprint => text().nullable()();
  IntColumn get scannerVersion => integer().nullable()();
  IntColumn get sourceSizeBytes => integer().nullable()();
  BoolColumn get cancellationRequested =>
      boolean().withDefault(const Constant(false))();
  IntColumn get startedAtMicros => integer()();
  IntColumn get finishedAtMicros => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (bytes_processed >= 0)',
    'CHECK (blocks_scanned >= 0)',
    'CHECK (blocks_indexed >= 0)',
    'CHECK (blocks_skipped >= 0)',
    'CHECK (diagnostic_count >= 0)',
    'CHECK (safe_checkpoint >= 0)',
  ];
}

/// Sanitized diagnostics only; raw PGN text and private paths do not belong here.
@TableIndex(name: 'import_diagnostics_job', columns: {#importJobId})
class ImportDiagnostics extends Table {
  TextColumn get id => text()();
  TextColumn get importJobId => text().references(ImportJobs, #id)();
  TextColumn get severity => text()();
  IntColumn get blockOrdinal => integer().nullable()();
  IntColumn get startOffset => integer().nullable()();
  IntColumn get endOffset => integer().nullable()();
  TextColumn get diagnosticCode => text()();
  TextColumn get sanitizedMessage => text()();
  IntColumn get createdAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(name: 'training_sets_status', columns: {#status})
class TrainingSets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  IntColumn get createdAtMicros => integer()();
  IntColumn get updatedAtMicros => integer()();
  IntColumn get archivedAtMicros => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(name: 'training_set_items_block', columns: {#blockId})
@TableIndex(
  name: 'training_set_items_order',
  columns: {#trainingSetId, #position},
)
class TrainingSetItems extends Table {
  TextColumn get id => text()();
  TextColumn get trainingSetId => text().references(TrainingSets, #id)();
  TextColumn get blockId => text().references(PgnBlocks, #id)();
  IntColumn get position => integer()();
  TextColumn get contentType => text()();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  IntColumn get addedAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{trainingSetId, position},
  ];

  @override
  List<String> get customConstraints => <String>[
    'CHECK (position >= 0)',
  ];
}

@TableIndex.sql(
  "CREATE UNIQUE INDEX cycles_one_active_per_set "
  "ON cycles (training_set_id) WHERE status = 'active'",
)
@TableIndex(name: 'cycles_set_status', columns: {#trainingSetId, #status})
class Cycles extends Table {
  TextColumn get id => text()();
  TextColumn get trainingSetId => text().references(TrainingSets, #id)();
  TextColumn get status => text()();
  IntColumn get startedAtMicros => integer().nullable()();
  IntColumn get completedAtMicros => integer().nullable()();
  IntColumn get stoppedAtMicros => integer().nullable()();
  IntColumn get createdAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'training_sessions_cycle',
  columns: {#cycleId, #startedAtMicros},
)
class TrainingSessions extends Table {
  TextColumn get id => text()();
  TextColumn get cycleId => text().references(Cycles, #id)();
  TextColumn get status => text()();
  IntColumn get startedAtMicros => integer()();
  IntColumn get endedAtMicros => integer().nullable()();
  IntColumn get studyDayMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'puzzle_attempts_cycle',
  columns: {#cycleId, #startedAtMicros},
)
@TableIndex(
  name: 'puzzle_attempts_block',
  columns: {#blockId, #startedAtMicros},
)
@TableIndex(name: 'puzzle_attempts_session', columns: {#sessionId})
@TableIndex(name: 'puzzle_attempts_outcome', columns: {#outcome})
class PuzzleAttempts extends Table {
  TextColumn get id => text()();
  TextColumn get blockId => text().references(PgnBlocks, #id)();
  TextColumn get cycleId => text().references(Cycles, #id)();
  TextColumn get sessionId => text().references(TrainingSessions, #id)();
  TextColumn get status => text()();
  TextColumn get outcome => text().nullable()();
  TextColumn get failureReason => text().nullable()();
  IntColumn get startedAtMicros => integer()();
  IntColumn get completedAtMicros => integer().nullable()();
  IntColumn get activeMilliseconds =>
      integer().withDefault(const Constant(0))();
  IntColumn get wrongMoveCount => integer().withDefault(const Constant(0))();
  IntColumn get hintCount => integer().withDefault(const Constant(0))();
  BoolColumn get revealed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (active_milliseconds >= 0)',
    'CHECK (wrong_move_count >= 0)',
    'CHECK (hint_count >= 0)',
    'CHECK ((outcome IS NULL AND completed_at_micros IS NULL) OR '
        '(outcome IS NOT NULL AND completed_at_micros IS NOT NULL))',
  ];
}

@TableIndex(
  name: 'attempt_moves_attempt_order',
  columns: {#attemptId, #ordinal},
)
class AttemptMoves extends Table {
  TextColumn get id => text()();
  TextColumn get attemptId => text().references(PuzzleAttempts, #id)();
  IntColumn get ordinal => integer()();
  TextColumn get move => text()();
  BoolColumn get legal => boolean()();
  BoolColumn get accepted => boolean()();
  IntColumn get submittedAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{attemptId, ordinal},
  ];

  @override
  List<String> get customConstraints => <String>['CHECK (ordinal >= 0)'];
}

@TableIndex(
  name: 'timing_segments_attempt',
  columns: {#attemptId, #startedAtMicros},
)
class TimingSegments extends Table {
  TextColumn get id => text()();
  TextColumn get attemptId => text().references(PuzzleAttempts, #id)();
  IntColumn get startedAtMicros => integer()();
  IntColumn get endedAtMicros => integer().nullable()();
  IntColumn get activeMilliseconds => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (ended_at_micros IS NULL OR ended_at_micros >= started_at_micros)',
    'CHECK (active_milliseconds IS NULL OR active_milliseconds >= 0)',
    'CHECK ((ended_at_micros IS NULL AND active_milliseconds IS NULL) OR '
        '(ended_at_micros IS NOT NULL AND active_milliseconds IS NOT NULL))',
  ];
}
