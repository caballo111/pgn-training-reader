import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/shared/presentation/study_action_toolbar.dart';

void main() {
  testWidgets(
    'six icon actions fit a phone and invoke their distinct callbacks',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final actions = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: StudyActionToolbar(
                onPreviousBlock: () => actions.add('previous'),
                onToggleMode: () => actions.add('solve'),
                onReset: () => actions.add('reset'),
                onAnalyze: () => actions.add('analyze'),
                onNextBlock: () => actions.add('next'),
                onFlip: () => actions.add('flip'),
              ),
            ),
          ),
        ),
      );
      for (final label in [
        'Previous block',
        'Switch to solve mode',
        'Reset board',
        'Analyze position',
        'Next block',
      ]) {
        final target = find.byTooltip(label);
        final rect = tester.getRect(target);
        expect(rect.width, greaterThanOrEqualTo(48 - 1e-9));
        expect(rect.height, greaterThanOrEqualTo(48 - 1e-9));
        expect(rect.left, greaterThanOrEqualTo(12));
        expect(rect.right, lessThanOrEqualTo(308));
        await tester.tap(target);
      }
      expect(actions, ['previous', 'solve', 'reset', 'analyze', 'next']);
      expect(
        tester.getRect(find.byTooltip('More board actions')).left,
        greaterThan(tester.getRect(find.byTooltip('Next block')).left),
      );
      await tester.tap(find.byTooltip('More board actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flip board'));
      await tester.pumpAndSettle();
      expect(actions.last, 'flip');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'solve mode offers a book toggle and disables unavailable actions',
    (tester) async {
      var read = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudyActionToolbar(
              solving: true,
              onToggleMode: () => read = true,
              onNextBlock: () {},
              nextLabel: 'Back to book',
            ),
          ),
        ),
      );
      expect(find.byType(StudySolveIcon), findsNothing);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.byTooltip('Switch to solve mode'), findsNothing);
      for (final label in [
        'Reset board',
        'Analyze position',
        'Previous block',
      ]) {
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) => widget is IconButton && widget.tooltip == label,
                ),
              )
              .onPressed,
          isNull,
        );
      }
      await tester.tap(find.byTooltip('Switch to read mode'));
      expect(read, isTrue);
      expect(find.byTooltip('Back to book'), findsOneWidget);
    },
  );

  testWidgets(
    'more menu exposes board size and assistance without shrinking targets',
    (tester) async {
      tester.view.physicalSize = const Size(240, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var expanded = false;
      var hint = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudyActionToolbar(
              compactBoard: true,
              onToggleBoardSize: () => expanded = true,
              extraMenuItems: [
                StudyMenuAction(
                  'Hint',
                  Icons.lightbulb_outline,
                  () => hint = true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-180, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More board actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expand board'));
      await tester.pumpAndSettle();
      expect(expanded, isTrue);
      await tester.tap(find.byTooltip('More board actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hint'));
      await tester.pumpAndSettle();
      expect(hint, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
