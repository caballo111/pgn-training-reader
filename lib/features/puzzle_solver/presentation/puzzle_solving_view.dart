import 'package:flutter/material.dart';

import '../../../domain/training/puzzle_evaluator.dart';
import '../../../domain/training/puzzle_attempt.dart';
import '../application/puzzle_presentation_state.dart';
import '../application/puzzle_solver_controller.dart';
import 'puzzle_board.dart';
import 'puzzle_controls.dart';
import 'puzzle_header.dart';
import 'puzzle_solution_review_view.dart';
import '../../../shared/presentation/study_layout.dart';
import '../../../shared/presentation/flip_board_button.dart';
import '../../../shared/presentation/study_board_frame.dart';

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
  void _stateListener(PuzzlePresentationState _) {
    if (mounted) setState(() {});
  }

  late PuzzleSide _orientation =
      widget.controller.state?.boardOrientation ?? widget.orientation;

  @override
  void initState() {
    super.initState();
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
      _orientation =
          widget.controller.state?.boardOrientation ?? widget.orientation;
    }
  }

  @override
  void dispose() {
    widget.controller.removeStateListener(_stateListener);
    super.dispose();
  }

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

    return StudyLayout(
      board: StudyBoardFrame(
        sideToMove: presentation.sideToMove == PuzzleSide.white
            ? 'White to move'
            : 'Black to move',
        child: PuzzleBoard(
          fen: presentation.currentFen,
          sideToMove: presentation.sideToMove,
          legalDestinations: _legalDestinationMap(),
          orientation: _orientation,
          lastMoveUci: presentation.playedMoves.isEmpty
              ? null
              : presentation.playedMoves.last,
          hintSquare: presentation.hintSquare,
          enabled: widget.controller.canInteract && !isPaused && !_writePending,
          onMoveSubmitted: _submitMove,
        ),
      ),
      controls: FlipBoardButton(onPressed: _flip),
      details: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PuzzleHeader(
            currentExercise: widget.currentExercise,
            totalExercises: widget.totalExercises,
            evaluation: evaluation,
            showSideToMove: false,
          ),
          const SizedBox(height: 12),
          Text(presentation.policyLabel),
          if (presentation.isPredictingReply)
            const Text(
              'Predict the opponent’s reply to complete the calculation.',
            ),
          if (presentation.feedback != null)
            Semantics(liveRegion: true, child: Text(presentation.feedback!)),
          if (presentation.hintCount > 0)
            Text('Hints: ${presentation.hintCount}'),
          _PlayedMoves(moves: presentation.entries),
          if (_error case final error?)
            Semantics(liveRegion: true, child: Text(error)),
          const SizedBox(height: 16),
          if (isPaused) ...[
            if (widget.pauseOwnAttempt) ...[
              const Text('Attempt paused'),
              FilledButton.icon(
                onPressed: _writePending
                    ? null
                    : () => _run(widget.controller.resume),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume'),
              ),
            ],
          ] else ...[
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _writePending
                      ? null
                      : () => _run(widget.controller.hint),
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Hint'),
                ),
                if (presentation.hintSquare != null)
                  TextButton(
                    onPressed: _writePending
                        ? null
                        : () => _run(widget.controller.showMove),
                    child: const Text('Show move'),
                  ),
              ],
            ),
            if (presentation.outcome == null)
              const Text(
                'A hint makes this attempt assisted. Showing a move reveals the answer.',
              ),
            PuzzleControls(
              mode: PuzzleControlsMode.active,
              enabled: !_writePending,
              onPause: _pause,
              onShowSolution: () => _run(widget.controller.reveal),
              onSkip: () => _run(widget.controller.skip),
            ),
          ],
        ],
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

  final List<PuzzlePlayedMove> moves;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Moves played',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Moves played', style: Theme.of(context).textTheme.titleSmall),
        if (moves.isEmpty)
          const Text('No moves yet')
        else
          Wrap(
            spacing: 8,
            children: [
              for (final move in moves)
                Text(
                  '${move.label}${move.actor == 'automatic'
                      ? ' (reply)'
                      : move.actor == 'revealed'
                      ? ' (shown)'
                      : ''}',
                ),
            ],
          ),
      ],
    ),
  );
}
