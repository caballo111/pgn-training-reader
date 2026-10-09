import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dartchess/dartchess.dart' as chess;

import '../../../domain/training/puzzle_evaluator.dart';
import '../../../domain/training/puzzle_attempt.dart';
import '../application/puzzle_presentation_state.dart';
import '../application/puzzle_solver_controller.dart';
import 'puzzle_board.dart';
import 'puzzle_header.dart';
import 'puzzle_attempt_variations.dart';
import 'puzzle_solution_review_view.dart';
import '../../../shared/presentation/study_layout.dart';
import '../../../shared/presentation/study_board_frame.dart';
import '../../../shared/presentation/study_board_controls.dart';
import '../../../shared/presentation/study_block_navigation.dart';

/// Active puzzle surface. It consumes the safe presentation projection and
/// never renders puzzle metadata or the authored move tree.
final class PuzzleSolvingView extends StatefulWidget {
  const PuzzleSolvingView({
    required this.controller,
    required this.currentExercise,
    required this.totalExercises,
    required this.orientation,
    required this.onPause,
    this.onReview,
    this.pauseOwnAttempt = true,
    this.showProgress = true,
    this.contextTitle,
    this.sectionLabel,
    this.blockLabel,
    this.modeLabel,
    this.showBlockNavigation = false,
    this.onPreviousBlock,
    this.onNextBlock,
    this.nextBlockLabel = 'Next block',
    this.isCasualPractice = false,
    super.key,
  });

  final PuzzleSolverController controller;
  final int currentExercise;
  final int totalExercises;
  final PuzzleSide orientation;
  final VoidCallback onPause;

  /// Receives the finalized safe projection for a separate review surface.
  final ValueChanged<PuzzlePresentationState>? onReview;

  /// Session pages delegate pause persistence to their lifecycle coordinator.
  final bool pauseOwnAttempt;
  final bool showProgress;
  final String? contextTitle;
  final String? sectionLabel;
  final String? blockLabel;
  final String? modeLabel;
  final bool showBlockNavigation;
  final VoidCallback? onPreviousBlock;
  final VoidCallback? onNextBlock;
  final String nextBlockLabel;
  final bool isCasualPractice;

  @override
  State<PuzzleSolvingView> createState() => _PuzzleSolvingViewState();
}

final class _PuzzleSolvingViewState extends State<PuzzleSolvingView>
    with WidgetsBindingObserver {
  void _stateListener(PuzzlePresentationState _) {
    if (!mounted) return;
    final feedback = widget.controller.state?.feedback;
    final revealFeedback = feedback != null && feedback != _lastFeedback;
    _lastFeedback = feedback;
    setState(() {});
    if (revealFeedback) _scrollDetailsToFeedback();
  }

  late PuzzleSide _orientation =
      widget.controller.state?.boardOrientation ?? widget.orientation;
  Timer? _rejectionTimer;
  Completer<void>? _rejectionDelay;
  int _interactionGeneration = 0;
  bool _appForeground = true;
  final ScrollController _detailsController = ScrollController();
  String? _lastFeedback;

  @override
  void initState() {
    super.initState();
    _lastFeedback = widget.controller.state?.feedback;
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addStateListener(_stateListener);
  }

  @override
  void didUpdateWidget(covariant PuzzleSolvingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeStateListener(_stateListener);
      widget.controller.addStateListener(_stateListener);
    }
    if (oldWidget.orientation != widget.orientation ||
        oldWidget.controller != widget.controller ||
        oldWidget.currentExercise != widget.currentExercise) {
      _interactionGeneration++;
      _cancelRejectionDelay();
      _rejectedFen = null;
      _rejectedUci = null;
      _rejectedSideToMove = null;
      _writePending = false;
      _lastFeedback = widget.controller.state?.feedback;
      _orientation =
          widget.controller.state?.boardOrientation ?? widget.orientation;
    }
  }

  @override
  void dispose() {
    widget.controller.removeStateListener(_stateListener);
    WidgetsBinding.instance.removeObserver(this);
    _interactionGeneration++;
    _cancelRejectionDelay();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appForeground = true;
      return;
    }
    _appForeground = false;
    if (_rejectionTimer != null && mounted) {
      _cancelRejectionDelay();
      setState(() {
        _rejectedFen = null;
        _rejectedUci = null;
        _rejectedSideToMove = null;
        _writePending = false;
      });
    }
  }

  void _scrollDetailsToFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _detailsController.hasClients) {
        _detailsController.jumpTo(_detailsController.position.minScrollExtent);
      }
    });
  }

  String? _error;
  bool _writePending = false;
  String? _rejectedFen;
  String? _rejectedUci;
  PuzzleSide? _rejectedSideToMove;

  @override
  Widget build(BuildContext context) {
    final presentation = widget.controller.state;
    final evaluation = widget.controller.currentEvaluation;
    final isPaused = presentation?.attemptStatus == PuzzleAttemptStatus.paused;
    if (presentation == null || evaluation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (presentation.isSolutionVisible) {
      if (widget.onReview == null) {
        return PuzzleSolutionReviewView(presentation: presentation);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.state?.isSolutionVisible == true) {
          widget.onReview?.call(widget.controller.state!);
        }
      });
      return PuzzleSolutionReviewView(presentation: presentation);
    }

    final showStartingTurn =
        presentation.entries.isEmpty &&
        presentation.rejections.isEmpty &&
        presentation.playedMoves.isEmpty;
    final turnLabel = presentation.sideToMove == PuzzleSide.white
        ? 'White to move'
        : 'Black to move';

    return StudyLayout(
      controlCount: 0,
      controlTrailingWidth: 48,
      // Reserve the same caption space after play starts to keep the board
      // stationary, including when the initial caption wraps at large text.
      controlCaption: presentation.startingFen.split(' ')[1] == 'b'
          ? 'Black to move'
          : 'White to move',
      controls: StudyBoardControls(
        caption: showStartingTurn ? turnLabel : null,
        onFlip: _writePending ? null : _flip,
      ),
      board: StudyBoardFrame(
        sideToMove: presentation.sideToMove,
        child: PuzzleBoard(
          fen: presentation.currentFen,
          sideToMove: presentation.sideToMove,
          legalDestinations: _rejectedFen == null
              ? _legalDestinationMap()
              : const {},
          orientation: _orientation,
          lastMoveUci: presentation.playedMoves.isEmpty
              ? null
              : presentation.playedMoves.last,
          hintSquare: presentation.hintSquare,
          displayFen: _rejectedFen,
          displayLastMoveUci: _rejectedUci,
          displaySideToMove: _rejectedSideToMove,
          reducedMotion:
              MediaQuery.of(context).disableAnimations || !_appForeground,
          enabled: widget.controller.canInteract && !isPaused && !_writePending,
          onMoveSubmitted: _submitMove,
        ),
      ),
      header:
          widget.contextTitle != null ||
              widget.sectionLabel != null ||
              widget.blockLabel != null ||
              widget.modeLabel != null ||
              (widget.showProgress && widget.totalExercises > 1)
          ? PuzzleHeader(
              currentExercise: widget.currentExercise,
              totalExercises: widget.totalExercises,
              evaluation: evaluation,
              showSideToMove: false,
              showProgress: widget.showProgress,
              contextTitle: widget.contextTitle,
              sectionLabel: widget.sectionLabel,
              blockLabel: widget.blockLabel,
              modeLabel: widget.modeLabel,
            )
          : null,
      details: ListView(
        controller: _detailsController,
        padding: const EdgeInsets.all(16),
        children: [
          if (presentation.feedback != null)
            Semantics(liveRegion: true, child: Text(presentation.feedback!)),
          if (_error case final error?)
            Semantics(liveRegion: true, child: Text(error)),
          if (presentation.isPredictingReply)
            const Text(
              'Predict the opponent’s reply to complete the calculation.',
            ),
          if (presentation.hintCount > 0)
            Text('Hints: ${presentation.hintCount}'),
          _PlayedMoves(presentation: presentation),
          const SizedBox(height: 16),
          if (isPaused && widget.pauseOwnAttempt) const Text('Attempt paused'),
        ],
      ),
      actions: isPaused
          ? widget.pauseOwnAttempt
                ? FilledButton.icon(
                    onPressed: _writePending
                        ? null
                        : () => _run(widget.controller.resume),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                  )
                : const SizedBox.shrink()
          : _SolverActionBar(
              showMenu: !widget.isCasualPractice,
              showBlockNavigation: widget.showBlockNavigation,
              onPreviousBlock: widget.onPreviousBlock,
              onNextBlock: widget.onNextBlock,
              nextBlockLabel: widget.nextBlockLabel,
              enabled: !_writePending,
              showMove: presentation.hintSquare != null,
              onHint: () => _run(widget.controller.hint),
              onShowMove: () => _run(widget.controller.showMove),
              onReveal: () => _run(widget.controller.reveal),
              onPause: widget.pauseOwnAttempt ? _pause : null,
              onSkip: () => _run(widget.controller.skip),
            ),
    );
  }

  Future<void> _flip() async {
    if (_writePending) return;
    final orientation = _orientation == PuzzleSide.white
        ? PuzzleSide.black
        : PuzzleSide.white;
    setState(() => _writePending = true);
    try {
      await widget.controller.setOrientation(orientation);
      if (mounted) {
        setState(() {
          _orientation = orientation;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Board orientation could not be saved.');
      }
    } finally {
      if (mounted) setState(() => _writePending = false);
    }
  }

  Map<String, Set<String>> _legalDestinationMap() {
    final result = <String, Set<String>>{};
    for (final rank in '12345678'.split('')) {
      for (final file in 'abcdefgh'.split('')) {
        final destinations = widget.controller.legalDestinations(
          fromSquare: '$file$rank',
        );
        if (destinations.isNotEmpty) result['$file$rank'] = destinations;
      }
    }
    return result;
  }

  Future<void> _submitMove(String uci) async {
    if (_writePending) return;
    final generation = _interactionGeneration;
    setState(() => _writePending = true);
    try {
      final result = await widget.controller.submitMove(uci: uci);
      if (!mounted || generation != _interactionGeneration || !_appForeground) {
        return;
      }
      if (result.rejectedMove case final rejection?
          when rejection.uci == uci && rejection.legal) {
        final fen = _fenAfter(rejection.fenBefore, uci);
        if (fen != null && mounted) {
          setState(() {
            _rejectedFen = fen;
            _rejectedUci = uci;
            _rejectedSideToMove = fen.split(' ').elementAtOrNull(1) == 'b'
                ? PuzzleSide.black
                : PuzzleSide.white;
          });
          await _waitForRejectionCue(const Duration(milliseconds: 450));
          if (mounted &&
              generation == _interactionGeneration &&
              _appForeground) {
            setState(() {
              _rejectedFen = null;
              _rejectedUci = null;
              _rejectedSideToMove = null;
            });
            if (!MediaQuery.of(context).disableAnimations) {
              await _waitForRejectionCue(const Duration(milliseconds: 200));
            }
          }
        }
      }
      if (mounted && generation == _interactionGeneration) {
        setState(() => _error = null);
      }
    } catch (_) {
      if (mounted && generation == _interactionGeneration) {
        setState(() => _error = 'Your move could not be saved.');
        _scrollDetailsToFeedback();
      }
    } finally {
      if (mounted && generation == _interactionGeneration) {
        setState(() => _writePending = false);
      }
    }
  }

  Future<void> _waitForRejectionCue(Duration duration) {
    final completer = Completer<void>();
    _rejectionDelay = completer;
    _rejectionTimer = Timer(duration, () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future.whenComplete(() {
      if (identical(_rejectionDelay, completer)) {
        _rejectionDelay = null;
        _rejectionTimer = null;
      }
    });
  }

  void _cancelRejectionDelay() {
    _rejectionTimer?.cancel();
    _rejectionTimer = null;
    final delay = _rejectionDelay;
    _rejectionDelay = null;
    if (delay != null && !delay.isCompleted) delay.complete();
  }

  String? _fenAfter(String fen, String uci) {
    try {
      final position = chess.Chess.fromSetup(chess.Setup.parseFen(fen));
      final move = chess.Move.parse(uci);
      if (move == null || !position.isLegal(move)) return null;
      return position.playUnchecked(move).fen;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pause() async {
    if (widget.pauseOwnAttempt) await _run(widget.controller.pause);
    if (mounted &&
        (!widget.pauseOwnAttempt ||
            widget.controller.state?.attemptStatus ==
                PuzzleAttemptStatus.paused)) {
      widget.onPause();
    }
  }

  Future<void> _run(Future<PuzzlePresentationState> Function() action) async {
    if (_writePending) return;
    final generation = _interactionGeneration;
    setState(() => _writePending = true);
    try {
      await action();
      if (mounted && generation == _interactionGeneration) {
        setState(() => _error = null);
      }
    } catch (_) {
      if (mounted && generation == _interactionGeneration) {
        setState(() => _error = 'Your move could not be saved.');
        _scrollDetailsToFeedback();
      }
    } finally {
      if (mounted && generation == _interactionGeneration) {
        setState(() => _writePending = false);
      }
    }
  }
}

final class _SolverActionBar extends StatelessWidget {
  const _SolverActionBar({
    required this.showMenu,
    required this.showBlockNavigation,
    required this.onPreviousBlock,
    required this.onNextBlock,
    required this.nextBlockLabel,
    required this.enabled,
    required this.showMove,
    required this.onHint,
    required this.onShowMove,
    required this.onReveal,
    required this.onPause,
    required this.onSkip,
  });

  final bool enabled;
  final bool showMenu;
  final bool showMove;
  final VoidCallback onHint;
  final VoidCallback onShowMove;
  final VoidCallback onReveal;
  final VoidCallback? onPause;
  final VoidCallback onSkip;
  final bool showBlockNavigation;
  final VoidCallback? onPreviousBlock;
  final VoidCallback? onNextBlock;
  final String nextBlockLabel;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox(
        width: 48,
        child: showBlockNavigation
            ? StudyPreviousBlockButton(
                onPressed: enabled ? onPreviousBlock : null,
              )
            : null,
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textStyle = Theme.of(context).textTheme.labelLarge;
            final textScaler = MediaQuery.textScalerOf(context);
            double labelWidth(String label) {
              final painter = TextPainter(
                text: TextSpan(text: label, style: textStyle),
                textDirection: Directionality.of(context),
                textScaler: textScaler,
                maxLines: 1,
              )..layout();
              final width = painter.width;
              painter.dispose();
              return width;
            }

            // Reserve the wider label's width so the solution button stays
            // in the same place when Hint changes to Show move.
            final preferredWidth = labelWidth('Show move') + 18 + 8 + 32;
            final availableActionWidth = (constraints.maxWidth - 52)
                .clamp(48.0, double.infinity)
                .toDouble();
            final actionWidth = preferredWidth
                .clamp(48.0, availableActionWidth)
                .toDouble();
            final showLabel = actionWidth >= 82;
            final heightPainter = TextPainter(
              text: TextSpan(text: 'Show move', style: textStyle),
              textDirection: Directionality.of(context),
              textScaler: textScaler,
            )..layout(maxWidth: (actionWidth - 58).clamp(1.0, double.infinity));
            final actionHeight = showLabel
                ? (heightPainter.height + 16).clamp(48.0, double.infinity)
                : 48.0;
            heightPainter.dispose();

            return Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Tooltip(
                  message: showMove ? 'Show move' : 'Hint',
                  excludeFromSemantics: true,
                  child: SizedBox(
                    width: actionWidth,
                    height: actionHeight,
                    child: !showLabel
                        ? IconButton(
                            tooltip: showMove ? 'Show move' : 'Hint',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: enabled
                                ? (showMove ? onShowMove : onHint)
                                : null,
                            icon: Icon(
                              showMove
                                  ? Icons.play_arrow
                                  : Icons.lightbulb_outline,
                            ),
                          )
                        : TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            onPressed: enabled
                                ? (showMove ? onShowMove : onHint)
                                : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  showMove
                                      ? Icons.play_arrow
                                      : Icons.lightbulb_outline,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    showMove ? 'Show move' : 'Hint',
                                    softWrap: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                IconButton(
                  onPressed: enabled ? onReveal : null,
                  tooltip: 'Show solution',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const Icon(Icons.visibility_outlined),
                ),
              ],
            );
          },
        ),
      ),
      SizedBox(
        width: 48,
        child: showBlockNavigation
            ? StudyNextBlockButton(
                label: nextBlockLabel,
                iconOnly: true,
                onPressed: enabled ? onNextBlock : null,
              )
            : showMenu
            ? PopupMenuButton<String>(
                enabled: enabled,
                tooltip: 'More puzzle actions',
                onSelected: (value) {
                  if (value == 'pause') onPause?.call();
                  if (value == 'skip') onSkip();
                },
                itemBuilder: (context) => [
                  if (onPause != null)
                    const PopupMenuItem(value: 'pause', child: Text('Pause')),
                  const PopupMenuItem(
                    value: 'skip',
                    child: Text('Skip puzzle'),
                  ),
                ],
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.more_horiz,
                    semanticLabel: 'More puzzle actions',
                  ),
                ),
              )
            : null,
      ),
    ],
  );
}

final class _PlayedMoves extends StatelessWidget {
  const _PlayedMoves({required this.presentation});

  final PuzzlePresentationState presentation;

  @override
  Widget build(BuildContext context) {
    final acceptedMoves = presentation.entries
        .where((move) => move.accepted)
        .toList();
    final variations = puzzleAttemptVariations(presentation);
    if (acceptedMoves.isEmpty && variations.isEmpty) {
      return const SizedBox.shrink();
    }
    final rows = <Widget>[];
    final run = <Widget>[];
    void flushRun() {
      if (run.isEmpty) return;
      rows.add(Wrap(spacing: 8, children: List.of(run)));
      run.clear();
    }

    for (var index = 0; index <= acceptedMoves.length; index++) {
      if (index < acceptedMoves.length) {
        final move = acceptedMoves[index];
        run.add(
          Semantics(
            label: move.actor == 'automatic'
                ? '${move.label}, automatic opponent move'
                : move.actor == 'revealed'
                ? '${move.label}, shown move'
                : move.label,
            excludeSemantics: true,
            child: Text(move.label),
          ),
        );
      }
      final branches = puzzleVariationsAt(variations, [
        for (final move in acceptedMoves.take(index)) move.uci,
      ]);
      if (branches.isNotEmpty) {
        flushRun();
        rows.add(PuzzleAttemptVariations(variations: branches));
      }
    }
    flushRun();

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Moves played',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }
}
