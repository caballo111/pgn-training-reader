import 'dart:async';

import 'package:dartchess/dartchess.dart' as chess;

import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/move_node.dart';
import '../../../domain/training/attempt_move.dart';
import '../../../domain/training/authored_line_puzzle_evaluator.dart';
import '../../../domain/training/puzzle_attempt.dart';
import '../../../domain/training/puzzle_completion_policy.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../../../domain/training/puzzle_interaction_repository.dart';
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

/// Scored history is immutable; continued practice has its own durable cursor.
final class PuzzleSolverController {
  PuzzleSolverController({
    required this.repository,
    required this.evaluatorFactory,
    this.moveRecorder,
    this.attemptFinalizer,
    this.activeSegmentDurationProvider,
    this.loadInteraction,
    this.saveInteraction,
    this.completionPolicy,
    this.automaticReplies = true,
    this.automaticReplyDelay = const Duration(milliseconds: 300),
  });
  final TrainingRepository repository;
  final PuzzleEvaluatorFactory evaluatorFactory;
  final PuzzleMoveRecorder? moveRecorder;
  final PuzzleAttemptFinalizer? attemptFinalizer;
  final Duration Function(String attemptId)? activeSegmentDurationProvider;
  final Future<Map<String, dynamic>?> Function(String)? loadInteraction;
  final Future<void> Function(String, Map<String, dynamic>)? saveInteraction;
  final PuzzleCompletionPolicy? completionPolicy;
  final bool automaticReplies;
  final Duration automaticReplyDelay;

  ChessContent? _puzzle;
  PuzzleAttempt? _attempt;
  List<AttemptMove> _moves = const [];
  List<PuzzlePlayedMove> _entries = const [];
  PuzzleEvaluationState? _evaluation;
  PuzzlePresentationState? _presentation;
  PuzzleCompletionPolicy _policy = PuzzleCompletionPolicy.allMoves;
  bool _review = false;
  bool _transitionInProgress = false;
  bool _replyPending = false;
  bool _pauseRequested = false;
  bool _disposed = false;
  final Set<void Function(PuzzlePresentationState)> _stateListeners = {};
  Completer<void>? _transitionDone;

  /// Completes after the current durable puzzle transition finishes.
  Future<void> whenIdle() async {
    while (_transitionInProgress) {
      final pending = _transitionDone;
      if (pending != null) await pending.future;
    }
  }

  int _hintRequests = 0;
  String? _hintSquare;
  String? _feedback;
  PuzzleSide? _orientation;

  PuzzlePresentationState? get state => _presentation;
  void addStateListener(void Function(PuzzlePresentationState) listener) =>
      _stateListeners.add(listener);
  void removeStateListener(void Function(PuzzlePresentationState) listener) =>
      _stateListeners.remove(listener);
  void dispose() {
    _disposed = true;
    _pauseRequested = true;
    _stateListeners.clear();
  }

  PuzzleEvaluationState? get currentEvaluation => _evaluation;
  bool get canInteract =>
      _evaluation != null &&
      !_disposed &&
      !_review &&
      !_replyPending &&
      _attempt!.status != PuzzleAttemptStatus.paused;
  PuzzleSide get _learner => _puzzle!.startingFen.split(' ')[1] == 'b'
      ? PuzzleSide.black
      : PuzzleSide.white;
  chess.Chess get _position =>
      chess.Chess.fromSetup(chess.Setup.parseFen(_evaluation!.currentFen));
  List<MoveNode> get _choices {
    var choices = _puzzle!.rootMoves;
    for (final entry in _entries.where((entry) => entry.accepted)) {
      final node = choices.where((node) => node.uci == entry.uci).firstOrNull;
      if (node == null) {
        throw StateError('Interaction is outside the authored line.');
      }
      choices = node.children;
    }
    return choices;
  }

  bool get _predicting =>
      canInteract &&
      _evaluation!.sideToMove != _learner &&
      _policy == PuzzleCompletionPolicy.keyMoves &&
      _choices.any(isCompletionMarker);

  Future<PuzzlePresentationState> initialize({
    required ChessContent puzzle,
    required String attemptId,
  }) => _exclusive(() async {
    final attempt = await repository.getAttempt(attemptId);
    if (attempt == null) throw StateError('Puzzle attempt was not found.');
    final moves = await repository.listAttemptMoves(attemptId);
    final data = await _load(attemptId);
    _puzzle = puzzle;
    _attempt = attempt;
    _moves = List.unmodifiable(moves);
    // Missing policy means historical All Moves, even if new markers exist.
    _policy = data == null && moves.isNotEmpty
        ? PuzzleCompletionPolicy.allMoves
        : data?['policy'] != null
        ? PuzzleCompletionPolicy.values.byName(data!['policy'] as String)
        : completionPolicy ??
              (hasCompletionMarker(puzzle.rootMoves)
                  ? PuzzleCompletionPolicy.keyMoves
                  : PuzzleCompletionPolicy.allMoves);
    _entries = data?['entries'] != null
        ? List.unmodifiable([
            for (final raw in data!['entries'] as List)
              PuzzlePlayedMove.fromJson(Map<String, dynamic>.from(raw as Map)),
          ])
        : _entriesFromHistory(puzzle, moves);
    _review = data?['review'] as bool? ?? (attempt.outcome != null);
    _hintRequests = data?['hintRequests'] as int? ?? attempt.hintCount;
    _hintSquare = data?['hintSquare'] as String?;
    _feedback = data?['feedback'] as String?;
    _orientation = data?['orientation'] == null
        ? null
        : PuzzleSide.values.byName(data!['orientation'] as String);
    final position = _replay(puzzle, _entries);
    _evaluation = _snapshot(attempt, position, moves);
    // Validate unfinished history without exposing solution nodes.
    if (attempt.outcome == null) _candidateEvaluator();
    await _save(_data());
    _publish();
    await _automaticReply(delay: false);
    return _publish();
  });

  Set<String> legalDestinations({required String fromSquare}) {
    if (_evaluation == null) {
      throw StateError('Initialize the puzzle controller first.');
    }
    if (!canInteract) return const {};
    final from = chess.Square.parse(fromSquare);
    if (from == null) throw FormatException('Invalid square.', fromSquare);
    return Set.unmodifiable(
      chess.makeLegalMoves(_position)[from]?.map((square) => square.name) ??
          const <String>[],
    );
  }

  Future<PuzzlePresentationState> submitMove({
    required String uci,
    TimingSegment? closingTimingSegment,
  }) => _exclusive(() async {
    if (!canInteract) throw StateError('This puzzle is not accepting moves.');
    // Retry a durably pending automatic reply before accepting another gesture.
    if (automaticReplies &&
        _evaluation!.sideToMove != _learner &&
        !_predicting) {
      await _automaticReply();
      return _publish();
    }
    await _play(
      uci,
      _predicting ? 'prediction' : 'learner',
      closingTimingSegment,
    );
    await _automaticReply();
    return _publish();
  });

  Future<void> _automaticReply({bool delay = true}) async {
    if (!automaticReplies ||
        !canInteract ||
        _evaluation!.sideToMove == _learner ||
        _predicting) {
      return;
    }
    final choices = _choices;
    if (choices.isEmpty) return;
    if (delay && automaticReplyDelay > Duration.zero) {
      _replyPending = true;
      _publish();
      try {
        await Future<void>.delayed(automaticReplyDelay);
      } finally {
        _replyPending = false;
      }
      final cachedAttempt = _attempt!;
      final durableAttempt = await repository.getAttempt(cachedAttempt.id);
      if (durableAttempt == null) return;
      final externallyFinalized =
          cachedAttempt.outcome == null && durableAttempt.outcome != null;
      if (durableAttempt.status != cachedAttempt.status ||
          externallyFinalized) {
        _attempt = durableAttempt;
        if (durableAttempt.outcome != null) _review = true;
        _evaluation = _snapshot(durableAttempt, _position, _moves);
        _publish();
        if (durableAttempt.status == PuzzleAttemptStatus.paused ||
            externallyFinalized) {
          return;
        }
      }
      if (!canInteract ||
          _pauseRequested ||
          _evaluation!.sideToMove == _learner) {
        return;
      }
    }
    await _play(choices.first.uci, 'automatic', null);
  }

  Future<void> _play(
    String uci,
    String actor,
    TimingSegment? closingSegment,
  ) async {
    final position = _position;
    final move = chess.Move.parse(uci);
    if (move == null || move is! chess.NormalMove) {
      throw FormatException('Invalid UCI move.');
    }
    final node = _choices.where((node) => node.uci == uci).firstOrNull;
    final accepted = position.isLegal(move) && node != null;
    final nextPosition = accepted
        ? position.play(move) as chess.Chess
        : position;
    final event = PuzzlePlayedMove(
      uci: uci,
      san: accepted
          ? node.san
          : position.isLegal(move)
          ? position.makeSan(move).$2
          : uci,
      moveNumber: int.parse(position.fen.split(' ')[5]),
      side: _evaluation!.sideToMove,
      actor: actor,
      accepted: accepted,
    );
    final suppressRepeatedWrongPractice =
        _attempt!.outcome == PuzzleAttemptOutcome.wrongMove &&
        !accepted &&
        (actor == 'learner' || actor == 'prediction');
    final entries = suppressRepeatedWrongPractice
        ? _entries
        : List<PuzzlePlayedMove>.unmodifiable([..._entries, event]);
    final complete =
        accepted &&
        (node.children.isEmpty ||
            (_policy == PuzzleCompletionPolicy.keyMoves &&
                isCompletionMarker(node)));
    final feedback = accepted ? null : 'Incorrect — you can keep trying.';
    PuzzleAttempt attempt = _attempt!;
    List<AttemptMove> moves = _moves;
    if (attempt.outcome == null) {
      final evaluated = _candidateEvaluator().submitMove(uci: uci);
      final terminal = evaluated.isFinalized;
      await _atomic(() async {
        // Save interaction before the score callback; transaction commits both.
        await _save(
          _data(
            entries: entries,
            review: complete,
            hintSquare: null,
            clearHint: true,
            clearFeedback: accepted,
            feedback: feedback,
          ),
        );
        if (moveRecorder != null) {
          attempt = await moveRecorder!(
            move: evaluated.moves.last,
            updatedAttempt: evaluated.attempt,
            activeSegmentDuration: terminal
                ? activeSegmentDurationProvider?.call(attempt.id) ??
                      Duration.zero
                : Duration.zero,
          );
        } else {
          await repository.recordSubmittedMove(
            move: evaluated.moves.last,
            updatedAttempt: evaluated.attempt,
            closingTimingSegment: terminal ? closingSegment : null,
          );
          attempt = evaluated.attempt;
        }
      });
      moves = evaluated.moves;
    } else {
      await _save(
        _data(
          entries: entries,
          review: complete,
          hintSquare: null,
          clearHint: true,
          clearFeedback: accepted,
          feedback: feedback,
        ),
      );
    }
    _entries = entries;
    _attempt = attempt;
    _moves = List.unmodifiable(moves);
    _review = complete;
    _hintSquare = null;
    _feedback = feedback;
    _evaluation = _snapshot(attempt, nextPosition, moves);
    _publish();
  }

  Future<PuzzlePresentationState> hint() => _exclusive(() async {
    if (!canInteract || _choices.isEmpty) {
      throw StateError('No hint is available.');
    }
    final square = _choices.first.uci.substring(0, 2);
    var attempt = _attempt!;
    if (attempt.outcome == null) {
      attempt = _copyAttempt(attempt, hintCount: attempt.hintCount + 1);
      await _atomic(() async {
        await _save(
          _data(
            hintSquare: square,
            hintRequests: _hintRequests + 1,
            feedback: 'Hint used — this attempt is assisted.',
          ),
        );
        await repository.updateUnfinishedAttempt(attempt);
      });
    } else {
      await _save(
        _data(
          hintSquare: square,
          hintRequests: _hintRequests + 1,
          feedback: 'Hint: consider the piece on $square.',
        ),
      );
    }
    _hintRequests++;
    _hintSquare = square;
    _feedback = attempt.outcome == null
        ? 'Hint used — this attempt is assisted.'
        : 'Hint: consider the piece on $square.';
    _attempt = attempt;
    _evaluation = _snapshot(attempt, _position, _moves);
    return _publish();
  });

  Future<PuzzlePresentationState> showMove() => _exclusive(() async {
    if (!canInteract || _choices.isEmpty) {
      throw StateError('No move is available.');
    }
    final uci = _choices.first.uci;
    if (_attempt!.outcome == null) {
      await _finish(PuzzleAttemptOutcome.revealed, review: false);
    }
    await _play(uci, 'revealed', null);
    await _automaticReply();
    return _publish();
  });

  Future<PuzzlePresentationState> reveal({
    TimingSegment? closingTimingSegment,
  }) => _exclusive(() async {
    await _finish(
      PuzzleAttemptOutcome.revealed,
      closingSegment: closingTimingSegment,
    );
    return _publish();
  });
  Future<PuzzlePresentationState> skip({TimingSegment? closingTimingSegment}) =>
      _exclusive(() async {
        await _finish(
          PuzzleAttemptOutcome.skipped,
          closingSegment: closingTimingSegment,
        );
        return _publish();
      });
  Future<PuzzlePresentationState> timeout({
    TimingSegment? closingTimingSegment,
  }) => _exclusive(() async {
    await _finish(
      PuzzleAttemptOutcome.timedOut,
      reason: PuzzleAttemptFailureReason.timeLimitExceeded,
      closingSegment: closingTimingSegment,
    );
    return _publish();
  });
  Future<PuzzlePresentationState> abandon({
    TimingSegment? closingTimingSegment,
  }) => _exclusive(() async {
    await _finish(
      PuzzleAttemptOutcome.abandoned,
      reason: PuzzleAttemptFailureReason.userAbandoned,
      closingSegment: closingTimingSegment,
    );
    return _publish();
  });

  Future<void> _finish(
    PuzzleAttemptOutcome outcome, {
    bool review = true,
    PuzzleAttemptFailureReason? reason,
    TimingSegment? closingSegment,
  }) async {
    var attempt =
        _attempt ??
        (throw StateError('Initialize the puzzle controller first.'));
    if (attempt.outcome == null) {
      final evaluated = outcome == PuzzleAttemptOutcome.revealed
          ? _candidateEvaluator().reveal()
          : outcome == PuzzleAttemptOutcome.skipped
          ? _candidateEvaluator().skip()
          : outcome == PuzzleAttemptOutcome.timedOut
          ? _candidateEvaluator().timeout()
          : _candidateEvaluator().abandon();
      await _atomic(() async {
        await _save(_data(review: review));
        if (attemptFinalizer != null) {
          attempt = await attemptFinalizer!(
            attemptId: attempt.id,
            outcome: outcome,
            completedAt: evaluated.attempt.completedAt!,
            activeSegmentDuration:
                activeSegmentDurationProvider?.call(attempt.id) ??
                Duration.zero,
            failureReason: reason,
            revealed: outcome == PuzzleAttemptOutcome.revealed,
          );
        } else {
          await repository.finalizeAttempt(
            attempt: evaluated.attempt,
            finalTimingSegment: closingSegment,
          );
          attempt = evaluated.attempt;
        }
      });
    } else {
      await _save(_data(review: review));
    }
    _attempt = attempt;
    _review = review;
    _evaluation = _snapshot(attempt, _position, _moves);
  }

  Future<PuzzlePresentationState> pause() async {
    _pauseRequested = true;
    await whenIdle();
    return _lifecycle(PuzzleAttemptStatus.paused);
  }

  Future<PuzzlePresentationState> resume() {
    _pauseRequested = false;
    return _lifecycle(PuzzleAttemptStatus.active);
  }

  Future<PuzzlePresentationState> _lifecycle(PuzzleAttemptStatus status) =>
      _exclusive(() async {
        final attempt =
            _attempt ??
            (throw StateError('Initialize the puzzle controller first.'));
        if (attempt.outcome != null) return _publish();
        if (attempt.status == status) {
          throw StateError('Invalid lifecycle transition.');
        }
        final updated = _copyAttempt(attempt, status: status);
        await repository.updateUnfinishedAttempt(updated);
        _attempt = updated;
        _evaluation = _snapshot(updated, _position, _moves);
        if (status == PuzzleAttemptStatus.active) {
          await _automaticReply(delay: false);
        }
        return _publish();
      });

  Future<void> setOrientation(PuzzleSide orientation) async {
    await _save(_data(orientation: orientation));
    _orientation = orientation;
    _publish();
  }

  PuzzleEvaluator _candidateEvaluator() {
    final attempt =
        _attempt ??
        (throw StateError('Initialize the puzzle controller first.'));
    if (attempt.outcome != null) {
      throw StateError('A finalized score cannot change.');
    }
    final supplied = evaluatorFactory();
    final evaluator = supplied is AuthoredLinePuzzleEvaluator
        ? supplied.withCompletionPolicy(_policy)
        : supplied;
    evaluator.initialize(
      puzzle: _puzzle!,
      attempt: attempt,
      previousMoves: _moves,
    );
    return evaluator;
  }

  PuzzlePresentationState _publish() {
    final accepted = _entries.where((entry) => entry.accepted).toList();
    var choices = _puzzle!.rootMoves;
    var marked = false;
    for (final entry in accepted) {
      final node = choices.where((node) => node.uci == entry.uci).first;
      marked |= isCompletionMarker(node);
      choices = node.children;
    }
    final state = PuzzlePresentationState.fromDomain(
      puzzle: _puzzle!,
      evaluation: _evaluation!,
      solutionVisibleOverride: _review,
      entries: _entries,
      learnerSide: _learner,
      isPredictingReply: _predicting,
      hintSquare: _hintSquare,
      feedback: _feedback,
      usedFullLineFallback:
          _policy == PuzzleCompletionPolicy.keyMoves &&
          _review &&
          !marked &&
          choices.isEmpty,
      policyLabel: _policy == PuzzleCompletionPolicy.keyMoves
          ? 'Key Moves'
          : 'All Moves',
      boardOrientation: _orientation,
      hintCount: _hintRequests,
    );
    _presentation = state;
    for (final listener in List.of(_stateListeners)) {
      listener(state);
    }
    return state;
  }

  Future<Map<String, dynamic>?> _load(String id) async {
    if (loadInteraction != null) return loadInteraction!(id);
    final storage = repository;
    return storage is PuzzleInteractionRepository
        ? (storage as PuzzleInteractionRepository).loadPuzzleInteraction(id)
        : null;
  }

  Future<void> _save(Map<String, dynamic> value) async {
    if (saveInteraction != null) {
      await saveInteraction!(_attempt!.id, value);
      return;
    }
    final storage = repository;
    if (storage is PuzzleInteractionRepository) {
      await (storage as PuzzleInteractionRepository).savePuzzleInteraction(
        _attempt!.id,
        value,
      );
    }
  }

  Map<String, dynamic> _data({
    List<PuzzlePlayedMove>? entries,
    bool? review,
    String? hintSquare,
    String? feedback,
    PuzzleSide? orientation,
    int? hintRequests,
    bool clearHint = false,
    bool clearFeedback = false,
  }) => {
    'version': 1,
    'policy': _policy.name,
    'review': review ?? _review,
    'entries': [for (final entry in entries ?? _entries) entry.toJson()],
    'hintRequests': hintRequests ?? _hintRequests,
    'hintSquare': clearHint ? null : hintSquare ?? _hintSquare,
    'feedback': clearFeedback ? null : feedback ?? _feedback,
    'orientation': (orientation ?? _orientation)?.name,
  };
  Future<T> _atomic<T>(Future<T> Function() action) {
    final storage = repository;
    return storage is AtomicTrainingRepository
        ? (storage as AtomicTrainingRepository).transaction(action)
        : action();
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_disposed) throw StateError('This puzzle controller is disposed.');
    if (_transitionInProgress) {
      throw StateError('Another puzzle transition is still in progress.');
    }
    _transitionInProgress = true;
    final transitionDone = Completer<void>();
    _transitionDone = transitionDone;
    try {
      return await action();
    } finally {
      _transitionInProgress = false;
      if (identical(_transitionDone, transitionDone)) {
        _transitionDone = null;
      }
      transitionDone.complete();
    }
  }

  List<PuzzlePlayedMove> _entriesFromHistory(
    ChessContent puzzle,
    List<AttemptMove> moves,
  ) {
    var position = chess.Chess.fromSetup(
      chess.Setup.parseFen(puzzle.startingFen),
    );
    var choices = puzzle.rootMoves;
    final entries = <PuzzlePlayedMove>[];
    for (final move in moves) {
      final node = choices.where((node) => node.uci == move.move).firstOrNull;
      entries.add(
        PuzzlePlayedMove(
          uci: move.move,
          san: node?.san ?? move.move,
          moveNumber: int.parse(position.fen.split(' ')[5]),
          side: position.turn == chess.Side.white
              ? PuzzleSide.white
              : PuzzleSide.black,
          actor: 'learner',
          accepted: move.accepted && move.legal,
        ),
      );
      if (move.accepted && move.legal) {
        if (node == null) {
          throw StateError('Recorded move is outside the authored line.');
        }
        position = position.play(chess.Move.parse(move.move)!) as chess.Chess;
        choices = node.children;
      }
    }
    return entries;
  }

  chess.Chess _replay(ChessContent puzzle, List<PuzzlePlayedMove> entries) {
    var position = chess.Chess.fromSetup(
      chess.Setup.parseFen(puzzle.startingFen),
    );
    var choices = puzzle.rootMoves;
    for (final entry in entries.where((entry) => entry.accepted)) {
      final node = choices.where((node) => node.uci == entry.uci).firstOrNull;
      final move = chess.Move.parse(entry.uci);
      if (node == null || move == null || !position.isLegal(move)) {
        throw StateError('Cannot restore puzzle interaction.');
      }
      position = position.play(move) as chess.Chess;
      choices = node.children;
    }
    return position;
  }

  PuzzleEvaluationState _snapshot(
    PuzzleAttempt attempt,
    chess.Chess position,
    List<AttemptMove> moves,
  ) => PuzzleEvaluationState(
    attempt: attempt,
    currentFen: position.fen,
    sideToMove: position.turn == chess.Side.white
        ? PuzzleSide.white
        : PuzzleSide.black,
    moves: moves,
  );
  PuzzleAttempt _copyAttempt(
    PuzzleAttempt attempt, {
    PuzzleAttemptStatus? status,
    int? hintCount,
  }) => PuzzleAttempt(
    id: attempt.id,
    blockId: attempt.blockId,
    cycleId: attempt.cycleId,
    sessionId: attempt.sessionId,
    status: status ?? attempt.status,
    startedAt: attempt.startedAt,
    completedAt: attempt.completedAt,
    activeDuration: attempt.activeDuration,
    outcome: attempt.outcome,
    failureReason: attempt.failureReason,
    wrongMoveCount: attempt.wrongMoveCount,
    hintCount: hintCount ?? attempt.hintCount,
    revealed: attempt.revealed,
  );
}
