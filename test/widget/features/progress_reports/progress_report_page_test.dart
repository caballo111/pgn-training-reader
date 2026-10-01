import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/training/cycle.dart';
import 'package:pgntrainingreader/domain/training/lifecycle_status.dart';
import 'package:pgntrainingreader/domain/training/progress_aggregate.dart';
import 'package:pgntrainingreader/domain/training/progress_calculator.dart';
import 'package:pgntrainingreader/domain/training/progress_report_data.dart';
import 'package:pgntrainingreader/domain/training/puzzle_interaction_repository.dart';
import 'package:pgntrainingreader/domain/training/training_repository.dart';
import 'package:pgntrainingreader/domain/training/training_session.dart';
import 'package:pgntrainingreader/domain/training/training_set.dart';
import 'package:pgntrainingreader/domain/training/training_set_item.dart';
import 'package:pgntrainingreader/features/progress_reports/application/progress_report_controller.dart';
import 'package:pgntrainingreader/features/progress_reports/presentation/progress_report_page.dart';

final _olderCycle = Cycle(
  id: 'older',
  trainingSetId: 'set',
  status: CycleStatus.completed,
  startedAt: DateTime(2026, 1, 1),
  completedAt: DateTime(2026, 1, 1, 1),
  createdAt: DateTime(2026, 1, 1),
);
final _selectedCycle = Cycle(
  id: 'selected',
  trainingSetId: 'set',
  status: CycleStatus.completed,
  startedAt: DateTime(2026, 1, 2),
  completedAt: DateTime(2026, 1, 2, 1),
  createdAt: DateTime(2026, 1, 2),
);

final _olderProgress = _progress(
  passed: 1,
  skipped: 1,
  durations: const [Duration(seconds: 10), Duration(seconds: 20)],
);
final _cycleProgress = _progress(
  passed: 2,
  wrong: 1,
  revealed: 1,
  skipped: 1,
  timeout: 1,
  abandoned: 1,
  assisted: 1,
  durations: const [
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 15),
    Duration(seconds: 20),
    Duration(seconds: 25),
    Duration(seconds: 30),
    Duration(seconds: 35),
    Duration(seconds: 40),
  ],
  nonPuzzleSeconds: 60,
);

ProgressAggregate _progress({
  int passed = 0,
  int assisted = 0,
  int wrong = 0,
  int revealed = 0,
  int skipped = 0,
  int timeout = 0,
  int abandoned = 0,
  List<Duration> durations = const [],
  int nonPuzzleSeconds = 0,
}) => ProgressAggregate(
  passedCount: passed,
  assistedCount: assisted,
  wrongMoveOutcomeCount: wrong,
  revealedCount: revealed,
  skippedCount: skipped,
  timedOutCount: timeout,
  abandonedCount: abandoned,
  wrongMoveCount: 0,
  hintCount: 0,
  attemptActiveDurations: durations,
  nonPuzzleActiveDuration: Duration(seconds: nonPuzzleSeconds),
);

final class _FakeTrainingRepository
    implements TrainingRepository, CycleSnapshotRepository {
  _FakeTrainingRepository({
    this.metadata = true,
    this.mismatchedCycle = false,
    this.mismatchedPolicy = false,
  });

  final bool metadata;
  final bool mismatchedCycle;
  final bool mismatchedPolicy;

  TrainingSet _snapshot(String cycleId) => TrainingSet(
    id: 'set',
    name: 'Tactics',
    items: [
      TrainingSetItem(
        id: 'item',
        trainingSetId: 'set',
        blockId: mismatchedCycle && cycleId == 'older' ? 'other' : 'block',
        position: 0,
        contentType: ContentType.puzzle,
        addedAt: DateTime(2026, 1, 1),
      ),
    ],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  @override
  Future<TrainingSet?> getCycleSet(String cycleId) async => _snapshot(cycleId);

  @override
  Future<String?> getCyclePolicy(String cycleId) async =>
      mismatchedPolicy && cycleId == 'older' ? 'allMoves' : 'keyMoves';

  @override
  Future<void> setCyclePolicy(String cycleId, String policy) async {}

  @override
  Future<String?> getCycleCursor(String cycleId) async => null;

  @override
  Future<void> setCycleCursor(String cycleId, String? attemptId) async {}

  @override
  Future<List<Cycle>> listCycles(String trainingSetId) async => [
    _olderCycle,
    _selectedCycle,
  ];

  @override
  Future<ProgressAggregate> aggregateForCycle(String cycleId) async =>
      cycleId == 'older' ? _olderProgress : _cycleProgress;

  @override
  Future<List<SessionProgressAggregate>> sessionAggregatesForCycle(
    String cycleId,
  ) async => [
    SessionProgressAggregate(
      session: TrainingSession(
        id: 'session',
        cycleId: cycleId,
        status: TrainingSessionStatus.closed,
        startedAt: DateTime(2026, 1, 2, 9),
        endedAt: DateTime(2026, 1, 2, 10),
        studyDay: DateTime(2026, 1, 2),
      ),
      progress: _cycleProgress,
    ),
  ];

  @override
  Future<List<MetadataProgressAggregate>> themeAggregatesForCycle(
    String cycleId,
  ) async => metadata
      ? [
          MetadataProgressAggregate(
            value: 'Forks',
            progress: _progress(
              passed: 1,
              durations: const [Duration(seconds: 8)],
            ),
          ),
        ]
      : [];

  @override
  Future<List<MetadataProgressAggregate>> difficultyAggregatesForCycle(
    String cycleId,
  ) async => metadata
      ? [
          MetadataProgressAggregate(
            value: 'Intermediate',
            progress: _progress(
              passed: 1,
              durations: const [Duration(seconds: 8)],
            ),
          ),
        ]
      : [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'displays cycle, outcome, daily, comparison, and metadata metrics from calculator',
    (tester) async {
      final repository = _FakeTrainingRepository();
      final controller = ProgressReportController(
        trainingSetId: 'set',
        repository: repository,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ProgressReportPage(
            controller: controller,
            trainingSetName: 'Tactics',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final summary = ProgressCalculator.calculate(_cycleProgress);
      final comparison = ProgressCalculator.compare(
        _olderProgress,
        _cycleProgress,
      );

      expect(find.text('Cycle results'), findsOneWidget);
      expect(find.text('${summary.attemptedCount}'), findsOneWidget);
      expect(find.text('${summary.passedCount}'), findsNWidgets(2));
      expect(find.text('${summary.nonPassingCount}'), findsOneWidget);
      expect(
        find.text('${summary.accuracyPercent!.toStringAsFixed(1)}%'),
        findsOneWidget,
      );
      expect(find.text(_duration(summary.totalActiveTime)), findsOneWidget);
      expect(
        find.text(_duration(summary.averageAttemptActiveTime!)),
        findsNWidgets(2),
      );
      expect(
        find.text(_duration(summary.medianAttemptActiveTime!)),
        findsNWidgets(2),
      );
      for (final label in [
        ('Failed on a wrong move', summary.wrongMoveOutcomeCount),
        ('Assisted', summary.assistedCount),
        ('Revealed', summary.revealedCount),
        ('Skipped', summary.skippedCount),
        ('Timed out', summary.timedOutCount),
        ('Abandoned', summary.abandonedCount),
      ]) {
        _expectMetric(label.$1, '${label.$2}');
      }

      await tester.scrollUntilVisible(
        find.text('Daily sessions'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('2026-01-02'), findsOneWidget);
      expect(find.text('Daily sessions'), findsOneWidget);
      _expectMetric('Active duration', _duration(summary.totalActiveTime));
      _expectMetric('Attempted', '${summary.attemptedCount}');
      _expectMetric('Passed', '${summary.passedCount}');
      _expectMetric('Skipped', '${summary.skippedCount}');

      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Cycle comparison'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Cycle comparison'), findsOneWidget);
      expect(
        find.text(_percent(comparison.earlier.accuracyPercent)),
        findsOneWidget,
      );
      expect(
        find.text(_percent(comparison.later.accuracyPercent)),
        findsOneWidget,
      );
      expect(
        find.text(_pointChange(comparison.accuracyPercentagePointChange)),
        findsOneWidget,
      );
      expect(
        find.text(_duration(comparison.earlier.totalActiveTime)),
        findsOneWidget,
      );
      expect(
        find.text(_duration(comparison.later.totalActiveTime)),
        findsNWidgets(2),
      );
      expect(
        find.text(_durationChange(comparison.totalActiveTimeChange)),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('By theme'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('By theme'), findsOneWidget);
      expect(find.text('Forks'), findsOneWidget);
      expect(find.text('By difficulty'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);
      final metadataSummary = ProgressCalculator.calculate(
        _progress(passed: 1, durations: const [Duration(seconds: 8)]),
      );
      await tester.scrollUntilVisible(
        find.text('Intermediate'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('${metadataSummary.accuracyPercent!.toStringAsFixed(1)}%'),
        findsAtLeastNWidgets(1),
      );
    },
  );

  testWidgets('suppresses comparisons when cycle snapshots differ', (
    tester,
  ) async {
    final controller = ProgressReportController(
      trainingSetId: 'set',
      repository: _FakeTrainingRepository(mismatchedCycle: true),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ProgressReportPage(
          controller: controller,
          trainingSetName: 'Tactics',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Cycle comparison'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(controller.state.comparisonCompatible, isFalse);
    expect(controller.state.comparison, isNull);
    expect(
      find.text(
        'Selections or completion policies differ; these cycles are not directly comparable.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('suppresses comparisons when cycle policies differ', (
    tester,
  ) async {
    final controller = ProgressReportController(
      trainingSetId: 'set',
      repository: _FakeTrainingRepository(mismatchedPolicy: true),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ProgressReportPage(
          controller: controller,
          trainingSetName: 'Tactics',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Cycle comparison'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(controller.state.comparisonCompatible, isFalse);
    expect(controller.state.comparison, isNull);
    expect(
      find.text(
        'Selections or completion policies differ; these cycles are not directly comparable.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows explicit unavailable state when theme and difficulty metadata are absent',
    (tester) async {
      final controller = ProgressReportController(
        trainingSetId: 'set',
        repository: _FakeTrainingRepository(metadata: false),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ProgressReportPage(
            controller: controller,
            trainingSetName: 'Tactics',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Theme metadata unavailable for this cycle.'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Theme metadata unavailable for this cycle.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Difficulty metadata unavailable for this cycle.'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Difficulty metadata unavailable for this cycle.'),
        findsOneWidget,
      );
    },
  );
}

void _expectMetric(String label, String value) {
  final row = find
      .ancestor(of: find.text(label), matching: find.byType(Row))
      .first;
  expect(find.descendant(of: row, matching: find.text(value)), findsOneWidget);
}

String _duration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}

String _percent(double? value) =>
    value == null ? 'Not available' : '${value.toStringAsFixed(1)}%';

String _pointChange(double? value) {
  if (value == null) return 'Not available';
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)} percentage points';
}

String _durationChange(Duration value) {
  final sign = value.isNegative ? '−' : '+';
  return '$sign${_duration(Duration(microseconds: value.inMicroseconds.abs()))}';
}
