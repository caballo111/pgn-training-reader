import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/training/progress_aggregate.dart';
import 'package:pgntrainingreader/domain/training/progress_report_data.dart';
import 'package:pgntrainingreader/domain/training/training_repository.dart';
import 'package:pgntrainingreader/features/progress_reports/presentation/metadata_progress_summary_view.dart';

void main() {
  testWidgets('shows theme summaries without an empty difficulty section', (
    tester,
  ) async {
    await _pump(tester, _MetadataRepository(themes: ['Fork']));

    expect(find.text('By theme'), findsOneWidget);
    expect(find.text('Fork'), findsOneWidget);
    expect(find.text('By difficulty'), findsNothing);
  });

  testWidgets('shows difficulty summaries without an empty theme section', (
    tester,
  ) async {
    await _pump(tester, _MetadataRepository(difficulties: ['Easy']));

    expect(find.text('By theme'), findsNothing);
    expect(find.text('By difficulty'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
  });

  testWidgets('Retry reloads metadata after a real repository error', (
    tester,
  ) async {
    final repository = _MetadataRepository(
      themes: ['Fork'],
      failFirstThemeLoad: true,
    );
    await _pump(tester, repository);

    expect(
      find.text('Could not load theme and difficulty summaries.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not load theme and difficulty summaries.'),
      findsNothing,
    );
    expect(find.text('By theme'), findsOneWidget);
    expect(find.text('Fork'), findsOneWidget);
    expect(repository.themeCalls, 2);
  });

  testWidgets('difficulty failures show Retry while themes are pending', (
    tester,
  ) async {
    final repository = _MetadataRepository(failDifficultyLoad: true);
    final pending = Completer<List<MetadataProgressAggregate>>();
    repository.pendingThemes['cycle'] = pending;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MetadataProgressSummaryView(
            repository: repository,
            cycleId: 'cycle',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(
      find.text('Could not load theme and difficulty summaries.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('cycle changes hide old metadata while the new cycle loads', (
    tester,
  ) async {
    final repository = _MetadataRepository();
    await _pump(tester, repository, cycleId: 'old');
    expect(find.text('Fork'), findsOneWidget);

    final nextThemes = Completer<List<MetadataProgressAggregate>>();
    repository.pendingThemes['new'] = nextThemes;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MetadataProgressSummaryView(
            repository: repository,
            cycleId: 'new',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Fork'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    nextThemes.complete([_summary('Pin')]);
    await tester.pumpAndSettle();
    expect(find.text('Pin'), findsOneWidget);
    expect(find.text('Fork'), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester,
  _MetadataRepository repository, {
  String cycleId = 'cycle',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MetadataProgressSummaryView(
          repository: repository,
          cycleId: cycleId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MetadataProgressAggregate _summary(String value) => MetadataProgressAggregate(
  value: value,
  progress: ProgressAggregate(
    passedCount: 1,
    wrongMoveOutcomeCount: 0,
    revealedCount: 0,
    skippedCount: 0,
    timedOutCount: 0,
    abandonedCount: 0,
    wrongMoveCount: 0,
    hintCount: 0,
    attemptActiveDurations: const [Duration(seconds: 8)],
  ),
);

final class _MetadataRepository implements TrainingRepository {
  _MetadataRepository({
    this.themes = const [],
    this.difficulties = const [],
    this.failFirstThemeLoad = false,
    this.failDifficultyLoad = false,
  });

  final List<String> themes;
  final List<String> difficulties;
  final bool failFirstThemeLoad;
  final bool failDifficultyLoad;
  final Map<String, Completer<List<MetadataProgressAggregate>>> pendingThemes =
      {};
  int themeCalls = 0;

  @override
  Future<List<MetadataProgressAggregate>> themeAggregatesForCycle(
    String cycleId,
  ) {
    themeCalls++;
    final pending = pendingThemes[cycleId];
    if (pending != null) return pending.future;
    if (failFirstThemeLoad && themeCalls == 1) {
      return Future.error(StateError('repository unavailable'));
    }
    final values = cycleId == 'old' ? ['Fork'] : themes;
    return Future.value(values.map(_summary).toList());
  }

  @override
  Future<List<MetadataProgressAggregate>> difficultyAggregatesForCycle(
    String cycleId,
  ) => failDifficultyLoad
      ? Future.error(StateError('difficulty unavailable'))
      : Future.value(difficulties.map(_summary).toList());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
