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

String _afterMove(String fen, String uci) {
  final position = chess.Chess.fromSetup(chess.Setup.parseFen(fen));
  final move = chess.Move.parse(uci)!;
  return (position.play(move) as chess.Chess).fen;
}

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
    final semantics = tester.ensureSemantics();
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
      PuzzleAttemptOutcome.wrongMove: 'First attempt failed',
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
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Solution line',
        ),
        findsOneWidget,
      );
      expect(find.text('e4'), findsWidgets);
      expect(find.byTooltip(labels[expectedOutcome]!), findsOneWidget);
      expect(find.bySemanticsLabel('Puzzle outcome'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Puzzle outcome')).value,
        labels[expectedOutcome],
      );
      await tester.ensureVisible(find.byTooltip('Next move'));
      await tester.tap(find.byTooltip('Next move'));
      await tester.pumpAndSettle();
      expect(presentation.outcome, expectedOutcome);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    semantics.dispose();
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
    List<int>? selectedPath;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PuzzleSolutionReviewView(
            presentation: presentation,
            onNext: () => nextCalls++,
            onPathChanged: (path) => selectedPath = path,
            isFinalExercise: true,
          ),
        ),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Solution line',
      ),
      findsOneWidget,
    );
    expect(find.text('Puzzle note'), findsOneWidget);
    expect(
      tester.widget<ReaderBoard>(find.byType(ReaderBoard)).positionLabel,
      'Starting position.',
    );
    expect(find.text('e4'), findsWidgets);
    expect(find.text('e5'), findsOneWidget);
    expect(find.text('Reply annotation'), findsOneWidget);
    expect(find.text('Position after e4: position after e4'), findsNothing);

    await tester.tap(find.byTooltip('Next move'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ReaderBoard &&
            widget.positionLabel?.contains('e4.') == true,
      ),
      findsOneWidget,
    );
    expect(find.text('Root annotation'), findsOneWidget);
    expect(find.text('!'), findsWidgets);
    await tester.tap(find.byTooltip('Next move'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ReaderBoard &&
            widget.positionLabel?.contains('e5.') == true,
      ),
      findsOneWidget,
    );
    expect(find.text('Reply annotation'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('alternatives-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('alternative-1-1')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Solution line',
      ),
      findsOneWidget,
    );
    expect(find.text('c5'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ReaderBoard &&
            widget.positionLabel?.contains('c5.') == true,
      ),
      findsOneWidget,
    );
    expect(selectedPath, [0, 1]);
    expect(find.text('Sicilian variation'), findsOneWidget);
    expect(find.text('Reply annotation'), findsOneWidget);
    expect(nextCalls, 0);
    expect(find.byType(AppBar), findsNothing);
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
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ReaderBoard &&
            widget.positionLabel?.contains('e5.') == true,
      ),
      findsOneWidget,
    );
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
    PuzzleSide? savedOrientation;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PuzzleSolutionReviewView(
            key: const ValueKey('saved-review-orientation'),
            presentation: presentation,
            initialOrientation: PuzzleSide.white,
            onOrientationChanged: (value) => savedOrientation = value,
          ),
        ),
      ),
    );
    expect(
      tester.widget<ReaderBoard>(find.byType(ReaderBoard)).board.orientation,
      chess.Side.white,
    );
    await tester.tap(find.byTooltip('Flip board'));
    await tester.pump();
    expect(savedOrientation, PuzzleSide.black);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('nested alternatives return to the played branch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    final afterE4 = _afterMove(_fen, 'e2e4');
    final afterE5 = _afterMove(afterE4, 'e7e5');
    final afterC5 = _afterMove(afterE4, 'c7c5');
    final afterNf3 = _afterMove(afterC5, 'g1f3');
    final afterNc3 = _afterMove(afterC5, 'b1c3');
    final puzzle = ChessContent(
      headers: const {},
      startingFen: _fen,
      contentType: ContentType.puzzle,
      rootMoves: [
        MoveNode(
          san: 'e4',
          uci: 'e2e4',
          fenBefore: _fen,
          fenAfter: afterE4,
          children: [
            MoveNode(
              san: 'e5',
              uci: 'e7e5',
              fenBefore: afterE4,
              fenAfter: afterE5,
              comments: const ['Played reply'],
            ),
            MoveNode(
              san: 'c5',
              uci: 'c7c5',
              fenBefore: afterE4,
              fenAfter: afterC5,
              comments: const ['Sicilian line'],
              children: [
                MoveNode(
                  san: 'Nf3',
                  uci: 'g1f3',
                  fenBefore: afterC5,
                  fenAfter: afterNf3,
                  children: [
                    MoveNode(
                      san: 'e6',
                      uci: 'e7e6',
                      fenBefore: afterNf3,
                      fenAfter: _afterMove(afterNf3, 'e7e6'),
                    ),
                    MoveNode(
                      san: 'd6',
                      uci: 'd7d6',
                      fenBefore: afterNf3,
                      fenAfter: _afterMove(afterNf3, 'd7d6'),
                    ),
                  ],
                ),
                MoveNode(
                  san: 'Nc3',
                  uci: 'b1c3',
                  fenBefore: afterC5,
                  fenAfter: afterNc3,
                  children: [
                    MoveNode(
                      san: 'Nf6',
                      uci: 'g8f6',
                      fenBefore: afterNc3,
                      fenAfter: _afterMove(afterNc3, 'g8f6'),
                    ),
                    MoveNode(
                      san: 'Nc6',
                      uci: 'b8c6',
                      fenBefore: afterNc3,
                      fenAfter: _afterMove(afterNc3, 'b8c6'),
                      comments: const ['Nested branch note'],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final evaluator = AuthoredLinePuzzleEvaluator();
    evaluator.initialize(
      puzzle: puzzle,
      attempt: PuzzleAttempt(
        id: 'nested-review',
        blockId: 'block',
        cycleId: 'cycle',
        sessionId: 'session',
        startedAt: DateTime.utc(2026),
      ),
    );
    final presentation = PuzzlePresentationState.fromDomain(
      puzzle: puzzle,
      evaluation: evaluator.reveal(),
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
    );
    List<int>? selectedPath;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PuzzleSolutionReviewView(
            presentation: presentation,
            initialPath: const [0, 0],
            onPathChanged: (path) => selectedPath = path,
          ),
        ),
      ),
    );

    expect(find.text('Played reply'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('alternatives-1')));
    await tester.pumpAndSettle();
    expect(find.text('1... c5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('alternative-1-1')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ReaderBoard &&
            widget.positionLabel?.contains('c5.') == true,
      ),
      findsOneWidget,
    );
    expect(find.text('Sicilian line'), findsOneWidget);
    expect(selectedPath, [0, 1]);

    await tester.tap(find.byTooltip('Previous move'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ReaderBoard &&
            widget.positionLabel?.contains('e4.') == true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Next move'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ReaderBoard &&
            widget.positionLabel?.contains('c5.') == true,
      ),
      findsOneWidget,
    );
    expect(selectedPath, [0, 1]);

    await tester.tap(find.byKey(const ValueKey('alternatives-2')));
    await tester.pumpAndSettle();
    expect(find.text('2. Nc3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('alternative-2-1')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ReaderBoard &&
            widget.positionLabel?.contains('Nc3.') == true,
      ),
      findsOneWidget,
    );
    expect(selectedPath, [0, 1, 1]);
    await tester.tap(find.byKey(const ValueKey('alternatives-3')));
    await tester.pumpAndSettle();
    expect(find.text('2... Nc6'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('alternative-3-1')));
    await tester.pumpAndSettle();
    expect(find.text('Nested branch note'), findsOneWidget);
    expect(selectedPath, [0, 1, 1, 1]);

    await tester.tap(find.byKey(const ValueKey('return-to-played-line')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ReaderBoard &&
            widget.positionLabel?.contains('e5.') == true,
      ),
      findsOneWidget,
    );
    expect(selectedPath, [0, 0]);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('review actions stay visible with long notes at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    final longNotes = List.generate(
      30,
      (index) => 'Review note $index ${'long ' * 20}',
    );
    final puzzle = ChessContent(
      headers: const {},
      startingFen: _fen,
      contentType: ContentType.puzzle,
      comments: longNotes,
      rootMoves: _terminalPuzzle.rootMoves,
    );
    final evaluator = AuthoredLinePuzzleEvaluator();
    evaluator.initialize(
      puzzle: puzzle,
      attempt: PuzzleAttempt(
        id: 'small-review',
        blockId: 'block',
        cycleId: 'cycle',
        sessionId: 'session',
        startedAt: DateTime.utc(2026),
      ),
    );
    final presentation = PuzzlePresentationState.fromDomain(
      puzzle: puzzle,
      evaluation: evaluator.reveal(),
      rejections: [
        PuzzleRejection(
          ordinal: 1,
          uci: 'e2e3',
          san: 'e3',
          authoredPath: const [],
          fenBefore: _fen,
          actor: 'learner',
          legal: true,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: PuzzleSolutionReviewView(
            presentation: presentation,
            onRetry: () {},
            onNext: () {},
            nextLabel: 'Next block',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(presentation.comments, hasLength(30));
    final detailsScroll = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(find.text('Puzzle notes'), findsNothing);
    expect(find.textContaining('Review note 0'), findsOneWidget);
    final initialNotesExtent = detailsScroll.position.maxScrollExtent;
    expect(initialNotesExtent, greaterThan(0));

    final retry = find.text('Try again');
    final next = find.text('Next block');
    expect(retry, findsOneWidget);
    expect(next, findsOneWidget);
    expect(
      find.ancestor(of: retry, matching: find.byType(ListView)),
      findsNothing,
    );
    expect(
      find.ancestor(of: next, matching: find.byType(ListView)),
      findsNothing,
    );
    for (final action in [retry, next]) {
      final rect = tester.getRect(action);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(640));
    }
    final actionBottomBeforeScroll = tester.getRect(next).bottom;
    // Scroll as a learner would: lazy children of different heights can
    // change the estimated extent while the engine controls enter view.
    await tester.scrollUntilVisible(
      find.text('1. e3'),
      250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await tester.pumpAndSettle();
    expect(detailsScroll.position.maxScrollExtent, greaterThan(0));
    expect(find.text('1 distinct wrong move'), findsNothing);
    expect(find.text('1. e3'), findsOneWidget);
    expect(tester.getRect(next).bottom, actionBottomBeforeScroll);
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('review keeps both actions reachable in compact landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    final evaluator = AuthoredLinePuzzleEvaluator();
    evaluator.initialize(
      puzzle: _terminalPuzzle,
      attempt: PuzzleAttempt(
        id: 'compact-landscape',
        blockId: 'block',
        cycleId: 'cycle',
        sessionId: 'session',
        startedAt: DateTime.utc(2026),
      ),
    );
    final presentation = PuzzlePresentationState.fromDomain(
      puzzle: _terminalPuzzle,
      evaluation: evaluator.reveal(),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: PuzzleSolutionReviewView(
            presentation: presentation,
            onRetry: () {},
            onNext: () {},
            nextLabel: 'Next block',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Next block'), findsOneWidget);
    for (final action in [
      find.widgetWithText(OutlinedButton, 'Try again'),
      find.widgetWithText(FilledButton, 'Next block'),
    ]) {
      final rect = tester.getRect(action);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(360));
      expect(rect.height, lessThanOrEqualTo(56));
    }
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
