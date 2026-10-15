import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/shared/chessboard/move_arrows.dart';

void main() {
  test('sanitizes malformed and duplicate moves and caps at three', () {
    expect(
      ChessboardMoveArrows.sanitizeMoves([
        '',
        'e2e4',
        'e2e4',
        'invalid',
        'e7e5',
        'g1f3',
        'b8c6',
      ]),
      ['e2e4', 'e7e5', 'g1f3'],
    );
    expect(ChessboardMoveArrows.sanitizeMoves(['N@f7']), isEmpty);
  });

  test('maps source and target square centers for either orientation', () {
    final white = ChessboardMoveArrows.normalizedEndpointsFor(
      'e2e4',
      chess.Side.white,
    );
    final black = ChessboardMoveArrows.normalizedEndpointsFor(
      'e2e4',
      chess.Side.black,
    );

    expect(white?.start, const Offset(4.5 / 8, 6.5 / 8));
    expect(white?.end, const Offset(4.5 / 8, 4.5 / 8));
    expect(black?.start, const Offset(3.5 / 8, 1.5 / 8));
    expect(black?.end, const Offset(3.5 / 8, 3.5 / 8));
    expect(
      ChessboardMoveArrows.normalizedEndpointsFor('', chess.Side.white),
      isNull,
    );
  });

  testWidgets('arrow overlay does not intercept board gestures', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 200,
              child: ChessboardMoveArrows(
                moves: const ['e2e4'],
                orientation: chess.Side.white,
                child: GestureDetector(
                  onTap: () => tapped = true,
                  child: const ColoredBox(
                    key: ValueKey<String>('arrow-overlay-tap-target'),
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('arrow-overlay-tap-target')));
    expect(tapped, isTrue);
    expect(
      find.byKey(const ValueKey('chessboard-move-arrows')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
