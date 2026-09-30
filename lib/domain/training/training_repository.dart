import 'attempt_move.dart';
import 'cycle.dart';
import 'progress_aggregate.dart';
import 'progress_report_data.dart';
import 'puzzle_attempt.dart';
import 'timing_segment.dart';
import 'training_session.dart';
import 'training_set.dart';

/// Persists training organization, lifecycle records, and local progress.
///
/// This interface is platform-neutral and describes domain records only.
/// Implementations must make each progress-affecting multi-record operation
/// atomic. Finalized [PuzzleAttempt] records are immutable history: subsequent
/// retries create separate records and must never replace a prior result.
abstract interface class TrainingRepository {
  /// Returns the set identified by [id], or `null` when it does not exist.
  Future<TrainingSet?> getSet(String id);

  /// Returns sets in a deterministic order, with stable tie-breaking.
  Future<List<TrainingSet>> listSets();

  /// Creates a set and its ordered items as one operation.
  ///
  /// Fails if the set or any item identity already exists, or if item
  /// references violate the set's invariants.
  Future<void> createSet(TrainingSet set);

  /// Replaces a set's mutable definition while preserving its identity and
  /// creation time. Existing cycle and attempt history must remain available.
  Future<void> updateSet(TrainingSet set);

  /// Returns the cycle identified by [id], or `null` when it does not exist.
  Future<Cycle?> getCycle(String id);

  /// Returns cycles for [trainingSetId] in stable creation order.
  Future<List<Cycle>> listCycles(String trainingSetId);

  /// Creates a new cycle record. A second active cycle for the same set must
  /// be rejected; starting a later cycle must create a new identity.
  Future<void> createCycle(Cycle cycle);

  /// Updates lifecycle fields on a cycle without changing its identity or
  /// training-set association.
  Future<void> updateCycle(Cycle cycle);

  /// Returns the session identified by [id], or `null` when absent.
  Future<TrainingSession?> getSession(String id);

  /// Returns sessions for [cycleId] in start-time order with stable tie-breaks.
  Future<List<TrainingSession>> listSessions(String cycleId);

  /// Creates a session associated with an existing cycle.
  Future<void> createSession(TrainingSession session);

  /// Updates the lifecycle of an existing session, preserving its identity,
  /// cycle association, and original start time.
  Future<void> updateSession(TrainingSession session);

  /// Returns the attempt identified by [id], or `null` when absent.
  Future<PuzzleAttempt?> getAttempt(String id);

  /// Returns attempts for [cycleId] in start-time order with stable tie-breaks.
  Future<List<PuzzleAttempt>> listAttempts(String cycleId);

  /// Creates an unfinished attempt. Its ID is unique and it is retained as a
  /// distinct record even when the same exercise is attempted again.
  Future<void> createAttempt(PuzzleAttempt attempt);

  /// Updates mutable fields of an unfinished attempt only.
  ///
  /// Implementations must reject this operation once the attempt has an
  /// outcome and completion time. Finalized results are append-only history.
  Future<void> updateUnfinishedAttempt(PuzzleAttempt attempt);

  /// Atomically records one submitted move with its resulting attempt state.
  ///
  /// [move] must belong to [updatedAttempt], have the next ordinal, and not
  /// replace an existing move. The attempt identity and its immutable context
  /// (exercise, cycle, session, and start time) must match the stored
  /// unfinished attempt. [updatedAttempt] includes the resulting counters and
  /// lifecycle state. If the move finalizes the attempt, the finalized attempt
  /// and optional [closingTimingSegment] must be committed in the same
  /// transaction; a failure must leave the prior attempt, move history, and
  /// timing data unchanged. For a non-terminal move, the attempt remains
  /// unfinished and [closingTimingSegment] must be null. A closing segment,
  /// when supplied, must be the open segment for this attempt and contain the
  /// final monotonic active duration.
  Future<void> recordSubmittedMove({
    required AttemptMove move,
    required PuzzleAttempt updatedAttempt,
    TimingSegment? closingTimingSegment,
  });

  /// Returns recorded moves in ordinal order.
  Future<List<AttemptMove>> listAttemptMoves(String attemptId);

  /// Returns timing segments for [attemptId] in start-time order.
  Future<List<TimingSegment>> listTimingSegments(String attemptId);

  /// Opens a new timing segment on an unfinished attempt.
  ///
  /// The segment identity must be unique. A segment is not a wall-clock
  /// estimate of elapsed time; its active duration is measured monotonically
  /// and is recorded when it closes.
  Future<void> startTimingSegment(TimingSegment segment);

  /// Closes an open segment and adds its active duration to the unfinished
  /// attempt atomically.
  ///
  /// Both records must remain unchanged if either write fails. The segment
  /// must belong to the attempt, and the attempt must still be unfinished.
  Future<void> closeTimingSegment({
    required TimingSegment segment,
    required PuzzleAttempt updatedAttempt,
  });

  /// Finalizes an unfinished attempt and optionally closes its active timing
  /// segment in the same transaction.
  ///
  /// The finalized attempt and final segment must either both be committed or
  /// neither committed. This operation must reject an already finalized
  /// attempt and must not mutate any previously finalized attempt, moves, or
  /// timing segments. A `null` segment means the attempt was already paused.
  Future<void> finalizeAttempt({
    required PuzzleAttempt attempt,
    TimingSegment? finalTimingSegment,
  });

  /// Marks an Instruction or Demonstration item complete for one cycle.
  ///
  /// Completion is scoped to [cycleId]; it must not change shared set-item
  /// state or create a scored puzzle attempt. Repeating this operation for an
  /// already completed cycle/item pair is idempotent. Implementations must
  /// reject puzzle items and items that do not belong to the cycle's set.
  /// The domain contract requires this state to be durable, while deliberately
  /// leaving its storage representation to the persistence schema.
  Future<void> completeNonPuzzleItem({
    required String cycleId,
    required String trainingSetItemId,
    required DateTime completedAt,
  });

  /// Returns completed Instruction and Demonstration item IDs for [cycleId].
  ///
  /// The returned IDs are stable training-set-item identities, not positions.
  Future<Set<String>> completedNonPuzzleItemIds(String cycleId);

  /// Returns the retained completion timestamp for one cycle item, if any.
  Future<DateTime?> nonPuzzleItemCompletedAt({
    required String cycleId,
    required String trainingSetItemId,
  });

  /// Returns raw progress inputs for all finalized puzzle attempts in a set.
  ///
  /// The aggregate preserves per-attempt active durations and keeps completed
  /// non-puzzle item time separate from scored puzzle time. Accuracy, averages,
  /// medians, and other display metrics are calculated outside persistence.
  Future<ProgressAggregate> aggregateForSet(String trainingSetId);

  /// Returns the same raw progress inputs restricted to one cycle.
  Future<ProgressAggregate> aggregateForCycle(String cycleId);

  /// Returns raw progress inputs for finalized attempts in one session.
  Future<ProgressAggregate> aggregateForSession(String sessionId);

  /// Returns a report entry for each session in a cycle, including empty ones.
  Future<List<SessionProgressAggregate>> sessionAggregatesForCycle(
    String cycleId,
  );

  /// Returns append-only attempt history grouped by exercise within a cycle.
  Future<List<ExerciseProgressHistory>> exerciseHistoryForCycle(String cycleId);

  /// Returns raw progress grouped by non-empty theme metadata in a cycle.
  Future<List<MetadataProgressAggregate>> themeAggregatesForCycle(
    String cycleId,
  );

  /// Returns raw progress grouped by non-empty difficulty metadata in a cycle.
  Future<List<MetadataProgressAggregate>> difficultyAggregatesForCycle(
    String cycleId,
  );
}

/// Optional transaction boundary for coordinating multiple repository writes.
///
/// Lifecycle services use this when available so a cycle/session/attempt
/// transition either commits all records or leaves the prior state untouched.
abstract interface class AtomicTrainingRepository {
  Future<T> transaction<T>(Future<T> Function() action);
}
