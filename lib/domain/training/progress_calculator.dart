import 'progress_aggregate.dart';

/// Metrics derived from the raw progress recorded for one cycle or selection.
///
/// Attempts are finalized puzzle attempts, so retries are counted separately.
/// Accuracy is unavailable when there are no finalized puzzle attempts.
final class ProgressSummary {
  const ProgressSummary({
    required this.attemptedCount,
    required this.passedCount,
    required this.wrongMoveOutcomeCount,
    required this.revealedCount,
    required this.skippedCount,
    required this.timedOutCount,
    required this.abandonedCount,
    required this.accuracyPercent,
    required this.totalActiveTime,
    required this.averageAttemptActiveTime,
    required this.medianAttemptActiveTime,
    required this.wrongMoveCount,
    required this.hintCount,
    required this.completedNonPuzzleItemCount,
  });

  final int attemptedCount;
  final int passedCount;
  int get nonPassingCount => attemptedCount - passedCount;
  final int wrongMoveOutcomeCount;
  final int revealedCount;
  final int skippedCount;
  final int timedOutCount;
  final int abandonedCount;

  /// Passed finalized puzzle attempts / all finalized puzzle attempts * 100.
  /// Null means no finalized puzzle attempts have been recorded.
  final double? accuracyPercent;

  /// Puzzle attempt active time plus active time spent on non-puzzle items.
  final Duration totalActiveTime;

  /// Mean duration across all finalized puzzle attempts, including retries.
  final Duration? averageAttemptActiveTime;

  /// Median duration across all finalized puzzle attempts, including retries.
  final Duration? medianAttemptActiveTime;

  final int wrongMoveCount;
  final int hintCount;
  final int completedNonPuzzleItemCount;
}

/// Change in raw metrics from an earlier cycle to a later cycle.
///
/// Positive duration changes mean the later cycle took longer. Accuracy
/// change is unavailable unless both cycles contain finalized attempts.
final class ProgressComparison {
  const ProgressComparison({
    required this.earlier,
    required this.later,
    required this.attemptedCountChange,
    required this.passedCountChange,
    required this.nonPassingCountChange,
    required this.accuracyPercentagePointChange,
    required this.totalActiveTimeChange,
    required this.averageAttemptActiveTimeChange,
    required this.medianAttemptActiveTimeChange,
    required this.wrongMoveCountChange,
    required this.hintCountChange,
    required this.revealedCountChange,
    required this.skippedCountChange,
    required this.timedOutCountChange,
    required this.abandonedCountChange,
  });

  final ProgressSummary earlier;
  final ProgressSummary later;
  final int attemptedCountChange;
  final int passedCountChange;
  final int nonPassingCountChange;
  final double? accuracyPercentagePointChange;
  final Duration totalActiveTimeChange;
  final Duration? averageAttemptActiveTimeChange;
  final Duration? medianAttemptActiveTimeChange;
  final int wrongMoveCountChange;
  final int hintCountChange;
  final int revealedCountChange;
  final int skippedCountChange;
  final int timedOutCountChange;
  final int abandonedCountChange;
}

/// The sole implementation of transparent training progress calculations.
abstract final class ProgressCalculator {
  static ProgressSummary calculate(ProgressAggregate aggregate) {
    final attemptedCount =
        aggregate.passedCount +
        aggregate.wrongMoveOutcomeCount +
        aggregate.revealedCount +
        aggregate.skippedCount +
        aggregate.timedOutCount +
        aggregate.abandonedCount;
    final durations = List<Duration>.of(aggregate.attemptActiveDurations)
      ..sort((left, right) => left.compareTo(right));

    final Duration? average;
    final Duration? median;
    if (durations.isEmpty) {
      average = null;
      median = null;
    } else {
      final totalAttemptTime = durations.fold<Duration>(
        Duration.zero,
        (total, duration) => total + duration,
      );
      average = Duration(
        microseconds: totalAttemptTime.inMicroseconds ~/ durations.length,
      );
      final middle = durations.length ~/ 2;
      median = durations.length.isOdd
          ? durations[middle]
          : Duration(
              microseconds:
                  (durations[middle - 1].inMicroseconds +
                      durations[middle].inMicroseconds) ~/
                  2,
            );
    }

    final puzzleActiveTime = aggregate.attemptActiveDurations.fold<Duration>(
      Duration.zero,
      (total, duration) => total + duration,
    );

    return ProgressSummary(
      attemptedCount: attemptedCount,
      passedCount: aggregate.passedCount,
      wrongMoveOutcomeCount: aggregate.wrongMoveOutcomeCount,
      revealedCount: aggregate.revealedCount,
      skippedCount: aggregate.skippedCount,
      timedOutCount: aggregate.timedOutCount,
      abandonedCount: aggregate.abandonedCount,
      accuracyPercent: attemptedCount == 0
          ? null
          : aggregate.passedCount * 100 / attemptedCount,
      totalActiveTime: puzzleActiveTime + aggregate.nonPuzzleActiveDuration,
      averageAttemptActiveTime: average,
      medianAttemptActiveTime: median,
      wrongMoveCount: aggregate.wrongMoveCount,
      hintCount: aggregate.hintCount,
      completedNonPuzzleItemCount: aggregate.completedNonPuzzleItemCount,
    );
  }

  static ProgressComparison compare(
    ProgressAggregate earlier,
    ProgressAggregate later,
  ) {
    final before = calculate(earlier);
    final after = calculate(later);
    return ProgressComparison(
      earlier: before,
      later: after,
      attemptedCountChange: after.attemptedCount - before.attemptedCount,
      passedCountChange: after.passedCount - before.passedCount,
      nonPassingCountChange: after.nonPassingCount - before.nonPassingCount,
      accuracyPercentagePointChange:
          before.accuracyPercent == null || after.accuracyPercent == null
          ? null
          : after.accuracyPercent! - before.accuracyPercent!,
      totalActiveTimeChange: after.totalActiveTime - before.totalActiveTime,
      averageAttemptActiveTimeChange: _durationChange(
        before.averageAttemptActiveTime,
        after.averageAttemptActiveTime,
      ),
      medianAttemptActiveTimeChange: _durationChange(
        before.medianAttemptActiveTime,
        after.medianAttemptActiveTime,
      ),
      wrongMoveCountChange: after.wrongMoveCount - before.wrongMoveCount,
      hintCountChange: after.hintCount - before.hintCount,
      revealedCountChange: after.revealedCount - before.revealedCount,
      skippedCountChange: after.skippedCount - before.skippedCount,
      timedOutCountChange: after.timedOutCount - before.timedOutCount,
      abandonedCountChange: after.abandonedCount - before.abandonedCount,
    );
  }

  static Duration? _durationChange(Duration? before, Duration? after) =>
      before == null || after == null ? null : after - before;
}
