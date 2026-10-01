import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/time/app_clock.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/domain/training/attempt_move.dart';
import 'package:pgntrainingreader/domain/training/authored_line_puzzle_evaluator.dart';
import 'package:pgntrainingreader/domain/training/cycle.dart';
import 'package:pgntrainingreader/domain/training/lifecycle_status.dart';
import 'package:pgntrainingreader/domain/training/progress_aggregate.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/domain/training/timing_segment.dart';
import 'package:pgntrainingreader/domain/training/training_repository.dart';
import 'package:pgntrainingreader/domain/training/training_session.dart';
import 'package:pgntrainingreader/domain/training/training_session_service.dart';
import 'package:pgntrainingreader/domain/training/training_set.dart';
import 'package:pgntrainingreader/domain/training/training_set_item.dart';
import 'package:pgntrainingreader/features/training_session/application/active_session_controller.dart';
import 'package:pgntrainingreader/features/training_session/presentation/active_session_page.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_solving_view.dart';

final _startedAt = DateTime.utc(2026, 9, 28, 12);
const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  testWidgets(
    'session shows the existing puzzle solver and pauses on app inactivity',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
                      builder: (_) => ActiveSessionPage(controller: controller),
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
      expect(find.text('White to move'), findsOneWidget);
      expect(find.byType(PuzzleSolvingView), findsOneWidget);

      clock.elapsed += const Duration(seconds: 3);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(service.pauseCalls, 1);
      expect(service.segmentDurations, [const Duration(seconds: 3)]);
      expect(
        find.text('Session paused. Resume when you are ready.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume'));
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
      expect(find.text('Selected move: e4'), findsOneWidget);
      expect(find.text('Continue to review'), findsNothing);
      await tester.tap(find.byTooltip('Pause session'));
      await tester.pumpAndSettle();
      expect(controller.state.status, ActiveSessionStatus.paused);
      clock.elapsed += const Duration(seconds: 5);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Session 00:07'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Session active time')).value,
        '00:07',
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Cycle active time')).value,
        '00:07',
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

final class _TrainingRepository implements TrainingRepository {
  _TrainingRepository({required this.attempt, required this.item});
  PuzzleAttempt attempt;
  final TrainingSetItem item;
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
  final _TrainingRepository repository;
  int pauseCalls = 0;
  int closeCalls = 0;
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
      item;
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
