import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/features/game_reader/presentation/demonstration_view.dart';

void main() {
  final content = ChessContent(
    headers: const {},
    startingFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    contentType: ContentType.demonstration,
    comments: const ['Model game: open with the king pawn.'],
    rootMoves: [
      MoveNode(
        san: 'e4',
        uci: 'e2e4',
        fenBefore: 'ignored',
        fenAfter: 'ignored',
        comments: const ['White claims the center.'],
        nags: const [1],
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
            comments: const ['The Sicilian Defense.'],
          ),
        ],
      ),
    ],
  );

  testWidgets('combines board, annotations, and navigable move tree', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DemonstrationView(content: content)),
      ),
    );

    expect(find.text('White to move'), findsOneWidget);
    expect(find.text('Model game: open with the king pawn.'), findsOneWidget);
    expect(find.text('White claims the center.'), findsOneWidget);
    expect(find.text('\$1'), findsOneWidget);
    expect(find.text('Variation 1'), findsOneWidget);

    await tester.tap(find.text('e4'));
    await tester.pumpAndSettle();
    expect(find.text('Black to move'), findsOneWidget);

    await tester.tap(find.text('c5'));
    await tester.pumpAndSettle();
    expect(find.text('White to move'), findsOneWidget);
    expect(find.text('The Sicilian Defense.'), findsOneWidget);
  });

  testWidgets('rejects content that is not a demonstration', (tester) async {
    final instruction = ChessContent(
      headers: const {},
      startingFen: content.startingFen,
      contentType: ContentType.instruction,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DemonstrationView(content: instruction)),
      ),
    );
    expect(tester.takeException(), isA<ArgumentError>());
  });

  testWidgets('navigation controls and board orientation remain available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DemonstrationView(content: content)),
      ),
    );

    expect(find.text('White to move'), findsOneWidget);
    expect(find.text('Rotate: Black at bottom'), findsOneWidget);
    await tester.tap(find.text('Rotate: Black at bottom'));
    await tester.pumpAndSettle();
    expect(find.text('Rotate: White at bottom'), findsOneWidget);

    await tester.tap(find.byTooltip('Next move'));
    await tester.pumpAndSettle();
    expect(find.text('Black to move'), findsOneWidget);

    await tester.tap(find.byTooltip('Last move on main line'));
    await tester.pumpAndSettle();
    expect(find.text('White to move'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous move'));
    await tester.pumpAndSettle();
    expect(find.text('Black to move'), findsOneWidget);

    await tester.tap(find.byTooltip('Starting position'));
    await tester.pumpAndSettle();
    expect(find.text('White to move'), findsOneWidget);
  });

  testWidgets('fits a narrow phone with enlarged text and long comments', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final longCommentContent = ChessContent(
      headers: const {},
      startingFen: content.startingFen,
      contentType: ContentType.demonstration,
      comments: List.generate(8, (index) => 'Introductory note ${index + 1}.'),
      rootMoves: content.rootMoves,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: Scaffold(
              body: DemonstrationView(content: longCommentContent),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('White to move'), findsOneWidget);
    expect(find.text('Introductory note 8.'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('e4'), findsOneWidget);
  });
}
