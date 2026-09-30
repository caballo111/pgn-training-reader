import 'package:flutter/material.dart';

import '../../../domain/training/puzzle_evaluator.dart';
import '../../../domain/training/puzzle_attempt.dart';
import '../application/puzzle_presentation_state.dart';
import '../application/puzzle_solver_controller.dart';
import 'puzzle_board.dart';
import 'puzzle_controls.dart';
import 'puzzle_header.dart';

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

  @override
  State<PuzzleSolvingView> createState() => _PuzzleSolvingViewState();
}

final class _PuzzleSolvingViewState extends State<PuzzleSolvingView> {
  String? _error;
  bool _writePending = false;

  @override
  Widget build(BuildContext context) {
    final presentation = widget.controller.state;
    final evaluation = widget.controller.currentEvaluation;
    final isPaused = presentation?.attemptStatus == PuzzleAttemptStatus.paused;
    if (presentation == null || evaluation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (presentation.isSolutionVisible) {
      return Scaffold(
        appBar: AppBar(title: const Text('Puzzle complete')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Your attempt has ended.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: widget.onReview == null
                      ? null
                      : () => widget.onReview!(presentation),
                  child: const Text('Continue to review'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Puzzle')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PuzzleHeader(
                    currentExercise: widget.currentExercise,
                    totalExercises: widget.totalExercises,
                    evaluation: evaluation,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: PuzzleBoard(
                        fen: presentation.currentFen,
                        sideToMove: presentation.sideToMove,
                        legalDestinations: _legalDestinationMap(),
                        orientation: widget.orientation,
                        lastMoveUci: presentation.playedMoves.isEmpty
                            ? null
                            : presentation.playedMoves.last,
                        enabled: !isPaused && !_writePending,
                        onMoveSubmitted: _submitMove,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PlayedMoves(moves: presentation.playedMoves),
                  if (_error case final error?) ...[
                    const SizedBox(height: 8),
                    Semantics(liveRegion: true, child: Text(error)),
                  ],
                  const SizedBox(height: 12),
                  if (isPaused) ...[
                    if (widget.pauseOwnAttempt) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text('Attempt paused'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _writePending
                            ? null
                            : () => _run(widget.controller.resume),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Resume'),
                      ),
                    ],
                  ] else
                    PuzzleControls(
                      mode: PuzzleControlsMode.active,
                      enabled: !_writePending,
                      onPause: _pause,
                      onShowSolution: () => _run(widget.controller.reveal),
                      onSkip: () => _run(widget.controller.skip),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

  Future<void> _submitMove(String uci) =>
      _run(() => widget.controller.submitMove(uci: uci));

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
    setState(() => _writePending = true);
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) setState(() => _error = 'Your move could not be saved.');
    } finally {
      if (mounted) setState(() => _writePending = false);
    }
  }
}

final class _PlayedMoves extends StatelessWidget {
  const _PlayedMoves({required this.moves});

  final List<String> moves;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Moves played by you',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your moves'),
        if (moves.isEmpty)
          const Text('No moves yet')
        else
          Wrap(spacing: 8, children: [for (final move in moves) Text(move)]),
      ],
    ),
  );
}
