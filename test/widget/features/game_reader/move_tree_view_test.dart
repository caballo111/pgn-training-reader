import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/features/game_reader/application/reader_navigation_state.dart';
import 'package:pgntrainingreader/features/game_reader/presentation/move_tree_view.dart';

void main() {
  final content = ChessContent(
    headers: const {},
    startingFen: 'starting position',
    contentType: ContentType.demonstration,
    rootMoves: [
      MoveNode(
        san: 'e4',
        uci: 'e2e4',
        fenBefore: 'start',
        fenAfter: 'after e4',
        comments: const ['A central pawn move.'],
        nags: const [1, 14],
        children: [
          MoveNode(
            san: 'e5',
            uci: 'e7e5',
            fenBefore: 'after e4',
            fenAfter: 'after e5',
          ),
          MoveNode(
            san: 'c5',
            uci: 'c7c5',
            fenBefore: 'after e4',
            fenAfter: 'after c5',
            comments: const ['The Sicilian Defense.'],
          ),
        ],
      ),
    ],
  );

  testWidgets('shows moves, branches, comments, and NAG annotations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoveTreeView(
            content: content,
            navigation: ReaderNavigationState.initial(content),
            onNavigationChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('e4'), findsOneWidget);
    expect(find.text('e5'), findsOneWidget);
    expect(find.text('c5'), findsOneWidget);
    expect(find.text('Variation 1'), findsOneWidget);
    expect(find.text('A central pawn move.'), findsOneWidget);
    expect(find.text('The Sicilian Defense.'), findsOneWidget);
    expect(find.text('\$1 \$14'), findsOneWidget);
  });

  testWidgets('selecting a move reports a navigation cursor at that move', (
    tester,
  ) async {
    ReaderNavigationState? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoveTreeView(
            content: content,
            navigation: ReaderNavigationState.initial(content),
            onNavigationChanged: (state) => selected = state,
          ),
        ),
      ),
    );

    await tester.tap(find.text('c5'));
    await tester.pump();

    expect(selected?.currentNode?.san, 'c5');
    expect(selected?.path.map((node) => node.san), ['e4', 'c5']);
  });
}
