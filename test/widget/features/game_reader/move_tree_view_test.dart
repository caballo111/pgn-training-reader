import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/pgn/dartchess_content_parser.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/features/game_reader/application/reader_navigation_state.dart';
import 'package:pgntrainingreader/features/game_reader/presentation/move_tree_view.dart';

void main() {
  final content = ChessContent(
    headers: const {},
    startingFen: 'starting position',
    contentType: ContentType.text,
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

  testWidgets('preserves comments around the final authored variation', (
    tester,
  ) async {
    final parsed = const DartchessContentParser().parse(
      '[SetUp "1"]\n'
      '[FEN "5rk1/2N2ppp/4p3/R1b2q2/4b3/6Q1/5PPP/5RK1 b - - 0 1"]\n'
      '1... Bxf2+ 2. Qxf2 Qxa5 3. Nxe6 Bxg2 '
      '({Before the alternative} 3... Qa8 {After the alternative}) *',
      contentType: ContentType.text,
    );
    final nxe6 =
        parsed.rootMoves.single.children.single.children.single.children.single;
    final alternative = nxe6.children[1];
    expect(alternative.san, 'Qa8');
    expect(alternative.startingComments, ['Before the alternative']);
    expect(alternative.comments, ['After the alternative']);
    expect(alternative.fenBefore, nxe6.fenAfter);
    ReaderNavigationState? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoveTreeView(
            content: parsed,
            navigation: ReaderNavigationState.initial(parsed),
            onNavigationChanged: (state) => selected = state,
          ),
        ),
      ),
    );
    final before = find.text('Before the alternative');
    final move = find.text('Qa8');
    final after = find.text('After the alternative');
    expect(tester.getTopLeft(before).dy, lessThan(tester.getTopLeft(move).dy));
    expect(tester.getTopLeft(move).dy, lessThan(tester.getTopLeft(after).dy));
    await tester.tap(move);
    expect(selected?.currentNode, alternative);
  });

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
