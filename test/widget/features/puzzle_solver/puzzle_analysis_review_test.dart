import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/analysis/exploration_repository.dart';
import 'package:pgntrainingreader/domain/analysis/exploration_session.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/domain/training/authored_line_puzzle_evaluator.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/features/analysis/presentation/analysis_panel.dart';
import 'package:pgntrainingreader/features/analysis/presentation/exploration_workspace.dart';
import 'package:pgntrainingreader/features/game_reader/presentation/reader_board.dart';
import 'package:pgntrainingreader/features/puzzle_solver/application/puzzle_presentation_state.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_solution_review_view.dart';

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

final _puzzle = ChessContent(
  headers: const {},
  startingFen: _fen,
  contentType: ContentType.puzzle,
  comments: const ['Book introduction'],
  rootMoves: [
    MoveNode(
      san: 'e4',
      uci: 'e2e4',
      fenBefore: _fen,
      fenAfter: (chess.Chess.fromSetup(
        chess.Setup.parseFen(_fen),
      ).play(chess.Move.parse('e2e4')!) as chess.Chess).fen,
      comments: const ['Author explains e4'],
    ),
  ],
);

AuthoredLinePuzzleEvaluator _evaluator() {
  final evaluator = AuthoredLinePuzzleEvaluator();
  evaluator.initialize(
    puzzle: _puzzle,
    attempt: PuzzleAttempt(
      id: 'attempt',
      blockId: 'block',
      cycleId: 'cycle',
      sessionId: 'session',
      startedAt: DateTime.utc(2026),
    ),
  );
  return evaluator;
}

void main() {
  testWidgets('a new scope clears exploration with the same presentation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final evaluator = _evaluator()..reveal();
    final presentation = PuzzlePresentationState.fromDomain(
      puzzle: _puzzle,
      evaluation: evaluator.state!,
    );
    final key = GlobalKey<PuzzleSolutionReviewViewState>();
    Widget app(String scope) => MaterialApp(
      home: Scaffold(
        body: PuzzleSolutionReviewView(
          key: key,
          presentation: presentation,
          explorationScopeId: scope,
        ),
      ),
    );
    await tester.pumpWidget(app('revision-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore position'));
    await tester.pumpAndSettle();
    expect(key.currentState!.isExploring, isTrue);
    await tester.pumpWidget(app('revision-2'));
    await tester.pumpAndSettle();
    expect(key.currentState!.isExploring, isFalse);
    await tester.tap(find.text('Explore position'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ExplorationWorkspace>(find.byType(ExplorationWorkspace))
          .origin
          .scopeId,
      'revision-2',
    );
  });

  testWidgets(
    'final failed concealed practice cannot open engine or exploration',
    (tester) async {
      final evaluator = _evaluator()..submitMove(uci: 'd2d4');
      expect(evaluator.state!.attempt.outcome, PuzzleAttemptOutcome.wrongMove);
      final presentation = PuzzlePresentationState.fromDomain(
        puzzle: _puzzle,
        evaluation: evaluator.state!,
        phase: PuzzleInteractionPhase.failedPractice,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PuzzleSolutionReviewView(presentation: presentation),
          ),
        ),
      );
      expect(find.byType(AnalysisPanel), findsNothing);
      expect(find.text('Explore position'), findsNothing);
      expect(find.text('Book introduction'), findsNothing);
    },
  );

  testWidgets(
    'review detour preserves reached position and source, and starts engine off',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final evaluator = _evaluator()..submitMove(uci: 'e2e4');
      final outcome = evaluator.state!.attempt.outcome;
      final duration = evaluator.state!.attempt.activeDuration;
      final originalMoves = _puzzle.rootMoves;
      final presentation = PuzzlePresentationState.fromDomain(
        puzzle: _puzzle,
        evaluation: evaluator.state!,
      );
      final key = GlobalKey<PuzzleSolutionReviewViewState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PuzzleSolutionReviewView(
              key: key,
              presentation: presentation,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester
          .widget<ReaderBoard>(find.byType(ReaderBoard))
          .board
          .game
          .fen;
      await tester.tap(find.text('Explore position'));
      await tester.pumpAndSettle();
      final workspace = tester.widget<ExplorationWorkspace>(
        find.byType(ExplorationWorkspace),
      );
      expect(workspace.origin.authoredMoves, ['e2e4']);
      expect(workspace.origin.authoredPath, [0]);
      expect(find.text('Engine: Off'), findsOneWidget);
      expect(key.currentState!.isExploring, isTrue);
      await tester.tap(find.text('Return to review'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ReaderBoard>(find.byType(ReaderBoard)).board.game.fen,
        before,
      );
      expect(identical(_puzzle.rootMoves, originalMoves), isTrue);
      expect(evaluator.state!.attempt.outcome, outcome);
      expect(evaluator.state!.attempt.activeDuration, duration);
    },
  );

  testWidgets(
    'reviewing a legal rejected try seeds it without changing accepted solution',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final evaluator = _evaluator()..reveal();
      final presentation = PuzzlePresentationState.fromDomain(
        puzzle: _puzzle,
        evaluation: evaluator.state!,
        rejections: [
          PuzzleRejection(
            ordinal: 1,
            uci: 'd2d4',
            san: 'd4',
            authoredPath: const [],
            fenBefore: _fen,
            actor: 'learner',
            legal: true,
          ),
        ],
      );
      final repository = _Drafts();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PuzzleSolutionReviewView(
              presentation: presentation,
              explorationScopeId: 'block-revision-1',
              explorationRepository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Your tries'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explore this try'));
      await tester.pumpAndSettle();
      final workspace = tester.widget<ExplorationWorkspace>(
        find.byType(ExplorationWorkspace),
      );
      expect(workspace.origin.authoredPath, isEmpty);
      expect(workspace.origin.discriminator, 'try:d2d4');
      await tester.tap(find.text('Return to review'));
      await tester.pumpAndSettle();
      expect(repository.draft!.moves, ['d2d4']);
      expect(presentation.playedMoves, isEmpty);
      expect(presentation.rejections.single.uci, 'd2d4');
      expect(evaluator.state!.attempt.outcome, PuzzleAttemptOutcome.revealed);
    },
  );
}

class _Drafts implements ExplorationRepository {
  ExplorationSession? draft;
  @override
  Future<ExplorationSession?> load(ExplorationOrigin origin) async => draft;
  @override
  Future<void> save(ExplorationSession session) async => draft = session;
}
