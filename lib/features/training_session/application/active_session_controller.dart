import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/time/app_clock.dart';
import '../../../core/errors/app_failure.dart';
import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/chess_content_repository.dart';
import '../../../domain/chess_content/content_type.dart';
import '../../../domain/training/cycle.dart';
import '../../../domain/training/lifecycle_status.dart';
import '../../../domain/training/progress_aggregate.dart';
import '../../../domain/training/puzzle_attempt.dart';
import '../../../domain/training/puzzle_completion_policy.dart';
import '../../../domain/training/puzzle_interaction_repository.dart';
import '../../../domain/training/attempt_move.dart';
import '../../../domain/training/training_repository.dart';
import '../../../domain/training/training_session.dart';
import '../../../domain/training/training_session_service.dart';
import '../../../domain/training/training_set.dart';
import '../../../domain/training/training_set_item.dart';
import '../../puzzle_solver/application/puzzle_solver_controller.dart';

enum ActiveSessionStatus {
  loading,
  active,
  paused,
  completed,
  recoverableFailure,
}

final class ActiveSessionState {
  const ActiveSessionState({
    this.status = ActiveSessionStatus.loading,
    this.cycle,
    this.session,
    this.activeItem,
    this.content,
    this.attempt,
    this.progress,
    this.sessionActiveTime = Duration.zero,
    this.cycleActiveTime = Duration.zero,
    this.errorMessage,
  });

  final ActiveSessionStatus status;
  final Cycle? cycle;
  final TrainingSession? session;
  final TrainingSetItem? activeItem;
  final ChessContent? content;
  final PuzzleAttempt? attempt;
  final ProgressAggregate? progress;
  final Duration sessionActiveTime;
  final Duration cycleActiveTime;
  final String? errorMessage;
}

/// Drives one cycle across bounded sessions, including safe lifecycle pauses.
final class ActiveSessionController extends ChangeNotifier
    with WidgetsBindingObserver {
  ActiveSessionController({
    required this.trainingSet,
    required this.sessionService,
    required this.repository,
    required this.contentRepository,
    required this.clock,
    required this.evaluatorFactory,
    this.completionPolicy = PuzzleCompletionPolicy.keyMoves,
  });

  TrainingSet trainingSet;
  final PuzzleCompletionPolicy completionPolicy;
  PuzzleCompletionPolicy _effectivePolicy = PuzzleCompletionPolicy.allMoves;
  final TrainingSessionService sessionService;
  final TrainingRepository repository;
  final ChessContentRepository contentRepository;
  final AppClock clock;
  final PuzzleEvaluatorFactory evaluatorFactory;

  ActiveSessionState _state = const ActiveSessionState();
  ActiveSessionState get state => _state;
  Duration _sessionAccumulated = Duration.zero;
  Duration _cycleBaseTime = Duration.zero;
  Duration? _attemptStartedMonotonic;
  Duration? _nonPuzzleStartedMonotonic;
  Duration _localNonPuzzleCycleTime = Duration.zero;
  bool _started = false;
  final Set<PuzzleSolverController> _puzzleControllers = {};
  bool _transitioning = false;
  Completer<void>? _transitionDone;

  /// Completes after the current serialized session write finishes.
  Future<void> whenIdle() async {
    while (_transitioning) {
      final pending = _transitionDone;
      if (pending != null) await pending.future;
    }
  }

  PuzzleSolverController createPuzzleController() {
    final controller = PuzzleSolverController(
      repository: repository,
      evaluatorFactory: evaluatorFactory,
      completionPolicy: _effectivePolicy,
      moveRecorder: _recordMove,
      attemptFinalizer: _finalizeAttempt,
      activeSegmentDurationProvider: _activeAttemptDuration,
    );
    _puzzleControllers.add(controller);
    return controller;
  }

  Future<PuzzleAttempt> _recordMove({
    required AttemptMove move,
    required PuzzleAttempt updatedAttempt,
    required Duration activeSegmentDuration,
  }) async {
    final attempt = await sessionService.recordSubmittedMove(
      move: move,
      updatedAttempt: updatedAttempt,
      activeSegmentDuration: activeSegmentDuration,
    );
    if (attempt.outcome != null) {
      _sessionAccumulated += activeSegmentDuration;
      _cycleBaseTime += activeSegmentDuration;
      _attemptStartedMonotonic = null;
    }
    return attempt;
  }

  Future<PuzzleAttempt> _finalizeAttempt({
    required String attemptId,
    required PuzzleAttemptOutcome outcome,
    required DateTime completedAt,
    required Duration activeSegmentDuration,
    PuzzleAttemptFailureReason? failureReason,
    bool revealed = false,
  }) async {
    final attempt = await sessionService.finalizeAttempt(
      attemptId: attemptId,
      outcome: outcome,
      completedAt: completedAt,
      activeSegmentDuration: activeSegmentDuration,
      failureReason: failureReason,
      revealed: revealed,
    );
    _sessionAccumulated += activeSegmentDuration;
    _cycleBaseTime += activeSegmentDuration;
    _attemptStartedMonotonic = null;
    return attempt;
  }

  Duration _activeAttemptDuration(String attemptId) {
    if (_state.attempt?.id != attemptId || _attemptStartedMonotonic == null) {
      return Duration.zero;
    }
    return clock.monotonicElapsed - _attemptStartedMonotonic!;
  }

  Future<void> start() async {
    if (_started && _state.status != ActiveSessionStatus.recoverableFailure) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    await _run(() async {
      final cycle = await sessionService.startOrResumeCycle(
        trainingSetId: trainingSet.id,
        startedAt: clock.utcNow,
      );
      final snapshots = repository;
      if (snapshots is CycleSnapshotRepository) {
        final snapshot = await (snapshots as CycleSnapshotRepository)
            .getCycleSet(cycle.id);
        if (snapshot != null) trainingSet = snapshot;
        final savedPolicy = await (snapshots as CycleSnapshotRepository)
            .getCyclePolicy(cycle.id);
        // A cycle created before snapshots retains historical All Moves scoring.
        _effectivePolicy = savedPolicy == null
            ? (snapshot == null
                  ? PuzzleCompletionPolicy.allMoves
                  : completionPolicy)
            : PuzzleCompletionPolicy.values.byName(savedPolicy);
        if (savedPolicy == null) {
          await (snapshots as CycleSnapshotRepository).setCyclePolicy(
            cycle.id,
            _effectivePolicy.name,
          );
        }
      } else {
        _effectivePolicy = completionPolicy;
      }
      final sessions = await repository.listSessions(cycle.id);
      final interrupted = sessions
          .where((s) => s.status == TrainingSessionStatus.active)
          .toList();
      if (interrupted.isNotEmpty) {
        await sessionService.recoverSession(
          sessionId: interrupted.last.id,
          recoveredAt: clock.utcNow,
        );
      }
      TrainingSession session;
      final paused = sessions
          .where((s) => s.status == TrainingSessionStatus.paused)
          .toList();
      if (paused.isNotEmpty && interrupted.isEmpty) {
        await sessionService.closeSession(
          sessionId: paused.last.id,
          endedAt: clock.utcNow,
        );
      }
      session = await sessionService.openSession(
        cycleId: cycle.id,
        startedAt: clock.utcNow,
        studyDay: _studyDay(clock.utcNow),
      );
      await _loadNext(cycle, session);
    });
  }

  Future<void> continueNonPuzzle() async {
    final item = _state.activeItem;
    final cycle = _state.cycle;
    final session = _state.session;
    if (item == null ||
        cycle == null ||
        session == null ||
        item.contentType == ContentType.puzzle) {
      return;
    }
    await _run(() async {
      final elapsed = _nonPuzzleStartedMonotonic == null
          ? Duration.zero
          : clock.monotonicElapsed - _nonPuzzleStartedMonotonic!;
      await sessionService.completeNonPuzzleItem(
        cycleId: cycle.id,
        trainingSetItemId: item.id,
        completedAt: clock.utcNow,
      );
      _sessionAccumulated += elapsed;
      _cycleBaseTime += elapsed;
      _localNonPuzzleCycleTime += elapsed;
      _nonPuzzleStartedMonotonic = null;
      await _loadNext(cycle, session);
    });
  }

  Future<void> advance() async {
    final cycle = _state.cycle;
    final session = _state.session;
    if (cycle == null ||
        session == null ||
        session.status != TrainingSessionStatus.active) {
      return;
    }
    await _run(() async {
      final snapshots = repository;
      if (snapshots is CycleSnapshotRepository) {
        await (snapshots as CycleSnapshotRepository).setCycleCursor(
          cycle.id,
          null,
        );
      }
      await _loadNext(cycle, session);
    });
  }

  Future<void> pause() async {
    await whenIdle();
    await Future.wait([
      for (final controller in _puzzleControllers) controller.whenIdle(),
    ]);
    final session = _state.session;
    if (session == null || session.status != TrainingSessionStatus.active) {
      return;
    }
    await _run(_pauseActiveSession);
  }

  Future<TrainingSession> _pauseActiveSession() async {
    final session = _state.session!;
    final attempt = _state.attempt;
    final elapsed = attempt != null && _attemptStartedMonotonic != null
        ? clock.monotonicElapsed - _attemptStartedMonotonic!
        : null;
    final nonPuzzleElapsed = _nonPuzzleStartedMonotonic == null
        ? Duration.zero
        : clock.monotonicElapsed - _nonPuzzleStartedMonotonic!;
    final paused = await sessionService.pauseSession(
      sessionId: session.id,
      pausedAt: clock.utcNow,
      activeAttemptSegmentDuration: elapsed,
    );
    final updatedAttempt = attempt == null
        ? null
        : await repository.getAttempt(attempt.id);
    if (elapsed != null) {
      _sessionAccumulated += elapsed;
      _cycleBaseTime += elapsed;
    }
    _sessionAccumulated += nonPuzzleElapsed;
    _cycleBaseTime += nonPuzzleElapsed;
    _localNonPuzzleCycleTime += nonPuzzleElapsed;
    _attemptStartedMonotonic = null;
    _nonPuzzleStartedMonotonic = null;
    _publish(
      ActiveSessionState(
        status: ActiveSessionStatus.paused,
        cycle: _state.cycle,
        session: paused,
        activeItem: _state.activeItem,
        content: _state.content,
        attempt: updatedAttempt ?? _state.attempt,
        progress: _state.progress,
        sessionActiveTime: _sessionAccumulated,
        cycleActiveTime: _cycleBaseTime,
      ),
    );
    return paused;
  }

  Future<void> resume() async {
    final session = _state.session;
    if (session == null || session.status != TrainingSessionStatus.paused) {
      return;
    }
    await _run(() async {
      final result = await sessionService.resumeSession(
        sessionId: session.id,
        resumedAt: clock.utcNow,
      );
      if (result.resumedAttemptSegment != null) {
        _attemptStartedMonotonic = clock.monotonicElapsed;
      } else if (_state.activeItem?.contentType != ContentType.puzzle) {
        _nonPuzzleStartedMonotonic = clock.monotonicElapsed;
      }
      final updatedAttempt = _state.attempt == null
          ? null
          : await repository.getAttempt(_state.attempt!.id);
      _publish(
        ActiveSessionState(
          status: ActiveSessionStatus.active,
          cycle: _state.cycle,
          session: result.session,
          activeItem: _state.activeItem,
          content: _state.content,
          attempt: updatedAttempt ?? _state.attempt,
          progress: _state.progress,
          sessionActiveTime: _sessionAccumulated,
          cycleActiveTime: _cycleBaseTime,
        ),
      );
    });
  }

  Future<void> close() async {
    final session = _state.session;
    if (session == null ||
        (session.status != TrainingSessionStatus.active &&
            session.status != TrainingSessionStatus.paused)) {
      return;
    }
    await _run(() async {
      final paused = session.status == TrainingSessionStatus.active
          ? await _pauseActiveSession()
          : session;
      final closed = await sessionService.closeSession(
        sessionId: paused.id,
        endedAt: clock.utcNow,
      );
      _publish(
        ActiveSessionState(
          status: ActiveSessionStatus.paused,
          cycle: _state.cycle,
          session: closed,
          progress: _state.progress,
          cycleActiveTime: _cycleBaseTime,
          sessionActiveTime: _state.sessionActiveTime,
        ),
      );
    });
  }

  void refreshClock() {
    if (_state.status != ActiveSessionStatus.active) return;
    _publish(
      ActiveSessionState(
        status: _state.status,
        cycle: _state.cycle,
        session: _state.session,
        activeItem: _state.activeItem,
        content: _state.content,
        attempt: _state.attempt,
        progress: _state.progress,
        sessionActiveTime: _currentSessionElapsed,
        cycleActiveTime: _currentCycleElapsed,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        _state.status == ActiveSessionStatus.active) {
      unawaited(pause());
    }
  }

  Future<void> _loadNext(Cycle cycle, TrainingSession session) async {
    final snapshots = repository;
    PuzzleAttempt? cursorAttempt;
    if (snapshots is CycleSnapshotRepository) {
      final cursor = await (snapshots as CycleSnapshotRepository)
          .getCycleCursor(cycle.id);
      if (cursor != null) cursorAttempt = await repository.getAttempt(cursor);
    }
    final cursorItem = cursorAttempt == null
        ? null
        : trainingSet.items
              .where((item) => item.blockId == cursorAttempt!.blockId)
              .firstOrNull;
    final item =
        cursorItem ?? await sessionService.selectNextItem(cycleId: cycle.id);
    final progress = await repository.aggregateForCycle(cycle.id);
    final allAttempts = await repository.listAttempts(cycle.id);
    final cycleTime =
        allAttempts.fold<Duration>(
          Duration.zero,
          (sum, attempt) => sum + attempt.activeDuration,
        ) +
        progress.nonPuzzleActiveDuration +
        _localNonPuzzleCycleTime;
    _cycleBaseTime = cycleTime;
    if (item == null) {
      final completed = await sessionService.completeCycle(
        cycleId: cycle.id,
        completedAt: clock.utcNow,
      );
      final closed = await sessionService.closeSession(
        sessionId: session.id,
        endedAt: clock.utcNow,
      );
      _publish(
        ActiveSessionState(
          status: ActiveSessionStatus.completed,
          cycle: completed,
          session: closed,
          progress: progress,
          sessionActiveTime: _sessionAccumulated,
          cycleActiveTime: cycleTime,
        ),
      );
      return;
    }
    final segmentTime = await _sessionSegmentDuration(allAttempts, session.id);
    if (segmentTime > _sessionAccumulated) _sessionAccumulated = segmentTime;
    final content = await contentRepository.getById(item.blockId);
    if (content == null) {
      throw StateError('Selected training content is no longer available.');
    }
    PuzzleAttempt? attempt;
    if (item.contentType == ContentType.puzzle) {
      _nonPuzzleStartedMonotonic = null;
      final attempts = await repository.listAttempts(cycle.id);
      attempt =
          cursorAttempt ??
          attempts
              .where((a) => a.blockId == item.blockId && a.outcome == null)
              .firstOrNull;
      if (attempt == null) {
        attempt = await sessionService.startAttempt(
          cycleId: cycle.id,
          sessionId: session.id,
          trainingSetItemId: item.id,
          startedAt: clock.utcNow,
        );
        attempt = await repository.getAttempt(attempt.id);
        _attemptStartedMonotonic = clock.monotonicElapsed;
      } else if (attempt.status == PuzzleAttemptStatus.paused &&
          session.status == TrainingSessionStatus.active) {
        await sessionService.resumeAttempt(
          attemptId: attempt.id,
          resumedAt: clock.utcNow,
        );
        attempt = await repository.getAttempt(attempt.id);
        _attemptStartedMonotonic = clock.monotonicElapsed;
      } else if (attempt.status == PuzzleAttemptStatus.active &&
          _attemptStartedMonotonic == null) {
        _attemptStartedMonotonic = clock.monotonicElapsed;
      }
    } else {
      _attemptStartedMonotonic = null;
      _nonPuzzleStartedMonotonic ??= clock.monotonicElapsed;
    }
    if (snapshots is CycleSnapshotRepository && attempt != null) {
      await (snapshots as CycleSnapshotRepository).setCycleCursor(
        cycle.id,
        attempt.id,
      );
    }
    _publish(
      ActiveSessionState(
        status: ActiveSessionStatus.active,
        cycle: cycle,
        session: session,
        activeItem: item,
        content: content,
        attempt: attempt,
        progress: progress,
        sessionActiveTime: _currentSessionElapsed,
        cycleActiveTime: cycleTime,
      ),
    );
  }

  Duration get _currentSessionElapsed =>
      _sessionAccumulated +
      (_attemptStartedMonotonic == null
          ? Duration.zero
          : clock.monotonicElapsed - _attemptStartedMonotonic!) +
      (_nonPuzzleStartedMonotonic == null
          ? Duration.zero
          : clock.monotonicElapsed - _nonPuzzleStartedMonotonic!);

  Duration get _currentCycleElapsed =>
      _cycleBaseTime +
      (_attemptStartedMonotonic == null
          ? Duration.zero
          : clock.monotonicElapsed - _attemptStartedMonotonic!) +
      (_nonPuzzleStartedMonotonic == null
          ? Duration.zero
          : clock.monotonicElapsed - _nonPuzzleStartedMonotonic!);

  Future<Duration> _sessionSegmentDuration(
    List<PuzzleAttempt> attempts,
    String sessionId,
  ) async {
    var total = Duration.zero;
    for (final attempt in attempts) {
      for (final segment in await repository.listTimingSegments(attempt.id)) {
        if (segment.sessionId == sessionId && segment.activeDuration != null) {
          total += segment.activeDuration!;
        }
      }
    }
    return total;
  }

  DateTime _studyDay(DateTime value) {
    final local = value.toLocal();
    return DateTime.utc(local.year, local.month, local.day);
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_transitioning) return;
    _transitioning = true;
    final transitionDone = Completer<void>();
    _transitionDone = transitionDone;
    try {
      await work();
    } catch (error) {
      _publish(
        ActiveSessionState(
          status: ActiveSessionStatus.recoverableFailure,
          cycle: _state.cycle,
          session: _state.session,
          activeItem: _state.activeItem,
          content: _state.content,
          attempt: _state.attempt,
          progress: _state.progress,
          sessionActiveTime: _currentSessionElapsed,
          cycleActiveTime: _state.cycleActiveTime,
          errorMessage: error is AppFailure
              ? error.message
              : 'The session could not be saved or restored. Try again.',
        ),
      );
    } finally {
      _transitioning = false;
      if (identical(_transitionDone, transitionDone)) {
        _transitionDone = null;
      }
      transitionDone.complete();
    }
  }

  void _publish(ActiveSessionState value) {
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in _puzzleControllers) {
      controller.dispose();
    }
    _puzzleControllers.clear();
    super.dispose();
  }
}
