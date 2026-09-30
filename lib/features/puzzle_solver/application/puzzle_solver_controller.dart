import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/training/attempt_move.dart';
import '../../../domain/training/puzzle_attempt.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../../../domain/training/timing_segment.dart';
import '../../../domain/training/training_repository.dart';
import 'puzzle_presentation_state.dart';

typedef PuzzleEvaluatorFactory = PuzzleEvaluator Function();
typedef PuzzleMoveRecorder = Future<PuzzleAttempt> Function({
  required AttemptMove move,
  required PuzzleAttempt updatedAttempt,
  required Duration activeSegmentDuration,
});
typedef PuzzleAttemptFinalizer = Future<PuzzleAttempt> Function({
  required String attemptId,
  required PuzzleAttemptOutcome outcome,
  required DateTime completedAt,
  required Duration activeSegmentDuration,
  PuzzleAttemptFailureReason? failureReason,
  bool revealed,
});

/// Coordinates puzzle evaluation and durable attempt state. Each transition is
/// evaluated from the last committed snapshot and published only after storage
/// succeeds.
final class PuzzleSolverController {
  PuzzleSolverController({
    required this.repository,
    required this.evaluatorFactory,
    this.moveRecorder,
    this.attemptFinalizer,
    this.activeSegmentDurationProvider,
  });

  final TrainingRepository repository;
  final PuzzleEvaluatorFactory evaluatorFactory;
  final PuzzleMoveRecorder? moveRecorder;
  final PuzzleAttemptFinalizer? attemptFinalizer;
  final Duration Function(String attemptId)? activeSegmentDurationProvider;

  ChessContent? _puzzle;
  PuzzleAttempt? _attempt;
  List<AttemptMove> _moves = const [];
  PuzzleEvaluator? _evaluator;
  PuzzleEvaluationState? _evaluation;
  PuzzlePresentationState? _presentation;
  bool _transitionInProgress = false;

  PuzzlePresentationState? get state => _presentation;

  /// Safe evaluator snapshot for the current position and submitted history.
  PuzzleEvaluationState? get currentEvaluation => _evaluation;

  /// Loads durable history and restores either an unfinished attempt or a
  /// presentation-only snapshot of an already finalized attempt.
  Future<PuzzlePresentationState> initialize({
    required ChessContent puzzle,
    required String attemptId,
  }) => _exclusive(() async {
    final attempt = await repository.getAttempt(attemptId);
    if (attempt == null) throw StateError('Attempt $attemptId was not found.');
    final moves = await repository.listAttemptMoves(attemptId);

    if (attempt.outcome != null) {
      final evaluation = _restoreFinalized(puzzle, attempt, moves);
      _puzzle = puzzle;
      _attempt = attempt;
      _moves = List.unmodifiable(moves);
      _evaluator = null;
      _evaluation = evaluation;
      return _publish(evaluation);
    }

    final evaluator = evaluatorFactory();
    final evaluation = evaluator.initialize(
      puzzle: puzzle,
      attempt: attempt,
      previousMoves: moves,
    );
    _puzzle = puzzle;
    _attempt = attempt;
    _moves = List.unmodifiable(moves);
    _evaluator = evaluator;
    _evaluation = evaluation;
    return _publish(evaluation);
  });

  Set<String> legalDestinations({required String fromSquare}) {
    final evaluation = _evaluation;
    if (evaluation == null) {
      throw StateError('Initialize the puzzle controller first.');
    }
    if (evaluation.isFinalized ||
        evaluation.attempt.status != PuzzleAttemptStatus.active) {
      return const {};
    }
    return _requireEvaluator().legalDestinations(fromSquare: fromSquare);
  }

  /// Maps a board move in UCI notation to the evaluator and records the move
  /// and resulting attempt atomically.
  Future<PuzzlePresentationState> submitMove({
    required String uci,
    TimingSegment? closingTimingSegment,
  }) => _exclusive(() async {
    final evaluator = _candidateEvaluator();
    final evaluation = evaluator.submitMove(uci: uci);
    final move = evaluation.moves.last;
    final terminal = evaluation.isFinalized;
    final persisted = moveRecorder == null
        ? null
        : await moveRecorder!(
            move: move,
            updatedAttempt: evaluation.attempt,
            activeSegmentDuration: terminal
                ? activeSegmentDurationProvider?.call(evaluation.attempt.id) ??
                      Duration.zero
                : Duration.zero,
          );
    if (moveRecorder == null) {
      await repository.recordSubmittedMove(
        move: move,
        updatedAttempt: evaluation.attempt,
        closingTimingSegment: terminal ? closingTimingSegment : null,
      );
    }
    final committed = persisted == null
        ? evaluation
        : PuzzleEvaluationState(
            attempt: persisted,
            currentFen: evaluation.currentFen,
            sideToMove: evaluation.sideToMove,
            moves: evaluation.moves,
          );
    return _commit(evaluator, committed);
  });

  Future<PuzzlePresentationState> reveal({
    TimingSegment? closingTimingSegment,
  }) => _finalize((evaluator) => evaluator.reveal(), closingTimingSegment);

  Future<PuzzlePresentationState> skip({TimingSegment? closingTimingSegment}) =>
      _finalize((evaluator) => evaluator.skip(), closingTimingSegment);

  Future<PuzzlePresentationState> timeout({
    TimingSegment? closingTimingSegment,
  }) => _finalize((evaluator) => evaluator.timeout(), closingTimingSegment);

  Future<PuzzlePresentationState> abandon({
    TimingSegment? closingTimingSegment,
  }) => _finalize((evaluator) => evaluator.abandon(), closingTimingSegment);

  /// Pauses without changing accumulated active duration. The session service
  /// owns closing/opening timing segments.
  Future<PuzzlePresentationState> pause() => _exclusive(() async {
    final attempt = _requireAttempt();
    if (attempt.status != PuzzleAttemptStatus.active ||
        attempt.outcome != null) {
      throw StateError('Only an active attempt can be paused.');
    }
    final updated = _copyAttempt(attempt, status: PuzzleAttemptStatus.paused);
    await repository.updateUnfinishedAttempt(updated);
    return _commitLifecycle(updated);
  });

  /// Resumes without changing accumulated active duration. The session service
  /// owns opening the new timing segment.
  Future<PuzzlePresentationState> resume() => _exclusive(() async {
    final attempt = _requireAttempt();
    if (attempt.status != PuzzleAttemptStatus.paused ||
        attempt.outcome != null) {
      throw StateError('Only a paused attempt can be resumed.');
    }
    final updated = _copyAttempt(attempt, status: PuzzleAttemptStatus.active);
    await repository.updateUnfinishedAttempt(updated);
    return _commitLifecycle(updated);
  });

  Future<PuzzlePresentationState> _finalize(
    PuzzleEvaluationState Function(PuzzleEvaluator) action,
    TimingSegment? closingTimingSegment,
  ) => _exclusive(() async {
    final current = _evaluation;
    if (current == null) {
      throw StateError('Initialize the puzzle controller first.');
    }
    if (current.isFinalized) return _presentation!;
    final evaluator = _candidateEvaluator();
    final evaluation = action(evaluator);
    final persisted = attemptFinalizer == null
        ? null
        : await attemptFinalizer!(
            attemptId: evaluation.attempt.id,
            outcome: evaluation.attempt.outcome!,
            completedAt: evaluation.attempt.completedAt!,
            activeSegmentDuration:
                activeSegmentDurationProvider?.call(evaluation.attempt.id) ??
                Duration.zero,
            failureReason: evaluation.attempt.failureReason,
            revealed: evaluation.attempt.revealed,
          );
    if (attemptFinalizer == null) {
      await repository.finalizeAttempt(
        attempt: evaluation.attempt,
        finalTimingSegment: closingTimingSegment,
      );
    }
    final committed = persisted == null
        ? evaluation
        : PuzzleEvaluationState(
            attempt: persisted,
            currentFen: evaluation.currentFen,
            sideToMove: evaluation.sideToMove,
            moves: evaluation.moves,
          );
    return _commit(evaluator, committed);
  });

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_transitionInProgress) {
      throw StateError('Another puzzle transition is still in progress.');
    }
    _transitionInProgress = true;
    try {
      return await action();
    } finally {
      _transitionInProgress = false;
    }
  }

  PuzzleAttempt _requireAttempt() =>
      _attempt ?? (throw StateError('Initialize the puzzle controller first.'));

  PuzzleEvaluator _candidateEvaluator() {
    final puzzle = _puzzle;
    final attempt = _requireAttempt();
    if (puzzle == null) {
      throw StateError('Initialize the puzzle controller first.');
    }
    if (attempt.outcome != null) {
      throw StateError('A finalized attempt cannot change.');
    }
    final evaluator = evaluatorFactory();
    evaluator.initialize(
      puzzle: puzzle,
      attempt: attempt,
      previousMoves: _moves,
    );
    return evaluator;
  }

  PuzzleEvaluator _requireEvaluator() =>
      _evaluator ??
      (throw StateError('This finalized attempt has no live evaluator.'));

  PuzzlePresentationState _commit(
    PuzzleEvaluator evaluator,
    PuzzleEvaluationState evaluation,
  ) {
    _evaluator = evaluator;
    _attempt = evaluation.attempt;
    _moves = List.unmodifiable(evaluation.moves);
    _evaluation = evaluation;
    return _publish(evaluation);
  }

  PuzzlePresentationState _commitLifecycle(PuzzleAttempt attempt) {
    final current = _evaluation!;
    final evaluation = PuzzleEvaluationState(
      attempt: attempt,
      currentFen: current.currentFen,
      sideToMove: current.sideToMove,
      moves: current.moves,
    );
    _attempt = attempt;
    _evaluation = evaluation;
    if (attempt.status == PuzzleAttemptStatus.active) {
      _evaluator = _candidateEvaluator();
    } else {
      _evaluator = null;
    }
    return _publish(evaluation);
  }

  PuzzlePresentationState _publish(PuzzleEvaluationState evaluation) {
    _presentation = PuzzlePresentationState.fromDomain(
      puzzle: _puzzle!,
      evaluation: evaluation,
    );
    return _presentation!;
  }

  PuzzleEvaluationState _restoreFinalized(
    ChessContent puzzle,
    PuzzleAttempt attempt,
    List<AttemptMove> moves,
  ) {
    final activeAttempt = _copyAttempt(
      attempt,
      status: PuzzleAttemptStatus.active,
      completedAt: null,
      outcome: null,
      failureReason: null,
      wrongMoveCount: 0,
      revealed: false,
    );
    final accepted = moves
        .where((move) => move.legal && move.accepted)
        .toList(growable: false);
    final evaluator = evaluatorFactory();
    final reachesTerminal = attempt.outcome == PuzzleAttemptOutcome.passed;
    final prefix = reachesTerminal && accepted.isNotEmpty
        ? accepted.sublist(0, accepted.length - 1)
        : accepted;
    var replay = evaluator.initialize(
      puzzle: puzzle,
      attempt: activeAttempt,
      previousMoves: prefix,
    );
    if (reachesTerminal) {
      if (accepted.isEmpty) {
        throw StateError('A passed attempt must contain its terminal move.');
      }
      replay = evaluator.submitMove(uci: accepted.last.move);
    }
    return PuzzleEvaluationState(
      attempt: attempt,
      currentFen: replay.currentFen,
      sideToMove: replay.sideToMove,
      moves: moves,
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
}
