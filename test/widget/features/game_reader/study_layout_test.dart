import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/shared/presentation/flip_board_button.dart';
import 'package:pgntrainingreader/shared/presentation/study_layout.dart';
import 'package:pgntrainingreader/shared/presentation/study_navigation_controls.dart';
import 'package:pgntrainingreader/shared/presentation/study_move_button.dart';

void main() {
  testWidgets(
    'shrinks the board to preserve details on a short phone with large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 520);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: StudyLayout(
                board: const ColoredBox(
                  key: ValueKey('study-board'),
                  color: Colors.black,
                  child: AspectRatio(aspectRatio: 1),
                ),
                controls: StudyNavigationControls(
                  canPrevious: true,
                  canNext: true,
                  onFirst: () {},
                  onPrevious: () {},
                  onNext: () {},
                  onLast: () {},
                  onFlip: () {},
                ),
                details: SizedBox(
                  key: ValueKey('study-details'),
                  child: ListView(
                    children: [
                      Text('Supporting details'),
                      StudyMoveButton(label: 'e4', onPressed: () {}),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final board = tester.getSize(find.byKey(const ValueKey('study-board')));
      final details = tester.getSize(
        find.byKey(const ValueKey('study-details')),
      );
      expect(board.width, lessThan(360));
      expect(board.width, board.height);
      expect(details.height, greaterThanOrEqualTo(140));
      final moveTarget = tester.getRect(find.byType(TextButton));
      expect(moveTarget.width, greaterThanOrEqualTo(48));
      expect(moveTarget.height, greaterThanOrEqualTo(48));
      for (final name in [
        'Starting position',
        'Previous move',
        'Next move',
        'Last move on main line',
        'Flip board',
      ]) {
        final rect = tester.getRect(find.byTooltip(name));
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
      }
    },
  );

  testWidgets(
    'keeps landscape board bounded and details independently visible',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 360);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudyLayout(
              board: ColoredBox(
                key: ValueKey('study-board'),
                color: Colors.black,
                child: AspectRatio(aspectRatio: 1),
              ),
              controls: FlipBoardButton(onPressed: () {}),
              details: SizedBox(
                key: ValueKey('study-details'),
                child: ListView(children: [Text('Supporting details')]),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final board = tester.getSize(find.byKey(const ValueKey('study-board')));
      final details = tester.getSize(
        find.byKey(const ValueKey('study-details')),
      );
      expect(board.width, lessThanOrEqualTo(520));
      expect(board.width, lessThan(300));
      expect(details.width, greaterThan(100));
      expect(
        tester.getRect(find.byTooltip('Flip board')).height,
        greaterThanOrEqualTo(48),
      );
    },
  );
}
