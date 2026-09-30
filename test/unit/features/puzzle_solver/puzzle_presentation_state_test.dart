import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/domain/training/authored_line_puzzle_evaluator.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/features/puzzle_solver/application/puzzle_presentation_state.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
final _startTime = DateTime.utc(2026, 9, 29);

ChessContent _puzzle() => ChessContent(
  headers: const {},
  startingFen: _startFen,
  contentType: ContentType.puzzle,
  comments: const ['puzzle comment'],
  rootMoves: [
    MoveNode(
      san: 'e4',
      uci: 'e2e4',
      fenBefore: _startFen,
      fenAfter: 'position after e4',
      comments: const ['solution comment'],
      nags: const [1],
      children: [
        MoveNode(
          san: 'e5',
          uci: 'e7e5',
          fenBefore: 'position after e4',
          fenAfter: 'position after e5',
          comments: const ['reply comment'],
          nags: const [2],
        ),
      ],
    ),
  ],
);

PuzzleAttempt _attempt() => PuzzleAttempt(
  id: 'attempt-1',
  blockId: 'block-1',
  cycleId: 'cycle-1',
  sessionId: 'session-1',
  startedAt: _startTime,
);

void main() {
  test(
    'hides authored content until finalization and freezes review lists',
    () {
      final puzzle = _puzzle();
      final evaluator = AuthoredLinePuzzleEvaluator();
      final active = evaluator.initialize(puzzle: puzzle, attempt: _attempt());
      final activeView = PuzzlePresentationState.fromDomain(
        puzzle: puzzle,
        evaluation: active,
      );

      expect(activeView.solution, isNull);
      expect(activeView.comments, isEmpty);
      expect(activeView.playedMoves, isEmpty);

      evaluator.submitMove(uci: 'e2e4');
      final review = evaluator.submitMove(uci: 'e7e5');
      final reviewView = PuzzlePresentationState.fromDomain(
        puzzle: puzzle,
        evaluation: review,
      );

      expect(reviewView.isSolutionVisible, isTrue);
      expect(reviewView.playedMoves, ['e2e4', 'e7e5']);
      expect(reviewView.comments, ['puzzle comment']);
      final root = reviewView.solution!.single;
      final child = root.children.single;
      expect(root.comments, ['solution comment']);
      expect(child.comments, ['reply comment']);
      expect(() => reviewView.playedMoves.add('e7e5'), throwsUnsupportedError);
      expect(() => reviewView.comments.add('changed'), throwsUnsupportedError);
      expect(() => reviewView.solution!.add(root), throwsUnsupportedError);
      expect(() => root.comments.add('changed'), throwsUnsupportedError);
      expect(() => root.nags.add(3), throwsUnsupportedError);
      expect(() => root.children.clear(), throwsUnsupportedError);
      expect(() => child.comments.add('changed'), throwsUnsupportedError);
    },
  );
}
