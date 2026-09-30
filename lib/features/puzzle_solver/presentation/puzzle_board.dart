import 'package:chessground/chessground.dart' as chessground;
import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/material.dart';

import '../../../domain/training/puzzle_evaluator.dart';
import '../../../shared/chessboard/chessboard_adapter.dart';

/// Interactive puzzle board limited to the evaluator's legal destinations.
///
/// The caller supplies a current position snapshot and handles accepted board
/// moves. This widget has no move-tree or navigation API, so future solution
/// state cannot enter through its presentation boundary.
final class PuzzleBoard extends StatefulWidget {
  const PuzzleBoard({
    required this.fen,
    required this.sideToMove,
    required this.legalDestinations,
    required this.orientation,
    required this.onMoveSubmitted,
    this.enabled = true,
    this.lastMoveUci,
    super.key,
  });

  /// FEN for the current position only.
  final String fen;

  /// Side to move in [fen].
  final PuzzleSide sideToMove;

  /// Legal destinations keyed by algebraic origin square.
  final Map<String, Set<String>> legalDestinations;

  /// User's board orientation preference.
  final PuzzleSide orientation;

  /// Receives a move made through a supplied legal destination, in UCI form.
  final ValueChanged<String> onMoveSubmitted;

  /// Whether the board accepts interaction in the current attempt state.
  final bool enabled;

  /// Previous user move for highlighting, when available.
  final String? lastMoveUci;

  @override
  State<PuzzleBoard> createState() => _PuzzleBoardState();
}

final class _PuzzleBoardState extends State<PuzzleBoard> {
  late final chessground.ChessboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = chessground.ChessboardController(game: _gameData());
  }

  @override
  void didUpdateWidget(covariant PuzzleBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.updatePosition(_gameData(), resetPremove: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    enabled: widget.enabled,
    label: 'Puzzle board with files a through h and ranks 1 through 8.',
    child: IgnorePointer(
      ignoring: !widget.enabled,
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) => chessground.Chessboard(
              size: constraints.maxWidth,
              controller: _controller,
              orientation: _orientation(widget.orientation),
              settings: const chessground.ChessboardSettings(
                enableCoordinates: true,
                enablePremoves: false,
                enableDrops: false,
                showLastMove: true,
                showValidMoves: true,
              ),
              onMove: (move, {viaDragAndDrop}) =>
                  widget.onMoveSubmitted(move.uci),
            ),
          ),
        ),
      ),
    ),
  );

  chessground.GameData _gameData() {
    final board = ChessboardAdapter.fromPosition(
      fen: widget.fen,
      sideToMove: widget.sideToMove,
      legalDestinations: widget.legalDestinations,
      orientation: widget.orientation,
      lastMoveUci: widget.lastMoveUci,
    );
    return chessground.GameData(
      fen: board.game.fen,
      playerSide: _playerSide(widget.sideToMove),
      sideToMove: board.game.sideToMove,
      validMoves: board.game.validMoves,
      lastMove: board.game.lastMove,
    );
  }

  static chess.Side _orientation(PuzzleSide side) => switch (side) {
    PuzzleSide.white => chess.Side.white,
    PuzzleSide.black => chess.Side.black,
  };

  static chessground.PlayerSide _playerSide(PuzzleSide side) => switch (side) {
    PuzzleSide.white => chessground.PlayerSide.white,
    PuzzleSide.black => chessground.PlayerSide.black,
  };
}
