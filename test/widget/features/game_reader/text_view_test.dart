import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/analysis/analysis_engine.dart';
import 'package:pgntrainingreader/domain/analysis/exploration_repository.dart';
import 'package:pgntrainingreader/domain/analysis/exploration_session.dart';
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
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'White to move',
        ),
        hasPosition ? findsOneWidget : findsNothing,
      );
      expect(find.byTooltip('Next move'), findsNothing);
      expect(
        find.text('Explore position'),
        hasPosition ? findsOneWidget : findsNothing,
      );
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

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'White to move',
      ),
      findsOneWidget,
    );
    expect(find.text('Model game: open with the king pawn.'), findsOneWidget);
    expect(find.text('White claims the center.'), findsOneWidget);
    expect(find.text('\$1'), findsOneWidget);
    expect(find.text('Variation 1'), findsOneWidget);

    await tester.tap(find.text('e4'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Black to move',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('c5'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'White to move',
      ),
      findsOneWidget,
    );
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

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'White to move',
      ),
      findsOneWidget,
    );
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
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Black to move',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Flip board'), findsOneWidget);
    expect(orientation(), 'black');

    await tester.tap(find.byTooltip('Last move on main line'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'White to move',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Previous move'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Black to move',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Starting position'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'White to move',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'exploration keeps the authored cursor, orientation, scope, and scroll',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final readerKey = GlobalKey<TextViewState>();
      final repository = _RecordingExplorationRepository();
      final longContent = ChessContent(
        headers: const {},
        startingFen: content.startingFen,
        contentType: ContentType.text,
        comments: List.generate(10, (index) => 'Reading note ${index + 1}.'),
        rootMoves: content.rootMoves,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextView(
              key: readerKey,
              content: longContent,
              explorationScopeId: 'source-a-revision-7',
              explorationRepository: repository,
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('e4'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('e4'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Flip board'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -120));
      await tester.pumpAndSettle();
      final scrollBefore = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;

      await tester.tap(find.text('Explore position'));
      await tester.pumpAndSettle();
      expect(find.text('Return to reading'), findsOneWidget);
      expect(repository.loadedOrigin?.scopeId, 'source-a-revision-7');
      expect(repository.loadedOrigin?.authoredPath, [0]);
      expect(repository.loadedOrigin?.authoredMoves, ['e2e4']);

      await tester.tap(find.text('Return to reading'));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        closeTo(scrollBefore, 1),
      );
      expect(
        tester
            .widget<ReaderBoard>(find.byType(ReaderBoard))
            .board
            .orientation
            .name,
        'black',
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Black to move',
        ),
        findsOneWidget,
      );
      expect(readerKey.currentState?.isExploring, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('labels a saved current-origin tree as resumable', (
    tester,
  ) async {
    final repository = _RecordingExplorationRepository();
    final origin = ExplorationOrigin(
      scopeId: 'saved-source-revision',
      startingFen: content.startingFen,
      authoredPath: const [],
      authoredMoves: const [],
      label: 'Starting position',
    );
    repository.drafts[origin.identityKey] = ExplorationSession.initial(
      origin: origin,
    ).playUci('g1f3');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextView(
            content: content,
            explorationScopeId: origin.scopeId,
            explorationRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resume exploration'), findsOneWidget);
    expect(find.text('Explore position'), findsNothing);
  });

  testWidgets('an explicit engine suggestion seeds a personal line only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _RecordingExplorationRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextView(
            content: content,
            explorationScopeId: 'pv-source-revision',
            explorationRepository: repository,
            analysisEngineFactory: _SuggestionEngine.new,
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    // Keep these pumps bounded while the analysis panel can show its busy
    // indicator; pumpAndSettle would wait for that indicator's animation.
    await tester.tap(find.byType(SwitchListTile));
    for (var pump = 0; pump < 8; pump++) {
      if (find.text('Analysis ready.').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('Analysis ready.'), findsOneWidget);
    await tester.ensureVisible(find.text('Show suggestion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show suggestion'));
    await tester.pump();
    expect(find.text('Suggested line: e2e4 e7e5'), findsOneWidget);

    await tester.ensureVisible(find.text('Explore suggestion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore suggestion'));
    for (var pump = 0; pump < 8; pump++) {
      if (find.text('Return to reading').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('Return to reading'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(repository.loadedOrigin?.scopeId, 'pv-source-revision');
    expect(repository.loadedOrigin?.authoredPath, isEmpty);
    expect(repository.loadedOrigin?.authoredMoves, isEmpty);
    expect(find.text('1. e4'), findsOneWidget);
    expect(find.text('1... e5'), findsOneWidget);

    await tester.tap(find.text('Return to reading'));
    await tester.pumpAndSettle();
    final readerBoard = tester.widget<ReaderBoard>(find.byType(ReaderBoard));
    expect(readerBoard.board.game.fen, content.startingFen);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'White to move',
      ),
      findsOneWidget,
    );
    expect(repository.drafts.values.single.moves, ['e2e4', 'e7e5']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('book context authored move returns to that reader position', (
    tester,
  ) async {
    final repository = _RecordingExplorationRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextView(
            content: content,
            explorationScopeId: 'source-a-revision-7',
            explorationRepository: repository,
          ),
        ),
      ),
    );

    await tester.tap(find.text('e4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore position'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Book context at'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('e5'));
    await tester.pumpAndSettle();

    expect(find.text('Return to reading'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'White to move',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ReaderBoard>(find.byType(ReaderBoard))
          .board
          .orientation
          .name,
      'white',
    );
    expect(tester.takeException(), isNull);
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

final class _RecordingExplorationRepository implements ExplorationRepository {
  ExplorationOrigin? loadedOrigin;
  final Map<String, ExplorationSession> drafts = {};

  @override
  Future<ExplorationSession?> load(ExplorationOrigin origin) async {
    loadedOrigin = origin;
    return drafts[origin.identityKey];
  }

  @override
  Future<void> save(ExplorationSession session) async {
    drafts[session.origin.identityKey] = session;
  }
}

final class _SuggestionEngine implements AnalysisEngine {
  @override
  Stream<AnalysisResult> analyze({
    required String startingFen,
    required List<String> moves,
    required Duration budget,
  }) => Stream<AnalysisResult>.value(
    const AnalysisResult(
      depth: 12,
      centipawns: 28,
      principalVariation: ['e2e4', 'e7e5'],
      isComplete: true,
    ),
  );

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
