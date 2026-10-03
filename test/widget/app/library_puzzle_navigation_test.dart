import 'dart:convert';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/app/app.dart';
import 'package:pgntrainingreader/app/dependencies.dart';
import 'package:pgntrainingreader/app/library_puzzle_practice.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';
import 'package:pgntrainingreader/data/file_access/file_source_picker.dart';
import 'package:pgntrainingreader/data/file_access/flutter_file_source_picker.dart';
import 'package:pgntrainingreader/data/file_access/managed_file_source.dart';
import 'package:pgntrainingreader/data/file_access/source_fingerprint.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_board.dart';
import 'package:pgntrainingreader/features/game_reader/presentation/game_reader_page.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_solving_view.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';

Finder get _nextBlock => find.text('Next block').evaluate().isNotEmpty
    ? find.text('Next block')
    : find.byTooltip('Next block');

Finder get _previousBlock => find.text('Previous block').evaluate().isNotEmpty
    ? find.text('Previous block')
    : find.byTooltip('Previous block');

void main() {
  testWidgets(
    'library casual solving avoids cycles and remembers book reading preference',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final puzzleBytes = Uint8List.fromList(
        utf8.encode('''[Event "Exercise 1"]
[SetUp "1"]
[FEN "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1"]

{SECRET ANSWER} 1... e5 2. e4 Nc6 *
'''),
      );
      final instructionBytes = utf8.encode(
        '[Event "Study notes"]\n\n{Pause and review the idea.} *\n',
      );
      final bytes = Uint8List.fromList([...puzzleBytes, ...instructionBytes]);
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
              endOffset: puzzleBytes.length,
              ordinal: 0,
              contentType: 'Puzzle',
              parseStatus: 'NotParsed',
              event: const Value('Exercise 1'),
              section: const Value('Easy Exercises'),
            ),
          );
      await db
          .into(db.pgnBlocks)
          .insert(
            PgnBlocksCompanion.insert(
              id: 'second-block',
              sourceId: 'source',
              startOffset: 0,
              endOffset: puzzleBytes.length,
              ordinal: 1,
              contentType: 'Puzzle',
              parseStatus: 'NotParsed',
              event: const Value('Exercise 2'),
            ),
          );
      await db
          .into(db.pgnBlocks)
          .insert(
            PgnBlocksCompanion.insert(
              id: 'instruction',
              sourceId: 'source',
              startOffset: puzzleBytes.length,
              endOffset: bytes.length,
              ordinal: 2,
              contentType: 'Text',
              parseStatus: 'NotParsed',
              event: const Value('Study notes'),
            ),
          );
      await tester.pumpWidget(PgnTrainingReaderApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exercise 1').first);
      await tester.pumpAndSettle();
      final readerRoute = ModalRoute.of(
        tester.element(find.byType(GameReaderPage)),
      );
      await tester.tap(_nextBlock);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('second-block')), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(GameReaderPage))),
        same(readerRoute),
      );
      await tester.tap(_previousBlock);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('block')), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(GameReaderPage))),
        same(readerRoute),
      );

      // Unset book intent reads normally; viewing creates no scored attempt.
      expect(find.textContaining('SECRET ANSWER'), findsWidgets);
      expect(await db.select(db.puzzleAttempts).get(), isEmpty);
      expect(await db.select(db.trainingSets).get(), isEmpty);
      expect(await db.select(db.cycles).get(), isEmpty);
      await tester.tap(find.text('Solve puzzle'));
      await tester.pumpAndSettle();
      expect(find.byType(PuzzleSolvingView), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(PuzzleSolvingView))),
        same(readerRoute),
      );
      expect(find.text('Solution already viewed'), findsNothing);
      expect(find.text('Exercises'), findsOneWidget);
      expect(find.text('Easy Exercises · Block 1'), findsOneWidget);
      expect(find.textContaining('SECRET ANSWER'), findsNothing);
      expect(
        tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).fen.split(' ')[1],
        'b',
      );
      final pointer = await db
          .customSelect(
            'SELECT value FROM app_settings WHERE key = ?',
            variables: [Variable<String>('casual.current.block')],
          )
          .getSingle();
      final attemptId = pointer.data['value'] as String;

      // The first error freezes the score, but different later mistakes survive.
      var board = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
      board.onMoveSubmitted('d7d5');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      board = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
      board.onMoveSubmitted('d7d6');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      board = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
      board.onMoveSubmitted('d7d5');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      final solver = tester.widget<PuzzleSolvingView>(
        find.byType(PuzzleSolvingView),
      );
      expect(
        solver.controller.state!.entries.where((entry) => !entry.accepted),
        hasLength(2),
      );
      final scoreBefore =
          (await db
                  .customSelect(
                    'SELECT value FROM app_settings WHERE key = ?',
                    variables: [Variable<String>('casual.score.$attemptId')],
                  )
                  .getSingle())
              .data['value'];

      // Complete concealed practice and review on the same book route.
      board = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
      board.onMoveSubmitted('e7e5');
      await tester.pumpAndSettle();
      board = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
      board.onMoveSubmitted('b8c6');
      await tester.pumpAndSettle();
      expect(find.text('Review'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('1... d5'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('1... d5'), findsOneWidget);
      expect(find.text('Next block'), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(GameReaderPage))),
        same(readerRoute),
      );
      expect(
        (await db
                .customSelect(
                  'SELECT value FROM app_settings WHERE key = ?',
                  variables: [Variable<String>('casual.score.$attemptId')],
                )
                .getSingle())
            .data['value'],
        scoreBefore,
      );

      // Retry is a fresh identity; no cycle rows are created.
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      final retryId =
          (await db
                  .customSelect(
                    'SELECT value FROM app_settings WHERE key = ?',
                    variables: [Variable<String>('casual.current.block')],
                  )
                  .getSingle())
              .data['value'];
      expect(retryId, isNot(attemptId));
      expect(find.text('Solution already viewed'), findsNothing);
      expect(await db.select(db.cycles).get(), isEmpty);

      // Leaving via the book controls pauses and restores unfinished practice.
      await tester.tap(_nextBlock);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('second-block')), findsOneWidget);
      expect(find.byType(PuzzleSolvingView), findsNothing);
      await tester.tap(_previousBlock);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solve puzzle'));
      await tester.pumpAndSettle();
      final restored = tester.widget<PuzzleSolvingView>(
        find.byType(PuzzleSolvingView),
      );
      expect(restored.controller.currentEvaluation!.attempt.id, retryId);
      expect(
        restored.controller.state!.attemptStatus,
        PuzzleAttemptStatus.active,
      );

      // A current-block solve does not change book defaults. Settings do.
      await tester.tap(find.byTooltip('Book settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open puzzles for solving'));
      await tester.pumpAndSettle();
      await tester.tap(_nextBlock);
      await tester.pumpAndSettle();
      expect(find.byType(PuzzleSolvingView), findsOneWidget);
      expect(
        tester
            .widget<PuzzleSolvingView>(find.byType(PuzzleSolvingView))
            .controller
            .currentEvaluation!
            .attempt
            .blockId,
        'second-block',
      );
      await tester.tap(find.byTooltip('Show solution'));
      await tester.pumpAndSettle();
      expect(find.text('Next block'), findsOneWidget);
      await tester.tap(find.text('Next block'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('instruction')), findsOneWidget);
      expect(find.text('Pause and review the idea.'), findsOneWidget);
      expect(find.byType(PuzzleSolvingView), findsNothing);
      expect(find.text('Back to book'), findsOneWidget);
      // Changing a puzzle to text retains its reader cursor and keeps saving.
      await tester.tap(_previousBlock);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Last move on main line'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Change content type'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text('Study text / game'),
          matching: find.byWidgetPredicate(
            (widget) => widget is CheckedPopupMenuItem,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LibraryPuzzlePractice), findsNothing);
      var presentation = jsonDecode(
        (await db
                    .customSelect(
                      "SELECT value FROM app_settings WHERE key = 'study.presentation.second-block'",
                    )
                    .getSingle())
                .data['value']
            as String,
      ) as Map<String, dynamic>;
      expect((presentation['reader'] as Map)['path'], [0, 0, 0]);
      await tester.tap(find.byTooltip('Previous move'));
      await tester.pumpAndSettle();
      await tester.tap(_nextBlock);
      await tester.pumpAndSettle();
      presentation = jsonDecode(
        (await db
                    .customSelect(
                      "SELECT value FROM app_settings WHERE key = 'study.presentation.second-block'",
                    )
                    .getSingle())
                .data['value']
            as String,
      ) as Map<String, dynamic>;
      expect((presentation['reader'] as Map)['path'], [0, 0]);
      await tester.tap(find.text('Back to book'));
      await tester.pumpAndSettle();
      expect(find.byType(GameReaderPage), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
