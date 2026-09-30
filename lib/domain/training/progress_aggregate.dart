import 'puzzle_attempt.dart';

/// Raw progress inputs for a set, cycle, or selected group of attempts.
///
/// This value deliberately stores counts and durations without deriving
/// accuracy, averages, medians, or other report metrics. Finalized puzzle
/// attempt durations are retained individually so a domain calculator can
/// apply one consistent inclusion policy. Time spent on completed Text items
/// is tracked separately from scored puzzle attempts.
final class ProgressAggregate {
  factory ProgressAggregate({
    required int passedCount,
    required int wrongMoveOutcomeCount,
    required int revealedCount,
    required int skippedCount,
    required int timedOutCount,
    required int abandonedCount,
    required int wrongMoveCount,
    required int hintCount,
    required Iterable<Duration> attemptActiveDurations,
    int completedNonPuzzleItemCount = 0,
    Duration nonPuzzleActiveDuration = Duration.zero,
  }) {
    final counts = <String, int>{
      'passedCount': passedCount,
      'wrongMoveOutcomeCount': wrongMoveOutcomeCount,
      'revealedCount': revealedCount,
      'skippedCount': skippedCount,
      'timedOutCount': timedOutCount,
      'abandonedCount': abandonedCount,
      'wrongMoveCount': wrongMoveCount,
      'hintCount': hintCount,
      'completedNonPuzzleItemCount': completedNonPuzzleItemCount,
    };
    for (final entry in counts.entries) {
      if (entry.value < 0) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Must not be negative.',
        );
      }
    }
    if (nonPuzzleActiveDuration.isNegative) {
      throw ArgumentError.value(
        nonPuzzleActiveDuration,
        'nonPuzzleActiveDuration',
        'Must not be negative.',
      );
    }

    final durations = List<Duration>.of(attemptActiveDurations);
    if (durations.any((duration) => duration.isNegative)) {
      throw ArgumentError.value(
        attemptActiveDurations,
        'attemptActiveDurations',
        'Durations must not be negative.',
      );
    }
    final finalizedAttemptCount =
        passedCount +
        wrongMoveOutcomeCount +
        revealedCount +
        skippedCount +
        timedOutCount +
        abandonedCount;
    if (durations.length != finalizedAttemptCount) {
      throw ArgumentError(
        'One active duration is required for each finalized puzzle attempt.',
      );
    }

    return ProgressAggregate._(
      passedCount: passedCount,
      wrongMoveOutcomeCount: wrongMoveOutcomeCount,
      revealedCount: revealedCount,
      skippedCount: skippedCount,
      timedOutCount: timedOutCount,
      abandonedCount: abandonedCount,
      wrongMoveCount: wrongMoveCount,
      hintCount: hintCount,
      attemptActiveDurations: List.unmodifiable(durations),
      completedNonPuzzleItemCount: completedNonPuzzleItemCount,
      nonPuzzleActiveDuration: nonPuzzleActiveDuration,
    );
  }

  const ProgressAggregate._({
    required this.passedCount,
    required this.wrongMoveOutcomeCount,
    required this.revealedCount,
    required this.skippedCount,
    required this.timedOutCount,
    required this.abandonedCount,
    required this.wrongMoveCount,
    required this.hintCount,
    required this.attemptActiveDurations,
    required this.completedNonPuzzleItemCount,
    required this.nonPuzzleActiveDuration,
  });

  final int passedCount;

  /// Number of attempts finalized with the [PuzzleAttemptOutcome.wrongMove]
  /// outcome. This differs from [wrongMoveCount], which counts move errors.
  final int wrongMoveOutcomeCount;

  final int revealedCount;
  final int skippedCount;
  final int timedOutCount;
  final int abandonedCount;

  /// Total incorrect move submissions across attempts.
  final int wrongMoveCount;

  /// Total user-initiated hints across attempts.
  final int hintCount;

  /// Active duration for each finalized puzzle attempt, in the same order as
  /// the underlying attempt records supplied to this aggregate.
  final List<Duration> attemptActiveDurations;

  final int completedNonPuzzleItemCount;

  /// Eligible active session time spent on Text items, separate from puzzle
  /// attempt durations.
  final Duration nonPuzzleActiveDuration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressAggregate &&
          other.passedCount == passedCount &&
          other.wrongMoveOutcomeCount == wrongMoveOutcomeCount &&
          other.revealedCount == revealedCount &&
          other.skippedCount == skippedCount &&
          other.timedOutCount == timedOutCount &&
          other.abandonedCount == abandonedCount &&
          other.wrongMoveCount == wrongMoveCount &&
          other.hintCount == hintCount &&
          _sameDurations(
            other.attemptActiveDurations,
            attemptActiveDurations,
          ) &&
          other.completedNonPuzzleItemCount == completedNonPuzzleItemCount &&
          other.nonPuzzleActiveDuration == nonPuzzleActiveDuration;

  @override
  int get hashCode => Object.hash(
    passedCount,
    wrongMoveOutcomeCount,
    revealedCount,
    skippedCount,
    timedOutCount,
    abandonedCount,
    wrongMoveCount,
    hintCount,
    Object.hashAll(attemptActiveDurations),
    completedNonPuzzleItemCount,
    nonPuzzleActiveDuration,
  );
}

bool _sameDurations(List<Duration> left, List<Duration> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
