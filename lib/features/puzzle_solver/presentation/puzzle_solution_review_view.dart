import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/material.dart';

import '../../../domain/training/puzzle_attempt.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../../../shared/chessboard/chessboard_adapter.dart';
import '../../../shared/presentation/study_layout.dart';
import '../../../shared/presentation/study_navigation_controls.dart';
import '../../game_reader/presentation/reader_board.dart';
import '../application/puzzle_presentation_state.dart';
import 'puzzle_controls.dart';
import '../../../shared/presentation/study_move_button.dart';

/// Read-only solution review. This surface accepts only the safe projection,
/// which contains authored content only after the attempt has finalized.
final class PuzzleSolutionReviewView extends StatefulWidget {
  const PuzzleSolutionReviewView({
    required this.presentation,
    this.onRetry,
    this.onNext,
    this.canAdvance = true,
    this.isFinalExercise = false,
    super.key,
  });

  final PuzzlePresentationState presentation;
  final VoidCallback? onRetry;
  final VoidCallback? onNext;
  final bool canAdvance;
  final bool isFinalExercise;

  @override
  State<PuzzleSolutionReviewView> createState() =>
      _PuzzleSolutionReviewViewState();
}

final class _PuzzleSolutionReviewViewState
    extends State<PuzzleSolutionReviewView> {
  final Map<int, int> _variationChoices = {};
  int _plyIndex = 0;
  late PuzzleSide _orientation =
      widget.presentation.boardOrientation ?? _startingOrientation;

  PuzzleSide get _startingOrientation =>
      widget.presentation.startingFen.split(' ').elementAtOrNull(1) == 'b'
      ? PuzzleSide.black
      : PuzzleSide.white;

  @override
  void didUpdateWidget(covariant PuzzleSolutionReviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.presentation, widget.presentation)) {
      _variationChoices.clear();
      _orientation =
          widget.presentation.boardOrientation ?? _startingOrientation;
      _initializeReachedPath();
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeReachedPath();
  }

  void _initializeReachedPath() {
    final entries = widget.presentation.entries
        .where((entry) => entry.accepted)
        .toList();
    var siblings =
        widget.presentation.solution ?? const <PuzzlePresentationMove>[];
    for (
      var depth = 0;
      depth < entries.length && siblings.isNotEmpty;
      depth++
    ) {
      final choice = siblings.indexWhere(
        (move) => move.uci == entries[depth].uci,
      );
      if (choice < 0) break;
      _variationChoices[depth] = choice;
      siblings = siblings[choice].children;
    }
    _plyIndex = entries.isEmpty ? -1 : entries.length - 1;
  }

  List<PuzzlePresentationMove> get _line {
    final nodes =
        widget.presentation.solution ?? const <PuzzlePresentationMove>[];
    final result = <PuzzlePresentationMove>[];
    var siblings = nodes;
    var depth = 0;
    while (siblings.isNotEmpty) {
      final choice = (_variationChoices[depth] ?? 0).clamp(
        0,
        siblings.length - 1,
      );
      final selected = siblings[choice];
      result.add(selected);
      siblings = selected.children;
      depth++;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.presentation.isSolutionVisible) {
      return const Center(child: Text('The solution is not available yet.'));
    }
    final line = _line;
    if (line.isEmpty) {
      return const Center(child: Text('No solution moves are available.'));
    }
    _plyIndex = _plyIndex.clamp(-1, line.length - 1);
    final position = _positionAt(_plyIndex, line);
    final selected = _plyIndex < 0 ? null : line[_plyIndex];
    final legal = <String, Set<String>>{
      for (final entry in chess.makeLegalMoves(position).entries)
        entry.key.name: {
          for (final destination in entry.value) destination.name,
        },
    };
    final board = ChessboardAdapter.fromPosition(
      fen: position.fen,
      sideToMove: position.turn == chess.Side.white
          ? PuzzleSide.white
          : PuzzleSide.black,
      legalDestinations: legal,
      orientation: _orientation,
      lastMoveUci: selected?.uci,
    );

    return StudyLayout(
      board: ReaderBoard(board: board, showOrientationControl: false),
      controls: StudyNavigationControls(
        canPrevious: _plyIndex >= 0,
        canNext: _plyIndex + 1 < line.length,
        onFirst: () => setState(() => _plyIndex = -1),
        onPrevious: () => setState(() => _plyIndex--),
        onNext: () => setState(() => _plyIndex++),
        onLast: () => setState(() => _plyIndex = line.length - 1),
        onFlip: () => setState(() {
          _orientation = _orientation == PuzzleSide.white
              ? PuzzleSide.black
              : PuzzleSide.white;
        }),
      ),
      details: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Semantics(
            label: 'Puzzle outcome',
            value: _outcomeLabel(widget.presentation),
            child: ExcludeSemantics(
              child: Text('Result: ${_outcomeLabel(widget.presentation)}'),
            ),
          ),
          if (widget.presentation.comments.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Puzzle notes',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final comment in widget.presentation.comments) Text(comment),
          ],
          const SizedBox(height: 16),
          const Text(
            'Solution line',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Wrap(
            children: [
              for (var index = 0; index < line.length; index++)
                StudyMoveButton(
                  prefix: _movePrefix(line[index]),
                  label: line[index].san,
                  selected: _plyIndex == index,
                  annotation: line[index].nags.isEmpty
                      ? null
                      : line[index].nags.map(_nagLabel).join(' '),
                  onPressed: () => setState(() => _plyIndex = index),
                ),
            ],
          ),
          if (widget.presentation.usedFullLineFallback)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Full line used: no completion marker on this continuation.',
              ),
            ),
          for (var depth = 0; depth < line.length; depth++)
            if (_siblingsAt(depth).length > 1)
              DropdownButton<int>(
                key: ValueKey('variation-$depth'),
                value: _variationChoices[depth] ?? 0,
                isExpanded: true,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _variationChoices[depth] = value;
                    _variationChoices.removeWhere((key, _) => key > depth);
                    _plyIndex = depth;
                  });
                },
                items: [
                  for (
                    var index = 0;
                    index < _siblingsAt(depth).length;
                    index++
                  )
                    DropdownMenuItem(
                      value: index,
                      child: Text(
                        'Variation at move ${depth + 1}: ${_siblingsAt(depth)[index].san}',
                      ),
                    ),
                ],
              ),
          const SizedBox(height: 8),
          Text(
            selected == null
                ? 'Starting position'
                : 'Selected move: ${selected.san}',
          ),
          if (selected != null) ...[
            if (selected.nags.isNotEmpty)
              Text('Annotations: ${selected.nags.map(_nagLabel).join(', ')}'),
            for (final comment in selected.comments) Text(comment),
          ],
          Center(child: Text('${_plyIndex + 1} of ${line.length}')),
          const SizedBox(height: 12),
          PuzzleControls(
            mode: PuzzleControlsMode.review,
            onPause: () {},
            onShowSolution: () {},
            onSkip: () {},
            onRetry: widget.onRetry,
          ),
          if (widget.onNext != null)
            FilledButton(
              onPressed: widget.canAdvance ? widget.onNext : null,
              child: Text(
                widget.isFinalExercise ? 'Finish cycle' : 'Next exercise',
              ),
            ),
        ],
      ),
    );
  }

  List<PuzzlePresentationMove> _siblingsAt(int depth) {
    var siblings =
        widget.presentation.solution ?? const <PuzzlePresentationMove>[];
    for (var index = 0; index < depth; index++) {
      if (siblings.isEmpty) return const [];
      final choice = (_variationChoices[index] ?? 0).clamp(
        0,
        siblings.length - 1,
      );
      siblings = siblings[choice].children;
    }
    return siblings;
  }

  String _movePrefix(PuzzlePresentationMove move) {
    final fields = move.fenBefore.split(' ');
    final number = fields.length >= 6 ? int.tryParse(fields[5]) ?? 1 : 1;
    final isBlack = fields.length >= 2 && fields[1] == 'b';
    return '$number${isBlack ? '...' : '.'} ';
  }

  chess.Chess _positionAt(int index, List<PuzzlePresentationMove> line) {
    var position = chess.Chess.fromSetup(
      chess.Setup.parseFen(widget.presentation.startingFen),
    );
    for (var ply = 0; ply <= index; ply++) {
      final move = chess.Move.parse(line[ply].uci);
      if (move == null || !position.isLegal(move)) {
        throw StateError(
          'The authored solution contains an invalid review move.',
        );
      }
      position = position.play(move) as chess.Chess;
    }
    return position;
  }

  String _outcomeLabel(PuzzlePresentationState presentation) =>
      switch (presentation.outcome) {
        PuzzleAttemptOutcome.passed => 'Passed',
        PuzzleAttemptOutcome.assisted => 'Assisted',
        PuzzleAttemptOutcome.wrongMove => 'Incorrect move',
        PuzzleAttemptOutcome.revealed => 'Solution revealed',
        PuzzleAttemptOutcome.skipped => 'Skipped',
        PuzzleAttemptOutcome.timedOut => 'Timed out',
        PuzzleAttemptOutcome.abandoned => 'Abandoned',
        null => 'In progress',
      };

  String _nagLabel(int nag) => switch (nag) {
    1 => '!',
    2 => '?',
    3 => '!!',
    4 => '??',
    5 => '!?',
    6 => '?!',
    _ => 'NAG $nag',
  };
}
