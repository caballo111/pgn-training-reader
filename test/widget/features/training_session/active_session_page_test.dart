import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/time/app_clock.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/domain/analysis/exploration_repository.dart';
import 'package:pgntrainingreader/domain/analysis/exploration_session.dart';
import 'package:pgntrainingreader/domain/training/attempt_move.dart';
import 'package:pgntrainingreader/domain/training/authored_line_puzzle_evaluator.dart';
import 'package:pgntrainingreader/domain/training/cycle.dart';
import 'package:pgntrainingreader/domain/training/lifecycle_status.dart';
import 'package:pgntrainingreader/domain/training/progress_aggregate.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/domain/training/puzzle_interaction_repository.dart';
import 'package:pgntrainingreader/domain/training/timing_segment.dart';
import 'package:pgntrainingreader/domain/training/training_repository.dart';
import 'package:pgntrainingreader/domain/training/training_session.dart';
import 'package:pgntrainingreader/domain/training/training_session_service.dart';
import 'package:pgntrainingreader/domain/training/training_set.dart';
import 'package:pgntrainingreader/domain/training/training_set_item.dart';
import 'package:pgntrainingreader/features/training_session/application/active_session_controller.dart';
import 'package:pgntrainingreader/features/training_session/presentation/active_session_page.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_solving_view.dart';
import 'package:pgntrainingreader/features/game_reader/presentation/reader_board.dart';

final _startedAt = DateTime.utc(2026, 9, 28, 12);
const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  testWidgets(
    'cycle reading waits for a durable exploration save before completing',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final clock = _TestClock();
      final item = TrainingSetItem(
        id: 'text-item',
        trainingSetId: 'set',
        blockId: 'text-block',
        position: 0,
        contentType: ContentType.text,
        addedAt: _startedAt,
      );
      final attempt = PuzzleAttempt(
        id: 'unused-attempt',
        blockId: 'unused-block',
        cycleId: 'cycle',
        sessionId: 'session',
        startedAt: _startedAt,
      );
      final repository = _TrainingRepository(attempt: attempt, item: item);
      final cycle = Cycle(
        id: 'cycle',
        trainingSetId: 'set',
        status: CycleStatus.active,
        startedAt: _startedAt,
        createdAt: _startedAt,
      );
      final session = TrainingSession(
        id: 'session',
        cycleId: cycle.id,
        status: TrainingSessionStatus.active,
        startedAt: _startedAt,
        studyDay: DateTime.utc(2026, 9, 28),
      );
      final content = ChessContent(
        headers: const {'Event': 'Reading fixture'},
        startingFen: _startFen,
        contentType: ContentType.text,
        rootMoves: [
          MoveNode(
            san: 'e4',
            uci: 'e2e4',
            fenBefore: _startFen,
            fenAfter:
                'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
          ),
        ],
      );
      final service = _SessionService(
        cycle: cycle,
        session: session,
        item: item,
        repository: repository,
      );
      final explorationRepository = _ExplorationRepository()..failWrites = true;
      final controller = ActiveSessionController(
        trainingSet: TrainingSet(
          id: 'set',
          name: 'Reading set',
          items: [item],
          createdAt: _startedAt,
          updatedAt: _startedAt,
        ),
        sessionService: service,
        repository: repository,
        contentRepository: _ContentRepository(content),
        clock: clock,
        evaluatorFactory: () =>
            AuthoredLinePuzzleEvaluator(clock: clock, idGenerator: _Ids()),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveSessionPage(
            controller: controller,
            explorationRepository: explorationRepository,
            explorationScopeIdResolver: (_) async => 'text-block/source/rev1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('explore-position')),
      );
      await tester.tap(find.byKey(const ValueKey('explore-position')));
      await tester.pumpAndSettle();
      await _playMoveOnBoard(tester, from: 'e2', to: 'e4');
      await tester.tap(find.text('Complete item and continue'));
      await tester.pumpAndSettle();
      expect(service.completeNonPuzzleCalls, 0);
      expect(controller.state.activeItem?.id, item.id);
      expect(find.text('Return to reading'), findsOneWidget);
      expect(
        find.text('Reading could not be saved. Retry before continuing.'),
        findsOneWidget,
      );

      explorationRepository.failWrites = false;
      ScaffoldMessenger.of(
        tester.element(find.text('Complete item and continue')),
      ).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete item and continue'));
      await tester.pumpAndSettle();
      expect(service.completeNonPuzzleCalls, 1);
      expect(controller.state.status, ActiveSessionStatus.completed);
      expect(explorationRepository.savedSessions.last.moves, ['e2e4']);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'session shows the existing puzzle solver and pauses on app inactivity',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final clock = _TestClock();
      final attempt = PuzzleAttempt(
        id: 'attempt',
        blockId: 'block',
        cycleId: 'cycle',
        sessionId: 'session',
        startedAt: _startedAt,
      );
      final item = TrainingSetItem(
        id: 'item',
        trainingSetId: 'set',
        blockId: 'block',
        position: 0,
        contentType: ContentType.puzzle,
        addedAt: _startedAt,
      );
      final cycle = Cycle(
        id: 'cycle',
        trainingSetId: 'set',
        status: CycleStatus.active,
        startedAt: _startedAt,
        createdAt: _startedAt,
      );
      final session = TrainingSession(
        id: 'session',
        cycleId: cycle.id,
        status: TrainingSessionStatus.active,
        startedAt: _startedAt,
        studyDay: DateTime.utc(2026, 9, 28),
      );
      final content = ChessContent(
        headers: const {'Event': 'Training fixture'},
        startingFen: _startFen,
        contentType: ContentType.puzzle,
        rootMoves: [
          MoveNode(
            san: 'e4',
            uci: 'e2e4',
            fenBefore: _startFen,
            fenAfter:
                'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
          ),
        ],
      );
      final repository = _TrainingRepository(attempt: attempt, item: item);
      final explorationRepository = _ExplorationRepository();
      final service = _SessionService(
        cycle: cycle,
        session: session,
        item: item,
        repository: repository,
      );
      service.failCloseCount = 1;
      final controller = ActiveSessionController(
        trainingSet: TrainingSet(
          id: 'set',
          name: 'Puzzle set',
          items: [item],
          createdAt: _startedAt,
          updatedAt: _startedAt,
        ),
        sessionService: service,
        repository: repository,
        contentRepository: _ContentRepository(content),
        clock: clock,
        evaluatorFactory: () =>
            AuthoredLinePuzzleEvaluator(clock: clock, idGenerator: _Ids()),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ActiveSessionPage(
                        controller: controller,
                        explorationRepository: explorationRepository,
                        explorationScopeIdResolver: (_) async =>
                            '["block","source","revision-1"]',
                      ),
                    ),
                  ),
                  child: const Text('Open session'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open session'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'White to move',
        ),
        findsOneWidget,
      );
      expect(find.byType(PuzzleSolvingView), findsOneWidget);
      await _checkActionGeometry(tester, ['Hint', 'Show solution']);

      clock.elapsed += const Duration(seconds: 3);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(service.pauseCalls, 1);
      expect(service.segmentDurations, [const Duration(seconds: 3)]);
      expect(find.byTooltip('Resume session'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Resume session'));
      await tester.pumpAndSettle();
      clock.elapsed += const Duration(seconds: 4);
      await tester.pump(const Duration(seconds: 1));
      final puzzleView = tester.widget<PuzzleSolvingView>(
        find.byType(PuzzleSolvingView),
      );
      await puzzleView.controller.submitMove(uci: 'e2e4');
      expect(service.segmentDurations, [
        const Duration(seconds: 3),
        const Duration(seconds: 4),
      ]);
      expect(repository.attempt.activeDuration, const Duration(seconds: 7));
      expect(repository.attempt.outcome, PuzzleAttemptOutcome.passed);
      controller.refreshClock();
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ReaderBoard &&
              widget.positionLabel?.contains('e4.') == true,
        ),
        findsOneWidget,
      );
      expect(find.text('Continue to review'), findsNothing);
      await tester.ensureVisible(find.text('Explore position'));
      await tester.tap(find.text('Explore position'));
      await tester.pumpAndSettle();
      expect(find.text('Exploring from 1. e4'), findsOneWidget);
      explorationRepository.failWrites = true;
      await _playMoveOnBoard(tester, from: 'd7', to: 'd5');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Return to review'), findsOneWidget);
      expect(service.closeCalls, 0);
      expect(find.textContaining('Exploration not saved.'), findsOneWidget);
      explorationRepository.failWrites = false;
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Retry save'));
      await tester.tap(find.text('Retry save'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Solution line'), findsOneWidget);
      expect(service.closeCalls, 0);
      expect(explorationRepository.savedSessions, hasLength(1));
      expect(
        explorationRepository.savedSessions.single.origin.scopeId,
        '["block","source","revision-1"]',
      );
      expect(explorationRepository.savedSessions.single.moves, [
        'e2e4',
        'd7d5',
      ]);
      await _checkActionGeometry(tester, ['Finish cycle']);
      repository.failInteractionWrites = true;
      await tester.tap(find.byTooltip('Starting position'));
      await tester.pumpAndSettle();
      expect(find.text('Review position could not be saved.'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.text('Finish cycle')))
          .clearSnackBars();
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text('Finish cycle'),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Finish cycle'), findsOneWidget);
      expect(
        find.text('Review could not be saved. Retry to continue.'),
        findsOneWidget,
      );
      expect(controller.state.status, ActiveSessionStatus.active);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(service.closeCalls, 0);
      expect(find.text('Open session'), findsNothing);
      repository.failInteractionWrites = false;
      await tester.tap(find.byTooltip('Pause session'));
      await tester.pumpAndSettle();
      expect(controller.state.status, ActiveSessionStatus.paused);
      clock.elapsed += const Duration(seconds: 5);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('00:07'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Session active time')).value,
        '00:07',
      );
      expect(
        tester
            .getSemantics(
              find.bySemanticsLabel('Cycle progress, section, and active time'),
            )
            .value,
        contains('Cycle active time 00:07'),
      );
      expect(controller.state.session?.status, TrainingSessionStatus.paused);
      expect(
        tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
        isFalse,
      );
      await controller.whenIdle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(service.closeCalls, 1);
      expect(
        find.text('The session could not be saved or restored. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Open session'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Open session'), findsOneWidget);
      expect(service.closeCalls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
      controller.dispose();
    },
  );
}

Future<void> _playMoveOnBoard(
  WidgetTester tester, {
  required String from,
  required String to,
}) async {
  final board = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == 'Chessboard',
  );
  expect(board, findsOneWidget);
  final rect = tester.getRect(board);
  Offset squareCenter(String square) {
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square.substring(1));
    final row = 8 - rank;
    return Offset(
      rect.left + rect.width * (file + 0.5) / 8,
      rect.top + rect.height * (row + 0.5) / 8,
    );
  }

  await tester.tapAt(squareCenter(from));
  await tester.pump(const Duration(milliseconds: 80));
  await tester.tapAt(squareCenter(to));
  await tester.pumpAndSettle();
}

Future<void> _checkActionGeometry(
  WidgetTester tester,
  List<String> labels,
) async {
  for (final size in [
    const Size(360, 640),
    const Size(412, 915),
    const Size(640, 360),
  ]) {
    for (final scale in [1.0, 2.0]) {
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Cycle layout at $size with text scale $scale',
      );
      for (final label in labels) {
        final finder = find.text(label).evaluate().isNotEmpty
            ? find.text(label)
            : find.byTooltip(label);
        final rect = tester.getRect(finder);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
    }
  }
  tester.view.physicalSize = const Size(320, 800);
  tester.platformDispatcher.textScaleFactorTestValue = 1;
  await tester.pumpAndSettle();
}

final class _TestClock implements AppClock {
  Duration elapsed = Duration.zero;
  @override
  DateTime get utcNow => _startedAt.add(elapsed);
  @override
  Duration get monotonicElapsed => elapsed;
}

final class _Ids implements IdGenerator {
  int count = 0;
  @override
  String generateId() => 'id-${count++}';
}

final class _ContentRepository implements ChessContentRepository {
  _ContentRepository(this.content);
  final ChessContent content;
  @override
  Future<ChessContent?> getById(String id) async => content;
}

final class _ExplorationRepository implements ExplorationRepository {
  final Map<String, ExplorationSession> _sessions = {};
  final List<ExplorationSession> savedSessions = [];
  bool failWrites = false;

  @override
  Future<ExplorationSession?> load(ExplorationOrigin origin) async =>
      _sessions[origin.identityKey];

  @override
  Future<void> save(ExplorationSession session) async {
    if (failWrites) throw StateError('Draft save failed.');
    _sessions[session.origin.identityKey] = session;
    savedSessions.add(session);
  }
}

final class _TrainingRepository
    implements TrainingRepository, PuzzleInteractionRepository {
  _TrainingRepository({required this.attempt, required this.item});
  PuzzleAttempt attempt;
  final TrainingSetItem item;
  bool failInteractionWrites = false;
  Map<String, dynamic>? interaction;
  @override
  Future<Map<String, dynamic>?> loadPuzzleInteraction(String attemptId) async =>
      interaction;
  @override
  Future<void> savePuzzleInteraction(
    String attemptId,
    Map<String, dynamic> value,
  ) async {
    if (failInteractionWrites) throw StateError('Interaction save failed');
    interaction = Map.of(value);
  }

  @override
  Future<List<TrainingSession>> listSessions(String cycleId) async => [];
  @override
  Future<ProgressAggregate> aggregateForCycle(String cycleId) async =>
      ProgressAggregate(
        passedCount: 0,
        wrongMoveOutcomeCount: 0,
        revealedCount: 0,
        skippedCount: 0,
        timedOutCount: 0,
        abandonedCount: 0,
        wrongMoveCount: 0,
        hintCount: 0,
        attemptActiveDurations: const [],
      );
  @override
  Future<List<PuzzleAttempt>> listAttempts(String cycleId) async => [attempt];
  @override
  Future<PuzzleAttempt?> getAttempt(String id) async => attempt;
  final List<AttemptMove> moves = [];
  @override
  Future<List<AttemptMove>> listAttemptMoves(String attemptId) async => moves;
  @override
  Future<List<TimingSegment>> listTimingSegments(String attemptId) async => [];
  void saveAttempt(PuzzleAttempt value) => attempt = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SessionService implements TrainingSessionService {
  _SessionService({
    required this.cycle,
    required this.session,
    required this.item,
    required this.repository,
  });
  final Cycle cycle;
  final TrainingSession session;
  final TrainingSetItem item;
  late TrainingSetItem? nextItem = item;
  final _TrainingRepository repository;
  int pauseCalls = 0;
  int closeCalls = 0;
  int completeNonPuzzleCalls = 0;
  int failCloseCount = 0;
  final List<Duration> segmentDurations = [];
  @override
  Future<Cycle> startOrResumeCycle({
    required String trainingSetId,
    required DateTime startedAt,
  }) async => cycle;
  @override
  Future<TrainingSession> openSession({
    required String cycleId,
    required DateTime startedAt,
    required DateTime studyDay,
  }) async => session;
  @override
  Future<TrainingSetItem?> selectNextItem({required String cycleId}) async =>
      nextItem;
  @override
  Future<CycleItemCompletion> completeNonPuzzleItem({
    required String cycleId,
    required String trainingSetItemId,
    required DateTime completedAt,
  }) async {
    completeNonPuzzleCalls++;
    nextItem = null;
    return CycleItemCompletion(
      cycleId: cycleId,
      trainingSetItemId: trainingSetItemId,
      completedAt: completedAt,
    );
  }

  @override
  Future<Cycle> completeCycle({
    required String cycleId,
    required DateTime completedAt,
  }) async => Cycle(
    id: cycle.id,
    trainingSetId: cycle.trainingSetId,
    status: CycleStatus.completed,
    startedAt: cycle.startedAt,
    completedAt: completedAt,
    createdAt: cycle.createdAt,
  );

  @override
  Future<TrainingSession> pauseSession({
    required String sessionId,
    required DateTime pausedAt,
    required Duration? activeAttemptSegmentDuration,
  }) async {
    pauseCalls++;
    final duration = activeAttemptSegmentDuration ?? Duration.zero;
    segmentDurations.add(duration);
    if (repository.attempt.outcome == null) {
      repository.saveAttempt(
        _copyAttempt(
          repository.attempt,
          status: PuzzleAttemptStatus.paused,
          activeDuration: repository.attempt.activeDuration + duration,
        ),
      );
    }
    return TrainingSession(
      id: session.id,
      cycleId: session.cycleId,
      status: TrainingSessionStatus.paused,
      startedAt: session.startedAt,
      studyDay: session.studyDay,
    );
  }

  @override
  Future<TrainingSessionResumeResult> resumeSession({
    required String sessionId,
    required DateTime resumedAt,
  }) async {
    repository.saveAttempt(
      _copyAttempt(repository.attempt, status: PuzzleAttemptStatus.active),
    );
    return TrainingSessionResumeResult(
      session: TrainingSession(
        id: session.id,
        cycleId: session.cycleId,
        status: TrainingSessionStatus.active,
        startedAt: session.startedAt,
        studyDay: session.studyDay,
      ),
      resumedAttemptSegment: TimingSegment(
        id: 'resumed-segment',
        attemptId: repository.attempt.id,
        sessionId: session.id,
        startedAt: resumedAt,
      ),
    );
  }

  @override
  Future<TrainingSession> closeSession({
    required String sessionId,
    required DateTime endedAt,
  }) async {
    closeCalls++;
    if (failCloseCount > 0) {
      failCloseCount--;
      throw StateError('Session close failed.');
    }
    return TrainingSession(
      id: sessionId,
      cycleId: session.cycleId,
      status: TrainingSessionStatus.closed,
      startedAt: session.startedAt,
      endedAt: endedAt,
      studyDay: session.studyDay,
    );
  }

  @override
  Future<PuzzleAttempt> recordSubmittedMove({
    required AttemptMove move,
    required PuzzleAttempt updatedAttempt,
    Duration activeSegmentDuration = Duration.zero,
  }) async {
    segmentDurations.add(activeSegmentDuration);
    repository.moves.add(move);
    final saved = _copyAttempt(
      updatedAttempt,
      activeDuration: repository.attempt.activeDuration + activeSegmentDuration,
    );
    repository.saveAttempt(saved);
    return saved;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PuzzleAttempt _copyAttempt(
  PuzzleAttempt attempt, {
  PuzzleAttemptStatus? status,
  Duration? activeDuration,
  PuzzleAttemptOutcome? outcome,
  DateTime? completedAt,
  PuzzleAttemptFailureReason? failureReason,
}) => PuzzleAttempt(
  id: attempt.id,
  blockId: attempt.blockId,
  cycleId: attempt.cycleId,
  sessionId: attempt.sessionId,
  status: status ?? attempt.status,
  startedAt: attempt.startedAt,
  completedAt: completedAt ?? attempt.completedAt,
  activeDuration: activeDuration ?? attempt.activeDuration,
  outcome: outcome ?? attempt.outcome,
  failureReason: failureReason ?? attempt.failureReason,
  wrongMoveCount: attempt.wrongMoveCount,
  hintCount: attempt.hintCount,
  revealed: attempt.revealed,
);
