import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/domain/training/authored_line_puzzle_evaluator.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/domain/training/puzzle_evaluator.dart';

const _whiteToMoveFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _blackToMoveFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1';
final _startedAt = DateTime.utc(2026, 9, 29);

ChessContent _puzzle({
  required String fen,
  required String uci,
  required String san,
}) => ChessContent(
  headers: const {},
  startingFen: fen,
  contentType: ContentType.puzzle,
  rootMoves: [
    MoveNode(
      san: san,
      uci: uci,
      fenBefore: fen,
      fenAfter: 'position after $uci',
    ),
  ],
);

PuzzleAttempt _attempt(String id) => PuzzleAttempt(
  id: id,
  blockId: 'block-$id',
  cycleId: 'cycle-1',
  sessionId: 'session-1',
  startedAt: _startedAt,
);

void main() {
  test('derives White to move from a White-to-move FEN and accepts a move', () {
    final evaluator = AuthoredLinePuzzleEvaluator();
    final state = evaluator.initialize(
      puzzle: _puzzle(fen: _whiteToMoveFen, uci: 'e2e4', san: 'e4'),
      attempt: _attempt('white-attempt'),
    );

    expect(state.sideToMove, PuzzleSide.white);
    expect(
      evaluator.legalDestinations(fromSquare: 'e2'),
      containsAll(['e3', 'e4']),
    );

    final completed = evaluator.submitMove(uci: 'e2e4');
    expect(completed.moves.single.accepted, isTrue);
    expect(completed.attempt.outcome, PuzzleAttemptOutcome.passed);
  });

  test('derives Black to move from a Black-to-move FEN and accepts a move', () {
    final evaluator = AuthoredLinePuzzleEvaluator();
    final state = evaluator.initialize(
      puzzle: _puzzle(fen: _blackToMoveFen, uci: 'e7e5', san: 'e5'),
      attempt: _attempt('black-attempt'),
    );

    expect(state.sideToMove, PuzzleSide.black);
    expect(
      evaluator.legalDestinations(fromSquare: 'e7'),
      containsAll(['e6', 'e5']),
    );

    final completed = evaluator.submitMove(uci: 'e7e5');
    expect(completed.moves.single.accepted, isTrue);
    expect(completed.attempt.outcome, PuzzleAttemptOutcome.passed);
  });
}
