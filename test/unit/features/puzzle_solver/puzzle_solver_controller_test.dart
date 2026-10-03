import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/domain/training/attempt_move.dart';
import 'package:pgntrainingreader/domain/training/authored_line_puzzle_evaluator.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/domain/training/puzzle_evaluator.dart';
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
      automaticReplies: false,
      automaticReplyDelay: Duration.zero,
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
        automaticReplies: false,
        automaticReplyDelay: Duration.zero,
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

  test('hinted completion finalizes as Assisted, not Passed', () async {
    await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');
    await controller.hint();
    await controller.submitMove(uci: 'e2e4');
    await controller.submitMove(uci: 'e7e5');

    expect(repository.attempt.hintCount, 1);
    expect(repository.attempt.outcome, PuzzleAttemptOutcome.assisted);
    expect(repository.attempt.failureReason, isNull);
    expect(controller.state!.outcome, PuzzleAttemptOutcome.assisted);
  });

  test(
    'publishes learner move and locks input through paced opponent reply',
    () async {
      controller = PuzzleSolverController(
        repository: repository,
        evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: ids),
        automaticReplyDelay: const Duration(milliseconds: 80),
      );
      final states = <dynamic>[];
      controller.addStateListener(states.add);
      await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');

      final submitted = controller.submitMove(uci: 'e2e4');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.state!.playedMoves, ['e2e4']);
      expect(controller.canInteract, isFalse);
      expect(states.any((state) => state.playedMoves.length == 1), isTrue);
      await expectLater(controller.submitMove(uci: 'e7e5'), throwsStateError);
      await controller.whenIdle();
      await submitted;
      expect(controller.state!.playedMoves, ['e2e4', 'e7e5']);
      expect(controller.canInteract, isFalse); // authored line is complete
    },
  );

  test(
    'pause requested during reply delay cancels the automatic move',
    () async {
      controller = PuzzleSolverController(
        repository: repository,
        evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: ids),
        automaticReplyDelay: const Duration(milliseconds: 80),
      );
      await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');
      final submitted = controller.submitMove(uci: 'e2e4');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final paused = controller.pause();
      await submitted;
      final state = await paused;
      expect(state.attemptStatus, PuzzleAttemptStatus.paused);
      expect(state.playedMoves, ['e2e4']);
      expect(repository.moves, hasLength(1));
    },
  );

  test(
    'honors a durable session pause that arrives during reply delay',
    () async {
      controller = PuzzleSolverController(
        repository: repository,
        evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: ids),
        automaticReplyDelay: const Duration(milliseconds: 80),
      );
      await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');
      final submitted = controller.submitMove(uci: 'e2e4');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      repository.attempt = PuzzleAttempt(
        id: repository.attempt.id,
        blockId: repository.attempt.blockId,
        cycleId: repository.attempt.cycleId,
        sessionId: repository.attempt.sessionId,
        status: PuzzleAttemptStatus.paused,
        startedAt: repository.attempt.startedAt,
        activeDuration: repository.attempt.activeDuration,
        wrongMoveCount: repository.attempt.wrongMoveCount,
        hintCount: repository.attempt.hintCount,
      );

      final state = await submitted;
      expect(state.attemptStatus, PuzzleAttemptStatus.paused);
      expect(state.playedMoves, ['e2e4']);
      expect(repository.moves, hasLength(1));
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

  test('disposed controller rejects interaction', () async {
    await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');
    controller.dispose();

    expect(controller.canInteract, isFalse);
    await expectLater(controller.submitMove(uci: 'e2e4'), throwsStateError);
  });

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
        automaticReplies: false,
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

  test(
    'records interleaved distinct mistakes and restores v2 history',
    () async {
      Map<String, dynamic>? interaction;
      controller = PuzzleSolverController(
        automaticReplies: false,
        repository: repository,
        evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: ids),
        loadInteraction: (_) async => interaction,
        saveInteraction: (_, value) async => interaction = value,
      );
      await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');
      for (final move in ['e2e3', 'd2d3', 'e2e3', 'c2c3', 'd2d3']) {
        await controller.submitMove(uci: move);
      }

      expect(interaction!['version'], 2);
      expect(controller.state!.rejections.map((entry) => entry.uci), [
        'e2e3',
        'd2d3',
        'c2c3',
      ]);
      expect(
        controller.state!.entries.where((entry) => !entry.accepted),
        hasLength(3),
      );
      expect(repository.attempt.outcome, PuzzleAttemptOutcome.wrongMove);
      expect(repository.attempt.wrongMoveCount, 1);
      expect(controller.state!.rejectedMove!.uci, 'd2d3');
      expect(controller.state!.rejections.map((entry) => entry.id), [
        'rejection-1',
        'rejection-2',
        'rejection-3',
      ]);
      expect(controller.state!.phase.name, 'failedPractice');

      controller = PuzzleSolverController(
        automaticReplies: false,
        repository: repository,
        evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: ids),
        loadInteraction: (_) async => interaction,
        saveInteraction: (_, value) async => interaction = value,
      );
      final restored = await controller.initialize(
        puzzle: _puzzle,
        attemptId: 'attempt',
      );
      expect(restored.rejections.map((entry) => entry.uci), [
        'e2e3',
        'd2d3',
        'c2c3',
      ]);
      await controller.submitMove(uci: 'e2e3');
      expect(controller.state!.rejections, hasLength(3));
      await controller.submitMove(uci: 'b2b3');
      expect(controller.state!.rejections.map((entry) => entry.uci), [
        'e2e3',
        'd2d3',
        'c2c3',
        'b2b3',
      ]);
      expect(repository.attempt.outcome, PuzzleAttemptOutcome.wrongMove);
      expect(repository.attempt.wrongMoveCount, 1);
    },
  );

  test(
    'rejects unknown future interaction versions without overwriting them',
    () async {
      var saves = 0;
      controller = PuzzleSolverController(
        automaticReplies: false,
        repository: repository,
        evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: ids),
        loadInteraction: (_) async => {'version': 3, 'future': true},
        saveInteraction: (_, _) async => saves++,
      );

      await expectLater(
        controller.initialize(puzzle: _puzzle, attemptId: 'attempt'),
        throwsStateError,
      );
      expect(saves, 0);
    },
  );

  test(
    'upgrades legacy entries while retaining mistake history and review path',
    () async {
      Map<String, dynamic>? interaction;
      controller = PuzzleSolverController(
        automaticReplies: false,
        repository: repository,
        evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: ids),
        loadInteraction: (_) async => interaction,
        saveInteraction: (_, value) async => interaction = value,
      );
      await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');
      await controller.submitMove(uci: 'e2e3');
      await controller.submitMove(uci: 'd2d3');
      final legacy = Map<String, dynamic>.from(interaction!);
      legacy['version'] = 1;
      legacy.remove('rejections');
      legacy.remove('reviewPath');
      interaction = legacy;

      controller = PuzzleSolverController(
        automaticReplies: false,
        repository: repository,
        evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: ids),
        loadInteraction: (_) async => interaction,
        saveInteraction: (_, value) async => interaction = value,
      );
      final restored = await controller.initialize(
        puzzle: _puzzle,
        attemptId: 'attempt',
      );
      expect(restored.rejections.map((entry) => entry.uci), ['e2e3', 'd2d3']);
      expect(interaction!['version'], 2);
      expect(interaction!['phase'], 'failedPractice');

      await Future.wait([
        controller.setReviewPath([0]),
        controller.setReviewPath([]),
      ]);
      expect(controller.reviewPath, isEmpty);
      expect(interaction!['reviewPath'], isEmpty);
      await expectLater(
        controller.setReviewPath([0, 0, 0]),
        throwsArgumentError,
      );
      expect(controller.reviewPath, isEmpty);
    },
  );

  test(
    'same UCI at separate authored positions is a separate mistake',
    () async {
      final pathPuzzle = ChessContent(
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
                children: [
                  MoveNode(
                    san: 'd4',
                    uci: 'd2d4',
                    fenBefore: 'ignored',
                    fenAfter: 'ignored',
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      await controller.initialize(puzzle: pathPuzzle, attemptId: 'attempt');
      await controller.submitMove(uci: 'g1f3');
      await controller.submitMove(uci: 'e2e4');
      await controller.submitMove(uci: 'e7e5');
      await controller.submitMove(uci: 'g1f3');

      expect(controller.state!.rejections, hasLength(2));
      expect(controller.state!.rejections.map((entry) => entry.uci), [
        'g1f3',
        'g1f3',
      ]);
      expect(controller.state!.rejections.first.authoredPath, isEmpty);
      expect(controller.state!.rejections.last.authoredPath, ['e2e4', 'e7e5']);
    },
  );

  test(
    'whenIdle waits for cursor saves and surfaces failures for retry',
    () async {
      Map<String, dynamic>? interaction;
      Completer<void>? cursorWriteGate;
      var failCursorWrite = false;
      controller = PuzzleSolverController(
        automaticReplies: false,
        repository: repository,
        evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: ids),
        loadInteraction: (_) async => interaction,
        saveInteraction: (_, value) async {
          final gate = cursorWriteGate;
          if (gate != null) await gate.future;
          if (failCursorWrite) throw StateError('cursor save failed');
          interaction = value;
        },
      );
      await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');
      expect(controller.reviewOrientation, isNull);

      cursorWriteGate = Completer<void>();
      final cursorSave = controller.setReviewPath([0]);
      var idleCompleted = false;
      final idle = controller.whenIdle().then((_) => idleCompleted = true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(idleCompleted, isFalse);
      cursorWriteGate.complete();
      await Future.wait([cursorSave, idle]);
      expect(idleCompleted, isTrue);
      expect(interaction!['reviewPath'], [0]);

      cursorWriteGate = null;
      failCursorWrite = true;
      final failedCursorSave = controller.setReviewPath([]);
      await expectLater(failedCursorSave, throwsStateError);
      await expectLater(controller.whenIdle(), throwsStateError);

      failCursorWrite = false;
      await controller.setReviewPath([0]);
      await controller.whenIdle();
      expect(interaction!['reviewPath'], [0]);

      failCursorWrite = true;
      final failedOrientationSave = controller.setReviewOrientation(
        PuzzleSide.black,
      );
      await expectLater(failedOrientationSave, throwsStateError);
      await expectLater(controller.whenIdle(), throwsStateError);
      failCursorWrite = false;
      await controller.setReviewOrientation(PuzzleSide.black);
      await controller.whenIdle();
      expect(interaction!['reviewOrientation'], 'black');

      controller = PuzzleSolverController(
        automaticReplies: false,
        repository: repository,
        evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: ids),
        loadInteraction: (_) async => interaction,
        saveInteraction: (_, value) async => interaction = value,
      );
      await controller.initialize(puzzle: _puzzle, attemptId: 'attempt');
      expect(controller.reviewOrientation, PuzzleSide.black);
    },
  );

  test('promotion choices are distinct UCI mistake identities', () async {
    const promotionFen = '7k/P7/8/8/8/8/8/7K w - - 0 1';
    final promotionPuzzle = ChessContent(
      headers: const {},
      startingFen: promotionFen,
      contentType: ContentType.puzzle,
      rootMoves: [
        MoveNode(
          san: 'Kg2',
          uci: 'h1g2',
          fenBefore: promotionFen,
          fenAfter: 'ignored',
        ),
      ],
    );
    await controller.initialize(puzzle: promotionPuzzle, attemptId: 'attempt');
    await controller.submitMove(uci: 'a7a8q');
    await controller.submitMove(uci: 'a7a8r');
    await controller.submitMove(uci: 'a7a8q');

    expect(controller.state!.rejections.map((entry) => entry.uci), [
      'a7a8q',
      'a7a8r',
    ]);
    expect(controller.state!.rejectedMove!.uci, 'a7a8q');
    expect(controller.state!.rejections.map((entry) => entry.id), [
      'rejection-1',
      'rejection-2',
    ]);
  });
}
