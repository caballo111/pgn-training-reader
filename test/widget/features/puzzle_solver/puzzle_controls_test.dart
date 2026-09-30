import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_controls.dart';

Widget _host({
  required PuzzleControlsMode mode,
  required VoidCallback onPause,
  required VoidCallback onShowSolution,
  required VoidCallback onSkip,
  VoidCallback? onRetry,
}) => MaterialApp(
  home: Scaffold(
    body: PuzzleControls(
      mode: mode,
      onPause: onPause,
      onShowSolution: onShowSolution,
      onSkip: onSkip,
      onRetry: onRetry,
    ),
  ),
);

void main() {
  testWidgets('active controls are labeled and clarify final outcomes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var paused = false;
    var revealed = false;
    var skipped = false;
    await tester.pumpWidget(
      _host(
        mode: PuzzleControlsMode.active,
        onPause: () => paused = true,
        onShowSolution: () => revealed = true,
        onSkip: () => skipped = true,
      ),
    );

    expect(find.bySemanticsLabel('Pause'), findsOneWidget);
    expect(find.bySemanticsLabel('Show solution'), findsOneWidget);
    expect(find.bySemanticsLabel('Skip'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    expect(paused, isTrue);

    await tester.tap(find.text('Show solution').first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This ends the attempt and records a revealed result. You can review the solution afterward.',
      ),
      findsOneWidget,
    );
    expect(revealed, isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(revealed, isFalse);

    await tester.tap(find.text('Show solution').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show solution').last);
    await tester.pumpAndSettle();
    expect(revealed, isTrue);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This ends the attempt and records it as skipped. The solution will be available for review.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Skip puzzle'));
    await tester.pumpAndSettle();
    expect(skipped, isTrue);
    semantics.dispose();
  });

  testWidgets('review controls show retry only when it is permitted', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var retryCount = 0;
    await tester.pumpWidget(
      _host(
        mode: PuzzleControlsMode.review,
        onPause: () {},
        onShowSolution: () {},
        onSkip: () {},
        onRetry: () => retryCount++,
      ),
    );

    expect(find.text('Solution review'), findsOneWidget);
    expect(find.bySemanticsLabel('Try again'), findsOneWidget);
    expect(
      find.text(
        'This starts a new attempt. Your previous result stays in history.',
      ),
      findsOneWidget,
    );
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Show solution'), findsNothing);
    expect(find.text('Skip'), findsNothing);
    await tester.tap(find.text('Try again'));
    expect(retryCount, 1);

    await tester.pumpWidget(
      _host(
        mode: PuzzleControlsMode.review,
        onPause: () {},
        onShowSolution: () {},
        onSkip: () {},
      ),
    );
    expect(find.text('Solution review'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    semantics.dispose();
  });
}
