import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/content_type.dart';
import '../../../domain/chess_content/move_node.dart';
import '../../../domain/training/puzzle_attempt.dart';
import '../../../domain/training/puzzle_evaluator.dart';

/// Safe, immutable data for presenting one puzzle attempt.
///
/// While the attempt is unfinished, this projection contains only the current
/// position and moves accepted from the user. The authored tree and its
/// annotations are copied into [solution] only once evaluation has finalized
/// the attempt (including an explicit reveal).
final class PuzzlePresentationState {
  PuzzlePresentationState._({
    required this.currentFen,
    required this.startingFen,
    required this.sideToMove,
    required this.attemptStatus,
    required this.outcome,
    required List<String> playedMoves,
    required List<PuzzlePresentationMove>? solution,
    required List<String> comments,
  }) : playedMoves = List.unmodifiable(playedMoves),
       solution = solution == null ? null : List.unmodifiable(solution),
       comments = List.unmodifiable(comments);

  /// Creates a presentation-safe projection of the puzzle and evaluator.
  factory PuzzlePresentationState.fromDomain({
    required ChessContent puzzle,
    required PuzzleEvaluationState evaluation,
  }) {
    if (puzzle.contentType != ContentType.puzzle) {
      throw ArgumentError.value(
        puzzle.contentType,
        'puzzle.contentType',
        'Puzzle presentation requires Puzzle content.',
      );
    }

    // A paused attempt is unfinished too. Only a terminal evaluation makes
    // authored content available to review presentation.
    final solutionVisible =
        evaluation.isFinalized || evaluation.solutionRevealed;
    return PuzzlePresentationState._(
      currentFen: evaluation.currentFen,
      startingFen: puzzle.startingFen,
      sideToMove: evaluation.sideToMove,
      attemptStatus: evaluation.attempt.status,
      outcome: evaluation.attempt.outcome,
      playedMoves: [
        for (final move in evaluation.moves)
          if (move.legal && move.accepted) move.move,
      ],
      solution: solutionVisible
          ? [
              for (final move in puzzle.rootMoves)
                PuzzlePresentationMove._(move),
            ]
          : null,
      // Block comments can also contain authored answers, so keep them behind
      // the same terminal-state gate as move annotations.
      comments: solutionVisible ? puzzle.comments : const [],
    );
  }

  /// FEN for the current board position only.
  final String currentFen;

  /// Authored starting position used to replay the revealed line for review.
  final String startingFen;

  /// Side to move in [currentFen].
  final PuzzleSide sideToMove;

  /// Persisted lifecycle status, safe to use for active/paused/review chrome.
  final PuzzleAttemptStatus attemptStatus;

  /// Persisted terminal outcome, or null while active or paused.
  final PuzzleAttemptOutcome? outcome;

  /// User-submitted moves accepted along the authored line, in UCI notation.
  /// Rejected submissions are omitted from the active presentation projection.
  final List<String> playedMoves;

  /// Authored solution tree, including future positions and annotations.
  /// This is `null` until the attempt has finalized or been explicitly revealed.
  final List<PuzzlePresentationMove>? solution;

  /// Block-level comments, withheld while the attempt is unfinished.
  final List<String> comments;

  bool get isSolutionVisible => solution != null;
}

/// A solution-tree node exposed only by a finalized presentation state.
///
/// Keeping this separate from [MoveNode] ensures widgets depend on the safe
/// presentation model rather than the complete imported content model.
final class PuzzlePresentationMove {
  PuzzlePresentationMove._(MoveNode move)
    : san = move.san,
      uci = move.uci,
      fenBefore = move.fenBefore,
      fenAfter = move.fenAfter,
      comments = List.unmodifiable(move.comments),
      nags = List.unmodifiable(move.nags),
      children = List.unmodifiable([
        for (final child in move.children) PuzzlePresentationMove._(child),
      ]);

  final String san;
  final String uci;
  final String fenBefore;
  final String fenAfter;
  final List<String> comments;
  final List<int> nags;
  final List<PuzzlePresentationMove> children;
}
