import '../chess_content/content_type.dart';
import 'attempt_move.dart';
import 'cycle.dart';
import 'puzzle_attempt.dart';
import 'timing_segment.dart';
import 'training_session.dart';
import 'training_set_item.dart';

/// Durable completion of a Text item in one cycle.
///
/// Completion is scoped to a cycle, so repeating the set in a later cycle does
/// not inherit this progress.
final class CycleItemCompletion {
  CycleItemCompletion({
    required this.cycleId,
    required this.trainingSetItemId,
    required this.completedAt,
  }) {
    if (cycleId.isEmpty) {
      throw ArgumentError.value(cycleId, 'cycleId', 'Must not be empty.');
    }
    if (trainingSetItemId.isEmpty) {
      throw ArgumentError.value(
        trainingSetItemId,
        'trainingSetItemId',
        'Must not be empty.',
      );
    }
  }

  final String cycleId;
  final String trainingSetItemId;
  final DateTime completedAt;
}

/// Result of resuming a session, including a newly opened attempt segment
/// when the session contained a paused puzzle attempt.
final class TrainingSessionResumeResult {
  const TrainingSessionResumeResult({
    required this.session,
    required this.resumedAttemptSegment,
  });

  final TrainingSession session;
  final TimingSegment? resumedAttemptSegment;
}

/// Coordinates durable training-cycle, session, and attempt transitions.
///
/// This contract is independent of Flutter and persistence implementations.
/// Implementations must make each progress-affecting transition atomic and
/// preserve finalized attempts as history. Implementations may obtain stable
/// record IDs and a monotonic clock from injected platform-neutral providers.
abstract interface class TrainingSessionService {
  /// Starts the next cycle for [trainingSetId], or resumes its active cycle.
  ///
  /// A set may have at most one active cycle. Starting a new cycle creates a
  /// new cycle record; resuming returns the existing active cycle unchanged.
  /// [startedAt] is the wall-clock time used only when a new cycle is created.
  /// Throws when the set does not exist, is archived, or cannot be trained.
  Future<Cycle> startOrResumeCycle({
    required String trainingSetId,
    required DateTime startedAt,
  });

  /// Opens a study session for an active [cycleId].
  ///
  /// [studyDay] is the calendar day used for grouping history; it is not used
  /// to calculate active duration. Throws when the cycle is missing or is not
  /// active, or when another session for the cycle is still active.
  Future<TrainingSession> openSession({
    required String cycleId,
    required DateTime startedAt,
    required DateTime studyDay,
  });

  /// Pauses an active session at [pausedAt].
  ///
  /// If the session owns an active attempt, the implementation also closes
  /// its active timing segment and pauses that attempt in the same durable
  /// transition. [activeAttemptSegmentDuration] is the monotonic elapsed time
  /// for that segment, or null when there is no active attempt. It must not be
  /// negative. The session can later be resumed without counting the paused
  /// interval.
  Future<TrainingSession> pauseSession({
    required String sessionId,
    required DateTime pausedAt,
    required Duration? activeAttemptSegmentDuration,
  });

  /// Resumes a paused session and any unfinished paused attempt it contains.
  ///
  /// A new attempt timing segment is opened when an attempt is resumed. The
  /// returned segment is null when the session has no paused attempt.
  Future<TrainingSessionResumeResult> resumeSession({
    required String sessionId,
    required DateTime resumedAt,
  });

  /// Recovers a session interrupted while active and leaves unfinished work
  /// resumable.
  ///
  /// The session is ended with `recovered` status. Any unfinished attempt is
  /// paused and its open segment is closed at the last durable lifecycle
  /// boundary; unmeasurable time since that boundary is excluded. A later
  /// session may resume that same attempt with a fresh timing segment.
  Future<TrainingSession> recoverSession({
    required String sessionId,
    required DateTime recoveredAt,
  });

  /// Closes an active or paused session at [endedAt].
  ///
  /// Any active attempt must first be paused or finalized so its active timing
  /// segment is closed. Session wall-clock duration must not be counted as
  /// puzzle-solving time.
  Future<TrainingSession> closeSession({
    required String sessionId,
    required DateTime endedAt,
  });

  /// Returns the unfinished exercise first, otherwise the next pending item
  /// in set order for [cycleId].
  ///
  /// Puzzle completion is determined from this cycle's attempt history;
  /// text completion is tracked per cycle. Returns
  /// `null` when every item is complete. It does not create a puzzle attempt.
  Future<TrainingSetItem?> selectNextItem({required String cycleId});

  /// Creates an unfinished attempt for a Puzzle item and opens its first
  /// timing segment.
  ///
  /// The item must belong to the active cycle's set, the session must be
  /// active in that cycle, and no unfinished attempt may already exist for
  /// that item in the cycle. Retrying after finalization creates a new attempt
  /// identity. The attempt and its open timing segment are committed together.
  Future<PuzzleAttempt> startAttempt({
    required String cycleId,
    required String sessionId,
    required String trainingSetItemId,
    required DateTime startedAt,
  });

  /// Marks a Text item as traversed in [cycleId].
  ///
  /// The item must belong to the cycle's set and have content type
  /// [ContentType.text]. The completion
  /// is durably keyed by cycle and set-item identity, and this operation is
  /// idempotent: repeating it returns the existing completion. This is not a
  /// scored puzzle attempt.
  Future<CycleItemCompletion> completeNonPuzzleItem({
    required String cycleId,
    required String trainingSetItemId,
    required DateTime completedAt,
  });

  /// Pauses an unfinished attempt and closes its active timing segment.
  ///
  /// [activeSegmentDuration] must be measured with a monotonic clock and must
  /// exclude time before the segment began. The persisted attempt's cumulative
  /// active duration is increased by this value. Throws when the attempt is
  /// finalized, not active, or the duration is negative.
  Future<PuzzleAttempt> pauseAttempt({
    required String attemptId,
    required DateTime pausedAt,
    required Duration activeSegmentDuration,
  });

  /// Persists one evaluated move; terminal moves close the current segment.
  Future<PuzzleAttempt> recordSubmittedMove({
    required AttemptMove move,
    required PuzzleAttempt updatedAttempt,
    Duration activeSegmentDuration = Duration.zero,
  });

  /// Resumes an unfinished paused attempt by starting a new timing segment.
  ///
  /// [resumedAt] is the wall-clock audit time; active duration starts from a
  /// fresh monotonic clock reading. The returned segment is the newly opened
  /// segment. Throws when the attempt is finalized or is not paused.
  Future<TimingSegment> resumeAttempt({
    required String attemptId,
    String? sessionId,
    required DateTime resumedAt,
  });

  /// Finalizes an unfinished attempt, closing its active segment if present.
  ///
  /// [outcome] records the terminal result without replacing an earlier
  /// attempt. [activeSegmentDuration] is the monotonic elapsed duration since
  /// the currently open segment began, or zero when the attempt is paused.
  /// [failureReason] is required for `wrongMove`, `timedOut`, and `abandoned`;
  /// it is absent for `passed`, `revealed`, and `skipped`. A `revealed` outcome
  /// must set [revealed] to true. The final attempt and any closing timing
  /// segment must be committed atomically.
  ///
  /// Throws when [attemptId] is unknown, the attempt is already finalized, the
  /// outcome metadata is inconsistent, or [activeSegmentDuration] is negative.
  Future<PuzzleAttempt> finalizeAttempt({
    required String attemptId,
    required PuzzleAttemptOutcome outcome,
    required DateTime completedAt,
    Duration activeSegmentDuration = Duration.zero,
    PuzzleAttemptFailureReason? failureReason,
    bool revealed = false,
  });

  /// Completes an active cycle after every required item has been traversed
  /// and each Puzzle has a finalized attempt.
  ///
  /// Text items must have durable cycle-item
  /// completions. This creates no new attempt and preserves the cycle record.
  Future<Cycle> completeCycle({
    required String cycleId,
    required DateTime completedAt,
  });
}
