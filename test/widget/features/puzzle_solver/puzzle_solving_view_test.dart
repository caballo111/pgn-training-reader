// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_board.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/domain/training/attempt_move.dart';
import 'package:pgntrainingreader/domain/training/authored_line_puzzle_evaluator.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/domain/training/timing_segment.dart';
import 'package:pgntrainingreader/domain/training/training_repository.dart';
import 'package:pgntrainingreader/features/puzzle_solver/application/puzzle_solver_controller.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_solving_view.dart';
import 'package:pgntrainingreader/domain/training/puzzle_evaluator.dart';

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
final _started = DateTime.utc(2026, 9, 29);

final _puzzle = ChessContent(
  headers: const {'White': 'Secret Player Name', 'Event': 'Secret Event Title'},
  startingFen: _fen,
  comments: const ['Secret block comment'],
  contentType: ContentType.puzzle,
  rootMoves: [
    MoveNode(
      san: 'e4',
      uci: 'e2e4',
      fenBefore: _fen,
      fenAfter: 'hidden-position',
      comments: const ['Secret solution comment'],
      nags: const [1],
      children: [
        MoveNode(
          san: 'e5',
          uci: 'e7e5',
          fenBefore: 'hidden-position',
          fenAfter: 'later-position',
          comments: const ['Secret variation label'],
          children: [
            MoveNode(
              san: 'Nf3',
              uci: 'g1f3',
              fenBefore: 'hidden',
              fenAfter: 'hidden',
            ),
          ],
        ),
      ],
    ),
  ],
);

final class _Ids implements IdGenerator {
  int next = 0;
  @override
  String generateId() => 'move-${next++}';
}

final class _Repository implements TrainingRepository {
  _Repository(this.attempt);
  PuzzleAttempt attempt;
  final List<AttemptMove> moves = [];

  @override
  Future<PuzzleAttempt?> getAttempt(String id) async => attempt;
  @override
  Future<List<AttemptMove>> listAttemptMoves(String id) async => List.of(moves);
  @override
  Future<void> recordSubmittedMove({
    required AttemptMove move,
    required PuzzleAttempt updatedAttempt,
    TimingSegment? closingTimingSegment,
  }) async {
    moves.add(move);
    attempt = updatedAttempt;
  }

  @override
  Future<void> finalizeAttempt({
    required PuzzleAttempt attempt,
    TimingSegment? finalTimingSegment,
  }) async {
    this.attempt = attempt;
  }

  @override
  Future<void> updateUnfinishedAttempt(PuzzleAttempt attempt) async {
    this.attempt = attempt;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'renders the learner position and locks the board during reply delay',
    (tester) async {
      final attempt = PuzzleAttempt(
        id: 'attempt-reply-delay',
        blockId: 'block',
        cycleId: 'cycle',
        sessionId: 'session',
        startedAt: _started,
      );
      final controller = PuzzleSolverController(
        repository: _Repository(attempt),
        evaluatorFactory: () =>
            AuthoredLinePuzzleEvaluator(idGenerator: _Ids()),
      );
      await controller.initialize(puzzle: _puzzle, attemptId: attempt.id);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PuzzleSolvingView(
              controller: controller,
              currentExercise: 1,
              totalExercises: 1,
              orientation: PuzzleSide.white,
              onPause: () {},
            ),
          ),
        ),
      );
      await controller.hint();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('puzzle-hint-square-highlight')),
        findsOneWidget,
      );
      final before = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).fen;

      final transition = controller.submitMove(uci: 'e2e4');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      final duringReply = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
      expect(duringReply.fen, isNot(before));
      expect(duringReply.fen.split(' ')[1], 'b');
      expect(duringReply.enabled, isFalse);
      expect(
        find.byKey(const ValueKey('puzzle-hint-square-highlight')),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 350));
      await transition;
      await tester.pump();
      expect(
        tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).fen.split(' ')[1],
        'w',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'active view shows accepted user moves and hides puzzle answers',
    (tester) async {
      final attempt = PuzzleAttempt(
        id: 'attempt',
        blockId: 'block',
        cycleId: 'cycle',
        sessionId: 'session',
        startedAt: _started,
      );
      final repository = _Repository(attempt);
      final ids = _Ids();
      final controller = PuzzleSolverController(
        repository: repository,
        evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: ids),
        automaticReplyDelay: Duration.zero,
      );
      await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');
      await controller.submitMove(uci: 'e2e4');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Puzzle')),
            body: PuzzleSolvingView(
              controller: controller,
              currentExercise: 2,
              totalExercises: 5,
              orientation: PuzzleSide.white,
              onPause: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();

      expect(find.text('1. e4'), findsOneWidget);
      expect(find.text('1... e5 (reply)'), findsOneWidget);
      expect(find.text('Moves played'), findsOneWidget);
      expect(find.text('White to move'), findsOneWidget);
      for (final secret in [
        'e4',
        'g1f3',
        'Secret solution comment',
        'Secret variation label',
        'Secret block comment',
        'Secret Player Name',
        'Secret Event Title',
        'hidden-position',
        'later-position',
        '1',
      ]) {
        expect(
          find.text(secret),
          findsNothing,
          reason: '$secret should stay hidden',
        );
      }

      // The test view's semantics owner is attached to its pipeline owner.
      final semanticsTree = tester
          .binding
          .pipelineOwner
          .semanticsOwner!
          .rootSemanticsNode!
          .toStringDeep();
      expect(semanticsTree, contains('1. e4'));
      for (final secret in [
        'g1f3',
        'Secret solution comment',
        'Secret variation label',
        'Secret block comment',
        'Secret Player Name',
        'Secret Event Title',
        'hidden-position',
        'later-position',
      ]) {
        expect(
          semanticsTree,
          isNot(contains(secret)),
          reason: '$secret leaked into semantics',
        );
      }
      expect(semanticsTree, isNot(contains('label: "e4"')));
      expect(semanticsTree, isNot(contains('label: "e5"')));
      semantics.dispose();
    },
  );

  testWidgets('pause persists, disables the board, and can be resumed', (
    tester,
  ) async {
    final attempt = PuzzleAttempt(
      id: 'attempt',
      blockId: 'block',
      cycleId: 'cycle',
      sessionId: 'session',
      startedAt: _started,
    );
    final repository = _Repository(attempt);
    final controller = PuzzleSolverController(
      repository: repository,
      evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: _Ids()),
      automaticReplyDelay: Duration.zero,
    );
    await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');
    var pauseNotified = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Puzzle')),
          body: PuzzleSolvingView(
            controller: controller,
            currentExercise: 1,
            totalExercises: 1,
            orientation: PuzzleSide.white,
            onPause: () => pauseNotified = true,
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Pause'));
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();

    expect(repository.attempt.status.name, 'paused');
    expect(pauseNotified, isTrue);
    expect(find.text('Attempt paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(
      tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).enabled,
      isFalse,
    );

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(repository.attempt.status.name, 'active');
    expect(
      tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).enabled,
      isTrue,
    );
    expect(find.text('Attempt paused'), findsNothing);
    expect(find.text('Pause'), findsOneWidget);
  });
}
