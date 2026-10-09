import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/pgn_block_index.dart';
import 'package:pgntrainingreader/domain/library/pgn_index_repository.dart';
import 'package:pgntrainingreader/domain/library/pgn_source_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/pgn_source.dart';
import 'package:pgntrainingreader/features/browse_library/application/library_controller.dart';
import 'package:pgntrainingreader/features/browse_library/presentation/library_page.dart';

void main() {
  testWidgets('shows indexed results and manage library action accessibly', (
    tester,
  ) async {
    final controller = LibraryController(
      indexRepository: _Index(),
      sourceRepository: _Sources(),
    );
    var manages = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryPage(
          controller: controller,
          onManageLibrary: () => manages++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Carlsen — Anand'), findsOneWidget);
    expect(find.byTooltip('Manage library'), findsOneWidget);
    await tester.tap(find.byTooltip('Manage library'));
    expect(manages, 1);
    await tester.enterText(
      find.byKey(const Key('library-search')),
      'unmatched',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('No matching PGN content.'), findsOneWidget);
  });

  testWidgets('compact filters apply only on confirmation and can be cleared', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = LibraryController(
      indexRepository: _Index(),
      sourceRepository: _Sources(),
    );
    await tester.pumpWidget(
      MaterialApp(home: LibraryPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Section'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('library-item-game-1'))).dy,
      lessThan(180),
    );

    await tester.tap(find.byKey(const Key('library-filters')));
    await tester.pumpAndSettle();
    final section = find.widgetWithText(TextField, 'Section');
    await tester.enterText(section, 'Endgames');
    expect(controller.state.query.section, isNull);
    await tester.ensureVisible(find.text('Apply filters'));
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(controller.state.query.section, 'Endgames');
    expect(find.byTooltip('Filters (1 active)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(section).controller!.text, isEmpty);
    await tester.ensureVisible(find.text('Apply filters'));
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(controller.state.query.section, isNull);
    expect(find.byTooltip('Filters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing source disables opening and offers relink', (
    tester,
  ) async {
    final controller = LibraryController(
      indexRepository: _Index(),
      sourceRepository: _Sources([_missingSource]),
    );
    var opened = 0;
    var repairs = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryPage(
          controller: controller,
          onOpen: (_) => opened++,
          onRepairSource: (_) => repairs++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Source missing · indexed history preserved'),
      findsOneWidget,
    );
    final tile = tester.widget<ListTile>(
      find.byKey(const Key('library-item-game-1')),
    );
    expect(tile.onTap, isNull);
    await tester.tap(find.byKey(const Key('library-item-game-1')));
    expect(opened, 0);
    await tester.tap(find.text('Relink'));
    expect(repairs, 1);
  });

  testWidgets('changed source disables opening and offers re-index', (
    tester,
  ) async {
    final controller = LibraryController(
      indexRepository: _Index(),
      sourceRepository: _Sources([_changedSource]),
    );
    var opened = 0;
    var reindexRequests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryPage(
          controller: controller,
          onOpen: (_) => opened++,
          onReindexSource: (source) {
            expect(source.id, 'source-1');
            reindexRequests++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Source changed · re-index required'),
      findsOneWidget,
    );
    final tile = tester.widget<ListTile>(
      find.byKey(const Key('library-item-game-1')),
    );
    expect(tile.onTap, isNull);
    await tester.tap(find.byKey(const Key('library-item-game-1')));
    expect(opened, 0);
    await tester.tap(find.text('Re-index'));
    expect(reindexRequests, 1);
  });

  testWidgets('duplicate exercise ID is preserved, blocked, and recoverable', (
    tester,
  ) async {
    final controller = LibraryController(
      indexRepository: _Index(_duplicateItem),
      sourceRepository: _Sources(),
    );
    var opened = 0;
    var imports = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryPage(
          controller: controller,
          onOpen: (_) => opened++,
          onImport: () => imports++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Duplicate exercise ID · preserved but blocked'),
      findsOneWidget,
    );
    final tile = tester.widget<ListTile>(
      find.byKey(const Key('library-item-game-1')),
    );
    expect(tile.onTap, isNull);
    await tester.tap(find.byKey(const Key('library-item-game-1')));
    expect(opened, 0);
    await tester.tap(find.text('Import corrected PGN'));
    expect(imports, 1);
  });
}

final class _Index implements PgnIndexRepository {
  _Index([PgnBlockIndex? item]) : item = item ?? _item;

  final PgnBlockIndex item;

  @override
  Future<PgnIndexPage> search({
    PgnIndexFilter filter = const PgnIndexFilter(),
    PgnIndexSort sort = PgnIndexSort.sourceOrder,
    int offset = 0,
    required int limit,
  }) async {
    if (filter.query == 'unmatched') {
      return PgnIndexPage(items: [], nextOffset: null);
    }
    return PgnIndexPage(items: [item], nextOffset: null);
  }

  @override
  Future<int> countForSource(String sourceId) async => 1;
  @override
  Future<PgnBlockIndex?> getById(String id) async => item;
}

final class _Sources implements PgnSourceRepository {
  _Sources([this.values = const []]);
  final List<PgnSource> values;

  @override
  Future<List<PgnSource>> list() async => values;
  @override
  Future<PgnSource?> getById(String id) async => null;
  @override
  Future<void> create(PgnSource source) async {}
  @override
  Future<void> update(PgnSource source) async {}

  @override
  Future<void> remove({
    required String id,
    required DateTime removedAt,
  }) async {}

  @override
  Future<void> updateAfterVerifiedRelink({
    required PgnSource source,
    required String expectedFingerprint,
  }) async {}
}

final _missingSource = PgnSource(
  id: 'source-1',
  displayName: 'Missing source',
  accessMode: PgnSourceAccessMode.managedCopy,
  managedPath: '0123456789abcdef0123456789abcdef',
  scannerVersion: 1,
  importState: 'sourceMissing',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

final _item = PgnBlockIndex(
  id: 'game-1',
  sourceId: 'source-1',
  startOffset: 0,
  endOffset: 42,
  ordinal: 0,
  white: 'Carlsen',
  black: 'Anand',
  event: 'World Championship',
  result: '1-0',
  contentType: ContentType.text,
  parseStatus: PgnBlockParseStatus.notParsed,
);

final _changedSource = PgnSource(
  id: 'source-1',
  displayName: 'Changed source',
  accessMode: PgnSourceAccessMode.managedCopy,
  managedPath: '0123456789abcdef0123456789abcdef',
  scannerVersion: 1,
  importState: 'sourceChanged',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

final _duplicateItem = PgnBlockIndex(
  id: 'game-1',
  sourceId: 'source-1',
  startOffset: 0,
  endOffset: 42,
  ordinal: 0,
  white: 'Carlsen',
  black: 'Anand',
  event: 'World Championship',
  result: '1-0',
  contentType: ContentType.puzzle,
  exerciseId: 'duplicate-id',
  parseStatus: PgnBlockParseStatus.notParsed,
  diagnosticSummary: 'duplicateExerciseId',
);
