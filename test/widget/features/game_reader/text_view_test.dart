import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/analysis/exploration_repository.dart';
import 'package:pgntrainingreader/domain/analysis/exploration_session.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/features/analysis/presentation/exploration_board.dart';
import 'package:pgntrainingreader/features/analysis/presentation/exploration_workspace.dart';
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

  Finder readerDetailsScrollable() => find
      .descendant(
        of: find.byKey(const ValueKey('reader-details')),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> selectBoardAction(WidgetTester tester, String label) async {
    final inline = find.byTooltip(label);
    if (inline.evaluate().isNotEmpty) {
      await tester.tap(inline);
    } else {
      await tester.tap(find.byTooltip('More board actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('prose disables board actions; FEN shows a static board', (
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
        find.byTooltip('More board actions'),
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
    await selectBoardAction(tester, 'Flip board');
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
    expect(find.byTooltip('More board actions'), findsOneWidget);
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
        scrollable: readerDetailsScrollable(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('e4'));
      await tester.pumpAndSettle();
      await selectBoardAction(tester, 'Flip board');
      await tester.drag(
        find.byKey(const ValueKey('reader-details')),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      final scrollBefore = tester
          .state<ScrollableState>(readerDetailsScrollable())
          .position
          .pixels;

      await selectBoardAction(tester, 'Analyze position');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Return to reading'), findsOneWidget);
      expect(repository.loadedOrigin?.scopeId, 'source-a-revision-7');
      expect(repository.loadedOrigin?.authoredPath, [0]);
      expect(repository.loadedOrigin?.authoredMoves, ['e2e4']);
      expect(repository.loadedOrigin?.label, '1. e4');

      await tester.tap(find.byTooltip('Return to reading'));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<ScrollableState>(readerDetailsScrollable())
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

  testWidgets('Analyze opens the saved current-origin exploration', (
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

    await selectBoardAction(tester, 'Analyze position');
    await tester.pumpAndSettle();
    expect(find.byType(ExplorationWorkspace), findsOneWidget);
    expect(repository.loadedOrigin?.identityKey, origin.identityKey);
    expect(find.text('Resume exploration'), findsNothing);
  });

  testWidgets('Analyze snapshots the selected origin and orientation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _RecordingExplorationRepository();
    final snapshotContent = ChessContent(
      headers: const {},
      startingFen: content.startingFen,
      contentType: ContentType.text,
      comments: List.generate(12, (index) => 'Snapshot note ${index + 1}.'),
      rootMoves: content.rootMoves,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextView(
            content: snapshotContent,
            explorationScopeId: 'snapshot-source',
            explorationRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await selectBoardAction(tester, 'Flip board');
    await tester.scrollUntilVisible(
      find.text('e4'),
      120,
      scrollable: readerDetailsScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('e4'));
    await tester.pumpAndSettle();
    final details = tester.state<ScrollableState>(readerDetailsScrollable());
    final tapScrollOffset = details.position.pixels;
    expect(tapScrollOffset, greaterThan(0));
    await selectBoardAction(tester, 'Analyze position');
    await tester.pumpAndSettle();
    expect(find.text('Exploring from 1. e4'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(repository.loadedOrigin?.authoredPath, [0]);
    expect(repository.loadedOrigin?.authoredMoves, ['e2e4']);
    expect(repository.loadedOrigin?.label, '1. e4');
    expect(
      tester
          .widget<ExplorationBoard>(find.byType(ExplorationBoard))
          .orientation
          .name,
      'black',
    );
    await tester.tap(find.byTooltip('Return to reading'));
    await tester.pumpAndSettle();
    final restoredDetails = tester.state<ScrollableState>(
      readerDetailsScrollable(),
    );
    expect(restoredDetails.position.pixels, closeTo(tapScrollOffset, 0.5));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Black to move',
      ),
      findsOneWidget,
    );
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
    await selectBoardAction(tester, 'Analyze position');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Book context at'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('e5'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Return to reading'), findsNothing);
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

    expect(find.byTooltip('More board actions'), findsOneWidget);
    final entryTop = tester.getTopLeft(find.byTooltip('More board actions')).dy;
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Introductory note 8.'),
      120,
      scrollable: readerDetailsScrollable(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Introductory note 8.'), findsOneWidget);
    expect(find.byTooltip('More board actions'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byTooltip('More board actions')).dy,
      entryTop,
    );
    await tester.scrollUntilVisible(
      find.text('e4'),
      150,
      scrollable: readerDetailsScrollable(),
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
