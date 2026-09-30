import 'package:drift/drift.dart';

import '../../core/errors/app_failure.dart';
import '../../domain/chess_content/content_type.dart';
import '../../domain/training/attempt_move.dart';
import '../../domain/training/cycle.dart';
import '../../domain/training/lifecycle_status.dart';
import '../../domain/training/progress_aggregate.dart';
import '../../domain/training/progress_report_data.dart';
import '../../domain/training/puzzle_attempt.dart';
import '../../domain/training/timing_segment.dart';
import '../../domain/training/training_repository.dart';
import '../../domain/training/training_session_service.dart';
import '../../domain/training/training_session.dart';
import '../../domain/training/training_set.dart';
import '../../domain/training/training_set_item.dart';
import '../../domain/training/training_set_repository.dart';
import '../database/app_database.dart'
    hide
        AttemptMove,
        Cycle,
        CycleItemCompletion,
        PuzzleAttempt,
        TimingSegment,
        TrainingSession,
        TrainingSet,
        TrainingSetItem;
import '../database/app_database.dart' as db;
import 'drift_training_set_repository.dart';

/// Drift persistence for training set definitions and durable lifecycle data.
final class DriftTrainingRepository
    implements TrainingRepository, AtomicTrainingRepository {
  DriftTrainingRepository(this._database)
    : _sets = DriftTrainingSetRepository(_database);

  final AppDatabase _database;
  final TrainingSetRepository _sets;

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _guard(() => _database.transaction(action));

  @override
  Future<TrainingSet?> getSet(String id) => _sets.getSet(id);
  @override
  Future<List<TrainingSet>> listSets() => _sets.listSets();
  @override
  Future<void> createSet(TrainingSet set) => _sets.createSet(set);

  @override
  Future<void> updateSet(TrainingSet set) => _guard(() async {
    await transaction(() async {
      final old = await getSet(set.id);
      if (old == null) {
        _missing('training_set_missing', 'Training set not found.');
      }
      if (old!.createdAt != set.createdAt) {
        _invalid('Training set identity cannot change.');
      }
      await (_database.update(
        _database.trainingSets,
      )..where((row) => row.id.equals(set.id))).write(
        TrainingSetsCompanion(
          name: Value(set.name.trim()),
          status: Value(set.status.toDatabaseValue()),
          updatedAtMicros: Value(_micros(set.updatedAt)),
          archivedAtMicros: Value(_nullableMicros(set.archivedAt)),
        ),
      );
      final existing = await (_database.select(
        _database.trainingSetItems,
      )..where((row) => row.trainingSetId.equals(set.id))).get();
      final newIds = set.items.map((item) => item.id).toSet();
      final offset =
          existing.length +
          existing.fold<int>(
            0,
            (maximum, row) => row.position > maximum ? row.position : maximum,
          ) +
          set.items.length +
          1;
      for (final row in existing) {
        await (_database.update(
          _database.trainingSetItems,
        )..where((item) => item.id.equals(row.id))).write(
          TrainingSetItemsCompanion(position: Value(row.position + offset)),
        );
      }
      for (final row in existing.where((row) => !newIds.contains(row.id))) {
        await (_database.delete(
          _database.trainingSetItems,
        )..where((item) => item.id.equals(row.id))).go();
      }
      for (var index = 0; index < set.items.length; index++) {
        final item = set.items[index];
        final row = existing.where((entry) => entry.id == item.id).firstOrNull;
        if (row == null) {
          await _database
              .into(_database.trainingSetItems)
              .insert(
                TrainingSetItemsCompanion.insert(
                  id: item.id,
                  trainingSetId: set.id,
                  blockId: item.blockId,
                  position: index,
                  contentType: item.contentType.toDatabaseValue(),
                  addedAtMicros: _micros(item.addedAt),
                ),
              );
        } else {
          await (_database.update(
            _database.trainingSetItems,
          )..where((entry) => entry.id.equals(item.id))).write(
            TrainingSetItemsCompanion(
              blockId: Value(item.blockId),
              position: Value(index),
              contentType: Value(item.contentType.toDatabaseValue()),
            ),
          );
        }
      }
    });
  });

  @override
  Future<Cycle?> getCycle(String id) => _guard(() async {
    final row = await (_database.select(
      _database.cycles,
    )..where((value) => value.id.equals(id))).getSingleOrNull();
    return row == null ? null : _cycle(row);
  });

  @override
  Future<List<Cycle>> listCycles(String trainingSetId) => _guard(() async {
    final rows =
        await (_database.select(_database.cycles)
              ..where((row) => row.trainingSetId.equals(trainingSetId))
              ..orderBy([
                (row) => OrderingTerm.asc(row.createdAtMicros),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    return List.unmodifiable(rows.map(_cycle));
  });

  @override
  Future<void> createCycle(Cycle cycle) => _guard(() async {
    await _database
        .into(_database.cycles)
        .insert(
          CyclesCompanion.insert(
            id: cycle.id,
            trainingSetId: cycle.trainingSetId,
            status: cycle.status.toDatabaseValue(),
            startedAtMicros: Value(_nullableMicros(cycle.startedAt)),
            completedAtMicros: Value(_nullableMicros(cycle.completedAt)),
            stoppedAtMicros: Value(_nullableMicros(cycle.stoppedAt)),
            createdAtMicros: _micros(cycle.createdAt),
          ),
        );
  });

  @override
  Future<void> updateCycle(Cycle cycle) => _guard(() async {
    final prior = await getCycle(cycle.id);
    if (prior == null) _missing('cycle_missing', 'Training cycle not found.');
    if (prior!.trainingSetId != cycle.trainingSetId ||
        prior.createdAt != cycle.createdAt ||
        prior.startedAt != cycle.startedAt) {
      _invalid('Cycle identity and start time cannot change.');
    }
    await (_database.update(
      _database.cycles,
    )..where((row) => row.id.equals(cycle.id))).write(
      CyclesCompanion(
        status: Value(cycle.status.toDatabaseValue()),
        completedAtMicros: Value(_nullableMicros(cycle.completedAt)),
        stoppedAtMicros: Value(_nullableMicros(cycle.stoppedAt)),
      ),
    );
  });

  @override
  Future<TrainingSession?> getSession(String id) => _guard(() async {
    final row = await (_database.select(
      _database.trainingSessions,
    )..where((value) => value.id.equals(id))).getSingleOrNull();
    return row == null ? null : _session(row);
  });

  @override
  Future<List<TrainingSession>> listSessions(String cycleId) =>
      _guard(() async {
        final rows =
            await (_database.select(_database.trainingSessions)
                  ..where((row) => row.cycleId.equals(cycleId))
                  ..orderBy([
                    (row) => OrderingTerm.asc(row.startedAtMicros),
                    (row) => OrderingTerm.asc(row.id),
                  ]))
                .get();
        return List.unmodifiable(rows.map(_session));
      });

  @override
  Future<void> createSession(TrainingSession session) => _guard(() async {
    if (session.status != TrainingSessionStatus.active ||
        session.endedAt != null) {
      _invalid('New sessions must be active and unfinished.');
    }
    await _database
        .into(_database.trainingSessions)
        .insert(
          TrainingSessionsCompanion.insert(
            id: session.id,
            cycleId: session.cycleId,
            status: session.status.toDatabaseValue(),
            startedAtMicros: _micros(session.startedAt),
            endedAtMicros: Value(_nullableMicros(session.endedAt)),
            studyDayMicros: _micros(session.studyDay),
          ),
        );
  });

  @override
  Future<void> updateSession(TrainingSession session) => _guard(() async {
    final prior = await getSession(session.id);
    if (prior == null) {
      _missing('session_missing', 'Training session not found.');
    }
    if (prior!.cycleId != session.cycleId ||
        prior.startedAt != session.startedAt ||
        prior.studyDay != session.studyDay) {
      _invalid('Session identity, cycle, start, and study day cannot change.');
    }
    if (prior.status == TrainingSessionStatus.closed ||
        prior.status == TrainingSessionStatus.recovered ||
        (prior.status == TrainingSessionStatus.active &&
            session.status == TrainingSessionStatus.active) ||
        (prior.status == TrainingSessionStatus.paused &&
            session.status == TrainingSessionStatus.paused)) {
      _invalid('Terminal sessions and repeated session states are immutable.');
    }
    await (_database.update(
      _database.trainingSessions,
    )..where((row) => row.id.equals(session.id))).write(
      TrainingSessionsCompanion(
        status: Value(session.status.toDatabaseValue()),
        endedAtMicros: Value(_nullableMicros(session.endedAt)),
      ),
    );
  });

  @override
  Future<PuzzleAttempt?> getAttempt(String id) => _guard(() async {
    final row = await (_database.select(
      _database.puzzleAttempts,
    )..where((value) => value.id.equals(id))).getSingleOrNull();
    return row == null ? null : _attempt(row);
  });

  @override
  Future<List<PuzzleAttempt>> listAttempts(String cycleId) => _guard(() async {
    final rows =
        await (_database.select(_database.puzzleAttempts)
              ..where((row) => row.cycleId.equals(cycleId))
              ..orderBy([
                (row) => OrderingTerm.asc(row.startedAtMicros),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    return List.unmodifiable(rows.map(_attempt));
  });

  @override
  Future<void> createAttempt(PuzzleAttempt attempt) => _guard(() async {
    if (attempt.status != PuzzleAttemptStatus.active ||
        attempt.outcome != null) {
      _invalid('New attempts must be active and unfinished.');
    }
    await transaction(() async {
      final unfinished =
          await (_database.select(_database.puzzleAttempts)..where(
                (row) =>
                    row.cycleId.equals(attempt.cycleId) &
                    row.blockId.equals(attempt.blockId) &
                    row.status.isNotValue(
                      PuzzleAttemptStatus.finalized.toDatabaseValue(),
                    ),
              ))
              .getSingleOrNull();
      if (unfinished != null) {
        _invalid(
          'An unfinished attempt already exists for this item in the cycle.',
        );
      }
      await _database
          .into(_database.puzzleAttempts)
          .insert(_attemptInsert(attempt));
    });
  });

  @override
  Future<void> updateUnfinishedAttempt(PuzzleAttempt attempt) =>
      _guard(() async {
        final prior = await getAttempt(attempt.id);
        if (prior == null) {
          _missing('attempt_missing', 'Puzzle attempt not found.');
        }
        if (prior!.status == PuzzleAttemptStatus.finalized) {
          _invalid('Finalized attempts are immutable.');
        }
        if (attempt.status == PuzzleAttemptStatus.finalized ||
            attempt.outcome != null ||
            attempt.completedAt != null ||
            attempt.activeDuration < prior.activeDuration ||
            attempt.wrongMoveCount < prior.wrongMoveCount ||
            attempt.hintCount < prior.hintCount) {
          _invalid(
            'Unfinished attempt updates cannot finalize or reduce progress.',
          );
        }
        if (prior.status != attempt.status &&
            !((prior.status == PuzzleAttemptStatus.active &&
                    attempt.status == PuzzleAttemptStatus.paused) ||
                (prior.status == PuzzleAttemptStatus.paused &&
                    attempt.status == PuzzleAttemptStatus.active))) {
          _invalid('Attempt lifecycle transition is invalid.');
        }
        if (!_sameAttemptIdentity(prior, attempt)) {
          _invalid('Attempt identity cannot change.');
        }
        await (_database.update(_database.puzzleAttempts)
              ..where((row) => row.id.equals(attempt.id)))
            .write(_attemptUpdate(attempt));
      });

  @override
  Future<void> recordSubmittedMove({
    required AttemptMove move,
    required PuzzleAttempt updatedAttempt,
    TimingSegment? closingTimingSegment,
  }) => _guard(() async {
    await transaction(() async {
      final prior = await getAttempt(updatedAttempt.id);
      if (prior == null ||
          prior.status != PuzzleAttemptStatus.active ||
          !_sameAttemptIdentity(prior, updatedAttempt)) {
        _invalid('Move must update its existing unfinished attempt.');
      }
      final moves = await listAttemptMoves(move.attemptId);
      if (move.attemptId != updatedAttempt.id || move.ordinal != moves.length) {
        _invalid('Move ordinal or attempt identity is invalid.');
      }
      if ((updatedAttempt.status == PuzzleAttemptStatus.finalized) !=
          (closingTimingSegment != null)) {
        _invalid('Finalized move requires its closing timing segment.');
      }
      await _database
          .into(_database.attemptMoves)
          .insert(
            AttemptMovesCompanion.insert(
              id: move.id,
              attemptId: move.attemptId,
              ordinal: move.ordinal,
              move: move.move,
              legal: move.legal,
              accepted: move.accepted,
              submittedAtMicros: _micros(move.submittedAt),
            ),
          );
      if (closingTimingSegment != null) {
        await finalizeAttempt(
          attempt: updatedAttempt,
          finalTimingSegment: closingTimingSegment,
        );
      } else {
        await updateUnfinishedAttempt(updatedAttempt);
      }
    });
  });

  @override
  Future<List<AttemptMove>> listAttemptMoves(String attemptId) =>
      _guard(() async {
        final rows =
            await (_database.select(_database.attemptMoves)
                  ..where((row) => row.attemptId.equals(attemptId))
                  ..orderBy([(row) => OrderingTerm.asc(row.ordinal)]))
                .get();
        return List.unmodifiable(
          rows.map(
            (row) => AttemptMove(
              id: row.id,
              attemptId: row.attemptId,
              ordinal: row.ordinal,
              move: row.move,
              legal: row.legal,
              accepted: row.accepted,
              submittedAt: _date(row.submittedAtMicros),
            ),
          ),
        );
      });

  @override
  Future<List<TimingSegment>> listTimingSegments(String attemptId) =>
      _guard(() async {
        final rows =
            await (_database.select(_database.timingSegments)
                  ..where((row) => row.attemptId.equals(attemptId))
                  ..orderBy([
                    (row) => OrderingTerm.asc(row.startedAtMicros),
                    (row) => OrderingTerm.asc(row.id),
                  ]))
                .get();
        return List.unmodifiable(rows.map(_timing));
      });

  @override
  Future<void> startTimingSegment(TimingSegment segment) => _guard(() async {
    await transaction(() async {
      if (segment.endedAt != null || segment.activeDuration != null) {
        _invalid('New timing segments must be open.');
      }
      final attempt = await getAttempt(segment.attemptId);
      if (attempt == null || attempt.status != PuzzleAttemptStatus.active) {
        _invalid('An active unfinished attempt is required to open a segment.');
      }
      if (await _openSegment(segment.attemptId) != null) {
        _invalid('Attempt already has an open timing segment.');
      }
      if (segment.startedAt.isBefore(attempt!.startedAt)) {
        _invalid('Timing segment cannot precede its attempt.');
      }
      if (segment.sessionId != null) {
        final session = await getSession(segment.sessionId!);
        if (session == null ||
            session.cycleId != attempt.cycleId ||
            session.status != TrainingSessionStatus.active ||
            segment.startedAt.isBefore(session.startedAt)) {
          _invalid(
            'Timing segment session must be active in the attempt cycle.',
          );
        }
      }
      await _database
          .into(_database.timingSegments)
          .insert(
            TimingSegmentsCompanion.insert(
              id: segment.id,
              attemptId: segment.attemptId,
              startedAtMicros: _micros(segment.startedAt),
              sessionId: Value(segment.sessionId),
            ),
          );
    });
  });

  @override
  Future<void> closeTimingSegment({
    required TimingSegment segment,
    required PuzzleAttempt updatedAttempt,
  }) => _guard(() async {
    await transaction(() async {
      final prior = await getAttempt(updatedAttempt.id);
      final open = await _openSegment(segment.attemptId);
      if (prior == null ||
          prior.status == PuzzleAttemptStatus.finalized ||
          open == null ||
          open.id != segment.id ||
          segment.endedAt == null) {
        _invalid('Open timing segment and unfinished attempt are required.');
      }
      if (open!.sessionId != segment.sessionId ||
          segment.activeDuration == null ||
          updatedAttempt.activeDuration - prior!.activeDuration !=
              segment.activeDuration) {
        _invalid(
          'Closing segment session and active duration must match the attempt update.',
        );
      }
      if (!_sameAttemptIdentity(prior!, updatedAttempt) ||
          updatedAttempt.activeDuration < prior.activeDuration ||
          updatedAttempt.status != PuzzleAttemptStatus.paused ||
          updatedAttempt.outcome != null ||
          updatedAttempt.completedAt != null) {
        _invalid('Attempt identity or active duration is invalid.');
      }
      await (_database.update(
        _database.timingSegments,
      )..where((row) => row.id.equals(segment.id))).write(
        TimingSegmentsCompanion(
          endedAtMicros: Value(_micros(segment.endedAt!)),
          activeMilliseconds: Value(segment.activeDuration!.inMilliseconds),
        ),
      );
      await updateUnfinishedAttempt(updatedAttempt);
    });
  });

  @override
  Future<void> finalizeAttempt({
    required PuzzleAttempt attempt,
    TimingSegment? finalTimingSegment,
  }) => _guard(() async {
    await transaction(() async {
      final prior = await getAttempt(attempt.id);
      if (prior == null || prior.status == PuzzleAttemptStatus.finalized) {
        _invalid('Only an unfinished attempt can be finalized.');
      }
      if (attempt.status != PuzzleAttemptStatus.finalized ||
          !_sameAttemptIdentity(prior!, attempt)) {
        _invalid(
          'Finalization must preserve attempt identity and be terminal.',
        );
      }
      final open = await _openSegment(attempt.id);
      if ((prior!.status == PuzzleAttemptStatus.active && open == null) ||
          (prior.status == PuzzleAttemptStatus.paused && open != null)) {
        _invalid('Attempt lifecycle does not match its open timing segment.');
      }
      if ((open == null) != (finalTimingSegment == null)) {
        _invalid('Final timing segment does not match attempt state.');
      }
      if (finalTimingSegment != null &&
          (open!.id != finalTimingSegment.id ||
              open.sessionId != finalTimingSegment.sessionId ||
              finalTimingSegment.activeDuration == null ||
              attempt.activeDuration - prior.activeDuration !=
                  finalTimingSegment.activeDuration)) {
        _invalid('Final timing segment context or duration is inconsistent.');
      }
      if (finalTimingSegment == null &&
          attempt.activeDuration != prior.activeDuration) {
        _invalid('Finalizing a paused attempt cannot change active duration.');
      }
      await (_database.update(_database.puzzleAttempts)
            ..where((row) => row.id.equals(attempt.id)))
          .write(_attemptUpdate(attempt));
      if (finalTimingSegment != null) {
        if (open!.id != finalTimingSegment.id ||
            finalTimingSegment.endedAt == null) {
          _invalid('Final timing segment is not the attempt open segment.');
        }
        await (_database.update(
          _database.timingSegments,
        )..where((row) => row.id.equals(open.id))).write(
          TimingSegmentsCompanion(
            endedAtMicros: Value(_micros(finalTimingSegment.endedAt!)),
            activeMilliseconds: Value(
              finalTimingSegment.activeDuration!.inMilliseconds,
            ),
          ),
        );
      }
    });
  });

  @override
  Future<void> completeNonPuzzleItem({
    required String cycleId,
    required String trainingSetItemId,
    required DateTime completedAt,
  }) => _guard(() async {
    final cycle = await getCycle(cycleId);
    if (cycle == null || cycle.status != CycleStatus.active) {
      _missing('cycle_missing', 'Active training cycle not found.');
    }
    final item =
        await (_database.select(_database.trainingSetItems)..where(
              (row) =>
                  row.id.equals(trainingSetItemId) &
                  row.trainingSetId.equals(cycle!.trainingSetId),
            ))
            .getSingleOrNull();
    if (item == null ||
        item.contentType == ContentType.puzzle.toDatabaseValue()) {
      _invalid('Only a cycle-owned non-puzzle item can be completed.');
    }
    await _database
        .into(_database.cycleItemCompletions)
        .insert(
          CycleItemCompletionsCompanion.insert(
            cycleId: cycleId,
            trainingSetItemId: trainingSetItemId,
            completedAtMicros: _micros(completedAt),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  });

  @override
  Future<Set<String>> completedNonPuzzleItemIds(String cycleId) =>
      _guard(() async {
        final rows = await (_database.select(
          _database.cycleItemCompletions,
        )..where((row) => row.cycleId.equals(cycleId))).get();
        return Set.unmodifiable(rows.map((row) => row.trainingSetItemId));
      });

  @override
  Future<DateTime?> nonPuzzleItemCompletedAt({
    required String cycleId,
    required String trainingSetItemId,
  }) => _guard(() async {
    final row =
        await (_database.select(_database.cycleItemCompletions)..where(
              (value) =>
                  value.cycleId.equals(cycleId) &
                  value.trainingSetItemId.equals(trainingSetItemId),
            ))
            .getSingleOrNull();
    return row == null ? null : _date(row.completedAtMicros);
  });

  @override
  Future<ProgressAggregate> aggregateForSet(
    String trainingSetId,
  ) => _guard(() async {
    final rows =
        await (_database.select(_database.puzzleAttempts)
              ..where(
                (row) =>
                    row.status.equals(
                      PuzzleAttemptStatus.finalized.toDatabaseValue(),
                    ) &
                    row.cycleId.isInQuery(
                      _database.selectOnly(_database.cycles)
                        ..addColumns([_database.cycles.id])
                        ..where(
                          _database.cycles.trainingSetId.equals(trainingSetId),
                        ),
                    ),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.startedAtMicros),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    final completions =
        await (_database.select(_database.cycleItemCompletions)..where(
              (row) => row.cycleId.isInQuery(
                _database.selectOnly(_database.cycles)
                  ..addColumns([_database.cycles.id])
                  ..where(_database.cycles.trainingSetId.equals(trainingSetId)),
              ),
            ))
            .get();
    return _aggregate(rows, completedNonPuzzleItemCount: completions.length);
  });

  @override
  Future<ProgressAggregate> aggregateForCycle(String cycleId) => _guard(
    () async {
      final rows =
          await (_database.select(_database.puzzleAttempts)
                ..where(
                  (row) =>
                      row.cycleId.equals(cycleId) &
                      row.status.equals(
                        PuzzleAttemptStatus.finalized.toDatabaseValue(),
                      ),
                )
                ..orderBy([
                  (row) => OrderingTerm.asc(row.startedAtMicros),
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      final completions = await (_database.select(
        _database.cycleItemCompletions,
      )..where((row) => row.cycleId.equals(cycleId))).get();
      return _aggregate(rows, completedNonPuzzleItemCount: completions.length);
    },
  );

  @override
  Future<ProgressAggregate> aggregateForSession(String sessionId) =>
      _guard(() async {
        final rows =
            await (_database.select(_database.puzzleAttempts)
                  ..where(
                    (row) =>
                        row.sessionId.equals(sessionId) &
                        row.status.equals(
                          PuzzleAttemptStatus.finalized.toDatabaseValue(),
                        ),
                  )
                  ..orderBy([
                    (row) => OrderingTerm.asc(row.startedAtMicros),
                    (row) => OrderingTerm.asc(row.id),
                  ]))
                .get();
        return _aggregate(rows);
      });

  @override
  Future<List<SessionProgressAggregate>> sessionAggregatesForCycle(
    String cycleId,
  ) => _guard(() async {
    final sessions = await listSessions(cycleId);
    final rows =
        await (_database.select(_database.puzzleAttempts)
              ..where(
                (row) =>
                    row.cycleId.equals(cycleId) &
                    row.status.equals(
                      PuzzleAttemptStatus.finalized.toDatabaseValue(),
                    ),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.startedAtMicros),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    final attemptsBySession = <String, List<db.PuzzleAttempt>>{};
    for (final row in rows) {
      attemptsBySession.putIfAbsent(row.sessionId, () => []).add(row);
    }
    return List.unmodifiable(
      sessions.map(
        (session) => SessionProgressAggregate(
          session: session,
          progress: _aggregate(attemptsBySession[session.id] ?? const []),
        ),
      ),
    );
  });

  @override
  Future<List<ExerciseProgressHistory>> exerciseHistoryForCycle(
    String cycleId,
  ) => _guard(() async {
    final attempts = await _finalizedAttempts(cycleId);
    if (attempts.isEmpty) return const [];
    final blocks = await _metadataFor(attempts);
    final grouped = <String, List<PuzzleAttempt>>{};
    for (final attempt in attempts) {
      grouped.putIfAbsent(attempt.blockId, () => []).add(attempt);
    }
    return List.unmodifiable(
      grouped.entries.map((entry) {
        final block = blocks[entry.key];
        final exerciseAttempts = entry.value;
        return ExerciseProgressHistory(
          exerciseId: entry.key,
          theme: block?.theme,
          difficulty: block?.difficulty,
          attempts: exerciseAttempts,
          progress: _aggregateAttempts(exerciseAttempts),
        );
      }),
    );
  });

  @override
  Future<List<MetadataProgressAggregate>> themeAggregatesForCycle(
    String cycleId,
  ) => _metadataAggregates(cycleId, (block) => block?.theme);

  @override
  Future<List<MetadataProgressAggregate>> difficultyAggregatesForCycle(
    String cycleId,
  ) => _metadataAggregates(cycleId, (block) => block?.difficulty);

  Future<List<MetadataProgressAggregate>> _metadataAggregates(
    String cycleId,
    String? Function(db.PgnBlock?) selectValue,
  ) => _guard(() async {
    final attempts = await _finalizedAttempts(cycleId);
    if (attempts.isEmpty) return const [];
    final blocks = await _metadataFor(attempts);
    final grouped = <String, List<PuzzleAttempt>>{};
    for (final attempt in attempts) {
      final value = selectValue(blocks[attempt.blockId]);
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty) continue;
      grouped.putIfAbsent(normalized, () => []).add(attempt);
    }
    final values = grouped.keys.toList()..sort();
    return List.unmodifiable(
      values.map(
        (value) => MetadataProgressAggregate(
          value: value,
          progress: _aggregateAttempts(grouped[value]!),
        ),
      ),
    );
  });

  Future<List<PuzzleAttempt>> _finalizedAttempts(String cycleId) async {
    final rows =
        await (_database.select(_database.puzzleAttempts)
              ..where(
                (row) =>
                    row.cycleId.equals(cycleId) &
                    row.status.equals(
                      PuzzleAttemptStatus.finalized.toDatabaseValue(),
                    ),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.startedAtMicros),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    return rows.map(_attempt).toList();
  }

  Future<Map<String, db.PgnBlock>> _metadataFor(
    List<PuzzleAttempt> attempts,
  ) async {
    final ids = attempts.map((attempt) => attempt.blockId).toSet().toList();
    final rows = await (_database.select(
      _database.pgnBlocks,
    )..where((block) => block.id.isIn(ids))).get();
    return {for (final row in rows) row.id: row};
  }

  static ProgressAggregate _aggregateAttempts(List<PuzzleAttempt> attempts) {
    final outcomes = <PuzzleAttemptOutcome, int>{
      for (final outcome in PuzzleAttemptOutcome.values) outcome: 0,
    };
    var wrongMoves = 0;
    var hints = 0;
    for (final attempt in attempts) {
      outcomes[attempt.outcome!] = outcomes[attempt.outcome!]! + 1;
      wrongMoves += attempt.wrongMoveCount;
      hints += attempt.hintCount;
    }
    return ProgressAggregate(
      passedCount: outcomes[PuzzleAttemptOutcome.passed]!,
      wrongMoveOutcomeCount: outcomes[PuzzleAttemptOutcome.wrongMove]!,
      revealedCount: outcomes[PuzzleAttemptOutcome.revealed]!,
      skippedCount: outcomes[PuzzleAttemptOutcome.skipped]!,
      timedOutCount: outcomes[PuzzleAttemptOutcome.timedOut]!,
      abandonedCount: outcomes[PuzzleAttemptOutcome.abandoned]!,
      wrongMoveCount: wrongMoves,
      hintCount: hints,
      attemptActiveDurations: attempts.map((attempt) => attempt.activeDuration),
    );
  }

  Future<List<CycleItemCompletion>> listCycleCompletions(
    String cycleId,
  ) async => _guard(() async {
    final rows = await (_database.select(
      _database.cycleItemCompletions,
    )..where((row) => row.cycleId.equals(cycleId))).get();
    return List.unmodifiable(
      rows.map(
        (row) => CycleItemCompletion(
          cycleId: row.cycleId,
          trainingSetItemId: row.trainingSetItemId,
          completedAt: _date(row.completedAtMicros),
        ),
      ),
    );
  });

  Future<void> addItem(TrainingSetItem item) => _sets.addItem(item);
  Future<void> removeItem({
    required String trainingSetId,
    required String itemId,
  }) => _sets.removeItem(trainingSetId: trainingSetId, itemId: itemId);
  Future<void> reorderItems({
    required String trainingSetId,
    required List<String> orderedItemIds,
  }) => _sets.reorderItems(
    trainingSetId: trainingSetId,
    orderedItemIds: orderedItemIds,
  );

  Future<TimingSegment?> _openSegment(String attemptId) async =>
      (await listTimingSegments(attemptId))
          .where((row) => row.endedAt == null)
          .firstOrNull;

  static bool _sameAttemptIdentity(PuzzleAttempt a, PuzzleAttempt b) =>
      a.id == b.id &&
      a.blockId == b.blockId &&
      a.cycleId == b.cycleId &&
      a.sessionId == b.sessionId &&
      a.startedAt == b.startedAt;

  static PuzzleAttempt _attempt(db.PuzzleAttempt row) => PuzzleAttempt(
    id: row.id,
    blockId: row.blockId,
    cycleId: row.cycleId,
    sessionId: row.sessionId,
    status: PuzzleAttemptStatus.fromDatabaseValue(row.status),
    startedAt: _date(row.startedAtMicros),
    completedAt: row.completedAtMicros == null
        ? null
        : _date(row.completedAtMicros!),
    activeDuration: Duration(milliseconds: row.activeMilliseconds),
    outcome: row.outcome == null
        ? null
        : PuzzleAttemptOutcome.fromDatabaseValue(row.outcome!),
    failureReason: row.failureReason == null
        ? null
        : PuzzleAttemptFailureReason.fromDatabaseValue(row.failureReason!),
    wrongMoveCount: row.wrongMoveCount,
    hintCount: row.hintCount,
    revealed: row.revealed,
  );

  static PuzzleAttemptsCompanion _attemptInsert(PuzzleAttempt a) =>
      PuzzleAttemptsCompanion.insert(
        id: a.id,
        blockId: a.blockId,
        cycleId: a.cycleId,
        sessionId: a.sessionId,
        status: a.status.toDatabaseValue(),
        outcome: Value(a.outcome?.toDatabaseValue()),
        failureReason: Value(a.failureReason?.toDatabaseValue()),
        startedAtMicros: _micros(a.startedAt),
        completedAtMicros: Value(_nullableMicros(a.completedAt)),
        activeMilliseconds: Value(a.activeDuration.inMilliseconds),
        wrongMoveCount: Value(a.wrongMoveCount),
        hintCount: Value(a.hintCount),
        revealed: Value(a.revealed),
      );

  static PuzzleAttemptsCompanion _attemptUpdate(PuzzleAttempt a) =>
      PuzzleAttemptsCompanion(
        status: Value(a.status.toDatabaseValue()),
        outcome: Value(a.outcome?.toDatabaseValue()),
        failureReason: Value(a.failureReason?.toDatabaseValue()),
        completedAtMicros: Value(_nullableMicros(a.completedAt)),
        activeMilliseconds: Value(a.activeDuration.inMilliseconds),
        wrongMoveCount: Value(a.wrongMoveCount),
        hintCount: Value(a.hintCount),
        revealed: Value(a.revealed),
      );

  static TimingSegment _timing(db.TimingSegment row) => TimingSegment(
    id: row.id,
    attemptId: row.attemptId,
    sessionId: row.sessionId,
    startedAt: _date(row.startedAtMicros),
    endedAt: row.endedAtMicros == null ? null : _date(row.endedAtMicros!),
    activeDuration: row.activeMilliseconds == null
        ? null
        : Duration(milliseconds: row.activeMilliseconds!),
  );

  static Cycle _cycle(db.Cycle row) => Cycle(
    id: row.id,
    trainingSetId: row.trainingSetId,
    status: CycleStatus.fromDatabaseValue(row.status),
    startedAt: row.startedAtMicros == null ? null : _date(row.startedAtMicros!),
    completedAt: row.completedAtMicros == null
        ? null
        : _date(row.completedAtMicros!),
    stoppedAt: row.stoppedAtMicros == null ? null : _date(row.stoppedAtMicros!),
    createdAt: _date(row.createdAtMicros),
  );

  static TrainingSession _session(db.TrainingSession row) => TrainingSession(
    id: row.id,
    cycleId: row.cycleId,
    status: TrainingSessionStatus.fromDatabaseValue(row.status),
    startedAt: _date(row.startedAtMicros),
    endedAt: row.endedAtMicros == null ? null : _date(row.endedAtMicros!),
    studyDay: _date(row.studyDayMicros),
  );

  ProgressAggregate _aggregate(
    List<db.PuzzleAttempt> rows, {
    int completedNonPuzzleItemCount = 0,
  }) {
    final attempts = rows.map(_attempt).toList();
    final outcomes = <PuzzleAttemptOutcome, int>{
      for (final outcome in PuzzleAttemptOutcome.values) outcome: 0,
    };
    var wrongMoves = 0;
    var hints = 0;
    for (final attempt in attempts) {
      outcomes[attempt.outcome!] = outcomes[attempt.outcome!]! + 1;
      wrongMoves += attempt.wrongMoveCount;
      hints += attempt.hintCount;
    }
    return ProgressAggregate(
      passedCount: outcomes[PuzzleAttemptOutcome.passed]!,
      wrongMoveOutcomeCount: outcomes[PuzzleAttemptOutcome.wrongMove]!,
      revealedCount: outcomes[PuzzleAttemptOutcome.revealed]!,
      skippedCount: outcomes[PuzzleAttemptOutcome.skipped]!,
      timedOutCount: outcomes[PuzzleAttemptOutcome.timedOut]!,
      abandonedCount: outcomes[PuzzleAttemptOutcome.abandoned]!,
      wrongMoveCount: wrongMoves,
      hintCount: hints,
      attemptActiveDurations: attempts.map((attempt) => attempt.activeDuration),
      completedNonPuzzleItemCount: completedNonPuzzleItemCount,
    );
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const DatabaseFailure(
        code: 'training_persistence_failed',
        message: 'Training progress could not be saved or loaded. Retry the operation.',
      );
    }
  }

  static int _micros(DateTime value) => value.toUtc().microsecondsSinceEpoch;
  static int? _nullableMicros(DateTime? value) =>
      value?.toUtc().microsecondsSinceEpoch;
  static DateTime _date(int value) =>
      DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true);
  static void _invalid(String message) => throw ValidationFailure(
    code: 'invalid_training_transition',
    message: message,
  );
  static void _missing(String code, String message) =>
      throw ValidationFailure(code: code, message: message);
}
