import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/app/casual_training_repository.dart';
import 'package:pgntrainingreader/data/database/app_database.dart'
    show AppDatabase;
import 'package:pgntrainingreader/domain/training/attempt_move.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';

void main() {
  test('casual score transaction rolls back memory and keeps final scores immutable', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = CasualTrainingRepository(
      database,
      'block',
      'casual-one',
    );
    final startedAt = DateTime.utc(2026, 10, 1);
    final attempt = PuzzleAttempt(
      id: 'casual-one',
      blockId: 'block',
      cycleId: 'local-cycle',
      sessionId: 'local-session',
      startedAt: startedAt,
    );
    await repository.createAttempt(attempt);

    final paused = _copyAttempt(attempt, status: PuzzleAttemptStatus.paused);
    await expectLater(
      repository.transaction(() async {
        await repository.updateUnfinishedAttempt(paused);
        throw StateError('force rollback');
      }),
      throwsStateError,
    );
    expect(
      (await repository.getAttempt(attempt.id))?.status,
      PuzzleAttemptStatus.active,
    );

    await repository.updateUnfinishedAttempt(paused);
    await expectLater(
      repository.recordSubmittedMove(
        move: AttemptMove(
          id: 'move-one',
          attemptId: attempt.id,
          ordinal: 0,
          move: 'e7e5',
          legal: true,
          accepted: true,
          submittedAt: startedAt,
        ),
        updatedAttempt: attempt,
      ),
      throwsStateError,
    );
    await repository.updateUnfinishedAttempt(attempt);

    await database.customStatement('''
      CREATE TRIGGER reject_casual_score
      BEFORE INSERT ON app_settings
      WHEN NEW.key LIKE 'casual.score.%'
      BEGIN SELECT RAISE(ABORT, 'simulated storage error'); END
    ''');
    await expectLater(
      repository.updateUnfinishedAttempt(paused),
      throwsA(anything),
    );
    expect(
      (await repository.getAttempt(attempt.id))?.status,
      PuzzleAttemptStatus.active,
    );
    await database.customStatement('DROP TRIGGER reject_casual_score');

    final failed = PuzzleAttempt(
      id: attempt.id,
      blockId: attempt.blockId,
      cycleId: attempt.cycleId,
      sessionId: attempt.sessionId,
      status: PuzzleAttemptStatus.finalized,
      startedAt: startedAt,
      completedAt: startedAt.add(const Duration(seconds: 1)),
      outcome: PuzzleAttemptOutcome.wrongMove,
      failureReason: PuzzleAttemptFailureReason.incorrectMove,
    );
    await repository.finalizeAttempt(attempt: failed);
    await expectLater(
      repository.finalizeAttempt(attempt: failed),
      throwsStateError,
    );
    await expectLater(
      repository.updateUnfinishedAttempt(
        _copyAttempt(failed, status: PuzzleAttemptStatus.finalized),
      ),
      throwsStateError,
    );
    final stored = await database
        .customSelect(
          'SELECT value FROM app_settings WHERE key = ?',
          variables: const [Variable<String>('casual.score.casual-one')],
        )
        .getSingle();
    final payload =
        jsonDecode(stored.data['value'] as String) as Map<String, dynamic>;
    expect(
      (payload['attempt'] as Map<String, dynamic>)['outcome'],
      'wrongMove',
    );
  });
}

PuzzleAttempt _copyAttempt(
  PuzzleAttempt source, {
  required PuzzleAttemptStatus status,
}) => PuzzleAttempt(
  id: source.id,
  blockId: source.blockId,
  cycleId: source.cycleId,
  sessionId: source.sessionId,
  status: status,
  startedAt: source.startedAt,
  completedAt: source.completedAt,
  activeDuration: source.activeDuration,
  outcome: source.outcome,
  failureReason: source.failureReason,
  wrongMoveCount: source.wrongMoveCount,
  hintCount: source.hintCount,
  revealed: source.revealed,
);
