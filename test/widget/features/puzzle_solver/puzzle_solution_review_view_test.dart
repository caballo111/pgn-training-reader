import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/domain/training/authored_line_puzzle_evaluator.dart';
import 'package:pgntrainingreader/domain/training/puzzle_evaluator.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/features/puzzle_solver/application/puzzle_presentation_state.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_solution_review_view.dart';
import 'package:pgntrainingreader/features/game_reader/presentation/reader_board.dart';

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

final _terminalPuzzle = ChessContent(
  headers: const {},
  startingFen: _fen,
  contentType: ContentType.puzzle,
  rootMoves: [
    MoveNode(
      san: 'e4',
      uci: 'e2e4',
      fenBefore: _fen,
      fenAfter: 'ignored',
      children: [
        MoveNode(
          san: 'e5',
          uci: 'e7e5',
          fenBefore: 'ignored',
          fenAfter: 'ignored',
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('review reveals authored content for every terminal outcome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    final outcomes =
        <PuzzleAttemptOutcome, void Function(AuthoredLinePuzzleEvaluator)>{
          PuzzleAttemptOutcome.passed: (evaluator) {
            evaluator.submitMove(uci: 'e2e4');
            evaluator.submitMove(uci: 'e7e5');
          },
          PuzzleAttemptOutcome.wrongMove: (evaluator) {
            evaluator.submitMove(uci: 'e2e3');
          },
          PuzzleAttemptOutcome.skipped: (evaluator) => evaluator.skip(),
          PuzzleAttemptOutcome.timedOut: (evaluator) => evaluator.timeout(),
          PuzzleAttemptOutcome.abandoned: (evaluator) => evaluator.abandon(),
          PuzzleAttemptOutcome.revealed: (evaluator) => evaluator.reveal(),
        };
    const labels = <PuzzleAttemptOutcome, String>{
      PuzzleAttemptOutcome.passed: 'Passed',
      PuzzleAttemptOutcome.wrongMove: 'Incorrect move',
      PuzzleAttemptOutcome.skipped: 'Skipped',
      PuzzleAttemptOutcome.timedOut: 'Timed out',
      PuzzleAttemptOutcome.abandoned: 'Abandoned',
      PuzzleAttemptOutcome.revealed: 'Solution revealed',
    };

    for (final expectedOutcome in outcomes.keys) {
      final attempt = PuzzleAttempt(
        id: 'attempt-${expectedOutcome.name}',
        blockId: 'block',
        cycleId: 'cycle',
        sessionId: 'session',
        startedAt: DateTime.utc(2026),
      );
      final evaluator = AuthoredLinePuzzleEvaluator();
      evaluator.initialize(puzzle: _terminalPuzzle, attempt: attempt);
      outcomes[expectedOutcome]!(evaluator);
      final state = evaluator.state!;
      expect(state.attempt.outcome, expectedOutcome);
      final presentation = PuzzlePresentationState.fromDomain(
        puzzle: _terminalPuzzle,
        evaluation: state,
      );
      expect(presentation.isSolutionVisible, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PuzzleSolutionReviewView(presentation: presentation),
          ),
        ),
      );
      expect(find.text('Solution line'), findsOneWidget);
      expect(find.text('e4'), findsWidgets);
      expect(find.text('Result: ${labels[expectedOutcome]}'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Next move'));
      await tester.tap(find.byTooltip('Next move'));
      await tester.pumpAndSettle();
      expect(presentation.outcome, expectedOutcome);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('review navigates authored moves and presents annotations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    final puzzle = ChessContent(
      headers: const {},
      startingFen: _fen,
      contentType: ContentType.puzzle,
      comments: const ['Puzzle note'],
      rootMoves: [
        MoveNode(
          san: 'e4',
          uci: 'e2e4',
          fenBefore: _fen,
          fenAfter: 'position after e4',
          comments: const ['Root annotation'],
          nags: const [1],
          children: [
            MoveNode(
              san: 'e5',
              uci: 'e7e5',
              fenBefore: 'position after e4',
              fenAfter: 'position after e5',
              comments: const ['Reply annotation'],
            ),
            MoveNode(
              san: 'c5',
              uci: 'c7c5',
              fenBefore: 'position after e4',
              fenAfter: 'position after c5',
              comments: const ['Sicilian variation'],
            ),
          ],
        ),
      ],
    );
    final attempt = PuzzleAttempt(
      id: 'attempt',
      blockId: 'block',
      cycleId: 'cycle',
      sessionId: 'session',
      startedAt: DateTime.utc(2026),
    );
    final evaluator = AuthoredLinePuzzleEvaluator();
    evaluator.initialize(puzzle: puzzle, attempt: attempt);
    final finalState = evaluator.reveal();
    final presentation = PuzzlePresentationState.fromDomain(
      puzzle: puzzle,
      evaluation: finalState,
    );
    var nextCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PuzzleSolutionReviewView(
            presentation: presentation,
            onNext: () => nextCalls++,
            isFinalExercise: true,
          ),
        ),
      ),
    );
    expect(find.text('Solution line'), findsOneWidget);
    expect(find.text('Puzzle note'), findsOneWidget);
    expect(find.text('Starting position'), findsOneWidget);
    expect(find.text('e4'), findsWidgets);
    expect(find.text('e5'), findsOneWidget);
    expect(find.text('Reply annotation'), findsNothing);
    expect(find.text('Position after e4: position after e4'), findsNothing);

    await tester.tap(find.byTooltip('Next move'));
    await tester.pumpAndSettle();
    expect(find.text('Selected move: e4'), findsOneWidget);
    expect(find.text('Root annotation'), findsOneWidget);
    expect(find.text('Annotations: !'), findsOneWidget);
    await tester.tap(find.byTooltip('Next move'));
    await tester.pumpAndSettle();
    expect(find.text('Selected move: e5'), findsOneWidget);
    expect(find.text('Reply annotation'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('variation-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Variation at move 2: c5'));
    await tester.pumpAndSettle();
    expect(find.text('Solution line'), findsOneWidget);
    expect(find.text('c5'), findsOneWidget);
    expect(find.text('Selected move: c5'), findsOneWidget);
    expect(find.text('Sicilian variation'), findsOneWidget);
    expect(find.text('Reply annotation'), findsNothing);
    expect(nextCalls, 0);
    expect(find.byType(AppBar), findsNothing);
    await tester.ensureVisible(find.text('Finish cycle'));
    await tester.tap(find.text('Finish cycle'));
    expect(nextCalls, 1);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('review restores accepted line, reached ply, and orientation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    final attempt = PuzzleAttempt(
      id: 'attempt-restored',
      blockId: 'block',
      cycleId: 'cycle',
      sessionId: 'session',
      startedAt: DateTime.utc(2026),
    );
    final evaluator = AuthoredLinePuzzleEvaluator();
    evaluator.initialize(puzzle: _terminalPuzzle, attempt: attempt);
    final evaluation = evaluator.reveal();
    final presentation = PuzzlePresentationState.fromDomain(
      puzzle: _terminalPuzzle,
      evaluation: evaluation,
      entries: const [
        PuzzlePlayedMove(
          uci: 'e2e4',
          san: 'e4',
          moveNumber: 1,
          side: PuzzleSide.white,
          actor: 'learner',
          accepted: true,
        ),
        PuzzlePlayedMove(
          uci: 'e7e5',
          san: 'e5',
          moveNumber: 1,
          side: PuzzleSide.black,
          actor: 'opponent',
          accepted: true,
        ),
      ],
      boardOrientation: PuzzleSide.black,
      usedFullLineFallback: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PuzzleSolutionReviewView(
            presentation: presentation,
            onNext: () {},
            canAdvance: false,
          ),
        ),
      ),
    );
    expect(find.text('Selected move: e5'), findsOneWidget);
    expect(
      find.text('Full line used: no completion marker on this continuation.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Next exercise'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<ReaderBoard>(find.byType(ReaderBoard)).board.orientation,
      chess.Side.black,
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
