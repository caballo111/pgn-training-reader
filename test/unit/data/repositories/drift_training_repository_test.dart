import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/errors/app_failure.dart';
import 'package:pgntrainingreader/data/database/app_database.dart'
    hide
        Cycle,
        PuzzleAttempt,
        TimingSegment,
        TrainingSession,
        TrainingSet,
        TrainingSetItem;
import 'package:pgntrainingreader/data/repositories/drift_training_repository.dart';
import 'package:pgntrainingreader/data/repositories/drift_training_set_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/training/cycle.dart';
import 'package:pgntrainingreader/domain/training/lifecycle_status.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
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
    'finalizing an attempt rolls back if its segment cannot be closed',
    () async {
      final active = _activeAttempt(startedAt);
      await repository.createAttempt(active);
      final openSegment = _openSegment(active, startedAt);
      await repository.startTimingSegment(openSegment);
      await database.customStatement('''
      CREATE TRIGGER reject_segment_close
      BEFORE UPDATE ON timing_segments
      BEGIN
        SELECT RAISE(ABORT, 'injected segment write failure');
      END
    ''');

      await expectLater(
        repository.finalizeAttempt(
          attempt: _passed(active, startedAt, const Duration(minutes: 1)),
          finalTimingSegment: _closedSegment(
            openSegment,
            startedAt.add(const Duration(minutes: 1)),
            const Duration(minutes: 1),
          ),
        ),
        throwsA(isA<DatabaseFailure>()),
      );

      expect(await repository.getAttempt(active.id), active);
      expect(await repository.listTimingSegments(active.id), <TimingSegment>[
        openSegment,
      ]);
    },
  );

  test(
    'finalized attempts cannot be changed through unfinished updates',
    () async {
      final active = _activeAttempt(startedAt);
      await repository.createAttempt(active);
      final openSegment = _openSegment(active, startedAt);
      await repository.startTimingSegment(openSegment);
      final finishedAt = startedAt.add(const Duration(minutes: 1));
      final passed = _passed(active, finishedAt, const Duration(minutes: 1));
      await repository.finalizeAttempt(
        attempt: passed,
        finalTimingSegment: _closedSegment(
          openSegment,
          finishedAt,
          const Duration(minutes: 1),
        ),
      );

      final replacement = PuzzleAttempt(
        id: active.id,
        blockId: active.blockId,
        cycleId: active.cycleId,
        sessionId: active.sessionId,
        status: PuzzleAttemptStatus.finalized,
        startedAt: active.startedAt,
        completedAt: finishedAt,
        activeDuration: const Duration(minutes: 1),
        outcome: PuzzleAttemptOutcome.wrongMove,
        failureReason: PuzzleAttemptFailureReason.incorrectMove,
      );
      await expectLater(
        repository.updateUnfinishedAttempt(replacement),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await repository.getAttempt(active.id), passed);
    },
  );

  test(
    'an active attempt cannot be finalized through unfinished update',
    () async {
      final active = _activeAttempt(startedAt);
      await repository.createAttempt(active);
      await repository.startTimingSegment(_openSegment(active, startedAt));

      await expectLater(
        repository.updateUnfinishedAttempt(
          _passed(
            active,
            startedAt.add(const Duration(minutes: 1)),
            const Duration(minutes: 1),
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await repository.getAttempt(active.id), active);
      final segments = await repository.listTimingSegments(active.id);
      expect(segments, hasLength(1));
      expect(segments.single.endedAt, isNull);
    },
  );

  test('an active attempt cannot have two open timing segments', () async {
    final active = _activeAttempt(startedAt);
    await repository.createAttempt(active);
    await repository.startTimingSegment(_openSegment(active, startedAt));

    await expectLater(
      repository.startTimingSegment(
        TimingSegment(
          id: 'second-segment',
          attemptId: active.id,
          sessionId: active.sessionId,
          startedAt: startedAt.add(const Duration(seconds: 1)),
        ),
      ),
      throwsA(isA<ValidationFailure>()),
    );
    expect(await repository.listTimingSegments(active.id), hasLength(1));
  });

  test('closing a segment must add exactly its active duration', () async {
    final active = _activeAttempt(startedAt);
    await repository.createAttempt(active);
    final segment = _openSegment(active, startedAt);
    await repository.startTimingSegment(segment);
    final mismatched = PuzzleAttempt(
      id: active.id,
      blockId: active.blockId,
      cycleId: active.cycleId,
      sessionId: active.sessionId,
      status: PuzzleAttemptStatus.paused,
      startedAt: active.startedAt,
      activeDuration: const Duration(seconds: 30),
    );

    await expectLater(
      repository.closeTimingSegment(
        segment: _closedSegment(
          segment,
          startedAt.add(const Duration(minutes: 1)),
          const Duration(minutes: 1),
        ),
        updatedAttempt: mismatched,
      ),
      throwsA(isA<ValidationFailure>()),
    );
    expect(await repository.getAttempt(active.id), active);
    expect(
      (await repository.listTimingSegments(active.id)).single.endedAt,
      isNull,
    );
  });

  test(
    'finalized attempt and final segment must have matching duration',
    () async {
      final active = _activeAttempt(startedAt);
      await repository.createAttempt(active);
      final segment = _openSegment(active, startedAt);
      await repository.startTimingSegment(segment);
      final completedAt = startedAt.add(const Duration(minutes: 1));

      await expectLater(
        repository.finalizeAttempt(
          attempt: _passed(active, completedAt, const Duration(minutes: 1)),
          finalTimingSegment: _closedSegment(
            segment,
            completedAt,
            const Duration(seconds: 30),
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await repository.getAttempt(active.id), active);
      expect(
        (await repository.listTimingSegments(active.id)).single.endedAt,
        isNull,
      );
    },
  );

  test(
    'finalizing a paused attempt cannot add unmeasured active time',
    () async {
      final active = _activeAttempt(startedAt);
      await repository.createAttempt(active);
      final paused = PuzzleAttempt(
        id: active.id,
        blockId: active.blockId,
        cycleId: active.cycleId,
        sessionId: active.sessionId,
        status: PuzzleAttemptStatus.paused,
        startedAt: active.startedAt,
        activeDuration: const Duration(minutes: 2),
      );
      await repository.updateUnfinishedAttempt(paused);
      final finalized = PuzzleAttempt(
        id: active.id,
        blockId: active.blockId,
        cycleId: active.cycleId,
        sessionId: active.sessionId,
        status: PuzzleAttemptStatus.finalized,
        startedAt: active.startedAt,
        completedAt: startedAt.add(const Duration(minutes: 3)),
        activeDuration: const Duration(minutes: 3),
        outcome: PuzzleAttemptOutcome.passed,
      );

      await expectLater(
        repository.finalizeAttempt(attempt: finalized),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await repository.getAttempt(active.id), paused);
    },
  );

  test('updateSet can reorder items across occupied positions', () async {
    await database
        .into(database.pgnBlocks)
        .insert(
          PgnBlocksCompanion.insert(
            id: 'block-b',
            sourceId: 'source',
            startOffset: 11,
            endOffset: 20,
            ordinal: 1,
            contentType: ContentType.puzzle.toDatabaseValue(),
            parseStatus: 'notParsed',
          ),
        );
    await DriftTrainingSetRepository(database).createSet(
      TrainingSet(
        id: 'set-order',
        name: 'Order',
        items: <TrainingSetItem>[
          _item('set-order', 'item-a', 'block', 0, startedAt),
          _item('set-order', 'item-b', 'block-b', 1, startedAt),
        ],
        createdAt: startedAt,
        updatedAt: startedAt,
      ),
    );
    final old = (await repository.getSet('set-order'))!;
    await repository.updateSet(
      TrainingSet(
        id: old.id,
        name: old.name,
        createdAt: old.createdAt,
        updatedAt: startedAt.add(const Duration(minutes: 1)),
        items: <TrainingSetItem>[
          _item('set-order', 'item-b', 'block-b', 0, startedAt),
          _item('set-order', 'item-a', 'block', 1, startedAt),
        ],
      ),
    );

    expect(
      (await repository.getSet('set-order'))!.items.map((item) => item.id),
      <String>['item-b', 'item-a'],
    );
  });

  test(
    'repeating non-puzzle completion retains original completion time',
    () async {
      await database
          .into(database.pgnBlocks)
          .insert(
            PgnBlocksCompanion.insert(
              id: 'instruction-block',
              sourceId: 'source',
              startOffset: 11,
              endOffset: 20,
              ordinal: 1,
              contentType: ContentType.instruction.toDatabaseValue(),
              parseStatus: 'notParsed',
            ),
          );
      await database
          .into(database.trainingSetItems)
          .insert(
            TrainingSetItemsCompanion.insert(
              id: 'instruction-item',
              trainingSetId: 'set',
              blockId: 'instruction-block',
              position: 1,
              contentType: ContentType.instruction.toDatabaseValue(),
              addedAtMicros: startedAt.microsecondsSinceEpoch,
            ),
          );
      final firstCompletion = startedAt.add(const Duration(minutes: 1));
      await repository.completeNonPuzzleItem(
        cycleId: 'cycle',
        trainingSetItemId: 'instruction-item',
        completedAt: firstCompletion,
      );
      await repository.completeNonPuzzleItem(
        cycleId: 'cycle',
        trainingSetItemId: 'instruction-item',
        completedAt: startedAt.add(const Duration(hours: 1)),
      );

      final row =
          await (database.select(database.cycleItemCompletions)..where(
                (completion) =>
                    completion.trainingSetItemId.equals('instruction-item'),
              ))
              .getSingle();
      expect(row.completedAtMicros, firstCompletion.microsecondsSinceEpoch);
    },
  );
}

TrainingSetItem _item(
  String setId,
  String itemId,
  String blockId,
  int position,
  DateTime addedAt,
) => TrainingSetItem(
  id: itemId,
  trainingSetId: setId,
  blockId: blockId,
  position: position,
  contentType: ContentType.puzzle,
  addedAt: addedAt,
);

Future<void> _seed(
  AppDatabase database,
  DriftTrainingRepository repository,
  DateTime startedAt,
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
  await database
      .into(database.pgnBlocks)
      .insert(
        PgnBlocksCompanion.insert(
          id: 'block',
          sourceId: 'source',
          startOffset: 0,
          endOffset: 10,
          ordinal: 0,
          contentType: ContentType.puzzle.toDatabaseValue(),
          parseStatus: 'notParsed',
        ),
      );
  await DriftTrainingSetRepository(database).createSet(
    TrainingSet(
      id: 'set',
      name: 'Set',
      items: <TrainingSetItem>[
        TrainingSetItem(
          id: 'item',
          trainingSetId: 'set',
          blockId: 'block',
          position: 0,
          contentType: ContentType.puzzle,
          addedAt: startedAt,
        ),
      ],
      createdAt: startedAt,
      updatedAt: startedAt,
    ),
  );
  await repository.createCycle(
    Cycle(
      id: 'cycle',
      trainingSetId: 'set',
      status: CycleStatus.active,
      startedAt: startedAt,
      createdAt: startedAt,
    ),
  );
  await repository.createSession(
    TrainingSession(
      id: 'session',
      cycleId: 'cycle',
      status: TrainingSessionStatus.active,
      startedAt: startedAt,
      studyDay: DateTime.utc(startedAt.year, startedAt.month, startedAt.day),
    ),
  );
}

PuzzleAttempt _activeAttempt(DateTime startedAt) => PuzzleAttempt(
  id: 'attempt',
  blockId: 'block',
  cycleId: 'cycle',
  sessionId: 'session',
  startedAt: startedAt,
);

PuzzleAttempt _passed(
  PuzzleAttempt active,
  DateTime completedAt,
  Duration duration,
) => PuzzleAttempt(
  id: active.id,
  blockId: active.blockId,
  cycleId: active.cycleId,
  sessionId: active.sessionId,
  status: PuzzleAttemptStatus.finalized,
  startedAt: active.startedAt,
  completedAt: completedAt,
  activeDuration: duration,
  outcome: PuzzleAttemptOutcome.passed,
);

TimingSegment _openSegment(PuzzleAttempt attempt, DateTime startedAt) =>
    TimingSegment(
      id: 'segment',
      attemptId: attempt.id,
      sessionId: attempt.sessionId,
      startedAt: startedAt,
    );

TimingSegment _closedSegment(
  TimingSegment segment,
  DateTime endedAt,
  Duration duration,
) => TimingSegment(
  id: segment.id,
  attemptId: segment.attemptId,
  sessionId: segment.sessionId,
  startedAt: segment.startedAt,
  endedAt: endedAt,
  activeDuration: duration,
);
