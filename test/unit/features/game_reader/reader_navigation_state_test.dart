import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/features/game_reader/application/reader_navigation_state.dart';

void main() {
  const startFen = 'start';
  const afterA = 'after-a';
  const afterB = 'after-b';
  const afterC = 'after-c';
  const afterD = 'after-d';

  final mainA = MoveNode(
    san: 'a',
    uci: 'a1a2',
    fenBefore: startFen,
    fenAfter: afterA,
    children: [
      MoveNode(
        san: 'b',
        uci: 'b1b2',
        fenBefore: afterA,
        fenAfter: afterB,
        children: [
          MoveNode(san: 'c', uci: 'c1c2', fenBefore: afterB, fenAfter: afterC),
        ],
      ),
      MoveNode(san: 'd', uci: 'd1d2', fenBefore: afterA, fenAfter: afterD),
    ],
  );
  final content = ChessContent(
    headers: const {},
    startingFen: startFen,
    rootMoves: [mainA],
    contentType: ContentType.demonstration,
  );

  test('navigates first, previous, next, and last along the main line', () {
    final initial = ReaderNavigationState.initial(content);
    expect(initial.currentFen, startFen);
    expect(initial.canPrevious, isFalse);

    final atA = initial.next();
    expect(atA.currentNode, mainA);
    expect(atA.currentFen, afterA);
    expect(atA.previous().currentFen, startFen);
    expect(atA.last().currentFen, afterC);
    expect(atA.last().first().currentFen, startFen);
    expect(atA.last().canNext, isFalse);
    expect(atA.last().next().currentFen, afterC);
  });

  test('selects a variation and returns to its parent line', () {
    final atA = ReaderNavigationState.initial(content).next();
    expect(atA.availableMoves.map((move) => move.san), ['b', 'd']);

    final onVariation = atA.selectVariation(1);
    expect(onVariation.currentNode?.san, 'd');
    expect(onVariation.currentFen, afterD);
    expect(onVariation.returnToParentLine().currentNode?.san, 'b');
    expect(onVariation.returnToParentLine().currentFen, afterB);
    expect(atA.selectVariation(2), same(atA));
  });

  test('keeps the starting FEN for content without moves', () {
    final empty = ReaderNavigationState.initial(
      ChessContent(
        headers: const {},
        startingFen: startFen,
        contentType: ContentType.instruction,
      ),
    );
    expect(empty.currentFen, startFen);
    expect(empty.first().currentFen, startFen);
    expect(empty.last().currentFen, startFen);
  });
}
