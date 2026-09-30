import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/pgn_block_index.dart';
import 'package:pgntrainingreader/domain/library/pgn_index_repository.dart';
import 'package:pgntrainingreader/domain/library/pgn_source_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/pgn_source.dart';
import 'package:pgntrainingreader/features/browse_library/application/library_controller.dart';
import 'package:pgntrainingreader/features/browse_library/application/library_query.dart';

void main() {
  test('loads bounded pages and appends the next page', () async {
    final index = _IndexRepository();
    final controller = LibraryController(
      indexRepository: index,
      sourceRepository: _Sources(),
      initialQuery: const LibraryQuery(pageSize: 2),
    );
    await controller.load();
    expect(controller.state.items.map((item) => item.id), ['one', 'two']);
    expect(controller.state.hasMore, isTrue);
    await controller.loadNextPage();
    expect(controller.state.items.map((item) => item.id), [
      'one',
      'two',
      'three',
    ]);
    expect(index.offsets, [0, 2]);
    controller.dispose();
  });

  test(
    'discards stale success and stale failure after a newer query',
    () async {
      final index = _IndexRepository()..holdNext = true;
      final controller = LibraryController(
        indexRepository: index,
        sourceRepository: _Sources(),
        debounceDuration: Duration.zero,
      );
      final pending = controller.load();
      await Future<void>.delayed(Duration.zero);
      controller.updateQuery(const LibraryQuery(searchText: 'new query'));
      await Future<void>.delayed(Duration.zero);
      index.pending!.completeError(StateError('stale error'));
      await pending;
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, LibraryLoadStatus.ready);
      expect(controller.state.items.single.id, 'new');
      controller.dispose();
    },
  );

  test('query maps supported filters and stable source order', () {
    const query = LibraryQuery(
      searchText: '  carlsen ',
      sourceId: 'source-1',
      result: '1-0',
      contentType: ContentType.puzzle,
      section: 'chapter',
      theme: 'fork',
      difficulty: 'hard',
    );
    final filter = query.toIndexFilter();
    expect(filter.query, 'carlsen');
    expect(filter.sourceId, 'source-1');
    expect(filter.result, '1-0');
    expect(filter.contentType, ContentType.puzzle);
    expect(query.sort, LibrarySort.sourceOrder);
  });
}

final class _IndexRepository implements PgnIndexRepository {
  final offsets = <int>[];
  bool holdNext = false;
  Completer<PgnIndexPage>? pending;
  @override
  Future<PgnIndexPage> search({
    PgnIndexFilter filter = const PgnIndexFilter(),
    PgnIndexSort sort = PgnIndexSort.sourceOrder,
    int offset = 0,
    required int limit,
  }) {
    offsets.add(offset);
    if (holdNext) {
      holdNext = false;
      pending = Completer<PgnIndexPage>();
      return pending!.future;
    }
    if (filter.query == 'new query') {
      return Future.value(
        PgnIndexPage(items: [_item('new')], nextOffset: null),
      );
    }
    final items = offset == 0 ? [_item('one'), _item('two')] : [_item('three')];
    return Future.value(
      PgnIndexPage(items: items, nextOffset: offset == 0 ? 2 : null),
    );
  }

  @override
  Future<int> countForSource(String sourceId) async => 0;
  @override
  Future<PgnBlockIndex?> getById(String id) async => null;
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

PgnBlockIndex _item(String id) => PgnBlockIndex(
  id: id,
  sourceId: 'source',
  startOffset: 0,
  endOffset: 1,
  ordinal: 0,
  contentType: ContentType.puzzle,
  parseStatus: PgnBlockParseStatus.notParsed,
);
