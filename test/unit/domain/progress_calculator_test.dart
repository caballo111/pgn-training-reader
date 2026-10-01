import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/training/progress_aggregate.dart';
import 'package:pgntrainingreader/domain/training/progress_calculator.dart';

ProgressAggregate _aggregate({
  int passed = 0,
  int assisted = 0,
  int wrongMoveOutcome = 0,
  int revealed = 0,
  int skipped = 0,
  int timedOut = 0,
  int abandoned = 0,
  int wrongMoves = 0,
  int hints = 0,
  List<Duration> durations = const [],
  int completedNonPuzzleItems = 0,
  Duration nonPuzzleDuration = Duration.zero,
}) => ProgressAggregate(
  passedCount: passed,
  assistedCount: assisted,
  wrongMoveOutcomeCount: wrongMoveOutcome,
  revealedCount: revealed,
  skippedCount: skipped,
  timedOutCount: timedOut,
  abandonedCount: abandoned,
  wrongMoveCount: wrongMoves,
  hintCount: hints,
  attemptActiveDurations: durations,
  completedNonPuzzleItemCount: completedNonPuzzleItems,
  nonPuzzleActiveDuration: nonPuzzleDuration,
);

void main() {
  group('ProgressCalculator.calculate', () {
    test('zero attempts have no accuracy, average, or median', () {
      final summary = ProgressCalculator.calculate(_aggregate());

      expect(summary.attemptedCount, 0);
      expect(summary.passedCount, 0);
      expect(summary.nonPassingCount, 0);
      expect(summary.accuracyPercent, isNull);
      expect(summary.totalActiveTime, Duration.zero);
      expect(summary.averageAttemptActiveTime, isNull);
      expect(summary.medianAttemptActiveTime, isNull);
    });

    test(
      'one passing attempt reports its duration and 100 percent accuracy',
      () {
        final summary = ProgressCalculator.calculate(
          _aggregate(passed: 1, durations: [const Duration(seconds: 12)]),
        );

        expect(summary.attemptedCount, 1);
        expect(summary.passedCount, 1);
        expect(summary.nonPassingCount, 0);
        expect(summary.accuracyPercent, 100);
        expect(summary.totalActiveTime, const Duration(seconds: 12));
        expect(summary.averageAttemptActiveTime, const Duration(seconds: 12));
        expect(summary.medianAttemptActiveTime, const Duration(seconds: 12));
      },
    );

    test('mixed outcomes count every finalized outcome in accuracy', () {
      final summary = ProgressCalculator.calculate(
        _aggregate(
          passed: 1,
          wrongMoveOutcome: 1,
          revealed: 1,
          skipped: 1,
          timedOut: 1,
          abandoned: 1,
          wrongMoves: 4,
          hints: 3,
          durations: List.generate(6, (index) => Duration(seconds: index + 1)),
          completedNonPuzzleItems: 2,
          nonPuzzleDuration: const Duration(seconds: 7),
        ),
      );

      expect(summary.attemptedCount, 6);
      expect(summary.passedCount, 1);
      expect(summary.nonPassingCount, 5);
      expect(summary.accuracyPercent, closeTo(100 / 6, 0.000001));
      expect(summary.wrongMoveOutcomeCount, 1);
      expect(summary.revealedCount, 1);
      expect(summary.skippedCount, 1);
      expect(summary.timedOutCount, 1);
      expect(summary.abandonedCount, 1);
      expect(summary.wrongMoveCount, 4);
      expect(summary.hintCount, 3);
      expect(summary.completedNonPuzzleItemCount, 2);
      expect(summary.totalActiveTime, const Duration(seconds: 28));
    });

    test(
      'assisted attempts are distinct and included in accuracy denominator',
      () {
        final summary = ProgressCalculator.calculate(
          _aggregate(
            passed: 1,
            assisted: 1,
            durations: [const Duration(seconds: 2), const Duration(seconds: 4)],
          ),
        );

        expect(summary.attemptedCount, 2);
        expect(summary.passedCount, 1);
        expect(summary.assistedCount, 1);
        expect(summary.nonPassingCount, 1);
        expect(summary.accuracyPercent, 50);
        expect(summary.averageAttemptActiveTime, const Duration(seconds: 3));
      },
    );

    test('cycle comparison reports assisted count change', () {
      final comparison = ProgressCalculator.compare(
        _aggregate(passed: 1, durations: [Duration.zero]),
        _aggregate(assisted: 2, durations: [Duration.zero, Duration.zero]),
      );

      expect(comparison.earlier.assistedCount, 0);
      expect(comparison.later.assistedCount, 2);
      expect(comparison.assistedCountChange, 2);
      expect(comparison.later.accuracyPercent, 0);
    });

    test(
      'even attempt count uses the midpoint of the two middle durations',
      () {
        final summary = ProgressCalculator.calculate(
          _aggregate(
            passed: 4,
            durations: [
              const Duration(seconds: 4),
              const Duration(seconds: 1),
              const Duration(seconds: 3),
              const Duration(seconds: 2),
            ],
          ),
        );

        expect(
          summary.averageAttemptActiveTime,
          const Duration(seconds: 2, milliseconds: 500),
        );
        expect(
          summary.medianAttemptActiveTime,
          const Duration(seconds: 2, milliseconds: 500),
        );
      },
    );

    test('odd attempt count uses the middle duration after sorting', () {
      final summary = ProgressCalculator.calculate(
        _aggregate(
          passed: 3,
          durations: [
            const Duration(seconds: 9),
            const Duration(seconds: 1),
            const Duration(seconds: 5),
          ],
        ),
      );

      expect(summary.medianAttemptActiveTime, const Duration(seconds: 5));
    });

    test('retries count as separate attempts for outcomes and timing', () {
      // Both fixture entries represent attempts on the same exercise.
      final summary = ProgressCalculator.calculate(
        _aggregate(
          passed: 1,
          wrongMoveOutcome: 1,
          wrongMoves: 2,
          durations: [const Duration(seconds: 3), const Duration(seconds: 5)],
        ),
      );

      expect(summary.attemptedCount, 2);
      expect(summary.passedCount, 1);
      expect(summary.nonPassingCount, 1);
      expect(summary.accuracyPercent, 50);
      expect(summary.totalActiveTime, const Duration(seconds: 8));
      expect(summary.averageAttemptActiveTime, const Duration(seconds: 4));
      expect(summary.medianAttemptActiveTime, const Duration(seconds: 4));
      expect(summary.wrongMoveOutcomeCount, 1);
      expect(summary.wrongMoveCount, 2);
    });

    test('cycle totals include attempts from multiple sessions', () {
      // The repository supplies one raw aggregate for the cycle, combining
      // attempts from both session fixtures while excluding idle time between.
      final firstSession = _aggregate(
        passed: 1,
        durations: [const Duration(seconds: 2)],
        completedNonPuzzleItems: 1,
        nonPuzzleDuration: const Duration(seconds: 3),
      );
      final secondSession = _aggregate(
        skipped: 1,
        durations: [const Duration(seconds: 4)],
        completedNonPuzzleItems: 1,
        nonPuzzleDuration: const Duration(seconds: 5),
      );
      final cycle = _aggregate(
        passed: firstSession.passedCount + secondSession.passedCount,
        skipped: firstSession.skippedCount + secondSession.skippedCount,
        durations: [
          ...firstSession.attemptActiveDurations,
          ...secondSession.attemptActiveDurations,
        ],
        completedNonPuzzleItems:
            firstSession.completedNonPuzzleItemCount +
            secondSession.completedNonPuzzleItemCount,
        nonPuzzleDuration:
            firstSession.nonPuzzleActiveDuration +
            secondSession.nonPuzzleActiveDuration,
      );

      final summary = ProgressCalculator.calculate(cycle);

      expect(summary.attemptedCount, 2);
      expect(summary.passedCount, 1);
      expect(summary.skippedCount, 1);
      expect(summary.accuracyPercent, 50);
      expect(summary.totalActiveTime, const Duration(seconds: 14));
      expect(summary.averageAttemptActiveTime, const Duration(seconds: 3));
      expect(summary.medianAttemptActiveTime, const Duration(seconds: 3));
      expect(summary.completedNonPuzzleItemCount, 2);
    });
  });
}
