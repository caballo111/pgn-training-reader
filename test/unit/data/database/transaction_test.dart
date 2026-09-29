import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'finalizing an attempt commits its final timing segment atomically',
    () async {
      await _seedActiveAttempt(database);

      await database.transaction(() async {
        await (database.update(
          database.puzzleAttempts,
        )..where((attempt) => attempt.id.equals('attempt-1'))).write(
          const PuzzleAttemptsCompanion(
            status: Value('completed'),
            outcome: Value('passed'),
            completedAtMicros: Value(300),
            activeMilliseconds: Value(1200),
          ),
        );
        await (database.update(
          database.timingSegments,
        )..where((segment) => segment.id.equals('segment-1'))).write(
          const TimingSegmentsCompanion(
            endedAtMicros: Value(300),
            activeMilliseconds: Value(1200),
          ),
        );
      });

      final attempt = await (database.select(
        database.puzzleAttempts,
      )..where((row) => row.id.equals('attempt-1'))).getSingle();
      final segment = await (database.select(
        database.timingSegments,
      )..where((row) => row.id.equals('segment-1'))).getSingle();

      expect(attempt.status, 'completed');
      expect(attempt.outcome, 'passed');
      expect(attempt.completedAtMicros, 300);
      expect(attempt.activeMilliseconds, 1200);
      expect(segment.endedAtMicros, 300);
      expect(segment.activeMilliseconds, 1200);
    },
  );

  test(
    'a failure after finalizing the attempt rolls back the whole transaction',
    () async {
      await _seedActiveAttempt(database);

      await expectLater(
        database.transaction(() async {
          await (database.update(
            database.puzzleAttempts,
          )..where((attempt) => attempt.id.equals('attempt-1'))).write(
            const PuzzleAttemptsCompanion(
              status: Value('completed'),
              outcome: Value('passed'),
              completedAtMicros: Value(300),
              activeMilliseconds: Value(1200),
            ),
          );

          throw StateError('injected failure after attempt update');

          // This update must not run; its unchanged state also confirms that
          // the transaction rolled back the preceding attempt update.
        }),
        throwsA(isA<StateError>()),
      );

      final attempt = await (database.select(
        database.puzzleAttempts,
      )..where((row) => row.id.equals('attempt-1'))).getSingle();
      final segment = await (database.select(
        database.timingSegments,
      )..where((row) => row.id.equals('segment-1'))).getSingle();

      expect(attempt.status, 'active');
      expect(attempt.outcome, isNull);
      expect(attempt.completedAtMicros, isNull);
      expect(attempt.activeMilliseconds, 0);
      expect(segment.endedAtMicros, isNull);
      expect(segment.activeMilliseconds, isNull);
    },
  );
}

Future<void> _seedActiveAttempt(AppDatabase database) async {
  await database
      .into(database.pgnSources)
      .insert(
        PgnSourcesCompanion.insert(
          id: 'source-1',
          displayName: 'fixture.pgn',
          accessMode: 'managed_copy',
          scannerVersion: 1,
          importState: 'completed',
          createdAtMicros: 100,
          updatedAtMicros: 100,
        ),
      );
  await database
      .into(database.pgnBlocks)
      .insert(
        PgnBlocksCompanion.insert(
          id: 'block-1',
          sourceId: 'source-1',
          startOffset: 0,
          endOffset: 10,
          ordinal: 0,
          contentType: 'Puzzle',
          parseStatus: 'valid',
        ),
      );
  await database
      .into(database.trainingSets)
      .insert(
        TrainingSetsCompanion.insert(
          id: 'set-1',
          name: 'set',
          createdAtMicros: 100,
          updatedAtMicros: 100,
        ),
      );
  await database
      .into(database.cycles)
      .insert(
        CyclesCompanion.insert(
          id: 'cycle-1',
          trainingSetId: 'set-1',
          status: 'active',
          createdAtMicros: 100,
        ),
      );
  await database
      .into(database.trainingSessions)
      .insert(
        TrainingSessionsCompanion.insert(
          id: 'session-1',
          cycleId: 'cycle-1',
          status: 'active',
          startedAtMicros: 100,
          studyDayMicros: 100,
        ),
      );
  await database
      .into(database.puzzleAttempts)
      .insert(
        PuzzleAttemptsCompanion.insert(
          id: 'attempt-1',
          blockId: 'block-1',
          cycleId: 'cycle-1',
          sessionId: 'session-1',
          status: 'active',
          startedAtMicros: 100,
        ),
      );
  await database
      .into(database.timingSegments)
      .insert(
        TimingSegmentsCompanion.insert(
          id: 'segment-1',
          attemptId: 'attempt-1',
          startedAtMicros: 100,
        ),
      );
}
