import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/time/app_clock.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/data/database/app_database.dart'
    hide TrainingSet, TrainingSetItem;
import 'package:pgntrainingreader/data/repositories/drift_training_repository.dart';
import 'package:pgntrainingreader/data/repositories/drift_training_set_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/domain/training/training_session_service_impl.dart';
import 'package:pgntrainingreader/domain/training/training_set.dart';
import 'package:pgntrainingreader/domain/training/training_set_item.dart';
import 'package:pgntrainingreader/domain/training/training_session_service.dart';

void main() {
  test(
    'a cycle spans Monday and Tuesday without counting idle overnight time',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _seed(database, puzzleCount: 2);
      final clock = _TestClock(DateTime.utc(2026, 9, 28, 9));
      final ids = _Ids();
      final service = _service(database, clock, ids);
      final cycle = await service.startOrResumeCycle(
        trainingSetId: 'set',
        startedAt: clock.utcNow,
      );
      final monday = await service.openSession(
        cycleId: cycle.id,
        startedAt: clock.utcNow,
        studyDay: DateTime.utc(2026, 9, 28),
      );
      final firstItem = (await service.selectNextItem(cycleId: cycle.id))!;
      final firstAttempt = await service.startAttempt(
        cycleId: cycle.id,
        sessionId: monday.id,
        trainingSetItemId: firstItem.id,
        startedAt: clock.utcNow,
      );
      clock.advance(const Duration(minutes: 2));
      await service.finalizeAttempt(
        attemptId: firstAttempt.id,
        outcome: PuzzleAttemptOutcome.passed,
        completedAt: clock.utcNow,
        activeSegmentDuration: const Duration(minutes: 2),
      );
      final unfinishedItem = (await service.selectNextItem(cycleId: cycle.id))!;
      final unfinishedAttempt = await service.startAttempt(
        cycleId: cycle.id,
        sessionId: monday.id,
        trainingSetItemId: unfinishedItem.id,
        startedAt: clock.utcNow,
      );
      clock.advance(const Duration(minutes: 4));
      await service.pauseSession(
        sessionId: monday.id,
        pausedAt: clock.utcNow,
        activeAttemptSegmentDuration: const Duration(minutes: 4),
      );
      await service.closeSession(sessionId: monday.id, endedAt: clock.utcNow);

      clock.advance(const Duration(hours: 20));
      final tuesday = await service.openSession(
        cycleId: cycle.id,
        startedAt: clock.utcNow,
        studyDay: DateTime.utc(2026, 9, 29),
      );
      final resumedAttempt = (await DriftTrainingRepository(database)
          .getAttempt(unfinishedAttempt.id))!;
      expect(resumedAttempt.id, unfinishedAttempt.id);
      expect(resumedAttempt.status.name, 'active');
      clock.advance(const Duration(minutes: 3));
      await service.finalizeAttempt(
        attemptId: resumedAttempt.id,
        outcome: PuzzleAttemptOutcome.passed,
        completedAt: clock.utcNow,
        activeSegmentDuration: const Duration(minutes: 3),
      );
      await service.closeSession(sessionId: tuesday.id, endedAt: clock.utcNow);
      await service.completeCycle(cycleId: cycle.id, completedAt: clock.utcNow);

      final repository = DriftTrainingRepository(database);
      final attempts = await repository.listAttempts(cycle.id);
      expect(attempts, hasLength(2));
      expect(
        attempts.fold(
          Duration.zero,
          (total, item) => total + item.activeDuration,
        ),
        const Duration(minutes: 9),
      );
      final sessions = await repository.listSessions(cycle.id);
      expect(sessions.map((s) => s.studyDay), <DateTime>[
        DateTime.utc(2026, 9, 28),
        DateTime.utc(2026, 9, 29),
      ]);
      final segments = await repository.listTimingSegments(
        unfinishedAttempt.id,
      );
      expect(segments, hasLength(2));
      expect(segments.map((segment) => segment.sessionId), <String>[
        monday.id,
        tuesday.id,
      ]);
    },
  );

  test(
    'process termination recovery closes open time at its safe boundary',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'training-recovery-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = File('${directory.path}/training.sqlite');
      var database = AppDatabase(NativeDatabase(path));
      await _seed(database, puzzleCount: 1);
      final start = DateTime.utc(2026, 9, 28, 15);
      final firstService = _service(database, _TestClock(start), _Ids());
      final cycle = await firstService.startOrResumeCycle(
        trainingSetId: 'set',
        startedAt: start,
      );
      final session = await firstService.openSession(
        cycleId: cycle.id,
        startedAt: start,
        studyDay: DateTime.utc(2026, 9, 28),
      );
      final item = (await firstService.selectNextItem(cycleId: cycle.id))!;
      final attempt = await firstService.startAttempt(
        cycleId: cycle.id,
        sessionId: session.id,
        trainingSetItemId: item.id,
        startedAt: start,
      );
      await database.close();

      database = AppDatabase(NativeDatabase(path));
      addTearDown(database.close);
      final recovery = _service(
        database,
        _TestClock(DateTime.utc(2026, 9, 29, 10)),
        _Ids(prefix: 'after-restart'),
      );
      final recoveredAt = DateTime.utc(2026, 9, 29, 10);
      final recoveredSession = await recovery.recoverSession(
        sessionId: session.id,
        recoveredAt: recoveredAt,
      );
      final repository = DriftTrainingRepository(database);
      final storedAttempt = (await repository.getAttempt(attempt.id))!;
      final segment = (await repository.listTimingSegments(attempt.id)).single;

      expect(recoveredSession.endedAt, recoveredAt);
      expect(storedAttempt.status.name, 'paused');
      expect(storedAttempt.activeDuration, Duration.zero);
      expect(segment.endedAt, start);
      expect(segment.activeDuration, Duration.zero);
      expect(segment.sessionId, session.id);
    },
  );

  test(
    'retry appends a new attempt and preserves the first finalized result',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _seed(database, puzzleCount: 1);
      final clock = _TestClock(DateTime.utc(2026, 9, 28, 9));
      final service = _service(database, clock, _Ids());
      final cycle = await service.startOrResumeCycle(
        trainingSetId: 'set',
        startedAt: clock.utcNow,
      );
      final session = await service.openSession(
        cycleId: cycle.id,
        startedAt: clock.utcNow,
        studyDay: DateTime.utc(2026, 9, 28),
      );
      final item = (await service.selectNextItem(cycleId: cycle.id))!;
      final first = await service.startAttempt(
        cycleId: cycle.id,
        sessionId: session.id,
        trainingSetItemId: item.id,
        startedAt: clock.utcNow,
      );
      await service.finalizeAttempt(
        attemptId: first.id,
        outcome: PuzzleAttemptOutcome.wrongMove,
        failureReason: PuzzleAttemptFailureReason.incorrectMove,
        completedAt: clock.utcNow,
        activeSegmentDuration: Duration.zero,
      );

      final retry = await service.startAttempt(
        cycleId: cycle.id,
        sessionId: session.id,
        trainingSetItemId: item.id,
        startedAt: clock.utcNow,
      );
      await service.finalizeAttempt(
        attemptId: retry.id,
        outcome: PuzzleAttemptOutcome.passed,
        completedAt: clock.utcNow,
        activeSegmentDuration: Duration.zero,
      );

      final attempts = await DriftTrainingRepository(database)
          .listAttempts(cycle.id);
      expect(retry.id, isNot(first.id));
      expect(attempts.map((a) => a.id).toSet(), <String>{first.id, retry.id});
      expect(
        (await DriftTrainingRepository(database).getAttempt(first.id))!.outcome,
        PuzzleAttemptOutcome.wrongMove,
      );
      expect(
        (await DriftTrainingRepository(database).getAttempt(retry.id))!.outcome,
        PuzzleAttemptOutcome.passed,
      );
    },
  );
}

TrainingSessionService _service(
  AppDatabase database,
  AppClock clock,
  IdGenerator ids,
) => TrainingSessionServiceImpl(
  repository: DriftTrainingRepository(database),
  clock: clock,
  idGenerator: ids,
);

Future<void> _seed(AppDatabase database, {required int puzzleCount}) async {
  await database.customStatement('PRAGMA foreign_keys = ON');
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
  for (var index = 0; index < puzzleCount; index++) {
    await database
        .into(database.pgnBlocks)
        .insert(
          PgnBlocksCompanion.insert(
            id: 'block-$index',
            sourceId: 'source',
            startOffset: index * 10,
            endOffset: index * 10 + 9,
            ordinal: index,
            contentType: ContentType.puzzle.toDatabaseValue(),
            parseStatus: 'notParsed',
          ),
        );
  }
  final setRepository = DriftTrainingSetRepository(database);
  await setRepository.createSet(
    TrainingSet(
      id: 'set',
      name: 'Set',
      items: List<TrainingSetItem>.generate(
        puzzleCount,
        (index) => TrainingSetItem(
          id: 'item-$index',
          trainingSetId: 'set',
          blockId: 'block-$index',
          position: index,
          contentType: ContentType.puzzle,
          addedAt: DateTime.utc(2026, 9, 27),
        ),
      ),
      createdAt: DateTime.utc(2026, 9, 27),
      updatedAt: DateTime.utc(2026, 9, 27),
    ),
  );
}

final class _TestClock implements AppClock {
  _TestClock(this._utcNow);

  DateTime _utcNow;
  Duration _elapsed = Duration.zero;

  @override
  DateTime get utcNow => _utcNow;

  @override
  Duration get monotonicElapsed => _elapsed;

  void advance(Duration duration) {
    _utcNow = _utcNow.add(duration);
    _elapsed += duration;
  }
}

final class _Ids implements IdGenerator {
  _Ids({this.prefix = 'training'});

  final String prefix;
  var _next = 0;

  @override
  String generateId() => '$prefix-${_next++}';
}
