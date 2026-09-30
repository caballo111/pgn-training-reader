import 'package:chessground/chessground.dart' as chessground;
import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/material.dart';

import '../../../shared/chessboard/chessboard_adapter.dart';

/// Read-only board presentation for the game reader.
///
/// The board view data comes from the chessboard adapter, so the position,
/// active side, last move, and initial orientation stay consistent with the
/// reader's reconstructed chess position.
final class ReaderBoard extends StatefulWidget {
  const ReaderBoard({
    required this.board,
    this.showOrientationControl = true,
    super.key,
  });

  final ChessboardViewData board;
  final bool showOrientationControl;

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
    final sideLabel = widget.board.game.sideToMove == chess.Side.white
        ? 'White to move'
        : 'Black to move';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: sideLabel,
          child: ExcludeSemantics(
            child: Text(sideLabel, textAlign: TextAlign.center),
          ),
        ),
        if (widget.showOrientationControl)
          Align(
            child: TextButton.icon(
              key: const ValueKey('reader-board-orientation'),
              onPressed: _toggleOrientation,
              icon: const Icon(Icons.rotate_90_degrees_ccw),
              label: Text(
                _orientation == chess.Side.white
                    ? 'Rotate: Black at bottom'
                    : 'Rotate: White at bottom',
              ),
            ),
          ),
        Semantics(
          container: true,
          label:
              'Chessboard with files a through h and ranks 1 through 8. '
              '$sideLabel.',
          child: ExcludeSemantics(
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, constraints) => chessground.StaticChessboard(
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
