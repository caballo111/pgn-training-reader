import 'dart:convert';

import 'package:dartchess/dartchess.dart' as chess;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/app/dependencies.dart';
import 'package:pgntrainingreader/app/library_puzzle_practice.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/features/game_reader/presentation/game_reader_page.dart';
import 'package:pgntrainingreader/features/game_reader/presentation/reader_board.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_board.dart';

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

ChessContent _puzzle() {
  final position = chess.Chess.fromSetup(chess.Setup.parseFen(_fen));
  final move = chess.Move.parse('e2e4')!;
  return ChessContent(
    headers: const {'X-Section': 'Chapter one'},
    startingFen: _fen,
    contentType: ContentType.puzzle,
    comments: const ['ANSWER SHOULD STAY HIDDEN'],
    rootMoves: [
      MoveNode(
        san: 'e4',
        uci: 'e2e4',
        fenBefore: _fen,
        fenAfter: position.play(move).fen,
      ),
    ],
  );
}

Future<AppDatabase> _mount(
  WidgetTester tester, {
  bool solve = true,
  double scale = 1,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  if (solve) {
    await db.customStatement(
      'INSERT INTO app_settings (key, value) VALUES (?, ?)',
      ['library.read-puzzles.book', 'solve'],
    );
  }
  final dependencies = AppDependencies(databaseFactory: () => db);
  final content = _puzzle();
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: GameReaderPage(
        content: content,
        bookName: 'Study book',
        section: 'Chapter one',
        blockNumber: 7,
        puzzleViewBuilder: (_, puzzle, _) => LibraryPuzzlePractice(
          dependencies: dependencies,
          blockId: 'puzzle',
          bookId: 'book',
          puzzle: puzzle,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(412, 915),
    const Size(640, 360),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'book solving and review actions fit $size at text scale $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await _mount(tester, scale: scale);
          expect(tester.takeException(), isNull);
          expect(
            find.textContaining('ANSWER SHOULD STAY HIDDEN'),
            findsNothing,
          );
          expect(find.text('Cycle training'), findsNothing);
          for (final label in ['Hint', 'Show solution']) {
            final rect = tester.getRect(
              label == 'Show solution'
                  ? find.byTooltip(label)
                  : find.text(label),
            );
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.bottom, lessThanOrEqualTo(size.height));
          }
          await tester.tap(find.byTooltip('Show solution'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final label in ['Try again', 'Back to book']) {
            final rect = tester.getRect(find.text(label));
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.bottom, lessThanOrEqualTo(size.height));
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final size in [const Size(360, 640), const Size(640, 360)]) {
    testWidgets(
      'failed review save keeps actions visible at $size and 2x text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = await _mount(tester, scale: 2);
        await db.customStatement(
          "CREATE TRIGGER reject_exposure BEFORE INSERT ON app_settings WHEN NEW.key = 'study.presentation.puzzle' AND NEW.value LIKE '%exposed%' BEGIN SELECT RAISE(FAIL, 'exposure save failed'); END",
        );
        await tester.tap(find.byTooltip('Show solution'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final label in ['Retry', 'Try again', 'Back to book']) {
          expect(
            tester.getRect(find.text(label)).bottom,
            lessThanOrEqualTo(size.height),
          );
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'failed exposure save retains an honest marker and blocks retry until saved',
    (tester) async {
      final db = await _mount(tester);
      expect(find.text('Solution already viewed'), findsNothing);
      await db.customStatement(
        "CREATE TRIGGER reject_exposure BEFORE INSERT ON app_settings WHEN NEW.key = 'study.presentation.puzzle' AND NEW.value LIKE '%exposed%' BEGIN SELECT RAISE(FAIL, 'exposure save failed'); END",
      );
      await tester.tap(find.byTooltip('Show solution'));
      await tester.pumpAndSettle();
      expect(find.text('Casual practice · Review'), findsOneWidget);
      expect(find.text('Solution already viewed'), findsNothing);
      expect(find.textContaining('Review is available'), findsOneWidget);
      final original =
          (await db
                  .customSelect(
                    "SELECT value FROM app_settings WHERE key = 'casual.current.puzzle'",
                  )
                  .getSingle())
              .data['value'];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(
        (await db
                .customSelect(
                  "SELECT value FROM app_settings WHERE key = 'casual.current.puzzle'",
                )
                .getSingle())
            .data['value'],
        original,
      );
      await db.customStatement('DROP TRIGGER reject_exposure');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Solution already viewed'), findsNothing);
      expect(
        (await db
                .customSelect(
                  "SELECT value FROM app_settings WHERE key = 'casual.current.puzzle'",
                )
                .getSingle())
            .data['value'],
        isNot(original),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('reading cursor survives solving and returning to reading', (
    tester,
  ) async {
    final db = await _mount(tester, solve: false);
    final moves = find.byTooltip('Next move');
    await tester.tap(moves);
    await tester.pumpAndSettle();
    final readingFen = tester
        .widget<ReaderBoard>(find.byType(ReaderBoard))
        .board
        .game
        .fen;
    expect(readingFen, isNot(_fen));
    await tester.tap(find.text('Solve puzzle'));
    await tester.pumpAndSettle();
    expect(tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).fen, _fen);
    expect(find.text('Solution already viewed'), findsNothing);
    await tester.tap(find.byTooltip('Show solution'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ReaderBoard>(find.byType(ReaderBoard)).board.game.fen,
      readingFen,
    );
    final row = await db
        .customSelect(
          "SELECT value FROM app_settings WHERE key = 'study.presentation.puzzle'",
        )
        .getSingle();
    final saved = jsonDecode(row.data['value'] as String) as Map;
    expect((saved['reader'] as Map)['path'], [0]);
    expect(saved['exposed'], true);
    await tester.pumpWidget(const SizedBox());
  });
}
