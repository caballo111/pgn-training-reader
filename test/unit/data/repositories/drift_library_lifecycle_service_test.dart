import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/errors/app_failure.dart';
import 'package:pgntrainingreader/core/time/app_clock.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/data/database/app_database.dart'
    hide PgnSource, TrainingSetItem;
import 'package:pgntrainingreader/data/file_access/file_source_picker.dart';
import 'package:pgntrainingreader/data/file_access/managed_file_source.dart';
import 'package:pgntrainingreader/data/pgn/pgn_indexer.dart';
import 'package:pgntrainingreader/data/repositories/drift_chess_content_repository.dart';
import 'package:pgntrainingreader/data/repositories/drift_library_lifecycle_service.dart';
import 'package:pgntrainingreader/data/repositories/drift_pgn_index_repository.dart';
import 'package:pgntrainingreader/data/repositories/drift_pgn_source_repository.dart';
import 'package:pgntrainingreader/data/repositories/drift_training_set_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/pgn_source.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/library/library_lifecycle_service.dart';
import 'package:pgntrainingreader/domain/library/pgn_import_service.dart';
import 'package:pgntrainingreader/domain/training/training_set_item.dart';

void main() {
  const token = '0123456789abcdef0123456789abcdef';
  late AppDatabase database;
  late Directory documents;
  late DriftPgnSourceRepository sources;
  late DriftLibraryLifecycleService lifecycle;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.customStatement('PRAGMA foreign_keys = ON');
    documents = await Directory.systemTemp.createTemp('library-lifecycle-');
    sources = DriftPgnSourceRepository(database);
    lifecycle = DriftLibraryLifecycleService(
      database: database,
      sourceRepository: sources,
      managedFileSource: ManagedFileSource(
        pickedSources: _PickedAccess(),
        directoryProvider: () async => documents,
      ),
      now: () => DateTime.utc(2026, 10, 2),
    );
    await database
        .into(database.pgnSources)
        .insert(
          PgnSourcesCompanion.insert(
            id: 'source-1',
            displayName: 'Opening book',
            accessMode: 'ManagedCopy',
            managedPath: const Value(token),
            scannerVersion: 1,
            importState: 'indexed',
            createdAtMicros: 1,
            updatedAtMicros: 1,
          ),
        );
    await _seedHistory(database);
  });

  tearDown(() async {
    await database.close();
    await documents.delete(recursive: true);
  });

  test(
    'removal deletes managed copy and retains every historical identity',
    () async {
      final managed = Directory('${documents.path}/managed_pgn_sources');
      await managed.create();
      final copy = File('${managed.path}/$token.pgn');
      await copy.writeAsString('[Event "source"]');

      final result = await lifecycle.removeBook('source-1');

      expect(result.status, LibraryRemovalStatus.removed);
      expect(await copy.exists(), isFalse);
      expect(await sources.list(), isEmpty);
      expect((await sources.getById('source-1'))!.importState, 'deleted');
      expect(
        (await database.select(database.pgnBlocks).get()).single.id,
        'block-1',
      );
      expect(
        (await database.select(database.importJobs).get()).single.id,
        'job-1',
      );
      expect(
        (await database.select(database.importDiagnostics).get()).single.id,
        'diagnostic-1',
      );
      expect(
        (await database.select(database.trainingSetItems).get()).single.blockId,
        'block-1',
      );
      expect(
        (await database.select(database.cycles).get()).single.id,
        'cycle-1',
      );
      expect(
        (await database.select(database.trainingSessions).get()).single.id,
        'session-1',
      );
      final attempt =
          (await database.select(database.puzzleAttempts).get()).single;
      expect(attempt.blockId, 'block-1');
      expect(attempt.outcome, 'passed');
      expect(attempt.completedAtMicros, 2);
      expect(
        (await database
                .customSelect(
                  "SELECT value FROM app_settings WHERE key = 'cycle-set:cycle-1'",
                )
                .getSingle())
            .read<String>('value'),
        '{"id":"set-1","items":[{"blockId":"block-1","position":0}]}',
      );
    },
  );

  test('active import blocks removal and repeated deletion is safe', () async {
    await database
        .into(database.importJobs)
        .insert(
          ImportJobsCompanion.insert(
            id: 'active-job',
            sourceId: 'source-1',
            status: 'indexing',
            startedAtMicros: 1,
          ),
        );
    await expectLater(
      sources.remove(id: 'source-1', removedAt: DateTime.utc(2026)),
      throwsA(isA<DatabaseFailure>()),
    );
    expect((await sources.getById('source-1'))!.importState, 'indexed');
    await (database.update(database.importJobs)
          ..where((job) => job.id.equals('active-job')))
        .write(const ImportJobsCompanion(status: Value('completed')));

    await sources.remove(id: 'source-1', removedAt: DateTime.utc(2026));
    await sources.remove(id: 'source-1', removedAt: DateTime.utc(2026, 10, 1));
    expect((await sources.getById('source-1'))!.importState, 'deleted');
    final index = DriftPgnIndexRepository(database);
    expect((await index.search(limit: 10)).items, isEmpty);
    expect(await index.countForSource('source-1'), 0);
    final block = await index.getById('block-1');
    expect(block, isNotNull, reason: 'historical identity remains resolvable');
    expect(await index.getNextInSource(block!), isNull);
    expect(await index.getPreviousInSource(block), isNull);
    final content = DriftChessContentRepository(
      indexRepository: index,
      sourceRepository: sources,
      fileSource: ManagedFileSource(
        pickedSources: _PickedAccess(),
        directoryProvider: () async => documents,
      ),
    );
    await expectLater(
      content.getById('block-1'),
      throwsA(
        isA<FileFailure>().having(
          (failure) => failure.code,
          'code',
          'source_deleted',
        ),
      ),
    );
    expect(await sources.list(), isEmpty);
  });

  test('cleanup failure remains pending and can be retried', () async {
    await database
        .into(database.pgnSources)
        .insert(
          PgnSourcesCompanion.insert(
            id: 'bad-source',
            displayName: 'Invalid token',
            accessMode: 'ManagedCopy',
            managedPath: const Value('../outside.pgn'),
            scannerVersion: 1,
            importState: 'indexed',
            createdAtMicros: 1,
            updatedAtMicros: 1,
          ),
        );

    final result = await lifecycle.removeBook('bad-source');

    expect(result.status, LibraryRemovalStatus.cleanupFailed);
    expect((await sources.getById('bad-source'))!.importState, 'deleted');
    expect(await lifecycle.pendingCleanupSourceIds(), ['bad-source']);
    final otherResult = await lifecycle.retryCleanup('bad-source');
    expect(otherResult.status, LibraryRemovalStatus.cleanupFailed);
  });

  test(
    'external references are retained and managed-root redirects are blocked',
    () async {
      final externalFile = File('${documents.path}/original.pgn');
      await externalFile.writeAsString('external bytes');
      await database
          .into(database.pgnSources)
          .insert(
            PgnSourcesCompanion.insert(
              id: 'external-source',
              displayName: 'External book',
              accessMode: 'ExternalReference',
              externalReference: const Value('content://provider/document/1'),
              scannerVersion: 1,
              importState: 'indexed',
              createdAtMicros: 1,
              updatedAtMicros: 1,
            ),
          );
      final externalResult = await lifecycle.removeBook('external-source');
      expect(externalResult.status, LibraryRemovalStatus.removed);
      expect(await externalFile.readAsString(), 'external bytes');

      final redirectedDocuments = await Directory.systemTemp.createTemp(
        'library-managed-redirect-',
      );
      addTearDown(() => redirectedDocuments.delete(recursive: true));
      final outside = Directory('${redirectedDocuments.path}/outside')
        ..createSync();
      final redirectedRoot = '${documents.path}/managed_pgn_sources';
      await Link(redirectedRoot).create(outside.path);
      final protected = File('${outside.path}/$token.pgn');
      await protected.writeAsString('protected bytes');

      final redirectedResult = await lifecycle.removeBook('source-1');
      expect(redirectedResult.status, LibraryRemovalStatus.cleanupFailed);
      expect(await protected.readAsString(), 'protected bytes');
      expect(await lifecycle.pendingCleanupSourceIds(), ['source-1']);
    },
  );

  test('source metadata cannot be updated after removal', () async {
    await sources.remove(id: 'source-1', removedAt: DateTime.utc(2026));
    final source = (await sources.getById('source-1'))!;
    final updated = PgnSource(
      id: source.id,
      displayName: source.displayName,
      accessMode: source.accessMode,
      managedPath: source.managedPath,
      fingerprint: source.fingerprint,
      scannerVersion: source.scannerVersion,
      importState: 'indexed',
      createdAt: source.createdAt,
      updatedAt: DateTime.utc(2026),
    );
    await expectLater(sources.update(updated), throwsA(isA<DatabaseFailure>()));
  });

  test('removed block cannot be selected into a new training set', () async {
    await sources.remove(id: 'source-1', removedAt: DateTime.utc(2026));
    final setRepository = DriftTrainingSetRepository(database);
    await expectLater(
      setRepository.addItem(
        TrainingSetItem(
          id: 'new-item',
          trainingSetId: 'set-1',
          blockId: 'block-1',
          position: 1,
          contentType: ContentType.puzzle,
          addedAt: DateTime.utc(2026),
        ),
      ),
      throwsA(isA<ValidationFailure>()),
    );
    expect(
      (await database.select(database.trainingSetItems).get()),
      hasLength(1),
    );
  });

  test('deleted source cannot start, resume, or reindex', () async {
    await database
        .into(database.importJobs)
        .insert(
          ImportJobsCompanion.insert(
            id: 'cancelled-job',
            sourceId: 'source-1',
            status: 'cancelled',
            startedAtMicros: 1,
            finishedAtMicros: const Value(2),
          ),
        );
    await sources.remove(id: 'source-1', removedAt: DateTime.utc(2026));
    final service = DriftPgnImportService(
      database: database,
      fileSource: ManagedFileSource(
        pickedSources: _PickedAccess(),
        directoryProvider: () async => documents,
      ),
      idGenerator: _Ids(),
      clock: _Clock(),
    );

    final start = await service
        .start(PgnImportRequest(sourceId: 'source-1'))
        .result;
    final resume = await service.resume('cancelled-job').result;
    final reindex = await service.reindex('source-1').result;

    expect(start.phase, PgnImportPhase.failed);
    expect(resume.phase, PgnImportPhase.failed);
    expect(reindex.phase, PgnImportPhase.failed);
    expect((await sources.getById('source-1'))!.importState, 'deleted');
    expect(
      (await (database.select(
        database.importJobs,
      )..where((job) => job.id.equals('cancelled-job'))).getSingle()).status,
      'cancelled',
    );
    expect(await database.select(database.pgnBlocks).get(), hasLength(1));
  });
}

Future<void> _seedHistory(AppDatabase database) async {
  await database.customStatement('''
    INSERT INTO pgn_blocks
      (id, source_id, start_offset, end_offset, ordinal, content_type, parse_status)
    VALUES ('block-1', 'source-1', 0, 10, 0, 'Puzzle', 'Valid')
  ''');
  await database.customStatement('''
    INSERT INTO import_jobs (id, source_id, status, started_at_micros)
    VALUES ('job-1', 'source-1', 'completed', 1)
  ''');
  await database.customStatement('''
    INSERT INTO import_diagnostics
      (id, import_job_id, severity, diagnostic_code, sanitized_message, created_at_micros)
    VALUES ('diagnostic-1', 'job-1', 'warning', 'other', 'retained', 1)
  ''');
  await database.customStatement('''
    INSERT INTO training_sets (id, name, created_at_micros, updated_at_micros)
    VALUES ('set-1', 'Set', 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO training_set_items
      (id, training_set_id, block_id, position, content_type, added_at_micros)
    VALUES ('item-1', 'set-1', 'block-1', 0, 'Puzzle', 1)
  ''');
  await database.customStatement('''
    INSERT INTO cycles (id, training_set_id, status, started_at_micros, completed_at_micros, created_at_micros)
    VALUES ('cycle-1', 'set-1', 'completed', 1, 2, 1)
  ''');
  await database.customStatement('''
    INSERT INTO training_sessions (id, cycle_id, status, started_at_micros, ended_at_micros, study_day_micros)
    VALUES ('session-1', 'cycle-1', 'closed', 1, 2, 1)
  ''');
  await database.customStatement('''
    INSERT INTO puzzle_attempts
      (id, block_id, cycle_id, session_id, status, outcome, started_at_micros, completed_at_micros)
    VALUES ('attempt-1', 'block-1', 'cycle-1', 'session-1', 'finalized', 'passed', 1, 2)
  ''');
  await database.customStatement('''
    INSERT INTO app_settings (key, value)
    VALUES ('cycle-set:cycle-1', '{"id":"set-1","items":[{"blockId":"block-1","position":0}]}')
  ''');
}

final class _PickedAccess implements PickedSourceAccess {
  @override
  Future<int?> length(OpaqueSourceReference reference) async => 0;

  @override
  Stream<List<int>> openReadStream(OpaqueSourceReference reference) =>
      const Stream.empty();

  @override
  Future<Uint8List> readRange(
    OpaqueSourceReference reference, {
    required int start,
    required int endExclusive,
  }) async => Uint8List(0);

  @override
  Future<DateTime?> modifiedAt(OpaqueSourceReference reference) async => null;
}

final class _Ids implements IdGenerator {
  var _next = 0;
  @override
  String generateId() => 'generated-${_next++}';
}

final class _Clock implements AppClock {
  @override
  DateTime get utcNow => DateTime.utc(2026, 10, 2);

  @override
  Duration get monotonicElapsed => Duration.zero;
}
