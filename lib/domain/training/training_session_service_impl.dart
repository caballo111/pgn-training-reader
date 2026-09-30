// ignore_for_file: prefer_initializing_formals

import '../../core/errors/app_failure.dart';
import '../../core/time/app_clock.dart';
import '../../core/utilities/id_generator.dart';
import '../chess_content/content_type.dart';
import 'attempt_move.dart';
import 'active_time_tracker.dart';
import 'cycle.dart';
import 'lifecycle_status.dart';
import 'puzzle_attempt.dart';
import 'timing_segment.dart';
import 'training_repository.dart';
import 'training_session.dart';
import 'training_session_service.dart';
import 'training_set.dart';
import 'training_set_item.dart';

/// Repository-backed implementation of training cycle and attempt lifecycle.
final class TrainingSessionServiceImpl implements TrainingSessionService {
  TrainingSessionServiceImpl({
    required TrainingRepository repository,
    required AppClock clock,
    required IdGenerator idGenerator,
  }) : _repository = repository,
       _idGenerator = idGenerator,
       _timeTracker = ActiveTimeTracker(clock: clock, idGenerator: idGenerator);

  final TrainingRepository _repository;
  final IdGenerator _idGenerator;
  final ActiveTimeTracker _timeTracker;

  @override
  Future<Cycle> startOrResumeCycle({
    required String trainingSetId,
    required DateTime startedAt,
  }) async {
    final set = await _repository.getSet(trainingSetId);
    if (set == null ||
        set.status != TrainingSetStatus.active ||
        set.items.isEmpty) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Training set is missing or cannot be trained.',
      );
    }
    final cycles = await _repository.listCycles(trainingSetId);
    for (final cycle in cycles) {
      if (cycle.status == CycleStatus.active) return cycle;
    }
    final cycle = Cycle(
      id: _idGenerator.generateId(),
      trainingSetId: trainingSetId,
      status: CycleStatus.active,
      startedAt: startedAt.toUtc(),
      createdAt: startedAt.toUtc(),
    );
    await _atomic(() => _repository.createCycle(cycle));
    return cycle;
  }

  @override
  Future<TrainingSession> openSession({
    required String cycleId,
    required DateTime startedAt,
    required DateTime studyDay,
  }) async {
    final cycle = await _repository.getCycle(cycleId);
    if (cycle == null || cycle.status != CycleStatus.active) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'An active cycle is required to open a session.',
      );
    }
    final sessions = await _repository.listSessions(cycleId);
    if (sessions.any(
      (session) => session.status == TrainingSessionStatus.active,
    )) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'The cycle already has an active session.',
      );
    }
    final session = TrainingSession(
      id: _idGenerator.generateId(),
      cycleId: cycleId,
      status: TrainingSessionStatus.active,
      startedAt: startedAt.toUtc(),
      studyDay: DateTime.utc(studyDay.year, studyDay.month, studyDay.day),
    );
    final pausedAttempt = await _pausedAttempt(cycleId);
    await _atomic(() async {
      await _repository.createSession(session);
      if (pausedAttempt != null) {
        await resumeAttempt(
          attemptId: pausedAttempt.id,
          sessionId: session.id,
          resumedAt: startedAt,
        );
      }
    });
    return session;
  }

  @override
  Future<TrainingSession> pauseSession({
    required String sessionId,
    required DateTime pausedAt,
    required Duration? activeAttemptSegmentDuration,
  }) async {
    if (activeAttemptSegmentDuration?.isNegative ?? false) {
      throw ArgumentError.value(
        activeAttemptSegmentDuration,
        'activeAttemptSegmentDuration',
      );
    }
    final session = await _requireSession(sessionId);
    if (session.status != TrainingSessionStatus.active) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Only an active session can be paused.',
      );
    }
    final attempt = await _activeAttempt(sessionId);
    if ((attempt == null) != (activeAttemptSegmentDuration == null)) {
      throw ArgumentError(
        'Segment duration must be supplied exactly when an attempt is active.',
      );
    }
    final updated = TrainingSession(
      id: session.id,
      cycleId: session.cycleId,
      status: TrainingSessionStatus.paused,
      startedAt: session.startedAt,
      studyDay: session.studyDay,
    );
    await _atomic(() async {
      if (attempt != null) {
        await pauseAttempt(
          attemptId: attempt.id,
          pausedAt: pausedAt,
          activeSegmentDuration: activeAttemptSegmentDuration!,
        );
      }
      await _repository.updateSession(updated);
    });
    return updated;
  }

  @override
  Future<TrainingSessionResumeResult> resumeSession({
    required String sessionId,
    required DateTime resumedAt,
  }) async {
    final session = await _requireSession(sessionId);
    if (session.status != TrainingSessionStatus.paused) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Only a paused session can be resumed.',
      );
    }
    final updated = TrainingSession(
      id: session.id,
      cycleId: session.cycleId,
      status: TrainingSessionStatus.active,
      startedAt: session.startedAt,
      studyDay: session.studyDay,
    );
    final pausedAttempt = await _pausedAttempt(session.cycleId);
    TimingSegment? segment;
    await _atomic(() async {
      await _repository.updateSession(updated);
      if (pausedAttempt != null) {
        segment = await resumeAttempt(
          attemptId: pausedAttempt.id,
          sessionId: sessionId,
          resumedAt: resumedAt,
        );
      }
    });
    return TrainingSessionResumeResult(
      session: updated,
      resumedAttemptSegment: segment,
    );
  }

  @override
  Future<TrainingSession> recoverSession({
    required String sessionId,
    required DateTime recoveredAt,
  }) async {
    final session = await _requireSession(sessionId);
    if (session.status != TrainingSessionStatus.active) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Only an active session can be recovered.',
      );
    }
    final attempt = await _activeAttempt(sessionId);
    final recovered = TrainingSession(
      id: session.id,
      cycleId: session.cycleId,
      status: TrainingSessionStatus.recovered,
      startedAt: session.startedAt,
      endedAt: recoveredAt.toUtc().isBefore(session.startedAt)
          ? session.startedAt
          : recoveredAt.toUtc(),
      studyDay: session.studyDay,
    );
    await _atomic(() async {
      if (attempt != null) await recoverAttempt(attempt.id);
      await _repository.updateSession(recovered);
    });
    return recovered;
  }

  @override
  Future<TrainingSession> closeSession({
    required String sessionId,
    required DateTime endedAt,
  }) async {
    final session = await _requireSession(sessionId);
    if (session.status != TrainingSessionStatus.active &&
        session.status != TrainingSessionStatus.paused) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Only an unfinished session can be closed.',
      );
    }
    if (await _activeAttempt(sessionId) != null) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message:
            'Pause or finalize the active attempt before closing the session.',
      );
    }
    final closed = TrainingSession(
      id: session.id,
      cycleId: session.cycleId,
      status: TrainingSessionStatus.closed,
      startedAt: session.startedAt,
      endedAt: endedAt.toUtc(),
      studyDay: session.studyDay,
    );
    await _repository.updateSession(closed);
    return closed;
  }

  @override
  Future<TrainingSetItem?> selectNextItem({required String cycleId}) async {
    final cycle = await _repository.getCycle(cycleId);
    if (cycle == null || cycle.status != CycleStatus.active) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Active cycle not found.',
      );
    }
    final set = await _requireSet(cycle.trainingSetId);
    final completed = await _repository.completedNonPuzzleItemIds(cycleId);
    final attempts = await _repository.listAttempts(cycleId);
    for (final item in set.items) {
      if (item.contentType == ContentType.puzzle) {
        final unfinished = attempts.any(
          (a) =>
              a.blockId == item.blockId &&
              a.status != PuzzleAttemptStatus.finalized,
        );
        if (unfinished) return item;
      }
    }
    for (final item in set.items) {
      if (item.contentType == ContentType.puzzle) {
        if (!attempts.any(
          (a) =>
              a.blockId == item.blockId &&
              a.status == PuzzleAttemptStatus.finalized,
        )) {
          return item;
        }
      } else if (!completed.contains(item.id)) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<PuzzleAttempt> startAttempt({
    required String cycleId,
    required String sessionId,
    required String trainingSetItemId,
    required DateTime startedAt,
  }) async {
    final cycle = await _repository.getCycle(cycleId);
    final session = await _requireSession(sessionId);
    if (cycle == null ||
        cycle.status != CycleStatus.active ||
        session.cycleId != cycleId ||
        session.status != TrainingSessionStatus.active) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Attempt requires an active session in an active cycle.',
      );
    }
    final set = await _requireSet(cycle.trainingSetId);
    final matches = set.items.where((item) => item.id == trainingSetItemId);
    if (matches.isEmpty || matches.single.contentType != ContentType.puzzle) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'A puzzle item in the cycle set is required.',
      );
    }
    final item = matches.single;
    final attempts = await _repository.listAttempts(cycleId);
    if (attempts.any(
      (a) =>
          a.blockId == item.blockId &&
          a.status != PuzzleAttemptStatus.finalized,
    )) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'An unfinished attempt already exists for this item.',
      );
    }
    final attempt = PuzzleAttempt(
      id: _idGenerator.generateId(),
      blockId: item.blockId,
      cycleId: cycleId,
      sessionId: sessionId,
      startedAt: startedAt.toUtc(),
    );
    try {
      await _atomic(() async {
        final segment = _timeTracker.startSegment(
          attemptId: attempt.id,
          sessionId: sessionId,
          startedAt: startedAt,
        );
        await _repository.createAttempt(attempt);
        await _repository.startTimingSegment(segment);
      });
    } catch (_) {
      _timeTracker.recover(attemptId: attempt.id);
      rethrow;
    }
    return attempt;
  }

  @override
  Future<CycleItemCompletion> completeNonPuzzleItem({
    required String cycleId,
    required String trainingSetItemId,
    required DateTime completedAt,
  }) async {
    final cycle = await _repository.getCycle(cycleId);
    if (cycle == null || cycle.status != CycleStatus.active) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Active cycle not found.',
      );
    }
    final set = await _requireSet(cycle.trainingSetId);
    final items = set.items.where((item) => item.id == trainingSetItemId);
    if (items.isEmpty || items.single.contentType == ContentType.puzzle) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'A cycle instruction or demonstration is required.',
      );
    }
    await _repository.completeNonPuzzleItem(
      cycleId: cycleId,
      trainingSetItemId: trainingSetItemId,
      completedAt: completedAt.toUtc(),
    );
    final retainedCompletedAt = await _repository.nonPuzzleItemCompletedAt(
      cycleId: cycleId,
      trainingSetItemId: trainingSetItemId,
    );
    return CycleItemCompletion(
      cycleId: cycleId,
      trainingSetItemId: trainingSetItemId,
      completedAt: retainedCompletedAt ?? completedAt.toUtc(),
    );
  }

  @override
  Future<PuzzleAttempt> pauseAttempt({
    required String attemptId,
    required DateTime pausedAt,
    required Duration activeSegmentDuration,
  }) async {
    if (activeSegmentDuration.isNegative) {
      throw ArgumentError.value(activeSegmentDuration, 'activeSegmentDuration');
    }
    final attempt = await _requireAttempt(attemptId);
    if (attempt.status != PuzzleAttemptStatus.active) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Only an active attempt can be paused.',
      );
    }
    final segments = await _repository.listTimingSegments(attemptId);
    final open = segments.where((s) => s.endedAt == null).toList();
    if (open.length != 1) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Attempt must have exactly one open segment.',
      );
    }
    final duration = _timeTracker.currentSegmentDuration(attemptId);
    // Caller owns the monotonic reading to support lifecycle handoff.
    final usedDuration = activeSegmentDuration;
    if (duration > Duration.zero && duration != usedDuration) {
      // Trust the explicit duration passed by the lifecycle owner.
    }
    final updated = _copyAttempt(
      attempt,
      status: PuzzleAttemptStatus.paused,
      activeDuration: attempt.activeDuration + usedDuration,
    );
    final closedSegment = TimingSegment(
      id: open.single.id,
      attemptId: attemptId,
      sessionId: open.single.sessionId,
      startedAt: open.single.startedAt,
      endedAt: pausedAt.toUtc(),
      activeDuration: usedDuration,
    );
    await _repository.closeTimingSegment(
      segment: closedSegment,
      updatedAttempt: updated,
    );
    _timeTracker.recover(attemptId: attemptId);
    return updated;
  }

  @override
  Future<TimingSegment> resumeAttempt({
    required String attemptId,
    String? sessionId,
    required DateTime resumedAt,
  }) async {
    final attempt = await _requireAttempt(attemptId);
    if (attempt.status != PuzzleAttemptStatus.paused) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Only a paused attempt can resume.',
      );
    }
    final updated = _copyAttempt(attempt, status: PuzzleAttemptStatus.active);
    late TimingSegment segment;
    try {
      await _atomic(() async {
        await _repository.updateUnfinishedAttempt(updated);
        segment = _timeTracker.resumeSegment(
          attemptId: attemptId,
          sessionId: sessionId ?? attempt.sessionId,
          startedAt: resumedAt,
        );
        await _repository.startTimingSegment(segment);
      });
      return segment;
    } catch (_) {
      _timeTracker.recover(attemptId: attemptId);
      rethrow;
    }
  }

  @override
  Future<PuzzleAttempt> recordSubmittedMove({
    required AttemptMove move,
    required PuzzleAttempt updatedAttempt,
    Duration activeSegmentDuration = Duration.zero,
  }) async {
    if (activeSegmentDuration.isNegative) {
      throw ArgumentError.value(activeSegmentDuration, 'activeSegmentDuration');
    }
    final current = await _requireAttempt(updatedAttempt.id);
    if (current.status != PuzzleAttemptStatus.active ||
        current.id != move.attemptId ||
        updatedAttempt.id != current.id) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'A move requires its matching active attempt.',
      );
    }
    final terminal = updatedAttempt.status == PuzzleAttemptStatus.finalized;
    if (terminal && updatedAttempt.completedAt == null) {
      throw ArgumentError('Finalized move requires a completion timestamp.');
    }
    final open = terminal
        ? (await _repository.listTimingSegments(current.id))
              .where((segment) => segment.endedAt == null)
              .toList()
        : <TimingSegment>[];
    if (terminal && open.length != 1) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Finalized attempt must have one open timing segment.',
      );
    }
    final persisted = terminal
        ? _copyAttempt(
            updatedAttempt,
            activeDuration: current.activeDuration + activeSegmentDuration,
          )
        : updatedAttempt;
    final closing = terminal
        ? TimingSegment(
            id: open.single.id,
            attemptId: current.id,
            sessionId: open.single.sessionId,
            startedAt: open.single.startedAt,
            endedAt: persisted.completedAt,
            activeDuration: activeSegmentDuration,
          )
        : null;
    await _atomic(
      () => _repository.recordSubmittedMove(
        move: move,
        updatedAttempt: persisted,
        closingTimingSegment: closing,
      ),
    );
    if (terminal) _timeTracker.recover(attemptId: current.id);
    return persisted;
  }

  @override
  Future<PuzzleAttempt> finalizeAttempt({
    required String attemptId,
    required PuzzleAttemptOutcome outcome,
    required DateTime completedAt,
    Duration activeSegmentDuration = Duration.zero,
    PuzzleAttemptFailureReason? failureReason,
    bool revealed = false,
  }) async {
    if (activeSegmentDuration.isNegative) {
      throw ArgumentError.value(activeSegmentDuration, 'activeSegmentDuration');
    }
    final attempt = await _requireAttempt(attemptId);
    if (attempt.status == PuzzleAttemptStatus.finalized) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Attempt is already finalized.',
      );
    }
    final segments = await _repository.listTimingSegments(attemptId);
    final open = segments.where((s) => s.endedAt == null).toList();
    if (open.length > 1) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Attempt has multiple open timing segments.',
      );
    }
    final duration =
        attempt.activeDuration +
        (open.isEmpty ? Duration.zero : activeSegmentDuration);
    final finalized = PuzzleAttempt(
      id: attempt.id,
      blockId: attempt.blockId,
      cycleId: attempt.cycleId,
      sessionId: attempt.sessionId,
      status: PuzzleAttemptStatus.finalized,
      startedAt: attempt.startedAt,
      completedAt: completedAt.toUtc(),
      activeDuration: duration,
      outcome: outcome,
      failureReason: failureReason,
      wrongMoveCount: attempt.wrongMoveCount,
      hintCount: attempt.hintCount,
      revealed: revealed,
    );
    final segment = open.isEmpty
        ? null
        : TimingSegment(
            id: open.single.id,
            attemptId: attemptId,
            sessionId: open.single.sessionId,
            startedAt: open.single.startedAt,
            endedAt: completedAt.toUtc(),
            activeDuration: activeSegmentDuration,
          );
    await _atomic(
      () => _repository.finalizeAttempt(
        attempt: finalized,
        finalTimingSegment: segment,
      ),
    );
    _timeTracker.recover(attemptId: attemptId);
    return finalized;
  }

  @override
  Future<Cycle> completeCycle({
    required String cycleId,
    required DateTime completedAt,
  }) async {
    final cycle = await _repository.getCycle(cycleId);
    if (cycle == null || cycle.status != CycleStatus.active) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Active cycle not found.',
      );
    }
    final set = await _requireSet(cycle.trainingSetId);
    final attempts = await _repository.listAttempts(cycleId);
    final completed = await _repository.completedNonPuzzleItemIds(cycleId);
    if (attempts.any(
      (attempt) => attempt.status != PuzzleAttemptStatus.finalized,
    )) {
      throw ValidationFailure(
        code: 'unfinished_attempts_remain',
        message: 'Pause or finalize unfinished puzzle work before completing the cycle.',
      );
    }
    for (final item in set.items) {
      if (item.contentType == ContentType.puzzle) {
        if (!attempts.any(
          (a) =>
              a.blockId == item.blockId &&
              a.status == PuzzleAttemptStatus.finalized,
        )) {
          throw ValidationFailure(
            code: 'invalid_training_transition',
            message: 'Every puzzle requires a finalized attempt.',
          );
        }
      } else if (!completed.contains(item.id)) {
        throw ValidationFailure(
          code: 'invalid_training_transition',
          message: 'Every ordered non-puzzle item must be traversed.',
        );
      }
    }
    final result = Cycle(
      id: cycle.id,
      trainingSetId: cycle.trainingSetId,
      status: CycleStatus.completed,
      startedAt: cycle.startedAt,
      completedAt: completedAt.toUtc(),
      createdAt: cycle.createdAt,
    );
    await _repository.updateCycle(result);
    return result;
  }

  /// Closes an open attempt at its persisted start boundary after process loss.
  Future<PuzzleAttempt> recoverAttempt(String attemptId) async {
    final attempt = await _requireAttempt(attemptId);
    if (attempt.status != PuzzleAttemptStatus.active) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Only active attempts can be recovered.',
      );
    }
    final segments = await _repository.listTimingSegments(attemptId);
    final open = segments.where((s) => s.endedAt == null).toList();
    if (open.length != 1) {
      throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Attempt must have exactly one open segment.',
      );
    }
    final current = open.single;
    final closed = TimingSegment(
      id: current.id,
      attemptId: attemptId,
      sessionId: current.sessionId,
      startedAt: current.startedAt,
      endedAt: current.startedAt,
      activeDuration: Duration.zero,
    );
    final paused = _copyAttempt(attempt, status: PuzzleAttemptStatus.paused);
    await _repository.closeTimingSegment(
      segment: closed,
      updatedAttempt: paused,
    );
    _timeTracker.recover(attemptId: attemptId);
    return paused;
  }

  Future<TrainingSession> _requireSession(String id) async =>
      await _repository.getSession(id) ??
      (throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Session not found.',
      ));
  Future<PuzzleAttempt> _requireAttempt(String id) async =>
      await _repository.getAttempt(id) ??
      (throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Attempt not found.',
      ));
  Future<TrainingSet> _requireSet(String id) async =>
      await _repository.getSet(id) ??
      (throw ValidationFailure(
        code: 'invalid_training_transition',
        message: 'Training set not found.',
      ));

  Future<PuzzleAttempt?> _activeAttempt(String sessionId) async {
    final session = await _requireSession(sessionId);
    final attempts = await _repository.listAttempts(session.cycleId);
    for (final attempt in attempts) {
      if (attempt.status != PuzzleAttemptStatus.active) continue;
      final segments = await _repository.listTimingSegments(attempt.id);
      if (segments.any(
        (segment) =>
            segment.endedAt == null &&
            (segment.sessionId ?? attempt.sessionId) == sessionId,
      )) {
        return attempt;
      }
    }
    return null;
  }

  Future<PuzzleAttempt?> _pausedAttempt(String cycleId) async {
    final cycle = await _repository.getCycle(cycleId);
    if (cycle == null) return null;
    final set = await _requireSet(cycle.trainingSetId);
    final attempts = await _repository.listAttempts(cycleId);
    for (final item in set.items) {
      if (item.contentType != ContentType.puzzle) continue;
      for (final attempt in attempts) {
        if (attempt.blockId == item.blockId &&
            attempt.status == PuzzleAttemptStatus.paused) {
          return attempt;
        }
      }
    }
    return null;
  }

  PuzzleAttempt _copyAttempt(
    PuzzleAttempt attempt, {
    PuzzleAttemptStatus? status,
    Duration? activeDuration,
  }) => PuzzleAttempt(
    id: attempt.id,
    blockId: attempt.blockId,
    cycleId: attempt.cycleId,
    sessionId: attempt.sessionId,
    status: status ?? attempt.status,
    startedAt: attempt.startedAt,
    completedAt: attempt.completedAt,
    activeDuration: activeDuration ?? attempt.activeDuration,
    outcome: attempt.outcome,
    failureReason: attempt.failureReason,
    wrongMoveCount: attempt.wrongMoveCount,
    hintCount: attempt.hintCount,
    revealed: attempt.revealed,
  );

  Future<T> _atomic<T>(Future<T> Function() action) {
    final repository = _repository;
    if (repository is AtomicTrainingRepository) {
      return (repository as AtomicTrainingRepository).transaction(action);
    }
    return action();
  }
}
