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
  testWidgets('shows indexed results and import action accessibly', (
    tester,
  ) async {
    final controller = LibraryController(
      indexRepository: _Index(),
      sourceRepository: _Sources(),
    );
    var imports = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryPage(controller: controller, onImport: () => imports++),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Carlsen — Anand'), findsOneWidget);
    expect(find.byTooltip('Import PGN'), findsOneWidget);
    await tester.tap(find.byTooltip('Import PGN'));
    expect(imports, 1);
    await tester.enterText(
      find.byKey(const Key('library-search')),
      'unmatched',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('No matching PGN content.'), findsOneWidget);
  });
}

final class _Index implements PgnIndexRepository {
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
    return PgnIndexPage(items: [_item], nextOffset: null);
  }

  @override
  Future<int> countForSource(String sourceId) async => 1;
  @override
  Future<PgnBlockIndex?> getById(String id) async => _item;
}

final class _Sources implements PgnSourceRepository {
  @override
  Future<List<PgnSource>> list() async => [];
  @override
  Future<PgnSource?> getById(String id) async => null;
  @override
  Future<void> create(PgnSource source) async {}
  @override
  Future<void> update(PgnSource source) async {}
}

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
  contentType: ContentType.demonstration,
  parseStatus: PgnBlockParseStatus.notParsed,
);
