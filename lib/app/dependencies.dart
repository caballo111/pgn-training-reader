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
import '../features/import_library/application/import_controller.dart';

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
  }) : clock = clock ?? SystemAppClock(),
       idGenerator = idGenerator ?? RandomIdGenerator(),
       logger = logger ?? const StructuredAppLogger(_discardLogRecord);

  final AppClock clock;
  final IdGenerator idGenerator;
  final AppLogger logger;

  final AppDatabase Function()? databaseFactory;
  AppDatabase? _database;
  ImportController? _importController;
  bool _restoreAttempted = false;

  /// Opened lazily so creating app dependencies performs no platform I/O.
  AppDatabase get database => _database ??=
      databaseFactory?.call() ??
      AppDatabase(driftDatabase(name: 'pgn_training_reader'));

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
    final fileSource = ManagedFileSource(
      pickedSources: const FlutterFileSource(),
    );
    final db = database;
    return ImportController(
      fileSourcePicker: const FlutterFileSourcePicker(),
      fileSource: fileSource,
      targetFactory: fileSource.createTarget,
      sourceRepository: DriftPgnSourceRepository(db),
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
                  (job) => job.status.isIn(const [
                    'cancelled',
                    'failed',
                    'indexing',
                  ]),
                )
                ..orderBy([(job) => OrderingTerm.desc(job.startedAtMicros)])
                ..limit(1))
              .get();
      if (jobs.isEmpty) return;
      final job = jobs.single;
      final source = await DriftPgnSourceRepository(db).getById(job.sourceId);
      if (source == null) return;
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
