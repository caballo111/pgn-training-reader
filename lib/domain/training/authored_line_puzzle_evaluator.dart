import 'package:dartchess/dartchess.dart' as chess;

import '../../core/time/app_clock.dart';
import '../../core/utilities/id_generator.dart';
import '../chess_content/chess_content.dart';
import '../chess_content/content_type.dart';
import '../chess_content/move_node.dart';
import 'attempt_move.dart';
import 'puzzle_attempt.dart';
import 'puzzle_evaluator.dart';

/// Evaluates submitted moves against the authored move tree of one puzzle.
///
/// The solution nodes are retained privately and are never included in
/// [PuzzleEvaluationState]. Paused attempts can be initialized for restoration,
/// but must be explicitly resumed before they accept a move.
final class AuthoredLinePuzzleEvaluator implements PuzzleEvaluator {
  AuthoredLinePuzzleEvaluator({AppClock? clock, IdGenerator? idGenerator})
    : _clock = clock ?? SystemAppClock(),
      _idGenerator = idGenerator ?? RandomIdGenerator();

  final AppClock _clock;
  final IdGenerator _idGenerator;

  ChessContent? _puzzle;
  PuzzleAttempt? _attempt;
  chess.Chess? _position;
  List<MoveNode> _currentChoices = const [];
  List<AttemptMove> _moves = const [];

  @override
  PuzzleEvaluationState? get state => _snapshotOrNull();

  @override
  PuzzleAttempt? get finalAttempt =>
      _attempt?.outcome == null ? null : _attempt;

  /// Initializes from the starting position and an unfinished attempt.
  ///
  /// [previousMoves] restores an active or paused attempt's accepted move
  /// history. Reinitializing the same attempt without an explicit history
  /// preserves its already loaded history.
  @override
  PuzzleEvaluationState initialize({
    required ChessContent puzzle,
    required PuzzleAttempt attempt,
    List<AttemptMove> previousMoves = const [],
  }) {
    final currentAttempt = _attempt;
    if (currentAttempt?.id == attempt.id && currentAttempt?.outcome != null) {
      throw StateError('A finalized attempt cannot be reinitialized.');
    }
    if (currentAttempt != null &&
        currentAttempt.outcome == null &&
        currentAttempt.id != attempt.id) {
      throw StateError(
        'An unfinished attempt must be finalized before replacement.',
      );
    }
    if (puzzle.contentType != ContentType.puzzle) {
      throw ArgumentError.value(
        puzzle.contentType,
        'puzzle.contentType',
        'Authored-line evaluation requires Puzzle content.',
      );
    }
    if (attempt.status == PuzzleAttemptStatus.finalized ||
        attempt.outcome != null) {
      throw StateError('A finalized attempt cannot be initialized.');
    }
    if (attempt.status != PuzzleAttemptStatus.active &&
        attempt.status != PuzzleAttemptStatus.paused) {
      throw StateError('Only active or paused attempts can be initialized.');
    }
    if (puzzle.rootMoves.isEmpty) {
      throw ArgumentError.value(
        puzzle.rootMoves,
        'puzzle.rootMoves',
        'Puzzle content must contain at least one authored solution move.',
      );
    }

    final initialPosition = _positionFromFen(puzzle.startingFen);
    for (final root in puzzle.rootMoves) {
      _validateLine(initialPosition, root);
    }
    final sameAttempt = _attempt?.id == attempt.id;
    final history = previousMoves.isNotEmpty
        ? List<AttemptMove>.of(previousMoves)
        : sameAttempt
        ? List<AttemptMove>.of(_moves)
        : <AttemptMove>[];
    final restored = _restoreMoves(
      puzzle: puzzle,
      attempt: attempt,
      initialPosition: initialPosition,
      moves: history,
    );

    _puzzle = puzzle;
    _attempt = attempt;
    _position = restored.position;
    _currentChoices = restored.node?.children ?? puzzle.rootMoves;
    _moves = List.unmodifiable(history);
    return _snapshot();
  }

  @override
  Set<String> legalDestinations({required String fromSquare}) {
    _requireInitialized();
    if (_attempt!.outcome != null) return const {};
    final from = chess.Square.parse(fromSquare);
    if (from == null) {
      throw FormatException('Invalid algebraic square.', fromSquare);
    }
    return Set.unmodifiable(
      chess.makeLegalMoves(_position!)[from]?.map((square) => square.name) ??
          const <String>[],
    );
  }

  @override
  PuzzleEvaluationState submitMove({required String uci}) {
    _requireInitialized();
    final attempt = _attempt!;
    if (attempt.outcome != null) {
      throw StateError('A finalized attempt cannot accept another move.');
    }
    if (attempt.status != PuzzleAttemptStatus.active) {
      throw StateError('Resume the paused attempt before submitting a move.');
    }

    final move = _parseUci(uci);
    final currentPosition = _position!;
    if (!currentPosition.isLegal(move)) {
      return _finalizeMove(
        uci: uci,
        legal: false,
        accepted: false,
        outcome: PuzzleAttemptOutcome.wrongMove,
        failureReason: PuzzleAttemptFailureReason.illegalMove,
      );
    }

    final acceptedNode = _currentChoices.cast<MoveNode?>().firstWhere(
      (node) => _parseUci(node!.uci).uci == move.uci,
      orElse: () => null,
    );
    if (acceptedNode == null) {
      return _finalizeMove(
        uci: uci,
        legal: true,
        accepted: false,
        outcome: PuzzleAttemptOutcome.wrongMove,
        failureReason: PuzzleAttemptFailureReason.incorrectMove,
      );
    }

    final nextPosition = currentPosition.play(move);
    final submitted = _newAttemptMove(uci, legal: true, accepted: true);
    _moves = List.unmodifiable([..._moves, submitted]);
    _position = nextPosition as chess.Chess;
    _currentChoices = acceptedNode.children;

    if (_currentChoices.isEmpty) {
      _finalize(
        outcome: PuzzleAttemptOutcome.passed,
        failureReason: null,
        revealed: false,
      );
    }
    return _snapshot();
  }

  @override
  PuzzleEvaluationState reveal() {
    _requireInitialized();
    if (_attempt!.outcome == null) {
      _finalize(
        outcome: PuzzleAttemptOutcome.revealed,
        failureReason: null,
        revealed: true,
      );
    }
    return _snapshot();
  }

  @override
  PuzzleEvaluationState skip() => _finalizeIfUnfinished(
    outcome: PuzzleAttemptOutcome.skipped,
    failureReason: null,
    revealed: false,
  );

  @override
  PuzzleEvaluationState timeout() => _finalizeIfUnfinished(
    outcome: PuzzleAttemptOutcome.timedOut,
    failureReason: PuzzleAttemptFailureReason.timeLimitExceeded,
    revealed: false,
  );

  @override
  PuzzleEvaluationState abandon() => _finalizeIfUnfinished(
    outcome: PuzzleAttemptOutcome.abandoned,
    failureReason: PuzzleAttemptFailureReason.userAbandoned,
    revealed: false,
  );

  PuzzleEvaluationState _finalizeIfUnfinished({
    required PuzzleAttemptOutcome outcome,
    required PuzzleAttemptFailureReason? failureReason,
    required bool revealed,
  }) {
    _requireInitialized();
    if (_attempt!.outcome == null) {
      _finalize(
        outcome: outcome,
        failureReason: failureReason,
        revealed: revealed,
      );
    }
    return _snapshot();
  }

  PuzzleEvaluationState _finalizeMove({
    required String uci,
    required bool legal,
    required bool accepted,
    required PuzzleAttemptOutcome outcome,
    required PuzzleAttemptFailureReason failureReason,
  }) {
    _moves = List.unmodifiable([
      ..._moves,
      _newAttemptMove(uci, legal: legal, accepted: accepted),
    ]);
    _finalize(
      outcome: outcome,
      failureReason: failureReason,
      revealed: false,
      wrongMoveCount: _attempt!.wrongMoveCount + 1,
    );
    return _snapshot();
  }

  AttemptMove _newAttemptMove(
    String uci, {
    required bool legal,
    required bool accepted,
  }) => AttemptMove(
    id: _idGenerator.generateId(),
    attemptId: _attempt!.id,
    ordinal: _moves.length,
    move: uci,
    legal: legal,
    accepted: accepted,
    submittedAt: _clock.utcNow,
  );

  void _finalize({
    required PuzzleAttemptOutcome outcome,
    required PuzzleAttemptFailureReason? failureReason,
    required bool revealed,
    int? wrongMoveCount,
  }) {
    final attempt = _attempt!;
    _attempt = _copyAttempt(
      attempt,
      status: PuzzleAttemptStatus.finalized,
      completedAt: _clock.utcNow,
      outcome: outcome,
      failureReason: failureReason,
      wrongMoveCount: wrongMoveCount ?? attempt.wrongMoveCount,
      revealed: revealed,
    );
  }

  PuzzleAttempt _copyAttempt(
    PuzzleAttempt attempt, {
    required PuzzleAttemptStatus status,
    DateTime? completedAt,
    PuzzleAttemptOutcome? outcome,
    PuzzleAttemptFailureReason? failureReason,
    int? wrongMoveCount,
    bool? revealed,
  }) => PuzzleAttempt(
    id: attempt.id,
    blockId: attempt.blockId,
    cycleId: attempt.cycleId,
    sessionId: attempt.sessionId,
    status: status,
    startedAt: attempt.startedAt,
    completedAt: completedAt,
    activeDuration: attempt.activeDuration,
    outcome: outcome,
    failureReason: failureReason,
    wrongMoveCount: wrongMoveCount ?? attempt.wrongMoveCount,
    hintCount: attempt.hintCount,
    revealed: revealed ?? attempt.revealed,
  );

  ({chess.Chess position, MoveNode? node}) _restoreMoves({
    required ChessContent puzzle,
    required PuzzleAttempt attempt,
    required chess.Chess initialPosition,
    required List<AttemptMove> moves,
  }) {
    var position = initialPosition;
    MoveNode? currentNode;
    var choices = puzzle.rootMoves;
    final seenIds = <String>{};
    for (var index = 0; index < moves.length; index++) {
      final submitted = moves[index];
      if (submitted.id.trim().isEmpty || !seenIds.add(submitted.id)) {
        throw ArgumentError.value(
          submitted.id,
          'previousMoves[$index].id',
          'Restored move IDs must be non-empty and unique.',
        );
      }
      if (submitted.attemptId != attempt.id ||
          submitted.ordinal != index ||
          !submitted.legal ||
          !submitted.accepted) {
        throw ArgumentError.value(
          moves,
          'previousMoves',
          'Restored unfinished attempts require ordered accepted legal moves.',
        );
      }
      final move = _parseUci(submitted.move);
      if (!position.isLegal(move)) {
        throw ArgumentError.value(
          submitted.move,
          'previousMoves[$index]',
          'Restored move is illegal in the current position.',
        );
      }
      final matchingNode = choices.cast<MoveNode?>().firstWhere(
        (node) => _parseUci(node!.uci).uci == move.uci,
        orElse: () => null,
      );
      if (matchingNode == null) {
        throw ArgumentError.value(
          submitted.move,
          'previousMoves[$index]',
          'Restored move is not in the authored solution.',
        );
      }
      position = position.play(move) as chess.Chess;
      currentNode = matchingNode;
      choices = currentNode.children;
      if (choices.isEmpty && index < moves.length - 1) {
        throw ArgumentError.value(
          moves,
          'previousMoves',
          'Restored moves continue beyond a terminal solution.',
        );
      }
    }
    if (moves.isNotEmpty && choices.isEmpty) {
      throw ArgumentError.value(
        moves,
        'previousMoves',
        'An unfinished attempt cannot resume after completing the solution.',
      );
    }
    return (position: position, node: currentNode);
  }

  chess.Move _parseUci(String uci) {
    if (uci.length < 4 || uci.length > 5) {
      throw FormatException('Invalid UCI move.', uci);
    }
    final move = chess.Move.parse(uci);
    if (move == null || move is! chess.NormalMove) {
      throw FormatException('Invalid UCI move.', uci);
    }
    return move;
  }

  chess.Chess _positionFromFen(String fen) {
    try {
      return chess.Chess.fromSetup(chess.Setup.parseFen(fen));
    } on FormatException catch (error) {
      throw FormatException('Invalid puzzle starting position: $error', fen);
    } on chess.PositionSetupException catch (error) {
      throw FormatException('Invalid puzzle starting position: $error', fen);
    }
  }

  void _validateLine(chess.Chess position, MoveNode node) {
    final move = _parseUci(node.uci);
    if (!position.isLegal(move)) {
      throw ArgumentError.value(
        node.uci,
        'puzzle.rootMoves',
        'Authored solution contains an illegal move.',
      );
    }
    final after = position.play(move) as chess.Chess;
    for (final child in node.children) {
      _validateLine(after, child);
    }
  }

  void _requireInitialized() {
    if (_attempt == null || _position == null || _puzzle == null) {
      throw StateError('Initialize the puzzle evaluator first.');
    }
  }

  PuzzleEvaluationState? _snapshotOrNull() =>
      _attempt == null ? null : _snapshot();

  PuzzleEvaluationState _snapshot() => PuzzleEvaluationState(
    attempt: _attempt!,
    currentFen: _position!.fen,
    sideToMove: _position!.turn == chess.Side.white
        ? PuzzleSide.white
        : PuzzleSide.black,
    moves: _moves,
  );
}
