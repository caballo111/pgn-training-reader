import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/database/app_database.dart'
    hide
        Cycle,
        PuzzleAttempt,
        TimingSegment,
        TrainingSession,
        TrainingSet,
        TrainingSetItem;
import 'package:pgntrainingreader/data/repositories/drift_training_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/training/cycle.dart';
import 'package:pgntrainingreader/domain/training/lifecycle_status.dart';
import 'package:pgntrainingreader/domain/training/progress_calculator.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/domain/training/puzzle_interaction_repository.dart';
import 'package:pgntrainingreader/domain/training/timing_segment.dart';
import 'package:pgntrainingreader/domain/training/training_session.dart';
import 'package:pgntrainingreader/domain/training/training_set.dart';
import 'package:pgntrainingreader/domain/training/training_set_item.dart';

void main() {
  late AppDatabase database;
  late DriftTrainingRepository repository;
  final startedAt = DateTime.utc(2026, 9, 28, 9);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftTrainingRepository(database);
    await database.customStatement('PRAGMA foreign_keys = ON');
    await _seed(database, repository, startedAt);
  });

  tearDown(() => database.close());

  test(
    'cycle keeps its ordered set snapshot after the set is edited',
    () async {
      final original = (await repository.getCycleSet('cycle'))!;
      await _addBlock(database, 'block-new', 3, ContentType.puzzle);
      final mutableSet = (await repository.getSet('set'))!;
      await repository.updateSet(
        TrainingSet(
          id: mutableSet.id,
          name: mutableSet.name,
          createdAt: mutableSet.createdAt,
          updatedAt: startedAt.add(const Duration(minutes: 1)),
          items: [
            _item('set', 'puzzle-b', 'block-b', 0, startedAt),
            _item('set', 'puzzle-a', 'block-a', 1, startedAt),
            _item('set', 'new-item', 'block-new', 2, startedAt),
          ],
        ),
      );

      final snapshot = (await repository.getCycleSet('cycle'))!;
      expect(
        snapshot.items.map((item) => item.id),
        original.items.map((item) => item.id),
      );
      expect(snapshot.items.map((item) => item.blockId), [
        'block-a',
        'block-text',
        'block-b',
      ]);
      expect((await repository.getSet('set'))!.items.map((item) => item.id), [
        'puzzle-b',
        'puzzle-a',
        'new-item',
      ]);
    },
  );

  test(
    'non-puzzle completion accepts an item removed after cycle creation',
    () async {
      final set = (await repository.getSet('set'))!;
      await repository.updateSet(
        TrainingSet(
          id: set.id,
          name: set.name,
          createdAt: set.createdAt,
          updatedAt: startedAt.add(const Duration(minutes: 1)),
          items: [
            _item('set', 'puzzle-a', 'block-a', 0, startedAt),
            _item('set', 'puzzle-b', 'block-b', 1, startedAt),
          ],
        ),
      );

      await repository.completeNonPuzzleItem(
        cycleId: 'cycle',
        trainingSetItemId: 'text-item',
        completedAt: startedAt.add(const Duration(minutes: 2)),
      );

      expect(await repository.completedNonPuzzleItemIds('cycle'), {
        'text-item',
      });
    },
  );

  test('cycle policy and cursor survive repository recreation', () async {
    final snapshots = repository as CycleSnapshotRepository;
    final reopenedRepository = DriftTrainingRepository(database);
    final reopenedSnapshots = reopenedRepository as CycleSnapshotRepository;
    await snapshots.setCyclePolicy('cycle', 'keyMoves');
    await snapshots.setCycleCursor('cycle', 'attempt-a');
    expect(await reopenedSnapshots.getCyclePolicy('cycle'), 'keyMoves');
    expect(await reopenedSnapshots.getCycleCursor('cycle'), 'attempt-a');
    await snapshots.setCycleCursor('cycle', null);
    expect(await snapshots.getCycleCursor('cycle'), isNull);
  });

  test(
    'interaction save rolls back with surrounding settings on SQLite error',
    () async {
      await database.customStatement('''
      CREATE TRIGGER reject_puzzle_interaction
      BEFORE INSERT ON app_settings
      WHEN NEW.key = 'puzzle:attempt-a'
      BEGIN
        SELECT RAISE(ABORT, 'injected interaction write failure');
      END
    ''');
      final interactions = repository as PuzzleInteractionRepository;

      await expectLater(
        repository.transaction(() async {
          await repository.setCyclePolicy('cycle', 'keyMoves');
          await interactions.savePuzzleInteraction('attempt-a', {
            'moves': ['e2e4'],
          });
        }),
        throwsA(anything),
      );

      expect(await repository.getCyclePolicy('cycle'), isNull);
      expect(await interactions.loadPuzzleInteraction('attempt-a'), isNull);
    },
  );

  test(
    'assisted attempt counts in report denominator and assisted count',
    () async {
      final active = PuzzleAttempt(
        id: 'assisted',
        blockId: 'block-a',
        cycleId: 'cycle',
        sessionId: 'session',
        startedAt: startedAt,
      );
      await repository.createAttempt(active);
      final segment = TimingSegment(
        id: 'assisted-segment',
        attemptId: active.id,
        sessionId: active.sessionId,
        startedAt: startedAt,
      );
      await repository.startTimingSegment(segment);
      await repository.finalizeAttempt(
        attempt: PuzzleAttempt(
          id: active.id,
          blockId: active.blockId,
          cycleId: active.cycleId,
          sessionId: active.sessionId,
          status: PuzzleAttemptStatus.finalized,
          startedAt: active.startedAt,
          completedAt: startedAt.add(const Duration(seconds: 20)),
          activeDuration: const Duration(seconds: 20),
          outcome: PuzzleAttemptOutcome.assisted,
          hintCount: 1,
        ),
        finalTimingSegment: TimingSegment(
          id: segment.id,
          attemptId: segment.attemptId,
          sessionId: segment.sessionId,
          startedAt: segment.startedAt,
          endedAt: startedAt.add(const Duration(seconds: 20)),
          activeDuration: const Duration(seconds: 20),
        ),
      );

      final report = ProgressCalculator.calculate(
        await repository.aggregateForCycle('cycle'),
      );
      expect(report.attemptedCount, 1);
      expect(report.assistedCount, 1);
      expect(report.accuracyPercent, 0);
    },
  );
}

TrainingSetItem _item(
  String setId,
  String itemId,
  String blockId,
  int position,
  DateTime addedAt, {
  ContentType type = ContentType.puzzle,
}) => TrainingSetItem(
  id: itemId,
  trainingSetId: setId,
  blockId: blockId,
  position: position,
  contentType: type,
  addedAt: addedAt,
);

Future<void> _addBlock(
  AppDatabase database,
  String id,
  int ordinal,
  ContentType type,
) async {
  await database
      .into(database.pgnBlocks)
      .insert(
        PgnBlocksCompanion.insert(
          id: id,
          sourceId: 'source',
          startOffset: ordinal * 10,
          endOffset: ordinal * 10 + 9,
          ordinal: ordinal,
          contentType: type.toDatabaseValue(),
          parseStatus: 'notParsed',
        ),
      );
}

Future<void> _seed(
  AppDatabase database,
  DriftTrainingRepository repository,
  DateTime at,
) async {
  await database
      .into(database.pgnSources)
      .insert(
        PgnSourcesCompanion.insert(
          id: 'source',
          displayName: 'Source',
          accessMode: 'managedCopy',
          scannerVersion: 1,
          importState: 'ready',
          createdAtMicros: 1,
          updatedAtMicros: 1,
        ),
      );
  await _addBlock(database, 'block-a', 0, ContentType.puzzle);
  await _addBlock(database, 'block-text', 1, ContentType.text);
  await _addBlock(database, 'block-b', 2, ContentType.puzzle);
  await repository.createSet(
    TrainingSet(
      id: 'set',
      name: 'Set',
      createdAt: at,
      updatedAt: at,
      items: [
        _item('set', 'puzzle-a', 'block-a', 0, at),
        _item('set', 'text-item', 'block-text', 1, at, type: ContentType.text),
        _item('set', 'puzzle-b', 'block-b', 2, at),
      ],
    ),
  );
  await repository.createCycle(
    Cycle(
      id: 'cycle',
      trainingSetId: 'set',
      status: CycleStatus.active,
      startedAt: at,
      createdAt: at,
    ),
  );
  await repository.createSession(
    TrainingSession(
      id: 'session',
      cycleId: 'cycle',
      status: TrainingSessionStatus.active,
      startedAt: at,
      studyDay: DateTime.utc(at.year, at.month, at.day),
    ),
  );
}
