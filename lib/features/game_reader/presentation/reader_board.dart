import 'package:chessground/chessground.dart' as chessground;
import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/material.dart';

import '../../../domain/training/puzzle_evaluator.dart';

import '../../../shared/chessboard/chessboard_adapter.dart';
import '../../../shared/presentation/flip_board_button.dart';
import '../../../shared/presentation/study_board_frame.dart';

/// Read-only board presentation for the game reader.
///
/// The board view data comes from the chessboard adapter, so the position,
/// active side, last move, and initial orientation stay consistent with the
/// reader's reconstructed chess position.
final class ReaderBoard extends StatefulWidget {
  const ReaderBoard({
    required this.board,
    this.showOrientationControl = true,
    this.positionLabel,
    super.key,
  });

  final ChessboardViewData board;
  final bool showOrientationControl;
  final String? positionLabel;

  @override
  State<ReaderBoard> createState() => _ReaderBoardState();
}

class _ReaderBoardState extends State<ReaderBoard> {
  late chess.Side _orientation = widget.board.orientation;

  @override
  void didUpdateWidget(covariant ReaderBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.board.orientation != widget.board.orientation) {
      _orientation = widget.board.orientation;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StudyBoardFrame(
          sideToMove: widget.board.game.sideToMove == chess.Side.white
              ? PuzzleSide.white
              : PuzzleSide.black,
          child: Semantics(
            container: true,
            liveRegion: widget.positionLabel != null,
            label:
                'Chessboard with files a through h and ranks 1 through 8. '
                '${widget.positionLabel ?? ''}',
            child: ExcludeSemantics(
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      chessground.StaticChessboard(
                        size: constraints.maxWidth,
                        orientation: _orientation,
                        fen: widget.board.game.fen,
                        lastMove: widget.board.game.lastMove,
                        settings: const chessground.StaticChessboardSettings(
                          enableCoordinates: true,
                          showLastMove: true,
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),
        if (widget.showOrientationControl)
          Center(
            child: FlipBoardButton(
              key: const ValueKey('reader-board-orientation'),
              onPressed: _toggleOrientation,
            ),
          ),
      ],
    );
  }

  void _toggleOrientation() {
    setState(() {
      _orientation = _orientation == chess.Side.white
          ? chess.Side.black
          : chess.Side.white;
    });
  }
}
