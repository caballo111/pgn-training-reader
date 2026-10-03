import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/domain/training/puzzle_evaluator.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_header.dart';

final _startedAt = DateTime.utc(2026, 9, 29);

PuzzleEvaluationState _evaluation(PuzzleSide side) => PuzzleEvaluationState(
  attempt: PuzzleAttempt(
    id: 'attempt-1',
    blockId: 'block-1',
    cycleId: 'cycle-1',
    sessionId: 'session-1',
    startedAt: _startedAt,
  ),
  currentFen: 'current position',
  sideToMove: side,
  moves: const [],
);

void main() {
  testWidgets('shows white to move and accessible exercise progress', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PuzzleHeader(
            currentExercise: 2,
            totalExercises: 4,
            evaluation: _evaluation(PuzzleSide.white),
          ),
        ),
      ),
    );

    expect(find.text('Exercise 2 of 4'), findsOneWidget);
    expect(find.text('White to move'), findsOneWidget);
    expect(find.bySemanticsLabel('White to move'), findsOneWidget);
    final progress = tester.getSemantics(
      find.bySemanticsLabel('Exercise progress'),
    );
    expect(progress.value, '2 of 4');
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.5,
    );
    semantics.dispose();
  });

  testWidgets('derives black to move from the active evaluation position', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PuzzleHeader(
            currentExercise: 3,
            totalExercises: 5,
            evaluation: _evaluation(PuzzleSide.black),
          ),
        ),
      ),
    );

    expect(find.text('Exercise 3 of 5'), findsOneWidget);
    expect(find.text('Black to move'), findsOneWidget);
    expect(find.bySemanticsLabel('Black to move'), findsOneWidget);
    expect(find.bySemanticsLabel('White to move'), findsNothing);
    final progress = tester.getSemantics(
      find.bySemanticsLabel('Exercise progress'),
    );
    expect(progress.value, '3 of 5');
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.6,
    );
    semantics.dispose();
  });

  testWidgets('shows safe source context without casual one-of-one progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PuzzleHeader(
            currentExercise: 1,
            totalExercises: 1,
            evaluation: _evaluation(PuzzleSide.white),
            showProgress: false,
            contextTitle: 'Endgame Basics',
            sectionLabel: 'Rook endings',
            blockLabel: 'Block 8',
            modeLabel: 'Casual practice',
          ),
        ),
      ),
    );

    expect(find.text('Endgame Basics'), findsOneWidget);
    expect(find.text('Rook endings · Block 8'), findsOneWidget);
    expect(find.text('Casual practice'), findsOneWidget);
    expect(find.textContaining('Exercise'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
