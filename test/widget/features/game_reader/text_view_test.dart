import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/features/game_reader/presentation/reader_board.dart';
import 'package:pgntrainingreader/features/game_reader/presentation/text_view.dart';

void main() {
  final content = ChessContent(
    headers: const {},
    startingFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    contentType: ContentType.text,
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

  testWidgets('prose hides board and controls; FEN shows a static board', (
    tester,
  ) async {
    for (final hasPosition in [false, true]) {
      final text = ChessContent(
        headers: hasPosition
            ? {'FEN': content.startingFen, 'X-ContentType': 'Text'}
            : const {'X-ContentType': 'Text'},
        startingFen: content.startingFen,
        contentType: ContentType.text,
        comments: const ['Read this lesson.'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextView(content: text)),
        ),
      );
      expect(find.text('Read this lesson.'), findsOneWidget);
      expect(
        find.text('White to move'),
        hasPosition ? findsOneWidget : findsNothing,
      );
      expect(find.byTooltip('Next move'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('combines board, annotations, and navigable move tree', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TextView(content: content)),
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

  testWidgets('rejects content that is not text', (tester) async {
    final puzzle = ChessContent(
      headers: const {},
      startingFen: content.startingFen,
      contentType: ContentType.puzzle,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TextView(content: puzzle)),
      ),
    );
    expect(find.text('This content is not text material.'), findsOneWidget);
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
        home: Scaffold(body: TextView(content: content)),
      ),
    );

    expect(find.text('White to move'), findsOneWidget);
    String orientation() => tester
        .widget<ReaderBoard>(find.byType(ReaderBoard))
        .board
        .orientation
        .name;
    expect(orientation(), 'white');
    await tester.tap(find.byTooltip('Flip board'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Flip board'), findsOneWidget);
    expect(orientation(), 'black');

    await tester.tap(find.byTooltip('Next move'));
    await tester.pumpAndSettle();
    expect(find.text('Black to move'), findsOneWidget);
    expect(find.byTooltip('Flip board'), findsOneWidget);
    expect(orientation(), 'black');

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
      contentType: ContentType.text,
      comments: List.generate(8, (index) => 'Introductory note ${index + 1}.'),
      rootMoves: content.rootMoves,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: Scaffold(body: TextView(content: longCommentContent)),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Introductory note 8.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Introductory note 8.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('e4'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('e4'), findsOneWidget);
  });
}
