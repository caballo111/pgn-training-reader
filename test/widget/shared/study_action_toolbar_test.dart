import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/shared/presentation/study_action_toolbar.dart';

Widget _host(Widget toolbar) => MaterialApp(
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(12), child: toolbar),
  ),
);

void main() {
  testWidgets('previous and next stay anchored while context changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final actions = <String>[];
    var solving = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return StudyActionToolbar(
                  solving: solving,
                  onPreviousBlock: () => actions.add('previous'),
                  onToggleMode: () => actions.add('toggle'),
                  onReset: () => actions.add('reset'),
                  onNextBlock: () => actions.add('next'),
                  onFlip: () => actions.add('flip'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final previous = find.byTooltip('Previous block');
    final next = find.byTooltip('Next block');
    final previousRect = tester.getRect(previous);
    final nextRect = tester.getRect(next);

    // Navigation is pinned to the leading and trailing page edges.
    expect(previousRect.left, 12);
    expect(nextRect.right, 308);
    expect(previousRect.width, greaterThanOrEqualTo(48));
    expect(nextRect.width, greaterThanOrEqualTo(48));

    // The single contextual slot is reserved at the true center of the bar.
    final toolbarRect = tester.getRect(find.byType(StudyActionToolbar));
    expect(
      tester.getRect(find.byTooltip('Switch to solve mode')).center.dx,
      closeTo(toolbarRect.center.dx, 0.5),
    );

    // Crossfading the contextual action must not move either anchor.
    rebuild(() => solving = true);
    await tester.pump(const Duration(milliseconds: 90));
    expect(find.byType(StudySolveIcon), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(StudySolveIcon), findsNothing);
    expect(tester.getRect(previous), previousRect);
    expect(tester.getRect(next), nextRect);

    // Secondary actions living in the overflow must not move them either.
    await tester.tap(find.byTooltip('Switch to read mode'));
    await tester.pumpAndSettle();
    expect(actions.last, 'toggle');
    expect(tester.getRect(previous), previousRect);
    expect(tester.getRect(next), nextRect);

    final overflow = tester.getRect(find.byTooltip('More board actions'));
    expect(overflow.left, greaterThan(previousRect.right));
    expect(overflow.right, lessThanOrEqualTo(nextRect.left));
    expect(overflow.width, greaterThanOrEqualTo(48));

    await tester.tap(previous);
    await tester.tap(next);
    expect(actions, containsAllInOrder(['previous', 'next']));
    expect(tester.takeException(), isNull);
  });

  testWidgets('contextual action rises and fades into its reserved slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(StudyActionToolbar(onToggleMode: () {}, onNextBlock: () {})),
    );

    // First frame reserves the slot with the action hidden and lowered.
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      const Offset(0, 0.18),
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );

    await tester.pump();
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      Offset.zero,
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Switch to solve mode'), findsOneWidget);
    expect(find.byType(StudySolveIcon), findsOneWidget);
  });

  testWidgets('overflow holds every secondary action at a full target size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final actions = <String>[];
    await tester.pumpWidget(
      _host(
        StudyActionToolbar(
          compactBoard: true,
          onPreviousBlock: () {},
          onNextBlock: () {},
          onReset: () => actions.add('reset'),
          onAnalyze: () => actions.add('analyze'),
          onFlip: () => actions.add('flip'),
          onToggleBoardSize: () => actions.add('expand'),
          extraMenuItems: [
            StudyMenuAction('Hint', Icons.lightbulb_outline, () {
              actions.add('hint');
            }),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in [
      'Reset board',
      'Analyze position',
      'Flip board',
      'Expand board',
      'Hint',
    ]) {
      expect(find.byTooltip(label), findsNothing);
    }
    expect(tester.getSize(find.byTooltip('More board actions')).width, 48);

    await tester.tap(find.byTooltip('More board actions'));
    await tester.pumpAndSettle();
    for (final label in [
      'Reset board',
      'Analyze position',
      'Flip board',
      'Expand board',
      'Hint',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Reset board'));
    await tester.pumpAndSettle();
    expect(actions, ['reset']);

    await tester.tap(find.byTooltip('More board actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hint'));
    await tester.pumpAndSettle();
    expect(actions, ['reset', 'hint']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled navigation keeps its slot from moving', (tester) async {
    var next = 0;
    await tester.pumpWidget(
      _host(StudyActionToolbar(onNextBlock: () => next++)),
    );
    await tester.pumpAndSettle();

    // Previous is unavailable, but its slot is still reserved at the edge.
    final previous = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.skip_previous),
        matching: find.byType(IconButton),
      ),
    );
    expect(previous.onPressed, isNull);
    expect(tester.getRect(find.byTooltip('Previous block')).left, 12);

    await tester.tap(find.byTooltip('Next block'));
    expect(next, 1);
  });

  testWidgets('solving swaps the contextual action to the book', (
    tester,
  ) async {
    var read = false;
    await tester.pumpWidget(
      _host(StudyActionToolbar(solving: true, onToggleMode: () => read = true)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StudySolveIcon), findsNothing);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    expect(find.byTooltip('Switch to solve mode'), findsNothing);
    expect(find.byTooltip('More board actions'), findsNothing);

    await tester.tap(find.byTooltip('Switch to read mode'));
    expect(read, isTrue);
  });

  testWidgets('toolbar with no actions takes no space', (tester) async {
    await tester.pumpWidget(_host(const StudyActionToolbar()));
    expect(tester.getSize(find.byType(StudyActionToolbar)), Size.zero);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(PopupMenuButton<int>), findsNothing);
  });
}
