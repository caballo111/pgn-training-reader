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
      expect(find.byIcon(Icons.biotech_outlined), findsOneWidget);
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

  testWidgets('solve mode offers a book toggle and hides unavailable actions', (
    tester,
  ) async {
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
      'More board actions',
      'Next block',
    ]) {
      expect(find.byTooltip(label), findsNothing);
    }
    await tester.tap(find.byTooltip('Switch to read mode'));
    expect(read, isTrue);
    expect(find.byTooltip('Back to book'), findsOneWidget);
  });

  testWidgets('empty toolbar takes no space and actions track availability', (
    tester,
  ) async {
    Widget toolbar({VoidCallback? analyze}) => MaterialApp(
      home: Scaffold(
        body: Center(child: StudyActionToolbar(onAnalyze: analyze)),
      ),
    );
    var calls = 0;
    await tester.pumpWidget(toolbar());
    expect(tester.getSize(find.byType(StudyActionToolbar)), Size.zero);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(PopupMenuButton<int>), findsNothing);

    await tester.pumpWidget(toolbar(analyze: () => calls++));
    expect(find.byIcon(Icons.biotech_outlined), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
    await tester.tap(find.byTooltip('Analyze position'));
    expect(calls, 1);

    await tester.pumpWidget(toolbar());
    expect(find.byTooltip('Analyze position'), findsNothing);
    expect(tester.getSize(find.byType(StudyActionToolbar)), Size.zero);
  });

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
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(
        tester.getSize(find.byTooltip('More board actions')).width,
        greaterThanOrEqualTo(48),
      );
      expect(tester.getRect(find.byTooltip('More board actions')).right, 240);
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
