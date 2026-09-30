import 'package:chessground/chessground.dart' as chessground;
import 'package:dartchess/dartchess.dart' as chess;

import '../../domain/training/puzzle_evaluator.dart';

/// Presentation inputs for a chessground board.
///
/// The adapter keeps the domain's string-based square notation at the
/// boundary and converts it to dartchess values used by chessground.
final class ChessboardViewData {
  const ChessboardViewData({required this.game, required this.orientation});

  /// Position, side to move, legal destinations, and previous move.
  final chessground.GameData game;

  /// Which side is shown at the bottom of the board.
  final chess.Side orientation;
}

/// Converts domain position data into the values expected by chessground.
abstract final class ChessboardAdapter {
  /// Creates board inputs from a FEN and domain-provided legal destinations.
  ///
  /// Destination keys and values use algebraic squares such as `e2` and
  /// `e4`. [lastMoveUci], when present, must be a valid UCI move.
  static ChessboardViewData fromPosition({
    required String fen,
    required PuzzleSide sideToMove,
    required Map<String, Set<String>> legalDestinations,
    required PuzzleSide orientation,
    String? lastMoveUci,
  }) {
    if (fen.isEmpty) {
      throw ArgumentError.value(fen, 'fen', 'Must not be empty.');
    }

    final validMoves = <chess.Square, Set<chess.Square>>{
      for (final entry in legalDestinations.entries)
        chess.Square.fromName(entry.key): {
          for (final destination in entry.value)
            chess.Square.fromName(destination),
        },
    };
    final lastMove = lastMoveUci == null
        ? null
        : chess.Move.parse(lastMoveUci) ??
              (throw FormatException('Invalid UCI move: $lastMoveUci'));
    final side = _toChessSide(sideToMove);

    return ChessboardViewData(
      game: chessground.GameData(
        fen: fen,
        playerSide: chessground.PlayerSide.none,
        sideToMove: side,
        validMoves: validMoves,
        lastMove: lastMove,
      ),
      orientation: _toChessSide(orientation),
    );
  }

  static chess.Side _toChessSide(PuzzleSide side) => switch (side) {
    PuzzleSide.white => chess.Side.white,
    PuzzleSide.black => chess.Side.black,
  };
}
