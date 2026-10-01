import 'dart:convert';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/app/app.dart';
import 'package:pgntrainingreader/app/dependencies.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';
import 'package:pgntrainingreader/data/file_access/file_source_picker.dart';
import 'package:pgntrainingreader/data/file_access/flutter_file_source_picker.dart';
import 'package:pgntrainingreader/data/file_access/managed_file_source.dart';
import 'package:pgntrainingreader/data/file_access/source_fingerprint.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_board.dart';
import 'package:pgntrainingreader/features/game_reader/presentation/game_reader_page.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_solving_view.dart';

void main() {
  testWidgets(
    'library casual solving avoids cycles and remembers book reading preference',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = Uint8List.fromList(
        utf8.encode('''[Event "Exercise 1"]
[SetUp "1"]
[FEN "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1"]

{SECRET ANSWER} 1... e5 2. e4 Nc6 *
'''),
      );
      const channel = MethodChannel(
        'lberrios.pgntrainingreader/external_source',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        switch (call.method) {
          case 'length':
            return bytes.length;
          case 'modifiedAtMicros':
            return 1000000;
          case 'readRange':
            final args = call.arguments! as Map<Object?, Object?>;
            return Uint8List.sublistView(
              bytes,
              args['start']! as int,
              args['endExclusive']! as int,
            );
          default:
            throw StateError(call.method);
        }
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final fileSource = ManagedFileSource(
        pickedSources: const FlutterFileSource(),
      );
      final fingerprint = SourceFingerprint.compute(
        await fileSource.fingerprintInput(
          ExternalSourceReference('content://fixture/exercise'),
        ),
      );
      final db = AppDatabase(NativeDatabase.memory());
      final dependencies = AppDependencies(databaseFactory: () => db);
      addTearDown(db.close);
      await db
          .into(db.pgnSources)
          .insert(
            PgnSourcesCompanion.insert(
              id: 'source',
              displayName: 'Exercises',
              accessMode: 'ExternalReference',
              externalReference: const Value('content://fixture/exercise'),
              fingerprint: Value(fingerprint),
              scannerVersion: 1,
              importState: 'indexed',
              createdAtMicros: 1,
              updatedAtMicros: 1,
            ),
          );
      await db
          .into(db.pgnBlocks)
          .insert(
            PgnBlocksCompanion.insert(
              id: 'block',
              sourceId: 'source',
              startOffset: 0,
              endOffset: bytes.length,
              ordinal: 0,
              contentType: 'Puzzle',
              parseStatus: 'NotParsed',
              event: const Value('Exercise 1'),
            ),
          );
      await db
          .into(db.pgnBlocks)
          .insert(
            PgnBlocksCompanion.insert(
              id: 'second-block',
              sourceId: 'source',
              startOffset: 0,
              endOffset: bytes.length,
              ordinal: 1,
              contentType: 'Puzzle',
              parseStatus: 'NotParsed',
              event: const Value('Exercise 2'),
            ),
          );
      await tester.pumpWidget(PgnTrainingReaderApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exercise 1').first);
      await tester.pumpAndSettle();
      final readerRoute = ModalRoute.of(
        tester.element(find.byType(GameReaderPage)),
      );
      await tester.tap(find.byTooltip('Next PGN block'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('second-block')), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(GameReaderPage))),
        same(readerRoute),
      );
      await tester.tap(find.byTooltip('Previous PGN block'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('block')), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(GameReaderPage))),
        same(readerRoute),
      );

      await tester.pumpAndSettle();
      expect(find.text('Black to move'), findsOneWidget);
      expect(find.textContaining('SECRET ANSWER'), findsNothing);
      expect(await db.select(db.puzzleAttempts).get(), isEmpty);
      expect(await db.select(db.trainingSets).get(), isEmpty);
      expect(await db.select(db.cycles).get(), isEmpty);
      await tester.tap(find.text('Solve this puzzle'));
      await tester.pumpAndSettle();
      expect(find.byType(PuzzleSolvingView), findsOneWidget);
      expect(
        tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).fen.split(' ')[1],
        'b',
      );
      expect(find.textContaining('SECRET ANSWER'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final initialPointer = await db
          .customSelect(
            'SELECT value FROM app_settings WHERE key = ?',
            variables: [Variable<String>('casual.current.block')],
          )
          .getSingle();
      final pausedId = initialPointer.data['value'] as String;
      final pausedScore = jsonDecode(
        (await db
                    .customSelect(
                      'SELECT value FROM app_settings WHERE key = ?',
                      variables: [Variable<String>('casual.score.$pausedId')],
                    )
                    .getSingle())
                .data['value']
            as String,
      ) as Map<String, dynamic>;
      expect(
        (pausedScore['attempt'] as Map<String, dynamic>)['status'],
        'paused',
      );

      await tester.tap(find.text('Solve this puzzle'));
      await tester.pumpAndSettle();
      expect(find.byType(PuzzleSolvingView), findsOneWidget);
      expect(
        tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).fen.split(' ')[1],
        'b',
      );
      await tester.tap(find.text('Read puzzle'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SECRET ANSWER'), findsWidgets);
      final revealedScore = jsonDecode(
        (await db
                    .customSelect(
                      'SELECT value FROM app_settings WHERE key = ?',
                      variables: [Variable<String>('casual.score.$pausedId')],
                    )
                    .getSingle())
                .data['value']
            as String,
      ) as Map<String, dynamic>;
      expect(
        (revealedScore['attempt'] as Map<String, dynamic>)['outcome'],
        'revealed',
      );
      await tester.tap(find.text('Solve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      final retryPointer = await db
          .customSelect(
            'SELECT value FROM app_settings WHERE key = ?',
            variables: [Variable<String>('casual.current.block')],
          )
          .getSingle();
      final retryId = retryPointer.data['value'] as String;
      expect(retryId, isNot(pausedId));
      expect(
        await db
            .customSelect(
              'SELECT key FROM app_settings WHERE key = ?',
              variables: [Variable<String>('casual.score.$pausedId')],
            )
            .get(),
        hasLength(1),
      );
      var board = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
      board.onMoveSubmitted('d7d5');
      await tester.pumpAndSettle();
      expect(find.textContaining('Incorrect'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solve this puzzle'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Incorrect'), findsOneWidget);
      board = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
      board.onMoveSubmitted('e7e5');
      // Back during continued practice must wait for the paced opponent reply,
      // even though the first incorrect move already finalized the score.
      final closingPractice = tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await closingPractice;
      expect(find.byType(PuzzleSolvingView), findsNothing);
      await tester.tap(find.text('Solve this puzzle'));
      await tester.pumpAndSettle();
      board = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
      expect(board.fen.split(' ')[1], 'b');
      expect(board.fen, contains('4P3'));
      board.onMoveSubmitted('b8c6');
      await tester.pumpAndSettle();
      expect(await db.select(db.puzzleAttempts).get(), isEmpty);
      expect(await db.select(db.trainingSets).get(), isEmpty);
      expect(await db.select(db.cycles).get(), isEmpty);
      final current = await db
          .customSelect(
            'SELECT value FROM app_settings WHERE key = ?',
            variables: [Variable<String>('casual.current.block')],
          )
          .getSingle();
      final attemptId = current.data['value'] as String;
      final scoreRow = await db
          .customSelect(
            'SELECT value FROM app_settings WHERE key = ?',
            variables: [Variable<String>('casual.score.$attemptId')],
          )
          .getSingle();
      final score =
          jsonDecode(scoreRow.data['value'] as String) as Map<String, dynamic>;
      expect(
        (score['attempt'] as Map<String, dynamic>)['outcome'],
        'wrongMove',
      );
      expect(find.text('Puzzle review'), findsOneWidget);
      await tester.tap(find.text('Read'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SECRET ANSWER'), findsWidgets);
      await tester.tap(find.text('Solve'));
      await tester.pumpAndSettle();
      expect(find.text('Puzzle review'), findsOneWidget);
      await tester.tap(find.text('Next exercise'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('second-block'), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(PuzzleSolvingView), findsOneWidget);
      final nextSolver = tester.widget<PuzzleSolvingView>(
        find.byType(PuzzleSolvingView),
      );
      expect(
        nextSolver.controller.currentEvaluation?.attempt.blockId,
        'second-block',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read puzzles in this book'));
      await tester.pumpAndSettle();
      expect(find.text('Reading this puzzle without scoring.'), findsOneWidget);
      expect(find.textContaining('SECRET ANSWER'), findsWidgets);
      await tester.tap(find.byTooltip('Previous PGN block'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('block')), findsOneWidget);
      expect(find.text('Reading this puzzle without scoring.'), findsOneWidget);
      final preference = await db
          .customSelect(
            'SELECT value FROM app_settings WHERE key = ?',
            variables: [Variable<String>('library.read-puzzles.source')],
          )
          .getSingle();
      expect(preference.data['value'], 'read');
      final indexedBlock = await (db.select(
        db.pgnBlocks,
      )..where((block) => block.id.equals('second-block'))).getSingle();
      expect(indexedBlock.contentType, 'Puzzle');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
