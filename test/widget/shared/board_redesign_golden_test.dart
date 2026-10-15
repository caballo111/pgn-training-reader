import 'dart:io';

import 'package:chessground/chessground.dart' as chessground;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/analysis/exploration_session.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/domain/training/puzzle_evaluator.dart';
import 'package:pgntrainingreader/features/analysis/presentation/exploration_workspace.dart';
import 'package:pgntrainingreader/features/game_reader/presentation/text_view.dart';
import 'package:pgntrainingreader/shared/presentation/study_action_toolbar.dart';

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _e4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';
const _e5 = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2';

void main() {
  setUpAll(() async {
    final bytes = await File('test/golden/fonts/Roboto-Regular.ttf')
        .readAsBytes();
    await (FontLoader(
      'Roboto',
    )..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<void> phone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Roboto',
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.teal,
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('The Italian Game')),
          body: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(chessground.ChessgroundImages.instance.ready);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'phone reading keeps notes below board and icon actions at bottom',
    (tester) async {
      final content = ChessContent(
        headers: const {},
        startingFen: _fen,
        contentType: ContentType.text,
        comments: const [
          'Develop your pieces toward the center. After e4, Black can mirror with e5 before you bring out the knight.',
        ],
        rootMoves: [
          MoveNode(
            san: 'e4',
            uci: 'e2e4',
            fenBefore: _fen,
            fenAfter: _e4,
            comments: const [
              'White claims space and opens lines for the queen and bishop.',
            ],
            children: [
              MoveNode(san: 'e5', uci: 'e7e5', fenBefore: _e4, fenAfter: _e5),
            ],
          ),
        ],
      );
      await phone(
        tester,
        TextView(
          content: content,
          initialState: const {
            'path': [0],
          },
          blockActions: StudyBlockActions(
            onPrevious: () {},
            onToggleMode: () {},
            onNext: () {},
          ),
        ),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('reader-details'))).top,
        greaterThan(
          tester.getRect(find.byType(chessground.StaticChessboard)).bottom,
        ),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../golden/board_ui/reading.png'),
      );
    },
  );

  testWidgets(
    'phone analysis shows selected continuation arrow and a back action',
    (tester) async {
      await phone(
        tester,
        ExplorationWorkspace(
          orientation: PuzzleSide.white,
          origin: ExplorationOrigin(
            scopeId: 'golden',
            startingFen: _fen,
            authoredPath: const [],
            authoredMoves: const [],
            label: 'starting position',
          ),
          initialMoves: const ['e2e4', 'e7e5', 'g1f3'],
          initialMovesAreEngine: true,
          onReturn: () {},
          returnLabel: 'Return to reading',
        ),
      );
      expect(find.byTooltip('Return to reading'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../golden/board_ui/analysis.png'),
      );
    },
  );
}
