import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/domain/training/attempt_move.dart';
import 'package:pgntrainingreader/domain/training/authored_line_puzzle_evaluator.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/domain/training/puzzle_completion_policy.dart';
import 'package:pgntrainingreader/domain/training/puzzle_evaluator.dart';
import 'package:pgntrainingreader/domain/training/puzzle_interaction_repository.dart';
import 'package:pgntrainingreader/domain/training/timing_segment.dart';
import 'package:pgntrainingreader/domain/training/training_repository.dart';
import 'package:pgntrainingreader/features/puzzle_solver/application/puzzle_solver_controller.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
// The supplied Exercise15 FEN has a pawn on f2 blocking Qxf1. This legal
// constructed position clears f2 and adds a knight on d3 to protect e1 and f2.
const _exercise15MateFen = '7k/8/8/8/5q2/3n4/4r1P1/5RK1 b - - 0 1';
final _started = DateTime.utc(2026, 9, 29);

PuzzleAttempt _attempt() => PuzzleAttempt(
  id: 'attempt',
  blockId: 'block',
  cycleId: 'cycle',
  sessionId: 'session',
  startedAt: _started,
);

ChessContent _puzzle(
  List<String> line, {
  String startingFen = _start,
  Set<int> markers = const {},
  List<String> alternatives = const [],
  Set<String> markedAlternatives = const {},
  List<List<String>> alternativeLines = const [],
  Set<int> alternativeMarkers = const {},
}) {
  final initial = chess.Chess.fromSetup(chess.Setup.parseFen(startingFen));
  MoveNode build(
    chess.Chess position,
    List<String> moves,
    int ply, {
    Set<int> lineMarkers = const {},
  }) {
    final move = chess.Move.parse(moves.first)!;
    final next = position.play(move) as chess.Chess;
    final children = moves.length > 1
        ? [
            build(
              next,
              moves.skip(1).toList(),
              ply + 1,
              lineMarkers: lineMarkers,
            ),
          ]
        : <MoveNode>[];
    return MoveNode(
      san: position.makeSan(move).$2,
      uci: moves.first,
      fenBefore: position.fen,
      fenAfter: next.fen,
      comments: lineMarkers.contains(ply) || markers.contains(ply)
          ? const ['✔']
          : const [],
      children: children,
    );
  }

  final roots = <MoveNode>[build(initial, line, 0)];
  for (final uci in alternatives) {
    final node = build(initial, [uci], 0);
    roots.add(
      markedAlternatives.contains(uci)
          ? MoveNode(
              san: node.san,
              uci: node.uci,
              fenBefore: node.fenBefore,
              fenAfter: node.fenAfter,
              comments: const ['✔'],
            )
          : node,
    );
  }
  for (final line in alternativeLines) {
    roots.add(build(initial, line, 0, lineMarkers: alternativeMarkers));
  }
  return ChessContent(
    headers: const {},
    startingFen: startingFen,
    contentType: ContentType.puzzle,
    rootMoves: roots,
  );
}

final class _Ids implements IdGenerator {
  int next = 0;
  @override
  String generateId() => 'move-${next++}';
}

final class _MemoryRepository
    implements TrainingRepository, PuzzleInteractionRepository {
  _MemoryRepository() : attempt = _attempt();
  PuzzleAttempt attempt;
  final List<AttemptMove> moves = [];
  final Map<String, Map<String, dynamic>> interactions = {};
  bool failInteractionSave = false;

  @override
  Future<PuzzleAttempt?> getAttempt(String id) async =>
      id == attempt.id ? attempt : null;
  @override
  Future<List<AttemptMove>> listAttemptMoves(String id) async => List.of(moves);
  @override
  Future<void> recordSubmittedMove({
    required AttemptMove move,
    required PuzzleAttempt updatedAttempt,
    TimingSegment? closingTimingSegment,
  }) async {
    moves.add(move);
    attempt = updatedAttempt;
  }

  @override
  Future<void> updateUnfinishedAttempt(PuzzleAttempt value) async =>
      attempt = value;
  @override
  Future<void> finalizeAttempt({
    required PuzzleAttempt attempt,
    TimingSegment? finalTimingSegment,
  }) async => this.attempt = attempt;
  @override
  Future<Map<String, dynamic>?> loadPuzzleInteraction(String attemptId) async =>
      interactions[attemptId];
  @override
  Future<void> savePuzzleInteraction(
    String attemptId,
    Map<String, dynamic> value,
  ) async {
    if (failInteractionSave) throw StateError('interaction save failed');
    interactions[attemptId] = Map.of(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PuzzleSolverController _controller(
  _MemoryRepository repository, {
  PuzzleCompletionPolicy? policy,
}) {
  final ids = _Ids();
  return PuzzleSolverController(
    repository: repository,
    evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: ids),
    completionPolicy: policy,
    automaticReplyDelay: Duration.zero,
  );
}

void main() {
  test('autoplays the opponent reply for white and black learner colors with SAN actors', () async {
    final whiteRepo = _MemoryRepository();
    final white = _controller(whiteRepo);
    final whiteState = await white.initialize(
      puzzle: _puzzle(['e2e4', 'e7e5']),
      attemptId: 'attempt',
    );
    expect(whiteState.entries, isEmpty);
    final afterWhite = await white.submitMove(uci: 'e2e4');
    expect(
      afterWhite.entries.map(
        (entry) => [entry.san, entry.actor, entry.accepted],
      ),
      [
        ['e4', 'learner', true],
        ['e5', 'automatic', true],
      ],
    );

    final afterE4 = chess.Chess.fromSetup(
      chess.Setup.parseFen(_start),
    ).play(chess.Move.parse('e2e4')!) as chess.Chess;
    final blackRepo = _MemoryRepository();
    final black = _controller(blackRepo);
    final blackState = await black.initialize(
      puzzle: _puzzle(['e7e5', 'g1f3'], startingFen: afterE4.fen),
      attemptId: 'attempt',
    );
    expect(blackState.entries, isEmpty);
    final afterBlack = await black.submitMove(uci: 'e7e5');
    expect(afterBlack.entries.map((entry) => [entry.san, entry.actor]), [
      ['e5', 'learner'],
      ['Nf3', 'automatic'],
    ]);
  });

  test('restored pending reply is applied without the live delay', () async {
    final repository = _MemoryRepository();
    final first = _controller(repository);
    await first.initialize(
      puzzle: _puzzle(['e2e4', 'e7e5']),
      attemptId: 'attempt',
    );
    await first.submitMove(uci: 'e2e4');

    final restored = PuzzleSolverController(
      repository: repository,
      evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: _Ids()),
      automaticReplyDelay: const Duration(seconds: 5),
    );
    final watch = Stopwatch()..start();
    final state = await restored.initialize(
      puzzle: _puzzle(['e2e4', 'e7e5']),
      attemptId: 'attempt',
    );
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    expect(state.entries.map((entry) => entry.actor), ['learner', 'automatic']);
  });

  test('wrong move stays in immutable score history while concealed practice can finish', () async {
    final repository = _MemoryRepository();
    final controller = _controller(repository);
    await controller.initialize(
      puzzle: _puzzle(['e2e4']),
      attemptId: 'attempt',
    );
    var state = await controller.submitMove(uci: 'd2d4');
    expect(state.outcome, PuzzleAttemptOutcome.wrongMove);
    expect(state.solution, isNull);
    expect(repository.attempt.outcome, PuzzleAttemptOutcome.wrongMove);
    final scoredRecord = repository.attempt;
    final firstWrongEntryCount = state.entries.length;
    state = await controller.submitMove(uci: 'd2d4');
    expect(state.feedback, contains('Incorrect'));
    expect(state.entries, hasLength(firstWrongEntryCount));
    expect(repository.moves, hasLength(1));
    state = await controller.submitMove(uci: 'e2e4');
    expect(state.outcome, PuzzleAttemptOutcome.wrongMove);
    expect(state.solution, isNotNull);
    expect(state.playedMoves, ['e2e4']);
    expect(repository.attempt, same(scoredRecord));
    expect(state.entries.last.accepted, isTrue);
    expect(repository.interactions['attempt']!['entries'], hasLength(2));
  });

  test('hint marks assistance and showMove finalizes as revealed', () async {
    final assistedRepo = _MemoryRepository();
    final assisted = _controller(assistedRepo);
    var state = await assisted.initialize(
      puzzle: _puzzle(['e2e4']),
      attemptId: 'attempt',
    );
    state = await assisted.hint();
    expect(state.hintSquare, 'e2');
    expect(state.outcome, isNull);
    await assisted.submitMove(uci: 'e2e4');
    expect(assisted.state!.outcome, PuzzleAttemptOutcome.assisted);

    final revealedRepo = _MemoryRepository();
    final revealed = _controller(revealedRepo);
    await revealed.initialize(
      puzzle: _puzzle(['e2e4', 'e7e5']),
      attemptId: 'attempt',
    );
    state = await revealed.showMove();
    expect(state.outcome, PuzzleAttemptOutcome.revealed);
    expect(state.entries.first.actor, 'revealed');
    expect(state.solution, isNotNull);
    expect(revealedRepo.attempt.revealed, isTrue);
  });

  test('key-move marker completes at the marker; all-moves falls back to the full line', () async {
    final puzzle = _puzzle(['e2e4', 'e7e5', 'g1f3', 'b8c6'], markers: {0});
    final keyRepo = _MemoryRepository();
    final key = _controller(keyRepo);
    var state = await key.initialize(puzzle: puzzle, attemptId: 'attempt');
    expect(state.policyLabel, 'Key Moves');
    state = await key.submitMove(uci: 'e2e4');
    expect(state.outcome, PuzzleAttemptOutcome.passed);
    expect(state.usedFullLineFallback, isFalse);

    final allRepo = _MemoryRepository();
    final all = _controller(allRepo, policy: PuzzleCompletionPolicy.allMoves);
    state = await all.initialize(puzzle: puzzle, attemptId: 'attempt');
    expect(state.policyLabel, 'All Moves');
    state = await all.submitMove(uci: 'e2e4');
    expect(state.outcome, isNull);
    state = await all.submitMove(uci: 'g1f3');
    expect(state.outcome, PuzzleAttemptOutcome.passed);
    expect(state.usedFullLineFallback, isFalse);

    final branchRepo = _MemoryRepository();
    final branch = _controller(branchRepo);
    state = await branch.initialize(
      puzzle: _puzzle(
        ['d2d4', 'd7d5', 'c2c4'],
        alternativeLines: [
          ['e2e4', 'e7e5'],
        ],
        alternativeMarkers: {1},
      ),
      attemptId: 'attempt',
    );
    expect(state.policyLabel, 'Key Moves');
    state = await branch.submitMove(uci: 'd2d4');
    expect(state.outcome, isNull);
    expect(state.playedMoves, ['d2d4', 'd7d5']);
    state = await branch.submitMove(uci: 'c2c4');
    expect(state.outcome, PuzzleAttemptOutcome.passed);
    expect(state.usedFullLineFallback, isTrue);
  });

  test(
    'explicit Key Moves with no markers uses full-line fallback on completion',
    () async {
      final repository = _MemoryRepository();
      final controller = _controller(
        repository,
        policy: PuzzleCompletionPolicy.keyMoves,
      );
      await controller.initialize(
        puzzle: _puzzle(['d2d4', 'd7d5']),
        attemptId: 'attempt',
      );
      final state = await controller.submitMove(uci: 'd2d4');
      expect(state.outcome, PuzzleAttemptOutcome.passed);
      expect(state.usedFullLineFallback, isTrue);
    },
  );

  test(
    'wrong marked opponent prediction is scored as a failed prediction',
    () async {
      final repository = _MemoryRepository();
      final controller = _controller(repository);
      await controller.initialize(
        puzzle: _puzzle(['e2e4', 'e7e5'], markers: {1}, alternatives: ['d2d4']),
        attemptId: 'attempt',
      );
      final predicting = await controller.submitMove(uci: 'e2e4');
      expect(predicting.isPredictingReply, isTrue);
      final failed = await controller.submitMove(uci: 'd7d5');
      expect(failed.outcome, PuzzleAttemptOutcome.wrongMove);
      expect(failed.entries.last.actor, 'prediction');
      expect(failed.entries.last.accepted, isFalse);
      expect(failed.entries, hasLength(2));
      expect(failed.rejections, hasLength(1));

      final scoredMoveCount = repository.moves.length;
      final scoredAttempt = repository.attempt;
      final secondDistinct = await controller.submitMove(uci: 'd7d6');
      expect(secondDistinct.feedback, contains('Incorrect'));
      expect(secondDistinct.entries, hasLength(3));
      expect(secondDistinct.rejections, hasLength(2));
      expect(secondDistinct.entries.last.actor, 'prediction');
      expect(secondDistinct.entries.last.accepted, isFalse);
      expect(repository.attempt, same(scoredAttempt));
      expect(repository.moves, hasLength(scoredMoveCount));
      expect(repository.interactions['attempt']!['entries'], hasLength(3));

      final repeated = await controller.submitMove(uci: 'd7d5');
      expect(repeated.feedback, contains('Incorrect'));
      expect(repeated.entries, hasLength(3));
      expect(repeated.rejections, hasLength(2));
      expect(repeated.rejectedMove!.uci, 'd7d5');
      expect(repository.attempt, same(scoredAttempt));
      expect(repository.moves, hasLength(scoredMoveCount));
      expect(repository.interactions['attempt']!['entries'], hasLength(3));
    },
  );

  test(
    'Exercise15 key move and full line retain the marked principal review',
    () async {
      final puzzle = _puzzle(
        ['f4f1', 'g1f1', 'e2e1'],
        startingFen: _exercise15MateFen,
        markers: {0},
      );

      final keyRepository = _MemoryRepository();
      final keyMoves = _controller(keyRepository);
      var state = await keyMoves.initialize(
        puzzle: puzzle,
        attemptId: 'attempt',
      );
      expect(state.learnerSide, PuzzleSide.black);
      expect(state.solution, isNull);
      state = await keyMoves.submitMove(uci: 'f4f1');
      expect(state.outcome, PuzzleAttemptOutcome.passed);
      expect(state.entries.map((entry) => [entry.san, entry.actor]), [
        ['Qxf1+', 'learner'],
      ]);
      expect(state.solution!.first.comments, contains('✔'));

      final allRepository = _MemoryRepository();
      final allMoves = _controller(
        allRepository,
        policy: PuzzleCompletionPolicy.allMoves,
      );
      state = await allMoves.initialize(puzzle: puzzle, attemptId: 'attempt');
      expect(state.solution, isNull);
      state = await allMoves.submitMove(uci: 'f4f1');
      expect(state.outcome, isNull);
      expect(state.entries.map((entry) => [entry.san, entry.actor]), [
        ['Qxf1+', 'learner'],
        ['Kxf1', 'automatic'],
      ]);
      expect(state.solution, isNull);
      state = await allMoves.submitMove(uci: 'e2e1');
      expect(state.outcome, PuzzleAttemptOutcome.passed);
      expect(state.entries.map((entry) => [entry.san, entry.actor]), [
        ['Qxf1+', 'learner'],
        ['Kxf1', 'automatic'],
        ['Re1#', 'learner'],
      ]);
      expect(state.solution!.first.comments, contains('✔'));
      expect(state.solution!.first.children.single.san, 'Kxf1');
      expect(state.solution!.first.children.single.children.single.san, 'Re1#');
    },
  );

  test(
    'interaction save failures leave the published projection unchanged',
    () async {
      final moveRepository = _MemoryRepository();
      final moveController = _controller(moveRepository);
      await moveController.initialize(
        puzzle: _puzzle(['e2e4']),
        attemptId: 'attempt',
      );
      final beforeMove = moveController.state;
      moveRepository.failInteractionSave = true;
      await expectLater(
        moveController.submitMove(uci: 'e2e4'),
        throwsStateError,
      );
      expect(moveController.state, same(beforeMove));
      expect(moveRepository.moves, isEmpty);
      expect(moveRepository.attempt.outcome, isNull);

      final hintRepository = _MemoryRepository();
      final hintController = _controller(hintRepository);
      await hintController.initialize(
        puzzle: _puzzle(['e2e4']),
        attemptId: 'attempt',
      );
      final beforeHint = hintController.state;
      hintRepository.failInteractionSave = true;
      await expectLater(hintController.hint(), throwsStateError);
      expect(hintController.state, same(beforeHint));
      expect(hintRepository.attempt.hintCount, 0);
    },
  );

  test('marked opponent prediction waits for learner choice rather than autoplaying', () async {
    final repository = _MemoryRepository();
    final controller = _controller(repository);
    var state = await controller.initialize(
      puzzle: _puzzle(['e2e4', 'e7e5'], markers: {1}, alternatives: ['d2d4']),
      attemptId: 'attempt',
    );
    state = await controller.submitMove(uci: 'e2e4');
    expect(state.isPredictingReply, isTrue);
    expect(state.entries.map((entry) => entry.actor), ['learner']);
    expect(state.entries.any((entry) => entry.actor == 'automatic'), isFalse);
    expect(repository.moves, hasLength(1));
  });

  test('initialize restores failed interaction and review through durable callbacks', () async {
    final repository = _MemoryRepository();
    final controller = _controller(repository);
    await controller.initialize(
      puzzle: _puzzle(['e2e4']),
      attemptId: 'attempt',
    );
    await controller.submitMove(uci: 'd2d4');
    await controller.setOrientation(PuzzleSide.black);
    final restored = _controller(repository);
    final state = await restored.initialize(
      puzzle: _puzzle(['e2e4']),
      attemptId: 'attempt',
    );
    expect(state.outcome, PuzzleAttemptOutcome.wrongMove);
    expect(state.entries.map((entry) => [entry.uci, entry.accepted]), [
      ['d2d4', false],
    ]);
    expect(state.boardOrientation, PuzzleSide.black);
    expect(state.solution, isNull);

    await restored.reveal();
    final reviewController = _controller(repository);
    final review = await reviewController.initialize(
      puzzle: _puzzle(['e2e4']),
      attemptId: 'attempt',
    );
    expect(review.isSolutionVisible, isTrue);
    expect(review.entries.length, 1);
    expect(repository.interactions['attempt']!['review'], isTrue);
  });
}
