import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/domain/training/puzzle_evaluator.dart';
import 'package:pgntrainingreader/features/game_reader/application/game_reader_controller.dart';

void main() {
  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  final content = ChessContent(
    headers: const {'SideToMove': 'black'},
    startingFen: startFen,
    contentType: ContentType.demonstration,
    rootMoves: [
      MoveNode(
        san: 'e4',
        uci: 'e2e4',
        fenBefore: startFen,
        // Intentionally contradictory: the controller must replay UCI.
        fenAfter: '8/8/8/8/8/8/8/K6k b - - 0 1',
        children: [
          MoveNode(
            san: 'e5',
            uci: 'e7e5',
            fenBefore: 'ignored',
            fenAfter: 'ignored',
          ),
          MoveNode(
            san: 'c5',
            uci: 'c7c5',
            fenBefore: 'ignored',
            fenAfter: 'ignored',
          ),
        ],
      ),
    ],
  );

  test('derives initial and current side from replayed chess positions', () {
    final controller = GameReaderController(content);

    expect(controller.current.fen, startFen);
    expect(controller.current.sideToMove, PuzzleSide.white);
    expect(controller.current.lastMoveUci, isNull);

    controller.next();
    expect(controller.current.sideToMove, PuzzleSide.black);
    expect(
      controller.current.position.board.pieceAt(chess.Square.e4),
      isNotNull,
    );
    expect(controller.current.lastMoveUci, 'e2e4');
    expect(
      controller.current.legalDestinations['e7'],
      containsAll(['e5', 'e6']),
    );

    controller.next();
    expect(controller.current.sideToMove, PuzzleSide.white);
    expect(controller.current.lastMoveUci, 'e7e5');
    expect(controller.current.fen, contains(' w KQkq '));
  });

  test('replays the selected variation and returns to the main line', () {
    final controller = GameReaderController(content)..next();

    controller.selectVariation(1);
    expect(controller.current.lastMoveUci, 'c7c5');
    expect(controller.current.sideToMove, PuzzleSide.white);

    controller.returnToParentLine();
    expect(controller.current.lastMoveUci, 'e7e5');
    expect(controller.current.sideToMove, PuzzleSide.white);
  });

  test('rejects an illegal move in the active authored path', () {
    final invalidContent = ChessContent(
      headers: const {},
      startingFen: startFen,
      contentType: ContentType.demonstration,
      rootMoves: [
        MoveNode(
          san: 'e5',
          uci: 'e7e5',
          fenBefore: startFen,
          fenAfter: startFen,
        ),
      ],
    );

    final controller = GameReaderController(invalidContent);
    expect(() => controller.next(), throwsFormatException);
    expect(controller.navigation.canPrevious, isFalse);
  });
}
