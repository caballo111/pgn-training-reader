import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/database/app_database.dart'
    hide PgnSource;
import 'package:pgntrainingreader/core/errors/app_failure.dart';
import 'package:pgntrainingreader/data/repositories/drift_pgn_source_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/pgn_source.dart';
import 'package:pgntrainingreader/domain/library/pgn_source_repository.dart';

void main() {
  late AppDatabase database;
  late PgnSourceRepository repository;
  late Directory temporaryDirectory;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftPgnSourceRepository(database);
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'pgn-source-repository-test-',
    );
    await database.customStatement('PRAGMA foreign_keys = ON');
  });

  tearDown(() async {
    await database.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'round-trips managed metadata and lists sources deterministically',
    () async {
      final managedFile = File('${temporaryDirectory.path}/library.pgn');
      await managedFile.writeAsString('[Event "Example"]\n*\n');
      final source = _source(
        id: 'source-b',
        name: 'Bravo',
        managedPath: managedFile.path,
        sizeBytes: await managedFile.length(),
        modifiedAt: DateTime.utc(2026, 9, 1),
        fingerprint: 'fingerprint-b',
      );
      final alphabetic = _source(
        id: 'source-a',
        name: 'Alpha',
        externalReference: 'opaque-document-token',
      );
      await repository.create(source);
      await repository.create(alphabetic);

      expect(await repository.getById(source.id), source);
      expect(
        (await repository.getById(source.id))?.managedPath,
        managedFile.path,
      );
      expect((await repository.list()).map((item) => item.id), <String>[
        'source-a',
        'source-b',
      ]);
      expect(await repository.getById('missing'), isNull);
      await expectLater(
        repository.create(source),
        throwsA(isA<DatabaseFailure>()),
      );
    },
  );

  test(
    'updates import checkpoint and establishes initial revision metadata',
    () async {
      final original = _source(
        id: 'source',
        importState: 'copying',
        safeCheckpoint: 0,
      );
      await repository.create(original);

      final updated = _replace(
        original,
        fingerprint: 'first-known-fingerprint',
        sizeBytes: 2048,
        modifiedAt: DateTime.utc(2026, 9, 20),
        importState: 'indexing',
        safeCheckpoint: 1800,
        updatedAt: DateTime.utc(2026, 9, 21),
      );
      await repository.update(updated);

      final stored = (await repository.getById(original.id))!;
      expect(stored.fingerprint, 'first-known-fingerprint');
      expect(stored.sizeBytes, 2048);
      expect(stored.modifiedAt, DateTime.utc(2026, 9, 20));
      expect(stored.importState, 'indexing');
      expect(stored.safeCheckpoint, 1800);
      expect(stored.createdAt, original.createdAt);
      expect(stored.updatedAt, updated.updatedAt);
    },
  );

  test('updates an external relink without changing source identity', () async {
    final original = _source(
      id: 'source',
      externalReference: 'provider:old-document',
      fingerprint: 'same-content',
      sizeBytes: 900,
      modifiedAt: DateTime.utc(2026, 9, 10),
      importState: 'ready',
      safeCheckpoint: 900,
    );
    await repository.create(original);

    await repository.update(
      _replace(original, externalReference: 'provider:relinked-document'),
    );

    final stored = (await repository.getById(original.id))!;
    expect(stored.externalReference, 'provider:relinked-document');
    expect(stored.importState, 'ready');
    expect(stored.safeCheckpoint, 900);
    expect(stored.createdAt, original.createdAt);
  });

  test('rejects update for an unregistered source', () async {
    await expectLater(
      repository.update(_source(id: 'missing')),
      throwsA(isA<DatabaseFailure>()),
    );
  });

  test(
    'revision changes reset import state but preserve indexed history',
    () async {
      final revisionCases = <String, PgnSource Function(PgnSource)>{
        'fingerprint': (source) => _replace(source, fingerprint: 'changed'),
        'size': (source) => _replace(source, sizeBytes: 101),
        'modified time': (source) =>
            _replace(source, modifiedAt: DateTime.utc(2026, 10, 1)),
        'scanner version': (source) => _replace(source, scannerVersion: 2),
      };

      for (final entry in revisionCases.entries) {
        final source = _source(
          id: 'source-${entry.key}',
          fingerprint: 'original',
          sizeBytes: 100,
          modifiedAt: DateTime.utc(2026, 9, 1),
          importState: 'ready',
          safeCheckpoint: 1000,
        );
        await repository.create(source);
        await _seedIndexedHistory(database, suffix: entry.key, source: source);

        final changed = _replace(
          entry.value(source),
          importState: 'indexing',
          safeCheckpoint: 1000,
        );
        await repository.update(changed);

        final stored = (await repository.getById(source.id))!;
        expect(stored.importState, 'sourceChanged', reason: entry.key);
        expect(stored.safeCheckpoint, 0, reason: entry.key);
        expect(stored.createdAt, source.createdAt, reason: entry.key);
        expect(
          await (database.select(
            database.pgnBlocks,
          )..where((row) => row.sourceId.equals(source.id))).getSingle(),
          isNotNull,
          reason: 'the indexed block survives ${entry.key} change',
        );
        expect(
          await (database.select(database.trainingSetItems)
                ..where((row) => row.id.equals('item-${entry.key}')))
              .getSingleOrNull(),
          isNotNull,
          reason: 'set membership survives ${entry.key} change',
        );
        expect(
          await (database.select(database.puzzleAttempts)
                ..where((row) => row.id.equals('attempt-${entry.key}')))
              .getSingleOrNull(),
          isNotNull,
          reason: 'attempt history survives ${entry.key} change',
        );

        // Completing the re-index with the same new revision must not be
        // mistaken for another source change.
        await repository.update(
          _replace(
            stored,
            importState: 'ready',
            safeCheckpoint: 100,
            updatedAt: DateTime.utc(2026, 10, 2),
          ),
        );
        final reindexed = (await repository.getById(source.id))!;
        expect(reindexed.importState, 'ready', reason: entry.key);
        expect(reindexed.safeCheckpoint, 100, reason: entry.key);
      }
    },
  );

  test('missing source status preserves index and training history', () async {
    final source = _source(
      id: 'missing-source',
      managedPath: '0123456789abcdef0123456789abcdef',
      fingerprint: 'known-fingerprint',
      sizeBytes: 100,
      modifiedAt: DateTime.utc(2026, 9, 1),
      importState: 'ready',
      safeCheckpoint: 100,
    );
    await repository.create(source);
    await _seedIndexedHistory(database, suffix: 'missing', source: source);

    await repository.update(
      _replace(
        source,
        importState: 'sourceMissing',
        updatedAt: DateTime.utc(2026, 9, 3),
      ),
    );

    final stored = (await repository.getById(source.id))!;
    expect(stored.importState, 'sourceMissing');
    expect(stored.safeCheckpoint, 100);
    expect(
      await (database.select(
        database.pgnBlocks,
      )..where((row) => row.id.equals('block-missing'))).getSingleOrNull(),
      isNotNull,
    );
    expect(
      await (database.select(
        database.trainingSetItems,
      )..where((row) => row.id.equals('item-missing'))).getSingleOrNull(),
      isNotNull,
    );
    expect(
      await (database.select(
        database.puzzleAttempts,
      )..where((row) => row.id.equals('attempt-missing'))).getSingleOrNull(),
      isNotNull,
    );

    final relinked = _replace(
      stored,
      managedPath: 'fedcba9876543210fedcba9876543210',
      modifiedAt: DateTime.utc(2026, 9, 4),
      fingerprint: 'relinked-fingerprint',
      importState: 'indexed',
      updatedAt: DateTime.utc(2026, 9, 4),
    );
    await repository.updateAfterVerifiedRelink(
      source: relinked,
      expectedFingerprint: stored.fingerprint!,
    );
    final restored = (await repository.getById(source.id))!;
    expect(restored.importState, 'indexed');
    expect(restored.managedPath, relinked.managedPath);
    expect(restored.fingerprint, 'relinked-fingerprint');
    expect(restored.safeCheckpoint, source.safeCheckpoint);
    expect(
      await (database.select(
        database.puzzleAttempts,
      )..where((row) => row.id.equals('attempt-missing'))).getSingleOrNull(),
      isNotNull,
    );
  });
}

PgnSource _source({
  required String id,
  String? name,
  String? managedPath,
  String? externalReference,
  int? sizeBytes,
  DateTime? modifiedAt,
  String? fingerprint,
  int scannerVersion = 1,
  String importState = 'queued',
  int safeCheckpoint = 0,
}) => PgnSource(
  id: id,
  displayName: name ?? id,
  accessMode: managedPath == null
      ? PgnSourceAccessMode.externalReference
      : PgnSourceAccessMode.managedCopy,
  managedPath: managedPath,
  externalReference: managedPath == null
      ? (externalReference ?? 'opaque:$id')
      : null,
  sizeBytes: sizeBytes,
  modifiedAt: modifiedAt,
  fingerprint: fingerprint,
  scannerVersion: scannerVersion,
  importState: importState,
  safeCheckpoint: safeCheckpoint,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 2),
);

PgnSource _replace(
  PgnSource source, {
  String? displayName,
  String? managedPath,
  String? externalReference,
  int? sizeBytes,
  DateTime? modifiedAt,
  String? fingerprint,
  int? scannerVersion,
  String? importState,
  int? safeCheckpoint,
  DateTime? updatedAt,
}) => PgnSource(
  id: source.id,
  displayName: displayName ?? source.displayName,
  accessMode: source.accessMode,
  managedPath: managedPath ?? source.managedPath,
  externalReference: externalReference ?? source.externalReference,
  sizeBytes: sizeBytes ?? source.sizeBytes,
  modifiedAt: modifiedAt ?? source.modifiedAt,
  fingerprint: fingerprint ?? source.fingerprint,
  scannerVersion: scannerVersion ?? source.scannerVersion,
  importState: importState ?? source.importState,
  safeCheckpoint: safeCheckpoint ?? source.safeCheckpoint,
  createdAt: source.createdAt,
  updatedAt: updatedAt ?? source.updatedAt,
);

Future<void> _seedIndexedHistory(
  AppDatabase database, {
  required String suffix,
  required PgnSource source,
}) async {
  await database
      .into(database.pgnBlocks)
      .insert(
        PgnBlocksCompanion.insert(
          id: 'block-$suffix',
          sourceId: source.id,
          startOffset: 0,
          endOffset: 100,
          ordinal: 0,
          contentType: 'Puzzle',
          parseStatus: 'ok',
        ),
      );
  await database
      .into(database.trainingSets)
      .insert(
        TrainingSetsCompanion.insert(
          id: 'set-$suffix',
          name: 'Training set',
          createdAtMicros: 1,
          updatedAtMicros: 1,
        ),
      );
  await database
      .into(database.trainingSetItems)
      .insert(
        TrainingSetItemsCompanion.insert(
          id: 'item-$suffix',
          trainingSetId: 'set-$suffix',
          blockId: 'block-$suffix',
          position: 0,
          contentType: 'Puzzle',
          addedAtMicros: 1,
        ),
      );
  await database
      .into(database.cycles)
      .insert(
        CyclesCompanion.insert(
          id: 'cycle-$suffix',
          trainingSetId: 'set-$suffix',
          status: 'completed',
          createdAtMicros: 1,
        ),
      );
  await database
      .into(database.trainingSessions)
      .insert(
        TrainingSessionsCompanion.insert(
          id: 'session-$suffix',
          cycleId: 'cycle-$suffix',
          status: 'closed',
          startedAtMicros: 1,
          endedAtMicros: const Value(2),
          studyDayMicros: 1,
        ),
      );
  await database
      .into(database.puzzleAttempts)
      .insert(
        PuzzleAttemptsCompanion.insert(
          id: 'attempt-$suffix',
          blockId: 'block-$suffix',
          cycleId: 'cycle-$suffix',
          sessionId: 'session-$suffix',
          status: 'finalized',
          outcome: const Value('passed'),
          startedAtMicros: 1,
          completedAtMicros: const Value(2),
        ),
      );
}
