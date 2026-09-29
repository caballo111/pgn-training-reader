import '../chess_content/chess_content.dart';
import 'attempt_move.dart';
import 'puzzle_attempt.dart';

/// Side of the chessboard that is to move in a puzzle position.
enum PuzzleSide { white, black }

/// Immutable view of the evaluator after initialization or a user action.
///
/// This snapshot exposes the current position and recorded user moves, but
/// never exposes the solution tree. [attempt] contains the current attempt
/// record; a non-null outcome means the attempt has been finalized.
final class PuzzleEvaluationState {
  PuzzleEvaluationState({
    required this.attempt,
    required this.currentFen,
    required this.sideToMove,
    required List<AttemptMove> moves,
  }) : moves = List.unmodifiable(moves) {
    if (currentFen.isEmpty) {
      throw ArgumentError.value(currentFen, 'currentFen', 'Must not be empty.');
    }
  }

  /// Current durable attempt data, including its final outcome when present.
  final PuzzleAttempt attempt;

  /// FEN for the currently displayed position.
  final String currentFen;

  /// Active side in [currentFen].
  final PuzzleSide sideToMove;

  /// User-submitted moves in submission order.
  final List<AttemptMove> moves;

  /// Whether the attempt has reached a terminal outcome.
  bool get isFinalized => attempt.outcome != null;

  /// Whether the solution is available for presentation.
  bool get solutionRevealed => attempt.revealed;
}

/// Evaluates submitted moves against legal chess moves and the authored PGN
/// solution tree.
///
/// The interface is independent of Flutter, persistence, and chess-library
/// types. Implementations must use the application's chess-rules adapter for
/// legality and must accept only authored solution-tree children. In
/// accordance with specification FR-023, a submitted move that is illegal in
/// the current position immediately finalizes the attempt as
/// [PuzzleAttemptOutcome.wrongMove] with
/// [PuzzleAttemptFailureReason.illegalMove]. An illegal board interaction
/// that is not submitted to this service is outside this contract.
abstract interface class PuzzleEvaluator {
  /// Latest state, or `null` before [initialize] has completed.
  PuzzleEvaluationState? get state;

  /// Final attempt after completion, failure, or reveal; otherwise `null`.
  PuzzleAttempt? get finalAttempt;

  /// Starts evaluating [puzzle] for the unfinished [attempt].
  ///
  /// The content must be a supported Puzzle with a valid starting position
  /// and at least one authored solution move. [attempt] must not already be
  /// finalized. Implementations must conceal the solution in the returned
  /// state.
  PuzzleEvaluationState initialize({
    required ChessContent puzzle,
    required PuzzleAttempt attempt,
  });

  /// Returns legal destination squares for [fromSquare] in the current
  /// position using algebraic board coordinates such as `e2` and `e4`.
  ///
  /// This reports chess legality, not solution correctness. An empty set is
  /// returned after finalization. Calling before initialization is an invalid
  /// state and may throw [StateError].
  Set<String> legalDestinations({required String fromSquare});

  /// Submits a move in UCI notation, for example `e2e4` or `e7e8q`.
  ///
  /// An accepted authored child advances the puzzle; completing an accepted
  /// terminal solution finalizes the attempt as `passed`. A legal move outside
  /// the authored children finalizes it as `wrong_move` with reason
  /// `incorrectMove`. An illegal submitted move finalizes it as `wrong_move`
  /// with reason `illegalMove`, as required by FR-023. No move may be submitted
  /// before initialization or after finalization.
  PuzzleEvaluationState submitMove({required String uci});

  /// Finalizes an unfinished attempt as `revealed` and makes the authored
  /// solution available to presentation. If already finalized, the historical
  /// result is retained unchanged.
  PuzzleEvaluationState reveal();
}
