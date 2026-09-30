import 'dart:convert';

import 'package:drift/drift.dart' show Value;
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
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_board.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_solving_view.dart';

void main() {
  testWidgets(
    'library practice hides answers and resumes an unfinished attempt',
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
      await tester.pumpWidget(PgnTrainingReaderApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exercise 1').first);
      await tester.pumpAndSettle();
      expect(find.text('Black to move'), findsOneWidget);
      expect(find.textContaining('SECRET ANSWER'), findsNothing);
      expect(await db.select(db.puzzleAttempts).get(), isEmpty);
      await tester.tap(find.text('Start or resume practice'));
      await tester.pumpAndSettle();
      expect(find.byType(PuzzleSolvingView), findsOneWidget);
      expect(
        tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).fen.split(' ')[1],
        'b',
      );
      expect(find.textContaining('SECRET ANSWER'), findsNothing);
      final attempt = (await db.select(db.puzzleAttempts).get()).single;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final paused = (await dependencies.trainingRepository.getAttempt(
        attempt.id,
      ))!;
      expect(paused.status, PuzzleAttemptStatus.paused);
      expect(paused.outcome, isNull);
      await tester.tap(find.text('Start or resume practice'));
      await tester.pumpAndSettle();
      expect(await db.select(db.puzzleAttempts).get(), hasLength(1));
      var board = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
      board.onMoveSubmitted('e7e5');
      await tester.pumpAndSettle();
      board = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
      board.onMoveSubmitted('e2e4');
      await tester.pumpAndSettle();
      board = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
      board.onMoveSubmitted('b8c6');
      await tester.pumpAndSettle();
      expect(
        (await dependencies.trainingRepository.getAttempt(attempt.id))!.outcome,
        PuzzleAttemptOutcome.passed,
      );
      await tester.tap(find.text('Continue to review'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SECRET ANSWER'), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
