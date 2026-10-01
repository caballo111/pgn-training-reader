import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/content_type.dart';
import '../../../domain/training/puzzle_attempt.dart';
import '../../../features/game_reader/presentation/game_reader_page.dart';
import '../../../features/puzzle_solver/application/puzzle_presentation_state.dart';
import '../../../features/puzzle_solver/application/puzzle_solver_controller.dart';
import '../../../features/puzzle_solver/presentation/puzzle_solving_view.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../../../features/puzzle_solver/presentation/puzzle_solution_review_view.dart';
import '../application/active_session_controller.dart';

/// Shows a cycle's current indexed content and its explicit lifecycle controls.
final class ActiveSessionPage extends StatefulWidget {
  const ActiveSessionPage({super.key, required this.controller});

  final ActiveSessionController controller;

  @override
  State<ActiveSessionPage> createState() => _ActiveSessionPageState();
}

final class _ActiveSessionPageState extends State<ActiveSessionPage> {
  Timer? _ticker;
  PuzzlePresentationState? _review;
  final Map<String, PuzzleSolverController> _puzzleControllers = {};
  bool _leaving = false;
  bool _allowPop = false;
  bool _advancePending = false;

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
      if (!didPop) _closeAndPop();
    },
    child: IgnorePointer(
      ignoring: _leaving,
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
                        onPressed: () => widget.controller.start(),
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
          return Scaffold(
            appBar: AppBar(
              leading: _backButton,
              title: Text(
                _review == null
                    ? widget.controller.trainingSet.name
                    : 'Solution review',
              ),
              actions: [
                if (state.status == ActiveSessionStatus.active)
                  IconButton(
                    tooltip: 'Pause session',
                    onPressed: widget.controller.pause,
                    icon: const Icon(Icons.pause_circle_outline),
                  ),
              ],
            ),
            body: Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cycle progress: ${current.clamp(0, total)} of $total',
                        ),
                        Text('Session ${_format(state.sessionActiveTime)}'),
                        Text('Cycle ${_format(state.cycleActiveTime)}'),
                      ],
                    ),
                  ),
                ),
                if (state.status == ActiveSessionStatus.paused)
                  MaterialBanner(
                    content: const Text(
                      'Session paused. Resume when you are ready.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: widget.controller.resume,
                        child: const Text('Resume'),
                      ),
                    ],
                  ),
                Expanded(
                  child: _review != null
                      ? PuzzleSolutionReviewView(
                          presentation: _review!,
                          onNext: _nextFromReview,
                          canAdvance:
                              state.status == ActiveSessionStatus.active &&
                              !_advancePending,
                          isFinalExercise: current >= total,
                        )
                      : _content(state, current, total),
                ),
                if (state.status == ActiveSessionStatus.active &&
                    state.activeItem != null &&
                    state.activeItem!.contentType != ContentType.puzzle)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: FilledButton(
                        onPressed: widget.controller.continueNonPuzzle,
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
    if (content == null) {
      return const Center(child: Text('No current content.'));
    }
    if (state.activeItem?.contentType == ContentType.puzzle &&
        state.attempt != null) {
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
      child: GameReaderPage(content: content),
    );
  }

  Widget get _backButton => IconButton(
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onPressed: _closeAndPop,
    icon: const BackButtonIcon(),
  );

  Future<void> _closeAndPop() async {
    if (_leaving) return;
    _leaving = true;
    setState(() {});
    await widget.controller.whenIdle();
    await Future.wait([
      ..._puzzleControllers.values.map((controller) => controller.whenIdle()),
    ]);
    await widget.controller.whenIdle();
    await widget.controller.close();
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

  Future<void> _nextFromReview() async {
    final before = widget.controller.state;
    if (_advancePending || before.status != ActiveSessionStatus.active) return;
    final previousItemId = before.activeItem?.id;
    setState(() => _advancePending = true);
    try {
      await widget.controller.advance();
    } catch (_) {
      if (mounted) setState(() => _advancePending = false);
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
