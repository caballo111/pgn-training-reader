import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/logging/app_logger.dart';
import '../core/time/app_clock.dart';
import '../core/utilities/id_generator.dart';
import '../data/database/app_database.dart';
import '../data/file_access/managed_file_source.dart';
import '../data/file_access/flutter_file_source_picker.dart';
import '../data/pgn/pgn_indexer.dart';
import '../data/repositories/drift_pgn_source_repository.dart';
import '../data/repositories/drift_pgn_index_repository.dart';
import '../data/repositories/drift_training_set_repository.dart';
import '../domain/training/training_set_repository.dart';
import '../data/repositories/drift_training_repository.dart';
import '../data/repositories/drift_chess_content_repository.dart';
import '../data/repositories/drift_library_lifecycle_service.dart';
import '../data/repositories/drift_exploration_repository.dart';
import '../data/analysis/stockfish_analysis_engine.dart';
import '../domain/analysis/analysis_engine.dart';
import '../domain/analysis/exploration_repository.dart';
import '../domain/chess_content/chess_content_repository.dart';
import '../domain/library/pgn_source_repository.dart';
import '../domain/library/library_lifecycle_service.dart';
import '../domain/training/training_repository.dart';
import '../domain/training/training_session_service.dart';
import '../domain/training/training_session_service_impl.dart';
import '../features/import_library/application/import_controller.dart';
import 'theme_controller.dart';

/// Application-level composition root for foundational abstractions.
///
/// Feature services and persistence dependencies are added here as their
/// contracts are implemented. Callers may provide substitutes for tests.
final class AppDependencies {
  AppDependencies({
    AppClock? clock,
    IdGenerator? idGenerator,
    AppLogger? logger,
    this.databaseFactory,
    ThemeController? themeController,
    ExplorationRepository? explorationRepository,
    AnalysisEngineFactory? analysisEngineFactory,
  }) : clock = clock ?? SystemAppClock(),
       themeController = themeController ?? ThemeController(),
       // Keep the public injection name distinct from the private lazy cache.
       // ignore: prefer_initializing_formals
       _explorationRepository = explorationRepository,
       analysisEngineFactory =
           analysisEngineFactory ?? defaultAnalysisEngineFactory,
       idGenerator = idGenerator ?? RandomIdGenerator(),
       logger = logger ?? const StructuredAppLogger(_discardLogRecord);

  final AppClock clock;
  final IdGenerator idGenerator;
  final AppLogger logger;
  final ThemeController themeController;
  final AnalysisEngineFactory analysisEngineFactory;
  ExplorationRepository? _explorationRepository;

  ExplorationRepository get explorationRepository =>
      _explorationRepository ??= DriftExplorationRepository(database);

  final AppDatabase Function()? databaseFactory;
  AppDatabase? _database;
  ImportController? _importController;
  TrainingSetRepository? _trainingSetRepository;
  TrainingRepository? _trainingRepository;
  TrainingSessionService? _trainingSessionService;
  ChessContentRepository? _chessContentRepository;
  PgnSourceRepository? _pgnSourceRepository;
  LibraryLifecycleService? _libraryLifecycleService;
  bool _restoreAttempted = false;

  /// Opened lazily so creating app dependencies performs no platform I/O.
  AppDatabase get database => _database ??=
      databaseFactory?.call() ??
      AppDatabase(driftDatabase(name: 'pgn_training_reader'));

  TrainingSetRepository get trainingSetRepository =>
      _trainingSetRepository ??= DriftTrainingSetRepository(database);

  TrainingRepository get trainingRepository =>
      _trainingRepository ??= DriftTrainingRepository(database);

  TrainingSessionService get trainingSessionService =>
      _trainingSessionService ??= TrainingSessionServiceImpl(
        repository: trainingRepository,
        clock: clock,
        idGenerator: idGenerator,
      );

  DriftPgnIndexRepository get pgnIndexRepository =>
      DriftPgnIndexRepository(database);

  PgnSourceRepository get pgnSourceRepository =>
      _pgnSourceRepository ??= DriftPgnSourceRepository(database);

  LibraryLifecycleService get libraryLifecycleService =>
      _libraryLifecycleService ??= DriftLibraryLifecycleService(
        database: database,
        sourceRepository: pgnSourceRepository,
        managedFileSource: _fileSource,
      );

  ChessContentRepository get chessContentRepository =>
      _chessContentRepository ??= DriftChessContentRepository(
        indexRepository: pgnIndexRepository,
        sourceRepository: pgnSourceRepository,
        fileSource: _fileSource,
      );

  ManagedFileSource get _fileSource =>
      ManagedFileSource(pickedSources: const FlutterFileSource());

  /// A process-scoped controller whose source and index stores survive routes.
  ImportController get importController {
    final controller = _importController ??= _makeImportController();
    if (!_restoreAttempted) {
      _restoreAttempted = true;
      unawaited(_restorePendingImport(controller));
    }
    return controller;
  }

  ImportController _makeImportController() {
    final fileSource = _fileSource;
    final db = database;
    return ImportController(
      fileSourcePicker: const FlutterFileSourcePicker(),
      fileSource: fileSource,
      targetFactory: fileSource.createTarget,
      sourceRepository: pgnSourceRepository,
      importService: DriftPgnImportService(
        database: db,
        fileSource: fileSource,
        idGenerator: idGenerator,
        clock: clock,
      ),
      clock: clock,
      idGenerator: idGenerator,
    );
  }

  Future<void> _restorePendingImport(ImportController controller) async {
    try {
      final db = database;
      final jobs =
          await (db.select(db.importJobs)
                ..where(
                  (job) =>
                      job.status.isIn(const [
                        'cancelled',
                        'failed',
                        'indexing',
                      ]) &
                      const CustomExpression<bool>(
                        "import_jobs.source_id IN (SELECT id FROM pgn_sources WHERE import_state != 'deleted')",
                      ),
                )
                ..orderBy([(job) => OrderingTerm.desc(job.startedAtMicros)])
                ..limit(1))
              .get();
      if (jobs.isEmpty) return;
      final job = jobs.single;
      final source = await DriftPgnSourceRepository(db).getById(job.sourceId);
      if (source == null || source.importState == 'deleted') return;
      controller.restoreResumableImport(
        source: source,
        jobId: job.id,
        indexedBlockCount: job.blocksIndexed,
        diagnosticCount: job.diagnosticCount,
        bytesRead: job.bytesProcessed,
        safeCheckpoint: job.safeCheckpoint,
      );
    } catch (_) {
      // The library remains usable when restore discovery cannot read storage.
    }
  }
}

void _discardLogRecord(AppLogRecord _) {}
