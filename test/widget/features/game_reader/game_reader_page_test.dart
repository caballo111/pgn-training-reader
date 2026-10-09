import 'package:flutter/material.dart';
import 'package:pgntrainingreader/data/pgn/dartchess_content_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/features/game_reader/presentation/game_reader_page.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

ChessContent _content(ContentType type) => ChessContent(
  headers: const {'X-Title': 'Reader test'},
  startingFen: _startFen,
  contentType: type,
  rootMoves: [
    MoveNode(
      san: 'secret solution',
      uci: 'e2e4',
      fenBefore: _startFen,
      fenAfter: 'ignored',
    ),
  ],
);

void main() {
  testWidgets('block navigation invokes callbacks and disables boundaries', (
    tester,
  ) async {
    var previous = 0;
    var next = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GameReaderPage(
          content: _content(ContentType.puzzle),
          showBlockNavigation: true,
          onPreviousBlock: () => previous++,
          onNextBlock: () => next++,
        ),
      ),
    );
    await tester.tap(find.text('Previous block'));
    await tester.tap(find.text('Next block'));
    expect(previous, 1);
    expect(next, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: GameReaderPage(
          content: _content(ContentType.puzzle),
          showBlockNavigation: true,
        ),
      ),
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Previous block'))
          .onPressed,
      isNull,
    );
    expect(find.text('Next block'), findsNothing);
    expect(find.text('Back to book'), findsOneWidget);
  });

  for (final token in ['Z0', '--']) {
    testWidgets(
      '$token introduction opens as non-scored content and saves an override',
      (tester) async {
        final content = const DartchessContentParser().parse(
          '[White "1) Introduction"]\n\n{Read this first} 1. $token *',
          contentType: ContentType.text,
        );
        ContentType? saved;
        var puzzleCalls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: GameReaderPage(
              content: content,
              onClassificationOverride: (type) async {
                saved = type;
              },
              puzzleViewBuilder: (_, _, _) {
                puzzleCalls++;
                return const Text('Solver');
              },
            ),
          ),
        );
        expect(find.text('Read this first'), findsOneWidget);
        expect(puzzleCalls, 0);
        await tester.tap(find.byTooltip('Change content type'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Study text / game'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(saved, ContentType.text);
        expect(find.text('Read this first'), findsOneWidget);
        expect(puzzleCalls, 0);
      },
    );
  }

  testWidgets('routes text content to TextView', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: GameReaderPage(content: _content(ContentType.text))),
    );

    expect(find.text('Reader test'), findsOneWidget);
    expect(find.text('secret solution'), findsOneWidget);
  });

  testWidgets('routes text with moves to the board reader', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: GameReaderPage(content: _content(ContentType.text))),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'White to move',
      ),
      findsOneWidget,
    );
    expect(find.text('secret solution'), findsOneWidget);
  });

  testWidgets('Back to book returns one nested exploration first', (
    tester,
  ) async {
    var exploring = true;
    var returned = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GameReaderPage(
          content: _content(ContentType.text),
          showBlockNavigation: true,
          isNestedExploring: () => exploring,
          onReturnFromExploration: () async {
            returned++;
            exploring = false;
          },
        ),
      ),
    );

    await tester.tap(find.text('Back to book'));
    await tester.pumpAndSettle();

    expect(returned, 1);
    expect(find.byType(GameReaderPage), findsOneWidget);
    expect(find.text('secret solution'), findsOneWidget);
  });

  testWidgets('delegates puzzles to the injected puzzle view', (tester) async {
    final puzzle = _content(ContentType.puzzle);
    ChessContent? received;

    await tester.pumpWidget(
      MaterialApp(
        home: GameReaderPage(
          content: puzzle,
          puzzleViewBuilder: (context, content, _) {
            received = content;
            return const Text('Injected puzzle solver');
          },
        ),
      ),
    );

    expect(received, same(puzzle));
    expect(find.text('Injected puzzle solver'), findsOneWidget);
  });

  testWidgets('does not expose a puzzle title hint in text or semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final puzzle = ChessContent(
      headers: const {'X-Title': 'Mate on h7', 'Event': 'Winning tactic'},
      startingFen: _startFen,
      contentType: ContentType.puzzle,
      rootMoves: _content(ContentType.puzzle).rootMoves,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameReaderPage(
          content: puzzle,
          puzzleViewBuilder: (context, content, _) => const Text('Puzzle view'),
        ),
      ),
    );

    expect(find.text('Puzzle'), findsOneWidget);
    expect(find.text('Mate on h7'), findsNothing);
    expect(find.text('Winning tactic'), findsNothing);
    expect(find.bySemanticsLabel('Mate on h7'), findsNothing);
    expect(find.bySemanticsLabel('Winning tactic'), findsNothing);
    semantics.dispose();
  });

  testWidgets('does not show solution moves without an injected puzzle view', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: GameReaderPage(content: _content(ContentType.puzzle))),
    );

    expect(find.text('Puzzle practice is not available yet.'), findsOneWidget);
    expect(find.text('secret solution'), findsNothing);
  });

  testWidgets(
    'unsupported classification can be corrected using only Puzzle or Text',
    (tester) async {
      ContentType? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: GameReaderPage(
            content: _content(ContentType.unsupported),
            onClassificationOverride: (type) async {
              saved = type;
            },
          ),
        ),
      );
      final menu = tester.widget<PopupMenuButton<ContentType>>(
        find.byType(PopupMenuButton<ContentType>),
      );
      expect(menu.enabled, isTrue);
      await tester.tap(find.byTooltip('Change content type'));
      await tester.pumpAndSettle();
      expect(find.text('Study text / game'), findsOneWidget);
      await tester.tap(find.text('Study text / game'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(saved, ContentType.text);
      expect(find.text('secret solution'), findsOneWidget);
    },
  );

  testWidgets('shows a safe fallback for unsupported content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameReaderPage(content: _content(ContentType.unsupported)),
      ),
    );

    expect(
      find.text('This content type is not supported for display.'),
      findsOneWidget,
    );
    expect(find.text('secret solution'), findsNothing);
  });
}
