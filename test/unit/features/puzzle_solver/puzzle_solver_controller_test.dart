import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
final _started = DateTime.utc(2026, 9, 29);

final _puzzle = ChessContent(
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

PuzzleAttempt _attempt() => PuzzleAttempt(
  id: 'attempt',
  blockId: 'block',
  cycleId: 'cycle',
  sessionId: 'session',
  startedAt: _started,
);

final class _Ids implements IdGenerator {
  int next = 0;
  @override
  String generateId() => 'move-${next++}';
}

final class _Repository implements TrainingRepository {
  _Repository(this.attempt, [List<AttemptMove> moves = const []])
    : moves = [...moves];
  PuzzleAttempt attempt;
  List<AttemptMove> moves;
  bool failMoveWrite = false;
  bool failFinalize = false;
  Completer<void>? moveWriteGate;
  Completer<PuzzleAttempt?>? attemptLookupGate;
  int moveWrites = 0;
  int finalizes = 0;

  @override
  Future<PuzzleAttempt?> getAttempt(String id) async {
    final gate = attemptLookupGate;
    if (gate != null) return gate.future;
    return id == attempt.id ? attempt : null;
  }

  @override
  Future<List<AttemptMove>> listAttemptMoves(String id) async =>
      List.unmodifiable(moves);
  @override
  Future<void> recordSubmittedMove({
    required AttemptMove move,
    required PuzzleAttempt updatedAttempt,
    TimingSegment? closingTimingSegment,
  }) async {
    moveWrites++;
    final gate = moveWriteGate;
    if (gate != null) await gate.future;
    if (failMoveWrite) throw StateError('move write failed');
    moves.add(move);
    attempt = updatedAttempt;
  }

  @override
  Future<void> updateUnfinishedAttempt(PuzzleAttempt attempt) async {
    this.attempt = attempt;
  }

  @override
  Future<void> finalizeAttempt({
    required PuzzleAttempt attempt,
    TimingSegment? finalTimingSegment,
  }) async {
    finalizes++;
    if (failFinalize) throw StateError('finalize failed');
    this.attempt = attempt;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Repository repository;
  late PuzzleSolverController controller;
  late _Ids ids;

  setUp(() {
    repository = _Repository(_attempt());
    ids = _Ids();
    controller = PuzzleSolverController(
      repository: repository,
      evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: ids),
    );
  });

  test(
    'restores persisted accepted moves before presenting the position',
    () async {
      final first = AuthoredLinePuzzleEvaluator(idGenerator: ids);
      first.initialize(puzzle: _puzzle, attempt: _attempt());
      final recorded = first.submitMove(uci: 'e2e4').moves.single;
      repository.moves = [recorded];
      repository.attempt = first.state!.attempt;

      final state = await controller.initialize(
        puzzle: _puzzle,
        attemptId: 'attempt',
      );
      expect(state.playedMoves, ['e2e4']);
      expect(state.currentFen, isNot(_fen));
      expect(repository.moves.single.attemptId, 'attempt');
    },
  );

  test(
    'persists accepted and wrong moves through the atomic move operation',
    () async {
      await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');
      await controller.submitMove(uci: 'e2e4');
      expect(repository.moveWrites, 1);
      expect(repository.moves.single.accepted, isTrue);
      expect(controller.state!.playedMoves, ['e2e4']);

      // Use another attempt for the terminal wrong move scenario.
      repository = _Repository(_attempt());
      controller = PuzzleSolverController(
        repository: repository,
        evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: ids),
      );
      await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');
      await controller.submitMove(uci: 'e2e3');
      expect(repository.moveWrites, 1);
      expect(repository.moves.single.accepted, isFalse);
      expect(repository.attempt.outcome, PuzzleAttemptOutcome.wrongMove);
      expect(controller.state!.playedMoves, isEmpty);
    },
  );

  test(
    'failed move and reveal writes leave prior presentation unpublished',
    () async {
      await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');
      final before = controller.state;
      repository.failMoveWrite = true;
      await expectLater(controller.submitMove(uci: 'e2e4'), throwsStateError);
      expect(controller.state, same(before));
      expect(controller.state!.playedMoves, isEmpty);

      repository.failMoveWrite = false;
      repository.failFinalize = true;
      await expectLater(controller.reveal(), throwsStateError);
      expect(controller.state, same(before));
      expect(controller.state!.solution, isNull);
      expect(repository.finalizes, 1);
    },
  );

  test(
    'failed terminal move write never exposes the finalized solution',
    () async {
      await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');
      final before = controller.state;
      repository.failMoveWrite = true;

      await expectLater(controller.submitMove(uci: 'e2e3'), throwsStateError);

      expect(controller.state, same(before));
      expect(controller.state!.solution, isNull);
      expect(controller.state!.outcome, isNull);
      expect(repository.attempt.outcome, isNull);
      expect(repository.moves, isEmpty);
    },
  );

  test(
    'rejects overlapping submit and reveal while a move write is pending',
    () async {
      await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');
      final gate = Completer<void>();
      repository.moveWriteGate = gate;
      final submitted = controller.submitMove(uci: 'e2e4');
      await expectLater(controller.reveal(), throwsStateError);
      expect(controller.state!.playedMoves, isEmpty);
      gate.complete();
      await submitted;
      expect(repository.moveWrites, 1);
      expect(repository.finalizes, 0);
      expect(controller.state!.playedMoves, ['e2e4']);
    },
  );

  test(
    'rejects switching attempts while initialization lookup is pending',
    () async {
      final gate = Completer<PuzzleAttempt?>();
      repository.attemptLookupGate = gate;
      final first = controller.initialize(
        puzzle: _puzzle,
        attemptId: 'attempt',
      );
      await expectLater(
        controller.initialize(puzzle: _puzzle, attemptId: 'another-attempt'),
        throwsStateError,
      );
      gate.complete(_attempt());
      await first;
      expect(controller.state!.attemptStatus, PuzzleAttemptStatus.active);
    },
  );

  test(
    'pause and resume persist lifecycle while preserving active duration',
    () async {
      repository.attempt = PuzzleAttempt(
        id: 'attempt',
        blockId: 'block',
        cycleId: 'cycle',
        sessionId: 'session',
        startedAt: _started,
        activeDuration: const Duration(seconds: 17),
      );
      await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');
      final paused = await controller.pause();
      expect(paused.attemptStatus, PuzzleAttemptStatus.paused);
      expect(paused.outcome, isNull);
      expect(repository.attempt.activeDuration, const Duration(seconds: 17));
      expect(controller.legalDestinations(fromSquare: 'e2'), isEmpty);

      final resumed = await controller.resume();
      expect(resumed.attemptStatus, PuzzleAttemptStatus.active);
      expect(repository.attempt.activeDuration, const Duration(seconds: 17));
    },
  );

  test('restores finalized passed attempt into solution review', () async {
    final evaluator = AuthoredLinePuzzleEvaluator(idGenerator: ids);
    evaluator.initialize(puzzle: _puzzle, attempt: _attempt());
    evaluator.submitMove(uci: 'e2e4');
    evaluator.submitMove(uci: 'e7e5');
    repository.attempt = evaluator.state!.attempt;
    repository.moves = evaluator.state!.moves;

    final restored = await controller.initialize(
      puzzle: _puzzle,
      attemptId: 'attempt',
    );
    expect(restored.attemptStatus, PuzzleAttemptStatus.finalized);
    expect(restored.outcome, PuzzleAttemptOutcome.passed);
    expect(restored.isSolutionVisible, isTrue);
    expect(restored.playedMoves, ['e2e4', 'e7e5']);
    expect(controller.currentEvaluation!.currentFen, isNot(_fen));
    expect(controller.legalDestinations(fromSquare: 'e7'), isEmpty);
  });

  test('restores every other terminal outcome for read-only review', () async {
    const cases = <(PuzzleAttemptOutcome, PuzzleAttemptFailureReason?, bool)>[
      (
        PuzzleAttemptOutcome.wrongMove,
        PuzzleAttemptFailureReason.incorrectMove,
        false,
      ),
      (PuzzleAttemptOutcome.revealed, null, true),
      (PuzzleAttemptOutcome.skipped, null, false),
      (
        PuzzleAttemptOutcome.timedOut,
        PuzzleAttemptFailureReason.timeLimitExceeded,
        false,
      ),
      (
        PuzzleAttemptOutcome.abandoned,
        PuzzleAttemptFailureReason.userAbandoned,
        false,
      ),
    ];

    for (final (outcome, failureReason, revealed) in cases) {
      final finalized = PuzzleAttempt(
        id: 'attempt-${outcome.name}',
        blockId: 'block',
        cycleId: 'cycle',
        sessionId: 'session',
        status: PuzzleAttemptStatus.finalized,
        startedAt: _started,
        completedAt: _started.add(const Duration(minutes: 1)),
        outcome: outcome,
        failureReason: failureReason,
        wrongMoveCount: outcome == PuzzleAttemptOutcome.wrongMove ? 1 : 0,
        revealed: revealed,
      );
      repository = _Repository(finalized);
      controller = PuzzleSolverController(
        repository: repository,
        evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: ids),
      );

      final restored = await controller.initialize(
        puzzle: _puzzle,
        attemptId: finalized.id,
      );

      expect(restored.outcome, outcome);
      expect(restored.isSolutionVisible, isTrue);
      expect(repository.attempt, same(finalized));
      expect(repository.finalizes, 0);
    }
  });

  test(
    'restores wrong attempt at prior position and ignores rejected tail',
    () async {
      final evaluator = AuthoredLinePuzzleEvaluator(idGenerator: ids);
      evaluator.initialize(puzzle: _puzzle, attempt: _attempt());
      evaluator.submitMove(uci: 'e2e4');
      evaluator.submitMove(uci: 'e2e3');
      repository.attempt = evaluator.state!.attempt;
      repository.moves = evaluator.state!.moves;

      final restored = await controller.initialize(
        puzzle: _puzzle,
        attemptId: 'attempt',
      );
      expect(restored.outcome, PuzzleAttemptOutcome.wrongMove);
      expect(restored.isSolutionVisible, isTrue);
      expect(restored.playedMoves, ['e2e4']);
      expect(controller.currentEvaluation!.currentFen, isNot(_fen));
    },
  );
}
