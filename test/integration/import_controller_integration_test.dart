import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm, Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/errors/app_failure.dart';
import 'package:pgntrainingreader/app/dependencies.dart';
import 'package:pgntrainingreader/core/time/app_clock.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';
import 'package:pgntrainingreader/data/file_access/file_source_picker.dart';
import 'package:pgntrainingreader/data/file_access/managed_file_source.dart';
import 'package:pgntrainingreader/data/pgn/pgn_indexer.dart';
import 'package:pgntrainingreader/data/repositories/drift_pgn_index_repository.dart';
import 'package:pgntrainingreader/data/repositories/drift_pgn_source_repository.dart';
import 'package:pgntrainingreader/data/repositories/drift_chess_content_repository.dart';
import 'package:pgntrainingreader/domain/library/pgn_index_repository.dart';
import 'package:pgntrainingreader/features/import_library/application/import_controller.dart';
import 'package:pgntrainingreader/features/import_library/application/import_recovery.dart';

void main() {
  test(
    'discovery skips newer deleted jobs and restores the latest active import',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      const now = 1790640000000000;
      const managedToken = '0123456789abcdef0123456789abcdef';
      await database
          .into(database.pgnSources)
          .insert(
            PgnSourcesCompanion.insert(
              id: 'restored-source',
              displayName: 'restored.pgn',
              accessMode: 'ManagedCopy',
              managedPath: const Value(managedToken),
              sizeBytes: const Value(4096),
              scannerVersion: 1,
              importState: 'indexing',
              createdAtMicros: now,
              updatedAtMicros: now,
            ),
          );
      await database
          .into(database.importJobs)
          .insert(
            ImportJobsCompanion.insert(
              id: 'restored-job',
              sourceId: 'restored-source',
              status: 'cancelled',
              blocksIndexed: const Value(50),
              bytesProcessed: const Value(2048),
              safeCheckpoint: const Value(2048),
              startedAtMicros: now,
            ),
          );
      await database
          .into(database.pgnSources)
          .insert(
            PgnSourcesCompanion.insert(
              id: 'deleted-source',
              displayName: 'removed.pgn',
              accessMode: 'ExternalReference',
              externalReference: const Value('content://removed'),
              scannerVersion: 1,
              importState: 'deleted',
              createdAtMicros: now,
              updatedAtMicros: now + 1,
            ),
          );
      await database
          .into(database.importJobs)
          .insert(
            ImportJobsCompanion.insert(
              id: 'newer-deleted-job',
              sourceId: 'deleted-source',
              status: 'cancelled',
              blocksIndexed: const Value(2),
              bytesProcessed: const Value(10),
              safeCheckpoint: const Value(10),
              startedAtMicros: now + 1,
            ),
          );

      final dependencies = AppDependencies(databaseFactory: () => database);
      final controller = dependencies.importController;
      addTearDown(controller.dispose);
      final restored = Completer<void>();
      void listener() {
        if (controller.state.status == ImportStatus.cancelled &&
            !restored.isCompleted) {
          restored.complete();
        }
      }

      controller.addListener(listener);
      if (controller.state.status == ImportStatus.cancelled) {
        restored.complete();
      }
      await restored.future.timeout(const Duration(seconds: 2));
      controller.removeListener(listener);

      expect(controller.state.progress?.indexedBlockCount, 50);
      expect(
        importRecoveryFor(controller.state).action,
        ImportRecoveryAction.resume,
      );
    },
  );

  test(
    'selects, copies, cancels at a committed batch, resumes, and indexes once',
    () async {
      final temp = await Directory.systemTemp.createTemp('pgn-controller-');
      addTearDown(() => temp.delete(recursive: true));
      final blocks = List<String>.generate(120, _pgnBlock);
      final sourceBytes = Uint8List.fromList(
        utf8.encode('${blocks.join('\n')}\n'),
      );
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final fileSource = ManagedFileSource(
        pickedSources: _PickedBytes(sourceBytes),
        directoryProvider: () async => temp,
      );
      final clock = _FixedClock(DateTime.utc(2026, 9, 29));
      final ids = _SequenceIds();
      final controller = _makeController(
        fileSource: fileSource,
        database: database,
        ids: ids,
        clock: clock,
        sourceBytes: sourceBytes,
      );
      var controllerDisposed = false;
      addTearDown(() {
        if (!controllerDisposed) controller.dispose();
      });

      var cancelRequested = false;
      Future<void>? cancelFuture;
      controller.addListener(() {
        final state = controller.state;
        if (!cancelRequested &&
            state.status == ImportStatus.indexing &&
            (state.progress?.indexedBlockCount ?? 0) >= 50) {
          cancelRequested = true;
          cancelFuture = controller.cancel();
        }
      });

      await controller.selectAndImport();
      await cancelFuture;

      expect(cancelRequested, isTrue);
      expect(controller.state.status, ImportStatus.cancelled);
      expect(
        controller.state.result?.indexedBlockCount,
        greaterThanOrEqualTo(50),
      );
      expect(controller.state.result?.resumeDisposition.name, 'resume');

      final savedSource =
          (await database.select(database.pgnSources).get()).single;
      final managedReference = ManagedSourceReference(savedSource.managedPath!);
      final bytesBeforeResume = await fileSource.readRange(
        managedReference,
        start: 0,
        endExclusive: savedSource.sizeBytes!,
      );
      expect(bytesBeforeResume, orderedEquals(sourceBytes));
      final committedBeforeResume = await (database.select(
        database.pgnBlocks,
      )..orderBy([(block) => OrderingTerm.asc(block.ordinal)])).get();
      expect(committedBeforeResume.length, greaterThanOrEqualTo(50));
      final committedIds = committedBeforeResume.map((row) => row.id).toList();

      final stoppedJob =
          (await (database.select(database.importJobs)
                ..where((job) => job.id.equals(controller.state.result!.jobId)))
              .getSingle());
      final stoppedSource = await DriftPgnSourceRepository(database)
          .getById(stoppedJob.sourceId);
      expect(stoppedSource, isNotNull);
      controller.dispose();
      controllerDisposed = true;

      final restoredController = _makeController(
        fileSource: fileSource,
        database: database,
        ids: ids,
        clock: clock,
        sourceBytes: sourceBytes,
      );
      addTearDown(restoredController.dispose);
      restoredController.restoreResumableImport(
        source: stoppedSource!,
        jobId: stoppedJob.id,
        indexedBlockCount: stoppedJob.blocksIndexed,
        diagnosticCount: stoppedJob.diagnosticCount,
        bytesRead: stoppedJob.bytesProcessed,
        safeCheckpoint: stoppedJob.safeCheckpoint,
      );

      expect(restoredController.state.status, ImportStatus.cancelled);
      expect(restoredController.state.result?.resumeDisposition.name, 'resume');
      expect(
        importRecoveryFor(restoredController.state).action,
        ImportRecoveryAction.resume,
      );
      expect(
        importRecoveryFor(restoredController.state).explanation,
        contains('managed copy'),
      );

      await restoredController.resume();

      expect(restoredController.state.status, ImportStatus.completed);
      expect(restoredController.state.result?.indexedBlockCount, 120);
      expect(restoredController.state.result?.diagnosticCount, 0);
      final rows = await (database.select(
        database.pgnBlocks,
      )..orderBy([(block) => OrderingTerm.asc(block.ordinal)])).get();
      expect(rows, hasLength(120));
      expect(rows.map((row) => row.id).toSet(), hasLength(120));
      expect(rows.map((row) => row.ordinal), List<int>.generate(120, (i) => i));
      expect(rows.take(committedIds.length).map((row) => row.id), committedIds);

      final indexedPage = await DriftPgnIndexRepository(database)
          .search(filter: PgnIndexFilter(sourceId: savedSource.id), limit: 200);
      expect(indexedPage.items, hasLength(120));
      for (var i = 0; i < blocks.length; i++) {
        final indexed = indexedPage.items[i];
        final raw = await fileSource.readRange(
          managedReference,
          start: indexed.startOffset,
          endExclusive: indexed.endOffset,
        );
        expect(
          utf8.decode(raw),
          blocks[i].trimRight(),
          reason: 'PGN block ordinal $i',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('missing source relinks under same ID; reindex preserves history and blocks duplicates', () async {
    final temp = await Directory.systemTemp.createTemp('pgn-reindex-');
    addTearDown(() => temp.delete(recursive: true));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime.utc(2026, 9, 29);
    final picker = _MutableSource(_authoredPuzzle('stable', '1. e4 *'));
    final fileSource = ManagedFileSource(
      pickedSources: picker,
      directoryProvider: () async => temp,
    );
    final ids = _SequenceIds();
    final clock = _FixedClock(now);
    final sourceRepository = DriftPgnSourceRepository(database);
    final controller = ImportController(
      fileSourcePicker: picker,
      fileSource: fileSource,
      targetFactory: fileSource.createTarget,
      sourceRepository: sourceRepository,
      importService: DriftPgnImportService(
        database: database,
        fileSource: fileSource,
        idGenerator: ids,
        clock: clock,
      ),
      clock: clock,
      idGenerator: ids,
    );
    addTearDown(controller.dispose);

    await controller.selectAndImport();
    expect(
      controller.state.status,
      ImportStatus.completed,
      reason:
          '${controller.state.failure?.code}: ${controller.state.errorMessage}',
    );
    final source = (await sourceRepository.list()).single;
    final original = (await DriftPgnIndexRepository(database).search(
      filter: PgnIndexFilter(sourceId: source.id),
      limit: 10,
    )).items.single;

    await database
        .into(database.trainingSets)
        .insert(
          TrainingSetsCompanion.insert(
            id: 'history-set',
            name: 'Existing history',
            createdAtMicros: now.microsecondsSinceEpoch,
            updatedAtMicros: now.microsecondsSinceEpoch,
          ),
        );
    await database
        .into(database.trainingSetItems)
        .insert(
          TrainingSetItemsCompanion.insert(
            id: 'history-item',
            trainingSetId: 'history-set',
            blockId: original.id,
            position: 0,
            contentType: 'Puzzle',
            addedAtMicros: now.microsecondsSinceEpoch,
          ),
        );

    await (database.update(database.pgnSources)
          ..where((row) => row.id.equals(source.id)))
        .write(const PgnSourcesCompanion(importState: Value('sourceMissing')));
    final missingFailure = await _captureFailure(
      DriftChessContentRepository(
        indexRepository: DriftPgnIndexRepository(database),
        sourceRepository: sourceRepository,
        fileSource: fileSource,
      ).getById(original.id),
    );
    expect(missingFailure.code, 'source_missing');

    // Selecting the identical bytes repairs the missing source without
    // changing its source or block identity.
    picker.bytes = _authoredPuzzle('stable', '1. e4 *');
    expect(
      await controller.relinkSource(source.id),
      SourceRelinkOutcome.sameRevision,
    );
    expect((await sourceRepository.getById(source.id))!.id, source.id);
    expect(
      (await DriftPgnIndexRepository(database).getById(original.id))!.id,
      original.id,
    );

    // A different revision blocks the old locator until re-index completes.
    await (database.update(database.pgnSources)
          ..where((row) => row.id.equals(source.id)))
        .write(const PgnSourcesCompanion(importState: Value('sourceMissing')));
    picker.bytes = _authoredPuzzle('stable', '1. d4 d5 *');
    expect(
      await controller.relinkSource(source.id),
      SourceRelinkOutcome.changedRevision,
    );
    final changedFailure = await _captureFailure(
      DriftChessContentRepository(
        indexRepository: DriftPgnIndexRepository(database),
        sourceRepository: sourceRepository,
        fileSource: fileSource,
      ).getById(original.id),
    );
    expect(changedFailure.code, 'source_changed');
    expect(
      await controller.reindexSource(source.id),
      isTrue,
      reason:
          '${controller.state.failure?.code}: ${controller.state.errorMessage}',
    );
    final afterReindex = await DriftPgnIndexRepository(database)
        .search(filter: PgnIndexFilter(sourceId: source.id), limit: 10);
    expect(afterReindex.items, hasLength(1));
    expect(afterReindex.items.single.id, original.id);
    expect(
      await (database.select(database.trainingSetItems)
            ..where((row) => row.id.equals('history-item')))
          .getSingle()
          .then((row) => row.blockId),
      original.id,
    );

    // A duplicate authored identity remains two distinct conflict rows;
    // it cannot be reconciled to the prior ID or opened by offset.
    await (database.update(database.pgnSources)
          ..where((row) => row.id.equals(source.id)))
        .write(const PgnSourcesCompanion(importState: Value('sourceMissing')));
    picker.bytes = Uint8List.fromList([
      ..._authoredPuzzle('stable', '1. c4 *'),
      10,
      ..._authoredPuzzle('stable', '1. Nf3 *'),
    ]);
    expect(
      await controller.relinkSource(source.id),
      SourceRelinkOutcome.changedRevision,
    );
    expect(await controller.reindexSource(source.id), isTrue);
    final duplicateRows = (await DriftPgnIndexRepository(
      database,
    ).search(filter: PgnIndexFilter(sourceId: source.id), limit: 10)).items;
    final sourceAfterDuplicates = await sourceRepository.getById(source.id);
    final rawAfterDuplicates = await database
        .customSelect(
          'SELECT id, is_current, reindex_job_id, diagnostic_summary, ordinal FROM pgn_blocks',
        )
        .get();
    expect(
      duplicateRows,
      hasLength(2),
      reason:
          'sourceState=${sourceAfterDuplicates?.importState}; rows=${rawAfterDuplicates.map((row) => '${row.read<String>('id')}:${row.read<int>('is_current')}:${row.read<String?>('reindex_job_id')}:${row.read<String?>('diagnostic_summary')}:${row.read<int>('ordinal')}').join(',')}',
    );
    expect(duplicateRows.map((row) => row.id).toSet(), hasLength(2));
    expect(
      duplicateRows.every(
        (row) => row.diagnosticSummary == 'duplicateExerciseId',
      ),
      isTrue,
    );
    expect(
      await (database.select(database.trainingSetItems)
            ..where((row) => row.id.equals('history-item')))
          .getSingle()
          .then((row) => row.blockId),
      original.id,
    );
    final contentRepository = DriftChessContentRepository(
      indexRepository: DriftPgnIndexRepository(database),
      sourceRepository: sourceRepository,
      fileSource: fileSource,
    );
    for (final duplicate in duplicateRows) {
      final failure = await _captureFailure(
        contentRepository.getById(duplicate.id),
      );
      expect(failure.code, 'duplicate_exercise_id');
    }
    final duplicateDiagnosticCount = await (database.select(
      database.importDiagnostics,
    )..where((row) => row.diagnosticCode.equals('duplicateExerciseId'))).get();
    expect(duplicateDiagnosticCount, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('reindex reports unresolved legacy fallback identity', () async {
    final temp = await Directory.systemTemp.createTemp('pgn-legacy-');
    addTearDown(() => temp.delete(recursive: true));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime.utc(2026, 9, 29);
    final picker = _MutableSource(_fallbackPuzzle('1. e4 *'));
    final fileSource = ManagedFileSource(
      pickedSources: picker,
      directoryProvider: () async => temp,
    );
    final ids = _SequenceIds();
    final clock = _FixedClock(now);
    final sourceRepository = DriftPgnSourceRepository(database);
    final controller = ImportController(
      fileSourcePicker: picker,
      fileSource: fileSource,
      targetFactory: fileSource.createTarget,
      sourceRepository: sourceRepository,
      importService: DriftPgnImportService(
        database: database,
        fileSource: fileSource,
        idGenerator: ids,
        clock: clock,
      ),
      clock: clock,
      idGenerator: ids,
    );
    addTearDown(controller.dispose);
    await controller.selectAndImport();
    final source = (await sourceRepository.list()).single;
    final oldRows = (await DriftPgnIndexRepository(
      database,
    ).search(filter: PgnIndexFilter(sourceId: source.id), limit: 10)).items;
    expect(oldRows, hasLength(1));
    // Simulate a row from a pre-provenance database. Its authored/fallback
    // identity is unknown and cannot safely inherit a fresh fallback ID.
    await database.customStatement(
      'UPDATE pgn_blocks SET authored_exercise_id = NULL, fallback_identity_key = NULL WHERE id = ?',
      [oldRows.single.id],
    );
    await (database.update(database.pgnSources)
          ..where((row) => row.id.equals(source.id)))
        .write(const PgnSourcesCompanion(importState: Value('sourceMissing')));
    picker.bytes = _fallbackPuzzle('1. d4 d5 *');
    expect(
      await controller.relinkSource(source.id),
      SourceRelinkOutcome.changedRevision,
    );
    expect(await controller.reindexSource(source.id), isTrue);
    final diagnostic =
        await (database.select(database.importDiagnostics)..where(
              (row) => row.diagnosticCode.equals('unresolvedFallbackIdentity'),
            ))
            .get();
    expect(diagnostic, isNotEmpty);
  });

  test(
    'retry after interrupted reindex restores current rows and stable IDs',
    () async {
      final temp = await Directory.systemTemp.createTemp('pgn-reindex-retry-');
      addTearDown(() => temp.delete(recursive: true));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime.utc(2026, 9, 29);
      final originalBytes = Uint8List.fromList(
        utf8.encode(
          List.generate(55, (i) => _authoredBlock(i, 'e4')).join('\n'),
        ),
      );
      final picker = _MutableSource(originalBytes);
      final fileSource = ManagedFileSource(
        pickedSources: picker,
        directoryProvider: () async => temp,
      );
      final ids = _SequenceIds();
      final clock = _FixedClock(now);
      final sourceRepository = DriftPgnSourceRepository(database);
      final controller = ImportController(
        fileSourcePicker: picker,
        fileSource: fileSource,
        targetFactory: fileSource.createTarget,
        sourceRepository: sourceRepository,
        importService: DriftPgnImportService(
          database: database,
          fileSource: fileSource,
          idGenerator: ids,
          clock: clock,
        ),
        clock: clock,
        idGenerator: ids,
      );
      addTearDown(controller.dispose);
      await controller.selectAndImport();
      expect(controller.state.status, ImportStatus.completed);
      final source = (await sourceRepository.list()).single;
      final originalRows = (await DriftPgnIndexRepository(
        database,
      ).search(filter: PgnIndexFilter(sourceId: source.id), limit: 100)).items;
      expect(originalRows, hasLength(55));
      final originalIds = originalRows.map((row) => row.id).toSet();

      await (database.update(
        database.pgnSources,
      )..where((row) => row.id.equals(source.id))).write(
        const PgnSourcesCompanion(importState: Value('sourceMissing')),
      );
      picker.bytes = Uint8List.fromList(
        utf8.encode(
          List.generate(60, (i) => _authoredBlock(i, 'd4')).join('\n'),
        ),
      );
      expect(
        await controller.relinkSource(source.id),
        SourceRelinkOutcome.changedRevision,
      );

      var cancelRequested = false;
      Future<void>? cancelFuture;
      void cancelReindexAtSafeBatch() {
        if (!cancelRequested &&
            controller.state.status == ImportStatus.indexing &&
            (controller.state.progress?.indexedBlockCount ?? 0) >= 50) {
          cancelRequested = true;
          cancelFuture = controller.cancel();
        }
      }

      controller.addListener(cancelReindexAtSafeBatch);
      expect(await controller.reindexSource(source.id), isFalse);
      await cancelFuture;
      controller.removeListener(cancelReindexAtSafeBatch);
      expect(cancelRequested, isTrue);
      expect(controller.state.status, ImportStatus.cancelled);
      expect(
        (await sourceRepository.getById(source.id))!.importState,
        'reindexing',
      );

      expect(await controller.reindexSource(source.id), isTrue);
      expect(
        (await sourceRepository.getById(source.id))!.importState,
        'indexed',
      );
      final currentRows = (await DriftPgnIndexRepository(
        database,
      ).search(filter: PgnIndexFilter(sourceId: source.id), limit: 100)).items;
      expect(currentRows, hasLength(60));
      expect(
        originalIds.difference(currentRows.map((row) => row.id).toSet()),
        isEmpty,
      );
      final rawCounts = await database
          .customSelect(
            'SELECT SUM(is_current) AS current_count, COUNT(*) AS total_count, '
            'SUM(CASE WHEN reindex_job_id IS NOT NULL THEN 1 ELSE 0 END) AS staged_count '
            'FROM pgn_blocks WHERE source_id = ?',
            variables: [Variable.withString(source.id)],
          )
          .getSingle();
      expect(rawCounts.read<int>('current_count'), 60);
      expect(rawCounts.read<int>('total_count'), 60);
      expect(rawCounts.read<int>('staged_count'), 0);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('changed known fallback identity produces a diagnostic', () async {
    final temp = await Directory.systemTemp.createTemp('pgn-fallback-change-');
    addTearDown(() => temp.delete(recursive: true));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime.utc(2026, 9, 29);
    final picker = _MutableSource(_fallbackPuzzle('1. e4 *'));
    final fileSource = ManagedFileSource(
      pickedSources: picker,
      directoryProvider: () async => temp,
    );
    final ids = _SequenceIds();
    final clock = _FixedClock(now);
    final sourceRepository = DriftPgnSourceRepository(database);
    final controller = ImportController(
      fileSourcePicker: picker,
      fileSource: fileSource,
      targetFactory: fileSource.createTarget,
      sourceRepository: sourceRepository,
      importService: DriftPgnImportService(
        database: database,
        fileSource: fileSource,
        idGenerator: ids,
        clock: clock,
      ),
      clock: clock,
      idGenerator: ids,
    );
    addTearDown(controller.dispose);
    await controller.selectAndImport();
    final source = (await sourceRepository.list()).single;
    final initial = await database
        .customSelect(
          'SELECT fallback_identity_key FROM pgn_blocks WHERE source_id = ?',
          variables: [Variable.withString(source.id)],
        )
        .getSingle();
    expect(initial.read<String?>('fallback_identity_key'), isNotNull);
    await (database.update(database.pgnSources)
          ..where((row) => row.id.equals(source.id)))
        .write(const PgnSourcesCompanion(importState: Value('sourceMissing')));
    picker.bytes = _fallbackPuzzle('1. d4 d5 *');
    expect(
      await controller.relinkSource(source.id),
      SourceRelinkOutcome.changedRevision,
    );
    expect(await controller.reindexSource(source.id), isTrue);
    final diagnostic =
        await (database.select(database.importDiagnostics)..where(
              (row) => row.diagnosticCode.equals('unresolvedFallbackIdentity'),
            ))
            .get();
    expect(diagnostic, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<AppFailure> _captureFailure(Future<Object?> operation) async {
  try {
    await operation;
  } on AppFailure catch (failure) {
    return failure;
  }
  throw StateError('Expected an AppFailure.');
}

Uint8List _authoredPuzzle(String id, String moves) => Uint8List.fromList(
  utf8.encode(
    '[Event "Authored $id"]\n'
    '[X-ContentType "Puzzle"]\n'
    '[X-ExerciseId "$id"]\n'
    '\n$moves\n',
  ),
);

Uint8List _fallbackPuzzle(String moves) =>
    Uint8List.fromList(utf8.encode('[Event "Fallback"]\n\n$moves\n'));

String _authoredBlock(int index, String move) =>
    '[Event "Authored $index"]\n'
    '[X-ContentType "Puzzle"]\n'
    '[X-ExerciseId "authored-$index"]\n'
    '\n1. $move *\n';

ImportController _makeController({
  required ManagedFileSource fileSource,
  required AppDatabase database,
  required _SequenceIds ids,
  required _FixedClock clock,
  required Uint8List sourceBytes,
}) => ImportController(
  fileSourcePicker: _FixturePicker(
    SelectedFileSource(
      reference: const _FixtureReference(),
      displayName: 'controller-fixture.pgn',
      lengthBytes: sourceBytes.length,
      mimeType: 'application/x-chess-pgn',
    ),
  ),
  fileSource: fileSource,
  targetFactory: fileSource.createTarget,
  sourceRepository: DriftPgnSourceRepository(database),
  importService: DriftPgnImportService(
    database: database,
    fileSource: fileSource,
    idGenerator: ids,
    clock: clock,
  ),
  clock: clock,
  idGenerator: ids,
);

String _pgnBlock(int index) =>
    '[Event "Game $index"]\n'
    '[White "White $index"]\n'
    '[Black "Black $index"]\n'
    '\n'
    '1. e4 e5 2. Nf3 Nc6 *\n';

final class _FixtureReference implements OpaqueSourceReference {
  const _FixtureReference();
}

final class _FixturePicker implements FileSourcePicker {
  _FixturePicker(this.source);
  final SelectedFileSource source;

  @override
  Future<SelectedFileSource?> pickPgnSource() async => source;
}

final class _MutableSource implements FileSourcePicker, PickedSourceAccess {
  _MutableSource(this.bytes);
  Uint8List bytes;

  @override
  Future<SelectedFileSource?> pickPgnSource() async => SelectedFileSource(
    reference: const _FixtureReference(),
    displayName: 'replacement.pgn',
    lengthBytes: bytes.length,
    mimeType: 'application/x-chess-pgn',
  );

  @override
  Stream<List<int>> openReadStream(OpaqueSourceReference reference) async* {
    yield bytes;
  }

  @override
  Future<int?> length(OpaqueSourceReference reference) async => bytes.length;

  @override
  Future<DateTime?> modifiedAt(OpaqueSourceReference reference) async => null;

  @override
  Future<Uint8List> readRange(
    OpaqueSourceReference reference, {
    required int start,
    required int endExclusive,
  }) async => Uint8List.fromList(bytes.sublist(start, endExclusive));
}

final class _PickedBytes implements PickedSourceAccess {
  _PickedBytes(this.bytes);
  final Uint8List bytes;

  @override
  Stream<List<int>> openReadStream(OpaqueSourceReference reference) async* {
    yield bytes;
  }

  @override
  Future<int?> length(OpaqueSourceReference reference) async => bytes.length;

  @override
  Future<DateTime?> modifiedAt(OpaqueSourceReference reference) async => null;

  @override
  Future<Uint8List> readRange(
    OpaqueSourceReference reference, {
    required int start,
    required int endExclusive,
  }) async => Uint8List.fromList(bytes.sublist(start, endExclusive));
}

final class _SequenceIds implements IdGenerator {
  var _next = 0;

  @override
  String generateId() => 'integration-${_next++}';
}

final class _FixedClock implements AppClock {
  const _FixedClock(this.utcNow);

  @override
  final DateTime utcNow;

  @override
  Duration get monotonicElapsed => Duration.zero;
}
