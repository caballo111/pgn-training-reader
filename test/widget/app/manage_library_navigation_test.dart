import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/app/app.dart';
import 'package:pgntrainingreader/app/dependencies.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';

void main() {
  testWidgets(
    'library manages books, routes Add book, and retains removed rows',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.pgnSources)
          .insert(
            PgnSourcesCompanion.insert(
              id: 'source-a',
              displayName: 'First book',
              accessMode: 'ExternalReference',
              externalReference: const Value('content://fixture/book'),
              scannerVersion: 1,
              importState: 'indexed',
              createdAtMicros: 1,
              updatedAtMicros: 1,
            ),
          );
      await database
          .into(database.pgnBlocks)
          .insert(
            PgnBlocksCompanion.insert(
              id: 'block-a',
              sourceId: 'source-a',
              startOffset: 0,
              endOffset: 10,
              ordinal: 0,
              contentType: 'Text',
              parseStatus: 'NotParsed',
              event: const Value('Opening notes'),
            ),
          );

      await tester.pumpWidget(
        PgnTrainingReaderApp(
          dependencies: AppDependencies(databaseFactory: () => database),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Opening notes'), findsWidgets);

      await tester.tap(find.byTooltip('Manage library'));
      await tester.pumpAndSettle();
      expect(find.text('First book'), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-book')));
      await tester.pumpAndSettle();
      expect(find.text('Import PGN'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Manage library'), findsOneWidget);

      await tester.tap(find.byTooltip('Book actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from library'));
      await tester.pumpAndSettle();
      expect(find.textContaining('“First book”'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-remove-book')));
      await tester.pumpAndSettle();
      expect(find.text('No books in your library yet.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Opening notes'), findsNothing);
      final source = await database.select(database.pgnSources).getSingle();
      final blocks = await database.select(database.pgnBlocks).get();
      expect(source.importState, 'deleted');
      expect(blocks.map((block) => block.id), ['block-a']);
    },
  );
}
