import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/domain/training/attempt_move.dart';
import 'package:pgntrainingreader/domain/training/authored_line_puzzle_evaluator.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/domain/training/puzzle_evaluator.dart';

import '../../support/fake_app_clock.dart';
import '../../support/fake_id_generator.dart';

final _startedAt = DateTime.utc(2026, 9, 29);
const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

ChessContent _puzzle({ContentType type = ContentType.puzzle}) => ChessContent(
  headers: const {},
  startingFen: _startFen,
  contentType: type,
  rootMoves: [
    MoveNode(
      san: 'e4',
      uci: 'e2e4',
      fenBefore: _startFen,
      fenAfter: 'ignored',
      children: [
        MoveNode(
          san: 'e5',
          uci: 'e7e5',
          fenBefore: 'ignored',
          fenAfter: 'ignored',
        ),
        MoveNode(
          san: 'c5',
          uci: 'c7c5',
          fenBefore: 'ignored',
          fenAfter: 'ignored',
        ),
      ],
    ),
  ],
);

PuzzleAttempt _attempt({
  PuzzleAttemptStatus status = PuzzleAttemptStatus.active,
  PuzzleAttemptOutcome? outcome,
  DateTime? completedAt,
}) => PuzzleAttempt(
  id: 'attempt-1',
  blockId: 'block-1',
  cycleId: 'cycle-1',
  sessionId: 'session-1',
  status: status,
  startedAt: _startedAt,
  completedAt: completedAt,
  outcome: outcome,
  activeDuration: const Duration(seconds: 3),
);

AttemptMove _acceptedFirstMove() => AttemptMove(
  id: 'move-1',
  attemptId: 'attempt-1',
  ordinal: 0,
  move: 'e2e4',
  legal: true,
  accepted: true,
  submittedAt: _startedAt.add(const Duration(seconds: 1)),
);

void main() {
  late FakeAppClock clock;
  late FakeIdGenerator ids;
  late AuthoredLinePuzzleEvaluator evaluator;

  setUp(() {
    clock = FakeAppClock(initialWallTime: _startedAt);
    ids = FakeIdGenerator(prefix: 'attempt-move');
    evaluator = AuthoredLinePuzzleEvaluator(clock: clock, idGenerator: ids);
  });

  final scenarios =
      <
        ({
          String name,
          PuzzleEvaluationState Function(AuthoredLinePuzzleEvaluator) run,
          PuzzleAttemptOutcome outcome,
          PuzzleAttemptFailureReason? reason,
          int wrongMoveCount,
        })
      >[
        (
          name: 'main line passes at its terminal node',
          run: (evaluator) {
            evaluator.submitMove(uci: 'e2e4');
            return evaluator.submitMove(uci: 'e7e5');
          },
          outcome: PuzzleAttemptOutcome.passed,
          reason: null,
          wrongMoveCount: 0,
        ),
        (
          name: 'alternate authored line passes at its terminal node',
          run: (evaluator) {
            evaluator.submitMove(uci: 'e2e4');
            return evaluator.submitMove(uci: 'c7c5');
          },
          outcome: PuzzleAttemptOutcome.passed,
          reason: null,
          wrongMoveCount: 0,
        ),
        (
          name: 'illegal submitted move records illegalMove',
          run: (evaluator) => evaluator.submitMove(uci: 'e2e5'),
          outcome: PuzzleAttemptOutcome.wrongMove,
          reason: PuzzleAttemptFailureReason.illegalMove,
          wrongMoveCount: 1,
        ),
        (
          name: 'wrong legal move records incorrectMove',
          run: (evaluator) => evaluator.submitMove(uci: 'e2e3'),
          outcome: PuzzleAttemptOutcome.wrongMove,
          reason: PuzzleAttemptFailureReason.incorrectMove,
          wrongMoveCount: 1,
        ),
        (
          name: 'reveal finalizes as revealed',
          run: (evaluator) => evaluator.reveal(),
          outcome: PuzzleAttemptOutcome.revealed,
          reason: null,
          wrongMoveCount: 0,
        ),
        (
          name: 'skip finalizes as skipped',
          run: (evaluator) => evaluator.skip(),
          outcome: PuzzleAttemptOutcome.skipped,
          reason: null,
          wrongMoveCount: 0,
        ),
        (
          name: 'timeout records timeLimitExceeded',
          run: (evaluator) => evaluator.timeout(),
          outcome: PuzzleAttemptOutcome.timedOut,
          reason: PuzzleAttemptFailureReason.timeLimitExceeded,
          wrongMoveCount: 0,
        ),
        (
          name: 'abandon records userAbandoned',
          run: (evaluator) => evaluator.abandon(),
          outcome: PuzzleAttemptOutcome.abandoned,
          reason: PuzzleAttemptFailureReason.userAbandoned,
          wrongMoveCount: 0,
        ),
        (
          name: 'submission after finalization cannot change the outcome',
          run: (evaluator) {
            final skipped = evaluator.skip();
            expect(() => evaluator.submitMove(uci: 'e2e4'), throwsStateError);
            expect(evaluator.finalAttempt, skipped.attempt);
            return evaluator.state!;
          },
          outcome: PuzzleAttemptOutcome.skipped,
          reason: null,
          wrongMoveCount: 0,
        ),
      ];

  for (final scenario in scenarios) {
    test('evaluator matrix: ${scenario.name}', () {
      evaluator.initialize(puzzle: _puzzle(), attempt: _attempt());

      final result = scenario.run(evaluator);

      expect(result.attempt.outcome, scenario.outcome);
      expect(result.attempt.failureReason, scenario.reason);
      expect(result.attempt.wrongMoveCount, scenario.wrongMoveCount);
      expect(result.attempt.status, PuzzleAttemptStatus.finalized);
    });
  }

  test(
    'starts from FEN and reports legal destinations without leaking line',
    () {
      expect(evaluator.state, isNull);
      final state = evaluator.initialize(
        puzzle: _puzzle(),
        attempt: _attempt(),
      );

      expect(state.sideToMove, PuzzleSide.white);
      expect(state.currentFen, _startFen);
      expect(state.moves, isEmpty);
      expect(evaluator.legalDestinations(fromSquare: 'e2'), contains('e4'));
      expect(
        () => evaluator.legalDestinations(fromSquare: 'z9'),
        throwsFormatException,
      );
    },
  );

  test('restores accepted move history and enforces paused lifecycle', () {
    final firstMove = _acceptedFirstMove();
    final pausedAttempt = _attempt(status: PuzzleAttemptStatus.paused);
    final paused = evaluator.initialize(
      puzzle: _puzzle(),
      attempt: pausedAttempt,
      previousMoves: [firstMove],
    );

    expect(paused.sideToMove, PuzzleSide.black);
    expect(paused.moves, [firstMove]);
    expect(() => evaluator.submitMove(uci: 'e7e5'), throwsStateError);

    final resumed = evaluator.initialize(
      puzzle: _puzzle(),
      attempt: _attempt(),
      previousMoves: paused.moves,
    );
    expect(resumed.sideToMove, PuzzleSide.black);
    expect(resumed.moves, [firstMove]);

    clock.advance(const Duration(minutes: 2));
    final passed = evaluator.submitMove(uci: 'e7e5');
    expect(passed.attempt.outcome, PuzzleAttemptOutcome.passed);
    expect(passed.moves, hasLength(2));
    expect(passed.attempt.activeDuration, const Duration(seconds: 3));
  });

  test('distinguishes malformed input from a submitted illegal chess move', () {
    final initial = evaluator.initialize(
      puzzle: _puzzle(),
      attempt: _attempt(),
    );

    expect(() => evaluator.submitMove(uci: 'malformed'), throwsFormatException);
    expect(evaluator.state?.attempt, same(initial.attempt));
    expect(evaluator.state?.moves, isEmpty);

    final failed = evaluator.submitMove(uci: 'e2e5');
    expect(failed.attempt.status, PuzzleAttemptStatus.finalized);
    expect(failed.attempt.outcome, PuzzleAttemptOutcome.wrongMove);
    expect(
      failed.attempt.failureReason,
      PuzzleAttemptFailureReason.illegalMove,
    );
    expect(failed.attempt.wrongMoveCount, 1);
    expect(failed.moves, hasLength(1));
    expect(failed.moves.single.move, 'e2e5');
    expect(failed.moves.single.legal, isFalse);
    expect(failed.moves.single.accepted, isFalse);
  });

  test('accepts a non-first authored child and preserves source order', () {
    final puzzle = _puzzle();
    final authoredOrder = puzzle.rootMoves.single.children
        .map((node) => node.uci)
        .toList();
    evaluator.initialize(puzzle: puzzle, attempt: _attempt());

    final afterFirstMove = evaluator.submitMove(uci: 'e2e4');
    expect(afterFirstMove.attempt.outcome, isNull);
    expect(afterFirstMove.sideToMove, PuzzleSide.black);

    final afterAlternate = evaluator.submitMove(uci: 'c7c5');
    expect(afterAlternate.attempt.outcome, PuzzleAttemptOutcome.passed);
    expect(afterAlternate.attempt.failureReason, isNull);
    expect(afterAlternate.moves.map((move) => move.move), ['e2e4', 'c7c5']);
    expect(
      puzzle.rootMoves.single.children.map((node) => node.uci),
      authoredOrder,
    );
    expect(authoredOrder, ['e7e5', 'c7c5']);
  });

  test(
    'passes only at an accepted terminal node and retains earlier outcomes',
    () {
      evaluator.initialize(puzzle: _puzzle(), attempt: _attempt());

      final nonterminal = evaluator.submitMove(uci: 'e2e4');
      expect(nonterminal.attempt.status, PuzzleAttemptStatus.active);
      expect(nonterminal.attempt.outcome, isNull);
      expect(evaluator.finalAttempt, isNull);

      final terminal = evaluator.submitMove(uci: 'e7e5');
      expect(terminal.attempt.status, PuzzleAttemptStatus.finalized);
      expect(terminal.attempt.outcome, PuzzleAttemptOutcome.passed);
      expect(evaluator.finalAttempt, terminal.attempt);

      final failedEvaluator = AuthoredLinePuzzleEvaluator(
        clock: clock,
        idGenerator: ids,
      );
      failedEvaluator.initialize(puzzle: _puzzle(), attempt: _attempt());
      final failed = failedEvaluator.submitMove(uci: 'e2e3');
      expect(failed.attempt.outcome, PuzzleAttemptOutcome.wrongMove);
      expect(() => failedEvaluator.submitMove(uci: 'e2e4'), throwsStateError);
      expect(
        failedEvaluator.finalAttempt?.outcome,
        PuzzleAttemptOutcome.wrongMove,
      );

      final revealedEvaluator = AuthoredLinePuzzleEvaluator(
        clock: clock,
        idGenerator: ids,
      );
      revealedEvaluator.initialize(puzzle: _puzzle(), attempt: _attempt());
      final revealed = revealedEvaluator.reveal();
      expect(revealed.attempt.outcome, PuzzleAttemptOutcome.revealed);
      expect(() => revealedEvaluator.submitMove(uci: 'e2e4'), throwsStateError);
      expect(
        revealedEvaluator.finalAttempt?.outcome,
        PuzzleAttemptOutcome.revealed,
      );
    },
  );

  test(
    'first legal authored mismatch fails once and blocks further scoring',
    () {
      evaluator.initialize(puzzle: _puzzle(), attempt: _attempt());

      final failed = evaluator.submitMove(uci: 'e2e3');
      expect(failed.moves.single.legal, isTrue);
      expect(failed.moves.single.accepted, isFalse);
      expect(failed.attempt.status, PuzzleAttemptStatus.finalized);
      expect(failed.attempt.outcome, PuzzleAttemptOutcome.wrongMove);
      expect(
        failed.attempt.failureReason,
        PuzzleAttemptFailureReason.incorrectMove,
      );
      expect(failed.attempt.wrongMoveCount, 1);

      expect(() => evaluator.submitMove(uci: 'e2e4'), throwsStateError);
      expect(evaluator.finalAttempt?.outcome, PuzzleAttemptOutcome.wrongMove);
      expect(evaluator.finalAttempt?.wrongMoveCount, 1);
      expect(evaluator.state?.moves, hasLength(1));
    },
  );

  test('reveal, skip, timeout, and abandon finalize with exact outcomes', () {
    AuthoredLinePuzzleEvaluator initialized({
      PuzzleAttemptStatus status = PuzzleAttemptStatus.active,
    }) =>
        AuthoredLinePuzzleEvaluator(clock: clock, idGenerator: ids)..initialize(
          puzzle: _puzzle(),
          attempt: _attempt(status: status),
        );

    final revealed = initialized(status: PuzzleAttemptStatus.paused).reveal();
    expect(revealed.attempt.outcome, PuzzleAttemptOutcome.revealed);
    expect(revealed.attempt.revealed, isTrue);
    expect(revealed.attempt.failureReason, isNull);
    expect(revealed.attempt.activeDuration, const Duration(seconds: 3));

    final skipped = initialized().skip();
    expect(skipped.attempt.outcome, PuzzleAttemptOutcome.skipped);
    expect(skipped.attempt.failureReason, isNull);
    expect(skipped.attempt.activeDuration, const Duration(seconds: 3));

    final timedOut = initialized(status: PuzzleAttemptStatus.paused).timeout();
    expect(timedOut.attempt.outcome, PuzzleAttemptOutcome.timedOut);
    expect(
      timedOut.attempt.failureReason,
      PuzzleAttemptFailureReason.timeLimitExceeded,
    );
    expect(timedOut.attempt.activeDuration, const Duration(seconds: 3));

    final abandoned = initialized().abandon();
    expect(abandoned.attempt.outcome, PuzzleAttemptOutcome.abandoned);
    expect(
      abandoned.attempt.failureReason,
      PuzzleAttemptFailureReason.userAbandoned,
    );
    expect(abandoned.attempt.activeDuration, const Duration(seconds: 3));
  });

  test('rejects malformed restored move history without replacing state', () {
    final state = evaluator.initialize(puzzle: _puzzle(), attempt: _attempt());
    final malformed = AttemptMove(
      id: 'move-other',
      attemptId: 'another-attempt',
      ordinal: 0,
      move: 'e2e4',
      legal: true,
      accepted: true,
      submittedAt: _startedAt,
    );

    expect(
      () => evaluator.initialize(
        puzzle: _puzzle(),
        attempt: _attempt(),
        previousMoves: [malformed],
      ),
      throwsArgumentError,
    );
    expect(evaluator.state?.attempt, same(state.attempt));
    expect(evaluator.state?.currentFen, state.currentFen);
    expect(evaluator.state?.moves, isEmpty);
  });

  test('rejects duplicate IDs and impossible restored history', () {
    final first = _acceptedFirstMove();
    final invalidSecondMoves = [
      AttemptMove(
        id: first.id,
        attemptId: 'attempt-1',
        ordinal: 1,
        move: 'e7e5',
        legal: true,
        accepted: true,
        submittedAt: _startedAt,
      ),
      AttemptMove(
        id: 'move-2',
        attemptId: 'attempt-1',
        ordinal: 2,
        move: 'e7e5',
        legal: true,
        accepted: true,
        submittedAt: _startedAt,
      ),
      AttemptMove(
        id: 'move-2',
        attemptId: 'attempt-1',
        ordinal: 1,
        move: 'e7e5',
        legal: false,
        accepted: false,
        submittedAt: _startedAt,
      ),
    ];

    for (final invalidSecond in invalidSecondMoves) {
      final freshEvaluator = AuthoredLinePuzzleEvaluator(
        clock: clock,
        idGenerator: ids,
      );
      expect(
        () => freshEvaluator.initialize(
          puzzle: _puzzle(),
          attempt: _attempt(),
          previousMoves: [first, invalidSecond],
        ),
        throwsArgumentError,
      );
      expect(freshEvaluator.state, isNull);
    }
  });

  test(
    'does not reopen a finalized attempt from a stale active or paused copy',
    () {
      evaluator.initialize(puzzle: _puzzle(), attempt: _attempt());
      evaluator.submitMove(uci: 'e2e4');
      evaluator.submitMove(uci: 'e7e5');
      expect(evaluator.finalAttempt?.outcome, PuzzleAttemptOutcome.passed);

      for (final status in [
        PuzzleAttemptStatus.active,
        PuzzleAttemptStatus.paused,
      ]) {
        expect(
          () => evaluator.initialize(
            puzzle: _puzzle(),
            attempt: _attempt(status: status),
          ),
          throwsStateError,
        );
        expect(evaluator.finalAttempt?.outcome, PuzzleAttemptOutcome.passed);
      }
    },
  );

  test('rejects non-puzzle, empty-solution, and finalized initialization', () {
    expect(
      () => evaluator.initialize(
        puzzle: _puzzle(type: ContentType.demonstration),
        attempt: _attempt(),
      ),
      throwsArgumentError,
    );
    expect(
      () => evaluator.initialize(
        puzzle: ChessContent(
          headers: const {},
          startingFen: _startFen,
          contentType: ContentType.puzzle,
        ),
        attempt: _attempt(),
      ),
      throwsArgumentError,
    );
    expect(
      () => evaluator.initialize(
        puzzle: _puzzle(),
        attempt: _attempt(
          status: PuzzleAttemptStatus.finalized,
          outcome: PuzzleAttemptOutcome.passed,
          completedAt: _startedAt,
        ),
      ),
      throwsStateError,
    );
  });
}
