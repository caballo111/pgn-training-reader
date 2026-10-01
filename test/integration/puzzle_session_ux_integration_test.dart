import 'dart:async';

import 'package:dartchess/dartchess.dart' as chess;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/time/app_clock.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/data/database/app_database.dart'
    hide Cycle, TrainingSet, TrainingSetItem;
import 'package:pgntrainingreader/data/repositories/drift_training_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/domain/training/authored_line_puzzle_evaluator.dart';
import 'package:pgntrainingreader/domain/training/lifecycle_status.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/domain/training/puzzle_completion_policy.dart';
import 'package:pgntrainingreader/domain/training/training_session_service_impl.dart';
import 'package:pgntrainingreader/domain/training/training_set.dart';
import 'package:pgntrainingreader/domain/training/training_set_item.dart';
import 'package:pgntrainingreader/features/puzzle_solver/application/puzzle_solver_controller.dart';
import 'package:pgntrainingreader/features/training_session/application/active_session_controller.dart';

const _startingFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
final _setDate = DateTime.utc(2026, 9, 27);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'session pause waits for a paced reply and resumes the saved position',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _seed(database);
      final repository = DriftTrainingRepository(database);
      final clock = _TestClock(DateTime.utc(2026, 10));
      final session = _sessionController(
        set: (await repository.getSet('set'))!,
        repository: repository,
        contentRepository: _ContentRepository({
          'block-original': _replyPuzzle(),
        }),
        clock: clock,
        ids: _Ids(),
        policy: PuzzleCompletionPolicy.allMoves,
      );
      addTearDown(session.dispose);
      await session.start();
      final solver = await _initializeActivePuzzle(session);
      final replyPending = Completer<void>();
      solver.addStateListener((state) {
        if (state.playedMoves.length == 1 &&
            !solver.canInteract &&
            !replyPending.isCompleted) {
          replyPending.complete();
        }
      });
      final moving = solver.submitMove(uci: 'e2e4');
      await replyPending.future;
      final pausing = session.pause();
      expect(session.state.status, ActiveSessionStatus.active);
      await moving;
      await pausing;
      expect(session.state.status, ActiveSessionStatus.paused);
      final attemptId = session.state.attempt!.id;
      expect(
        (await repository.getAttempt(attemptId))!.status,
        PuzzleAttemptStatus.paused,
      );
      expect(
        (await repository.listAttemptMoves(attemptId)).map((move) => move.move),
        ['e2e4', 'e7e5'],
      );
      await session.resume();
      await solver.initialize(
        puzzle: session.state.content!,
        attemptId: attemptId,
      );
      expect(solver.state!.playedMoves, ['e2e4', 'e7e5']);
      final completed = await solver.submitMove(uci: 'g1f3');
      expect(completed.outcome, PuzzleAttemptOutcome.passed);
    },
  );

  test('failed score time stops during review and cursor restores the immutable puzzle until advance', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seed(database);
    final clock = _TestClock(DateTime.utc(2026, 9, 28, 9));
    final ids = _Ids();
    final repository = DriftTrainingRepository(database);
    final contents = _ContentRepository({'block-original': _puzzle()});

    final firstSession = _sessionController(
      set: (await repository.getSet('set'))!,
      repository: repository,
      contentRepository: contents,
      clock: clock,
      ids: ids,
      policy: PuzzleCompletionPolicy.keyMoves,
    );
    await firstSession.start();
    final cycleId = firstSession.state.cycle!.id;
    final firstSolver = await _initializeActivePuzzle(firstSession);
    final attemptId = firstSession.state.attempt!.id;

    clock.advance(const Duration(seconds: 90));
    var puzzleState = await firstSolver.submitMove(uci: 'd2d4');
    expect(puzzleState.outcome, PuzzleAttemptOutcome.wrongMove);
    expect(puzzleState.solution, isNull);
    final failedRecord = (await repository.getAttempt(attemptId))!;
    expect(failedRecord.outcome, PuzzleAttemptOutcome.wrongMove);
    expect(failedRecord.activeDuration, const Duration(seconds: 90));

    // Solving during review changes the interaction only; scored history and
    // active attempt time remain fixed while the wall clock advances.
    clock.advance(const Duration(minutes: 4));
    puzzleState = await firstSolver.submitMove(uci: 'e2e4');
    expect(puzzleState.outcome, PuzzleAttemptOutcome.wrongMove);
    expect(puzzleState.solution, isNotNull);
    expect(puzzleState.playedMoves, ['e2e4']);
    expect(await repository.getAttempt(attemptId), failedRecord);
    expect(
      (await repository.aggregateForCycle(cycleId)).attemptActiveDurations,
      [const Duration(seconds: 90)],
    );

    await firstSession.close();
    firstSession.dispose();
    expect((await repository.getCycle(cycleId))!.status, CycleStatus.active);
    expect(await repository.getCycleCursor(cycleId), attemptId);

    // The mutable set removes the scored item, changes order and adds a new
    // puzzle. The cycle's own original selection and key-move policy persist.
    await database
        .into(database.pgnBlocks)
        .insert(
          PgnBlocksCompanion.insert(
            id: 'block-new',
            sourceId: 'source',
            startOffset: 10,
            endOffset: 19,
            ordinal: 1,
            contentType: ContentType.puzzle.toDatabaseValue(),
            parseStatus: 'notParsed',
          ),
        );
    contents.contentById['block-new'] = _puzzle();
    final oldSet = (await repository.getSet('set'))!;
    await repository.updateSet(
      TrainingSet(
        id: oldSet.id,
        name: oldSet.name,
        createdAt: oldSet.createdAt,
        updatedAt: clock.utcNow,
        items: [
          TrainingSetItem(
            id: 'item-new',
            trainingSetId: 'set',
            blockId: 'block-new',
            position: 0,
            contentType: ContentType.puzzle,
            addedAt: clock.utcNow,
          ),
        ],
      ),
    );

    final resumedSession = _sessionController(
      set: (await repository.getSet('set'))!,
      repository: repository,
      contentRepository: contents,
      clock: clock,
      ids: ids,
      // A changed caller preference must not replace this cycle's policy.
      policy: PuzzleCompletionPolicy.allMoves,
    );
    await resumedSession.start();
    expect(resumedSession.state.status, ActiveSessionStatus.active);
    expect(resumedSession.state.activeItem!.id, 'item-original');
    expect(resumedSession.state.activeItem!.blockId, 'block-original');
    expect(resumedSession.state.attempt!.id, attemptId);
    expect(await repository.getCycleCursor(cycleId), attemptId);

    final resumedSolver = await _initializeActivePuzzle(resumedSession);
    expect(resumedSolver.state!.outcome, PuzzleAttemptOutcome.wrongMove);
    expect(resumedSolver.state!.solution, isNotNull);
    expect(resumedSolver.state!.playedMoves, ['e2e4']);
    expect(resumedSolver.state!.policyLabel, 'Key Moves');
    expect(resumedSolver.canInteract, isFalse);
    expect(await repository.getCyclePolicy(cycleId), 'keyMoves');
    expect((await repository.getCycle(cycleId))!.status, CycleStatus.active);

    // Review dwell after reopening is also excluded from the failed score.
    clock.advance(const Duration(minutes: 3));
    resumedSession.refreshClock();
    expect(
      (await repository.getAttempt(attemptId))!.activeDuration,
      const Duration(seconds: 90),
    );

    await resumedSession.advance();
    expect(resumedSession.state.status, ActiveSessionStatus.completed);
    expect((await repository.getCycle(cycleId))!.status, CycleStatus.completed);
    expect(await repository.getAttempt(attemptId), failedRecord);
  });
}

Future<PuzzleSolverController> _initializeActivePuzzle(
  ActiveSessionController session,
) async {
  final solver = session.createPuzzleController();
  await solver.initialize(
    puzzle: session.state.content!,
    attemptId: session.state.attempt!.id,
  );
  return solver;
}

ActiveSessionController _sessionController({
  required TrainingSet set,
  required DriftTrainingRepository repository,
  required _ContentRepository contentRepository,
  required _TestClock clock,
  required _Ids ids,
  required PuzzleCompletionPolicy policy,
}) => ActiveSessionController(
  trainingSet: set,
  sessionService: TrainingSessionServiceImpl(
    repository: repository,
    clock: clock,
    idGenerator: ids,
  ),
  repository: repository,
  contentRepository: contentRepository,
  clock: clock,
  evaluatorFactory: () =>
      AuthoredLinePuzzleEvaluator(clock: clock, idGenerator: ids),
  completionPolicy: policy,
);

Future<void> _seed(AppDatabase database) async {
  await database.customStatement('PRAGMA foreign_keys = ON');
  await database
      .into(database.pgnSources)
      .insert(
        PgnSourcesCompanion.insert(
          id: 'source',
          displayName: 'Source',
          accessMode: 'managedCopy',
          scannerVersion: 1,
          importState: 'ready',
          createdAtMicros: 1,
          updatedAtMicros: 1,
        ),
      );
  await database
      .into(database.pgnBlocks)
      .insert(
        PgnBlocksCompanion.insert(
          id: 'block-original',
          sourceId: 'source',
          startOffset: 0,
          endOffset: 9,
          ordinal: 0,
          contentType: ContentType.puzzle.toDatabaseValue(),
          parseStatus: 'notParsed',
        ),
      );
  await DriftTrainingRepository(database).createSet(
    TrainingSet(
      id: 'set',
      name: 'Cycle fixture',
      createdAt: _setDate,
      updatedAt: _setDate,
      items: [
        TrainingSetItem(
          id: 'item-original',
          trainingSetId: 'set',
          blockId: 'block-original',
          position: 0,
          contentType: ContentType.puzzle,
          addedAt: _setDate,
        ),
      ],
    ),
  );
}

ChessContent _replyPuzzle() {
  MoveNode line(chess.Chess position, List<String> moves) {
    final move = chess.Move.parse(moves.first)!;
    final next = position.play(move) as chess.Chess;
    return MoveNode(
      san: position.makeSan(move).$2,
      uci: moves.first,
      fenBefore: position.fen,
      fenAfter: next.fen,
      children: moves.length == 1 ? const [] : [line(next, moves.sublist(1))],
    );
  }

  return ChessContent(
    headers: const {},
    startingFen: _startingFen,
    contentType: ContentType.puzzle,
    rootMoves: [
      line(chess.Chess.fromSetup(chess.Setup.parseFen(_startingFen)), [
        'e2e4',
        'e7e5',
        'g1f3',
      ]),
    ],
  );
}

ChessContent _puzzle() {
  final position = chess.Chess.fromSetup(chess.Setup.parseFen(_startingFen));
  final move = chess.Move.parse('e2e4')!;
  final after = position.play(move) as chess.Chess;
  return ChessContent(
    headers: const {},
    startingFen: _startingFen,
    contentType: ContentType.puzzle,
    rootMoves: [
      MoveNode(
        san: position.makeSan(move).$2,
        uci: 'e2e4',
        fenBefore: position.fen,
        fenAfter: after.fen,
        comments: const ['✔'],
      ),
    ],
  );
}

final class _ContentRepository implements ChessContentRepository {
  _ContentRepository(this.contentById);

  final Map<String, ChessContent> contentById;

  @override
  Future<ChessContent?> getById(String id) async => contentById[id];
}

final class _TestClock implements AppClock {
  _TestClock(this._utcNow);

  DateTime _utcNow;
  Duration _elapsed = Duration.zero;

  @override
  DateTime get utcNow => _utcNow;

  @override
  Duration get monotonicElapsed => _elapsed;

  void advance(Duration duration) {
    _utcNow = _utcNow.add(duration);
    _elapsed += duration;
  }
}

final class _Ids implements IdGenerator {
  var _next = 0;

  @override
  String generateId() => 'ux-${_next++}';
}
