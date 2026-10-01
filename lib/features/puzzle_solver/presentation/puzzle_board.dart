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
    this.hintSquare,
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

  /// Origin square emphasized by an assisted hint.
  final String? hintSquare;

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
    label: widget.hintSquare == null
        ? 'Puzzle board with files a through h and ranks 1 through 8.'
        : 'Puzzle board. Hint: the piece on ${widget.hintSquare} can move.',
    child: IgnorePointer(
      ignoring: !widget.enabled,
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              LayoutBuilder(
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
              if (widget.hintSquare case final square?)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: const ValueKey('puzzle-hint-square-highlight'),
                      painter: HintSquareHighlightPainter(
                        square: square,
                        blackOrientation:
                            widget.orientation == PuzzleSide.black,
                      ),
                    ),
                  ),
                ),
            ],
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

final class HintSquareHighlightPainter extends CustomPainter {
  const HintSquareHighlightPainter({
    required this.square,
    required this.blackOrientation,
  });

  final String square;
  final bool blackOrientation;

  Rect? squareRectFor(Size size) {
    if (square.length != 2) return null;
    final file = square.codeUnitAt(0) - 97;
    final rank = int.tryParse(square[1]);
    if (file < 0 || file > 7 || rank == null || rank < 1 || rank > 8) {
      return null;
    }
    final column = blackOrientation ? 7 - file : file;
    final row = blackOrientation ? rank - 1 : 8 - rank;
    return Rect.fromLTWH(
      column * size.width / 8,
      row * size.height / 8,
      size.width / 8,
      size.height / 8,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = squareRectFor(size);
    if (rect == null) return;
    canvas.drawRect(rect, Paint()..color = const Color(0x8867D6A0));
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF1B7A50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(HintSquareHighlightPainter oldDelegate) =>
      square != oldDelegate.square ||
      blackOrientation != oldDelegate.blackOrientation;
}
