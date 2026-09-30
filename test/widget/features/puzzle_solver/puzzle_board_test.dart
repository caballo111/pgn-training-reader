import 'package:chessground/chessground.dart' as chessground;
import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/training/puzzle_evaluator.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_board.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

Widget _host({
  required PuzzleSide orientation,
  required ValueChanged<String> onMoveSubmitted,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 320,
        child: PuzzleBoard(
          fen: _startFen,
          sideToMove: PuzzleSide.white,
          legalDestinations: const {
            'e2': {'e4'},
          },
          orientation: orientation,
          onMoveSubmitted: onMoveSubmitted,
        ),
      ),
    ),
  ),
);

Future<void> _tapSquare(
  WidgetTester tester,
  String square, {
  required chess.Side orientation,
}) async {
  final rect = tester.getRect(find.byType(chessground.Chessboard));
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.parse(square[1]) - 1;
  final column = orientation == chess.Side.white ? file : 7 - file;
  final row = orientation == chess.Side.white ? 7 - rank : rank;
  await tester.tapAt(
    rect.topLeft +
        Offset((column + 0.5) * rect.width / 8, (row + 0.5) * rect.height / 8),
  );
  await tester.pump();
}

void main() {
  testWidgets('uses orientation preference and only supplied destinations', (
    tester,
  ) async {
    final submitted = <String>[];
    await tester.pumpWidget(
      _host(orientation: PuzzleSide.black, onMoveSubmitted: submitted.add),
    );

    final board = tester.widget<chessground.Chessboard>(
      find.byType(chessground.Chessboard),
    );
    expect(board.orientation, chess.Side.black);
    expect(board.controller.game.playerSide, chessground.PlayerSide.white);
    expect(board.controller.game.validMoves, {
      chess.Square.e2: {chess.Square.e4},
    });

    // Black orientation puts e2 at the mirrored file and rank coordinates.
    await _tapSquare(tester, 'e2', orientation: chess.Side.black);
    await _tapSquare(tester, 'e3', orientation: chess.Side.black);
    expect(submitted, isEmpty);
    expect(find.text('Next'), findsNothing);
    expect(find.text('Previous'), findsNothing);
  });

  testWidgets('submits a move selected from the supplied legal destinations', (
    tester,
  ) async {
    final submitted = <String>[];
    await tester.pumpWidget(
      _host(orientation: PuzzleSide.white, onMoveSubmitted: submitted.add),
    );

    await _tapSquare(tester, 'e2', orientation: chess.Side.white);
    await _tapSquare(tester, 'e4', orientation: chess.Side.white);

    expect(submitted, ['e2e4']);
    expect(find.text('Next'), findsNothing);
    expect(find.text('Previous'), findsNothing);
  });
}
