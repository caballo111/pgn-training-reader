import 'package:chessground/chessground.dart' as chessground;
import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/material.dart';

import '../../../domain/analysis/exploration_session.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../../../shared/presentation/study_board_frame.dart';

/// Interactive chess board for a personal exploration tree.
///
/// The session owns legality and history. This widget only adapts its current
/// position and legal destinations to chessground.
final class ExplorationBoard extends StatefulWidget {
  const ExplorationBoard({
    required this.session,
    required this.orientation,
    required this.onMove,
    this.enabled = true,
    super.key,
  });

  final ExplorationSession session;
  final PuzzleSide orientation;
  final ValueChanged<String> onMove;
  final bool enabled;

  @override
  State<ExplorationBoard> createState() => _ExplorationBoardState();
}

final class _ExplorationBoardState extends State<ExplorationBoard> {
  late final chessground.ChessboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = chessground.ChessboardController(game: _gameData());
  }

  @override
  void didUpdateWidget(covariant ExplorationBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.updatePosition(_gameData(), animate: true, resetPremove: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final side = widget.session.position.turn == chess.Side.white
        ? PuzzleSide.white
        : PuzzleSide.black;
    return StudyBoardFrame(
      sideToMove: side,
      child: Semantics(
        container: true,
        enabled: widget.enabled,
        label:
            'Interactive exploration chessboard. Files a through h and '
            'ranks 1 through 8. ${side == PuzzleSide.white ? 'White' : 'Black'} to move.',
        child: IgnorePointer(
          ignoring: !widget.enabled,
          child: ExcludeSemantics(
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, constraints) => chessground.Chessboard(
                  size: constraints.maxWidth,
                  controller: _controller,
                  orientation: widget.orientation == PuzzleSide.white
                      ? chess.Side.white
                      : chess.Side.black,
                  settings: const chessground.ChessboardSettings(
                    enableCoordinates: true,
                    enablePremoves: false,
                    enableDrops: false,
                    showLastMove: true,
                    showValidMoves: true,
                    animationDuration: Duration(milliseconds: 180),
                  ),
                  onMove: (move, {viaDragAndDrop}) => widget.onMove(move.uci),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  chessground.GameData _gameData() {
    final position = widget.session.position;
    final boardMoves = <chess.Square, Set<chess.Square>>{
      if (!position.isGameOver)
        for (final entry in position.legalMoves.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value.squares.toSet(),
    };
    final lastMove = widget.session.moves.isEmpty
        ? null
        : chess.Move.parse(widget.session.moves.last);
    return chessground.GameData(
      fen: position.fen,
      // Both lets the learner choose either color on every turn.
      playerSide: chessground.PlayerSide.both,
      sideToMove: position.turn,
      validMoves: boardMoves,
      lastMove: lastMove,
    );
  }
}
