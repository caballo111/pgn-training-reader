import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/analysis/analysis_engine.dart';
import '../../../domain/analysis/exploration_repository.dart';
import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/content_type.dart';
import '../../../domain/training/puzzle_attempt.dart';
import '../../../domain/training/training_set_item.dart';
import '../../../features/game_reader/presentation/game_reader_page.dart';
import '../../../features/puzzle_solver/application/puzzle_presentation_state.dart';
import '../../../features/puzzle_solver/application/puzzle_solver_controller.dart';
import '../../../features/puzzle_solver/presentation/puzzle_solving_view.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../../../features/puzzle_solver/presentation/puzzle_solution_review_view.dart';
import '../application/active_session_controller.dart';
import '../../../shared/presentation/study_mode.dart';

/// Shows a cycle's current indexed content and its explicit lifecycle controls.
final class ActiveSessionPage extends StatefulWidget {
  const ActiveSessionPage({
    super.key,
    required this.controller,
    this.explorationRepository,
    this.analysisEngineFactory,
    this.explorationScopeIdResolver,
  });

  final ActiveSessionController controller;
  final ExplorationRepository? explorationRepository;
  final AnalysisEngineFactory? analysisEngineFactory;
  final Future<String?> Function(TrainingSetItem item)?
  explorationScopeIdResolver;

  @override
  State<ActiveSessionPage> createState() => _ActiveSessionPageState();
}

final class _ActiveSessionPageState extends State<ActiveSessionPage> {
  Timer? _ticker;
  PuzzlePresentationState? _review;
  final Map<String, PuzzleSolverController> _puzzleControllers = {};
  final GlobalKey<PuzzleSolutionReviewViewState> _reviewKey = GlobalKey();
  final GlobalKey<GameReaderPageState> _readerKey = GlobalKey();
  String? _scopeItemId;
  Future<String?>? _scopeFuture;
  bool _leaving = false;
  bool _allowPop = false;
  bool _advancePending = false;
  bool _backPending = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.start());
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => widget.controller.refreshClock(),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final controller in _puzzleControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_isExploring) _handleBack();
    },
    child: IgnorePointer(
      ignoring: _leaving || _advancePending || _backPending,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final state = widget.controller.state;
          final total = widget.controller.trainingSet.items.length;
          if (state.status == ActiveSessionStatus.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (state.status == ActiveSessionStatus.recoverableFailure) {
            return Scaffold(
              appBar: AppBar(
                leading: _backButton,
                title: const Text('Training session'),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync_problem_outlined, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        state.errorMessage ??
                            'The session could not be restored.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _retrySession,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (state.status == ActiveSessionStatus.completed) {
            return Scaffold(
              appBar: AppBar(title: const Text('Cycle complete')),
              body: const Center(
                child: Text('You completed every item in this cycle.'),
              ),
            );
          }
          final progress = state.progress;
          final attempted =
              (progress?.passedCount ?? 0) +
              (progress?.wrongMoveOutcomeCount ?? 0) +
              (progress?.revealedCount ?? 0) +
              (progress?.skippedCount ?? 0) +
              (progress?.timedOutCount ?? 0) +
              (progress?.abandonedCount ?? 0) +
              (progress?.completedNonPuzzleItemCount ?? 0);
          final current = state.activeItem == null
              ? attempted
              : state.activeItem!.position + 1;
          final section = state.content?.headers['X-Section']?.trim();
          final mode = _review != null
              ? StudyMode.review
              : state.activeItem?.contentType == ContentType.puzzle
              ? StudyMode.solving
              : StudyMode.reading;
          final subtitle = [
            'Cycle training',
            'Item ${current.clamp(0, total)} of $total',
            if (section?.isNotEmpty == true) section!,
          ].join(' · ');
          final sessionTime = _format(state.sessionActiveTime);
          final cycleTime = _format(state.cycleActiveTime);
          final modeLabel = state.status == ActiveSessionStatus.paused
              ? '${mode.label} · paused'
              : mode.label;
          final accessibleMetadata = [
            widget.controller.trainingSet.name,
            subtitle,
            modeLabel,
            'Session active time $sessionTime',
            'Cycle active time $cycleTime',
          ].join('. ');
          return Scaffold(
            appBar: AppBar(
              leading: _backButton,
              toolbarHeight: MediaQuery.textScalerOf(context).scale(1) >= 1.5
                  ? 80
                  : null,
              title: Semantics(
                container: true,
                explicitChildNodes: true,
                header: true,
                label: widget.controller.trainingSet.name,
                child: Tooltip(
                  message: accessibleMetadata,
                  excludeFromSemantics: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ExcludeSemantics(
                              child: Text(
                                widget.controller.trainingSet.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 2,
                            fit: FlexFit.loose,
                            child: Semantics(
                              label: 'Study mode',
                              value: modeLabel,
                              excludeSemantics: true,
                              child: Text(
                                modeLabel,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Semantics(
                            label: 'Session active time',
                            value: sessionTime,
                            child: ExcludeSemantics(
                              child: Text(
                                sessionTime,
                                maxLines: 1,
                                softWrap: false,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Tooltip(
                        message: 'Cycle active time $cycleTime',
                        excludeFromSemantics: true,
                        child: Semantics(
                          label: 'Cycle progress, section, and active time',
                          value: '$subtitle. Cycle active time $cycleTime',
                          excludeSemantics: true,
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (state.status == ActiveSessionStatus.active)
                  IconButton(
                    tooltip: 'Pause session',
                    onPressed: _pauseSession,
                    icon: const Icon(Icons.pause_circle_outline),
                  ),
                if (state.status == ActiveSessionStatus.paused)
                  IconButton(
                    tooltip: 'Resume session',
                    onPressed: widget.controller.resume,
                    icon: const Icon(Icons.play_circle_outline),
                  ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: _review != null
                      ? _reviewSurface(state, current, total)
                      : _content(state, current, total),
                ),
                if (state.status == ActiveSessionStatus.active &&
                    state.activeItem != null &&
                    state.activeItem!.contentType != ContentType.puzzle)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: FilledButton(
                        onPressed: _completeNonPuzzleItem,
                        child: const Text('Complete item and continue'),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _content(ActiveSessionState state, int current, int total) {
    final content = state.content;
    final item = state.activeItem;
    if (content == null) {
      return const Center(child: Text('No current content.'));
    }
    if (item?.contentType == ContentType.puzzle && state.attempt != null) {
      final puzzleController = _puzzleControllers.putIfAbsent(
        state.attempt!.id,
        widget.controller.createPuzzleController,
      );
      return IgnorePointer(
        ignoring: state.status != ActiveSessionStatus.active,
        child: _ActivePuzzleSurface(
          key: ValueKey(state.attempt!.id),
          controller: puzzleController,
          sessionController: widget.controller,
          content: content,
          attempt: state.attempt!,
          currentItem: current,
          totalItems: total,
          onReview: (review) => setState(() => _review = review),
        ),
      );
    }
    return IgnorePointer(
      ignoring: state.status != ActiveSessionStatus.active,
      child: FutureBuilder<String?>(
        future: item == null ? Future<String?>.value() : _scopeForItem(item),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final scopeId = snapshot.data;
          return GameReaderPage(
            key: _readerKey,
            content: content,
            explorationScopeId: scopeId,
            explorationRepository: scopeId == null
                ? null
                : widget.explorationRepository,
            analysisEngineFactory: widget.analysisEngineFactory,
          );
        },
      ),
    );
  }

  Widget _reviewSurface(ActiveSessionState state, int current, int total) {
    final item = state.activeItem;
    final presentation = _review;
    if (item == null || presentation == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<String?>(
      future: _scopeForItem(item),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final scopeId = snapshot.data;
        return PuzzleSolutionReviewView(
          key: _reviewKey,
          presentation: presentation,
          initialPath: _puzzleControllers[state.attempt?.id]?.reviewPath,
          onPathChanged: (path) => _saveReviewPath(state.attempt?.id, path),
          initialOrientation:
              _puzzleControllers[state.attempt?.id]?.reviewOrientation,
          onOrientationChanged: (orientation) =>
              _saveReviewOrientation(state.attempt?.id, orientation),
          nextLabel: current >= total ? 'Finish cycle' : 'Next exercise',
          onNext: _nextFromReview,
          canAdvance:
              state.status == ActiveSessionStatus.active && !_advancePending,
          isFinalExercise: current >= total,
          explorationScopeId: scopeId,
          explorationRepository: scopeId == null
              ? null
              : widget.explorationRepository,
          analysisEngineFactory: widget.analysisEngineFactory,
        );
      },
    );
  }

  Future<String?> _scopeForItem(TrainingSetItem item) {
    if (_scopeItemId != item.id || _scopeFuture == null) {
      _scopeItemId = item.id;
      final resolver = widget.explorationScopeIdResolver;
      _scopeFuture = resolver == null
          ? Future<String?>.value()
          : Future<String?>.sync(() => resolver(item))
                .catchError((Object _) => null);
    }
    return _scopeFuture!;
  }

  Future<void> _saveReviewPath(String? attemptId, List<int> path) async {
    try {
      await _puzzleControllers[attemptId]?.setReviewPath(path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Review position could not be saved.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _saveReviewPath(attemptId, path),
            ),
          ),
        );
      }
    }
  }

  Widget get _backButton => IconButton(
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onPressed: _handleBack,
    icon: const BackButtonIcon(),
  );

  bool get _isExploring =>
      _reviewKey.currentState?.isExploring == true ||
      _readerKey.currentState?.isExploring == true;

  Future<void> _saveReviewOrientation(
    String? attemptId,
    PuzzleSide orientation,
  ) async {
    try {
      await _puzzleControllers[attemptId]?.setReviewOrientation(orientation);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Review orientation could not be saved.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _saveReviewOrientation(attemptId, orientation),
            ),
          ),
        );
      }
    }
  }

  Future<void> _closeAndPop() async {
    if (_leaving) return;
    _leaving = true;
    setState(() {});
    try {
      await _prepareCurrentSurfaceToLeave();
      await widget.controller.whenIdle();
      await _settlePuzzleControllers();
      await widget.controller.whenIdle();
      await widget.controller.close();
    } catch (_) {
      if (mounted) {
        setState(() => _leaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session could not be saved. Retry before leaving.'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    if (widget.controller.state.status ==
        ActiveSessionStatus.recoverableFailure) {
      _leaving = false;
      setState(() {});
      return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  Future<void> _handleBack() async {
    if (_leaving || _advancePending || _backPending) return;
    final review = _reviewKey.currentState;
    final reader = _readerKey.currentState;
    if (review?.isExploring != true && reader?.isExploring != true) {
      await _closeAndPop();
      return;
    }

    setState(() => _backPending = true);
    try {
      if (review?.isExploring == true) {
        await review!.returnFromExploration();
      } else if (reader?.isExploring == true) {
        await reader!.returnFromExploration();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Exploration could not be saved. Retry before returning.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _backPending = false);
    }
  }

  Future<void> _prepareCurrentSurfaceToLeave() async {
    await _reviewKey.currentState?.prepareToLeave();
    await _readerKey.currentState?.prepareToLeave();
  }

  Future<void> _settlePuzzleControllers() async {
    for (final controller in _puzzleControllers.values) {
      final path = controller.reviewPath;
      if (path != null) await controller.setReviewPath(path);
      final orientation = controller.reviewOrientation;
      if (orientation != null) {
        await controller.setReviewOrientation(orientation);
      }
      await controller.whenIdle();
    }
  }

  Future<void> _pauseSession() async {
    if (_advancePending || _leaving) return;
    setState(() => _advancePending = true);
    try {
      await _prepareCurrentSurfaceToLeave();
      await _settlePuzzleControllers();
      await widget.controller.pause();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session could not be paused. Retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _advancePending = false);
    }
  }

  Future<void> _retrySession() async {
    if (_advancePending || _leaving) return;
    setState(() => _advancePending = true);
    try {
      await _prepareCurrentSurfaceToLeave();
      await _settlePuzzleControllers();
      await widget.controller.start();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Session could not be saved. Retry before restarting.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _advancePending = false);
    }
  }

  Future<void> _nextFromReview() async {
    final before = widget.controller.state;
    if (_advancePending || before.status != ActiveSessionStatus.active) return;
    final previousItemId = before.activeItem?.id;
    setState(() => _advancePending = true);
    try {
      await _prepareCurrentSurfaceToLeave();
      await _settlePuzzleControllers();
      await widget.controller.advance();
    } catch (_) {
      if (mounted) {
        setState(() => _advancePending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review could not be saved. Retry to continue.'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    final after = widget.controller.state;
    final advanced =
        after.status == ActiveSessionStatus.completed ||
        (after.status == ActiveSessionStatus.active &&
            after.activeItem?.id != previousItemId);
    setState(() {
      _advancePending = false;
      if (advanced) _review = null;
    });
  }

  Future<void> _completeNonPuzzleItem() async {
    final before = widget.controller.state;
    if (_advancePending || before.status != ActiveSessionStatus.active) return;
    setState(() => _advancePending = true);
    try {
      await _prepareCurrentSurfaceToLeave();
      await widget.controller.whenIdle();
      await widget.controller.continueNonPuzzle();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reading could not be saved. Retry before continuing.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _advancePending = false);
    }
  }

  static String _format(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

final class _ActivePuzzleSurface extends StatefulWidget {
  const _ActivePuzzleSurface({
    super.key,
    required this.controller,
    required this.sessionController,
    required this.content,
    required this.attempt,
    required this.currentItem,
    required this.totalItems,
    required this.onReview,
  });

  final PuzzleSolverController controller;
  final ActiveSessionController sessionController;
  final ChessContent content;
  final PuzzleAttempt attempt;
  final int currentItem;
  final int totalItems;
  final ValueChanged<PuzzlePresentationState> onReview;

  @override
  State<_ActivePuzzleSurface> createState() => _ActivePuzzleSurfaceState();
}

final class _ActivePuzzleSurfaceState extends State<_ActivePuzzleSurface> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  @override
  void didUpdateWidget(covariant _ActivePuzzleSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attempt.status != widget.attempt.status ||
        oldWidget.attempt.activeDuration != widget.attempt.activeDuration) {
      _initialization = _initialize();
    }
  }

  Future<void> _initialize() => widget.controller
      .initialize(puzzle: widget.content, attemptId: widget.attempt.id)
      .then((_) {});

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Text('Puzzle could not be opened. Try again.'),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final turn = widget.content.startingFen.split(' ').elementAtOrNull(1);
      return PuzzleSolvingView(
        controller: widget.controller,
        showProgress: false,
        modeLabel: null,
        currentExercise: widget.currentItem,
        totalExercises: widget.totalItems,
        orientation: turn == 'b' ? PuzzleSide.black : PuzzleSide.white,
        onPause: widget.sessionController.pause,
        pauseOwnAttempt: false,
        onReview: widget.onReview,
      );
    },
  );
}
