import 'package:chessground/chessground.dart' as chessground;
import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/training/puzzle_evaluator.dart';
import 'package:pgntrainingreader/shared/chessboard/chessboard_adapter.dart';

void main() {
  group('ChessboardAdapter.fromPosition', () {
    test('maps board values and square destinations for chessground', () {
      final board = ChessboardAdapter.fromPosition(
        fen: '8/8/8/8/8/8/4P3/4K2k w - - 0 1',
        sideToMove: PuzzleSide.white,
        legalDestinations: {
          'e2': {'e3', 'e4'},
        },
        orientation: PuzzleSide.black,
        lastMoveUci: 'd2d4',
      );

      expect(board.game.fen, '8/8/8/8/8/8/4P3/4K2k w - - 0 1');
      expect(board.game.sideToMove, chess.Side.white);
      expect(board.game.playerSide, chessground.PlayerSide.none);
      expect(board.game.validMoves, {
        chess.Square.e2: {chess.Square.e3, chess.Square.e4},
      });
      expect(board.game.lastMove?.uci, 'd2d4');
      expect(board.orientation, chess.Side.black);
    });

    test('allows positions without a last move or legal destinations', () {
      final board = ChessboardAdapter.fromPosition(
        fen: '8/8/8/8/8/8/8/K6k b - - 0 1',
        sideToMove: PuzzleSide.black,
        legalDestinations: const {},
        orientation: PuzzleSide.white,
      );

      expect(board.game.lastMove, isNull);
      expect(board.game.validMoves, isEmpty);
      expect(board.game.sideToMove, chess.Side.black);
      expect(board.orientation, chess.Side.white);
    });

    test('rejects invalid board square and UCI notation', () {
      expect(
        () => ChessboardAdapter.fromPosition(
          fen: '8/8/8/8/8/8/8/K6k w - - 0 1',
          sideToMove: PuzzleSide.white,
          legalDestinations: const {
            'z9': {'e4'},
          },
          orientation: PuzzleSide.white,
        ),
        throwsFormatException,
      );
      expect(
        () => ChessboardAdapter.fromPosition(
          fen: '8/8/8/8/8/8/8/K6k w - - 0 1',
          sideToMove: PuzzleSide.white,
          legalDestinations: const {},
          orientation: PuzzleSide.white,
          lastMoveUci: 'bad',
        ),
        throwsFormatException,
      );
    });
  });
}
