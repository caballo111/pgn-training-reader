import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/pgn_block_index.dart';
import 'package:pgntrainingreader/domain/library/pgn_index_repository.dart';
import 'package:pgntrainingreader/domain/training/training_set.dart';
import 'package:pgntrainingreader/domain/training/training_set_item.dart';
import 'package:pgntrainingreader/domain/training/training_set_repository.dart';
import 'package:pgntrainingreader/features/training_sets/application/training_set_editor_controller.dart';
import 'package:pgntrainingreader/features/training_sets/presentation/training_set_editor_page.dart';

import '../../../support/fake_app_clock.dart';
import '../../../support/fake_id_generator.dart';

void main() {
  test('bulk add deduplicates by block ID and reports unavailable entries', () {
    final controller = TrainingSetEditorController(
      repository: _SetRepository(),
      clock: FakeAppClock(initialWallTime: DateTime.utc(2026)),
      idGenerator: FakeIdGenerator(),
    );
    final duplicate = PgnBlockIndex(
      id: 'blocked',
      sourceId: 'book',
      startOffset: 0,
      endOffset: 1,
      ordinal: 2,
      contentType: ContentType.puzzle,
      parseStatus: PgnBlockParseStatus.valid,
      diagnosticSummary: 'duplicateExerciseId',
    );
    final report = controller.addMany([
      _block('first', ContentType.puzzle),
      _block('first', ContentType.puzzle),
      duplicate,
    ]);
    expect(report, {
      'added': 1,
      'duplicates': 1,
      'malformed': 0,
      'unsupported': 0,
      'unavailable': 1,
    });
    expect(controller.state.items.map((item) => item.blockId), ['first']);
  });

  test('builder title ignores question mark metadata', () {
    final block = PgnBlockIndex(
      id: 'named',
      sourceId: 'book',
      startOffset: 0,
      endOffset: 1,
      ordinal: 4,
      event: '?',
      white: 'Player',
      black: '?',
      contentType: ContentType.puzzle,
      parseStatus: PgnBlockParseStatus.valid,
    );
    expect(trainingBlockTitle(block), 'Player');
  });

  test('Woodpecker headers recover number and section over generated IDs', () {
    final block = _woodpeckerBlock('woodpecker-15', 0, black: 'Exercise 15');
    expect(trainingBlockNumber(block), 15);
    expect(trainingBlockSection(block), '4) Easy Exercises');
    expect(trainingBlockTitle(block), 'Exercise 15 · 4) Easy Exercises');
  });

  test('numeric authored exercise IDs take precedence and generated IDs do not display', () {
    final numeric = PgnBlockIndex(
      id: 'numeric-id',
      sourceId: 'book',
      startOffset: 0,
      endOffset: 1,
      ordinal: 0,
      exerciseId: '23',
      event: '?',
      contentType: ContentType.puzzle,
      parseStatus: PgnBlockParseStatus.valid,
    );
    final generatedWithoutHeader = PgnBlockIndex(
      id: 'generated-no-header',
      sourceId: 'book',
      startOffset: 0,
      endOffset: 1,
      ordinal: 8,
      exerciseId: 'generated-acde1234',
      event: '?',
      contentType: ContentType.puzzle,
      parseStatus: PgnBlockParseStatus.valid,
    );
    expect(trainingBlockNumber(numeric), 23);
    expect(trainingBlockTitle(numeric), 'Exercise 23');
    expect(trainingBlockNumber(generatedWithoutHeader), isNull);
    expect(trainingBlockTitle(generatedWithoutHeader), 'Game 9');
  });

  test('malformed and unsupported blocks are unavailable while not parsed is allowed', () {
    final controller = TrainingSetEditorController(
      repository: _SetRepository(),
      clock: FakeAppClock(initialWallTime: DateTime.utc(2026)),
      idGenerator: FakeIdGenerator(),
    );
    final malformed = _block(
      'malformed',
      ContentType.puzzle,
      parseStatus: PgnBlockParseStatus.malformed,
    );
    final unsupportedStatus = _block(
      'unsupported-status',
      ContentType.puzzle,
      parseStatus: PgnBlockParseStatus.unsupported,
    );
    final unsupportedType = _block('unsupported-type', ContentType.unsupported);
    final deferred = _block(
      'not-parsed',
      ContentType.puzzle,
      parseStatus: PgnBlockParseStatus.notParsed,
    );

    controller.add(malformed);
    expect(controller.state.items, isEmpty);
    expect(controller.state.validationMessage, contains('Malformed content'));
    final report = controller.addMany([
      malformed,
      unsupportedStatus,
      unsupportedType,
      deferred,
    ]);
    expect(report, {
      'added': 1,
      'duplicates': 0,
      'malformed': 1,
      'unsupported': 2,
      'unavailable': 0,
    });
    expect(controller.state.items.map((item) => item.blockId), ['not-parsed']);
  });

  testWidgets(
    'form opens while metadata loads and stops paging after leaving',
    (tester) async {
      final indexRepository = _PendingIndexRepository();
      final controller = TrainingSetEditorController(
        repository: _SetRepository(),
        clock: FakeAppClock(initialWallTime: DateTime.utc(2026)),
        idGenerator: FakeIdGenerator(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingSetEditorPage(
            controller: controller,
            indexRepository: indexRepository,
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('training-set-name')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('training-set-save')).hitTestable(),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('training-set-name')),
        'My set',
      );
      expect(controller.state.name, 'My set');
      await tester.pumpWidget(const SizedBox.shrink());
      indexRepository.page.complete(
        PgnIndexPage(
          items: [_block('pending', ContentType.puzzle)],
          nextOffset: 1000,
        ),
      );
      await tester.pump();
      expect(indexRepository.calls, 1);
      controller.dispose();
    },
  );

  testWidgets(
    'large libraries build only visible rows and bulk select all pages',
    (tester) async {
      final indexRepository = _IndexRepository([
        for (var i = 0; i < 3000; i++)
          _block('large-$i', ContentType.puzzle, sequence: i),
      ]);
      final controller = TrainingSetEditorController(
        repository: _SetRepository(),
        clock: FakeAppClock(initialWallTime: DateTime.utc(2026)),
        idGenerator: FakeIdGenerator(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingSetEditorPage(
            controller: controller,
            indexRepository: indexRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(indexRepository.searchLimits, [1000, 1000, 1000]);
      expect(find.byKey(const ValueKey('candidate-large-2999')), findsNothing);
      final rows = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            widget.key.toString().contains('candidate-large-'),
      );
      expect(rows.evaluate().length, lessThan(30));
      final selectAll = find.byKey(const Key('training-set-select-all'));
      await _reveal(tester, selectAll);
      await tester.pumpAndSettle();
      await tester.tap(selectAll);
      await tester.pumpAndSettle();
      expect(controller.state.items, hasLength(3000));
      expect(controller.state.items.last.blockId, 'large-2999');
      expect(controller.state.items.last.position, 2999);
      expect(rows.evaluate().length, lessThan(30));
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const Key('training-set-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('training-set-name')),
        'Large set',
      );
      await tester.pumpAndSettle();
      expect(indexRepository.searchLimits, hasLength(3));
      expect(
        find.byKey(const Key('training-set-save')).hitTestable(),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('lazy preview keeps drag reordering and removal working', (
    tester,
  ) async {
    final controller = TrainingSetEditorController(
      repository: _SetRepository(),
      clock: FakeAppClock(initialWallTime: DateTime.utc(2026)),
      idGenerator: FakeIdGenerator(),
    );
    final blocks = [
      for (var i = 0; i < 3; i++)
        _block('preview-$i', ContentType.puzzle, sequence: i),
    ];
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.addMany(blocks);
    expect(notifications, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingSetEditorPage(
          controller: controller,
          indexRepository: _IndexRepository(blocks),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _reveal(tester, find.byKey(ValueKey(controller.state.items.last.id)));
    final first = find.byKey(ValueKey(controller.state.items.first.id));
    final second = find.byKey(ValueKey(controller.state.items[1].id));
    final start = tester.getCenter(
      find.descendant(of: first, matching: find.byIcon(Icons.drag_handle)),
    );
    final destination = tester.getCenter(
      find.descendant(of: second, matching: find.byIcon(Icons.drag_handle)),
    );
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await gesture.moveTo(destination + const Offset(0, 90));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.state.items.map((item) => item.blockId), [
      'preview-1',
      'preview-0',
      'preview-2',
    ]);
    final moved = find.byKey(ValueKey(controller.state.items[1].id));
    await tester.tap(
      find.descendant(of: moved, matching: find.byTooltip('Remove item')),
    );
    await tester.pumpAndSettle();
    expect(controller.state.items.map((item) => item.blockId), [
      'preview-1',
      'preview-2',
    ]);
    expect(controller.state.items.map((item) => item.position), [0, 1]);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('editor marks puzzle as scored and instruction as not scored', (
    tester,
  ) async {
    final repository = _SetRepository();
    final clock = FakeAppClock(initialWallTime: DateTime.utc(2026));
    final controller = TrainingSetEditorController(
      repository: repository,
      clock: clock,
      idGenerator: FakeIdGenerator(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingSetEditorPage(
          controller: controller,
          indexRepository: _IndexRepository([
            _block('p', ContentType.puzzle),
            _block('i', ContentType.text),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.add(_block('p', ContentType.puzzle));
    controller.add(_block('i', ContentType.text));
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('training-set-scroll')),
      const Offset(0, -1400),
    );
    await tester.pumpAndSettle();
    expect(find.text('Scored puzzle'), findsOneWidget);
    expect(find.text('Not scored'), findsOneWidget);
    expect(controller.state.items.map((item) => item.contentType), [
      ContentType.puzzle,
      ContentType.text,
    ]);
  });

  testWidgets(
    'section filter first half keeps the extra match and other books',
    (tester) async {
      final controller = TrainingSetEditorController(
        repository: _SetRepository(),
        clock: FakeAppClock(initialWallTime: DateTime.utc(2026)),
        idGenerator: FakeIdGenerator(),
      );
      controller.add(
        _block('from-book-b', ContentType.puzzle, sourceId: 'book-b'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingSetEditorPage(
            controller: controller,
            indexRepository: _IndexRepository([
              _woodpeckerBlock('woodpecker-15', 0, black: 'Exercise 15'),
              _woodpeckerBlock('woodpecker-16', 1, black: 'Exercise 16'),
              _woodpeckerBlock('woodpecker-17', 2, black: 'Exercise 17'),
              _woodpeckerBlock(
                'woodpecker-text',
                3,
                black: 'Exercise 18',
                contentType: ContentType.text,
              ),
              _block(
                'other',
                ContentType.puzzle,
                sourceId: 'book-a',
                section: 'Other',
                sequence: 4,
              ),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('training-set-filter-Section-all')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('4) Easy Exercises').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Include text blocks'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('First half'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First half'));
      await tester.pumpAndSettle();

      expect(controller.state.items.map((item) => item.blockId), [
        'from-book-b',
        'woodpecker-15',
        'woodpecker-16',
      ]);
    },
  );

  testWidgets('search and select all apply to displayed filtered results', (
    tester,
  ) async {
    final controller = TrainingSetEditorController(
      repository: _SetRepository(),
      clock: FakeAppClock(initialWallTime: DateTime.utc(2026)),
      idGenerator: FakeIdGenerator(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingSetEditorPage(
          controller: controller,
          indexRepository: _IndexRepository([
            _block('find-me', ContentType.puzzle, sourceId: 'find-book'),
            _block('skip-me', ContentType.puzzle, sourceId: 'skip-book'),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('training-set-search')),
      'find-book',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('candidate-skip-me')), findsNothing);
    await _reveal(tester, find.byKey(const Key('training-set-select-all')));
    final action = tester.widget<TextButton>(
      find.byKey(const Key('training-set-select-all')),
    );
    expect(action.onPressed, isNotNull);
    await _reveal(tester, find.byKey(const Key('training-set-select-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('training-set-select-all')));
    await tester.pumpAndSettle();
    expect(controller.state.items.map((item) => item.blockId), ['find-me']);
  });

  testWidgets('save stays reachable on narrow large-text layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TrainingSetEditorController(
      repository: _SetRepository(),
      clock: FakeAppClock(initialWallTime: DateTime.utc(2026)),
      idGenerator: FakeIdGenerator(),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: TrainingSetEditorPage(
          controller: controller,
          indexRepository: _IndexRepository([
            for (var index = 0; index < 40; index++)
              _block(
                'long-title-$index',
                ContentType.puzzle,
                sourceId: 'A tactics book with a very long title that must fit the dropdown',
              ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final save = find.byKey(const Key('training-set-save'));
    expect(save.hitTestable(), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .text(
            'A tactics book with a very long title that must fit the dropdown',
          )
          .last,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const Key('training-set-scroll')),
      const Offset(0, -2500),
    );
    await tester.pumpAndSettle();
    expect(save.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exercise range reports gaps and preserves cross-book items', (
    tester,
  ) async {
    final controller = TrainingSetEditorController(
      repository: _SetRepository(),
      clock: FakeAppClock(initialWallTime: DateTime.utc(2026)),
      idGenerator: FakeIdGenerator(),
    );
    controller.add(
      _block('existing-book-b', ContentType.puzzle, sourceId: 'book-b'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingSetEditorPage(
          controller: controller,
          indexRepository: _IndexRepository([
            _woodpeckerBlock('woodpecker-15', 0, black: 'Exercise 15'),
            _woodpeckerBlock('woodpecker-17', 1, black: 'Exercise 17'),
            _woodpeckerBlock('woodpecker-18', 2, black: 'Exercise 18'),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _reveal(tester, find.textContaining('gaps: 16'));
    expect(find.textContaining('gaps: 16'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('training-set-range-start')),
      '15',
    );
    await tester.enterText(
      find.byKey(const Key('training-set-range-end')),
      '17',
    );
    await _reveal(tester, find.byTooltip('Add exercise range'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add exercise range'));
    await tester.pumpAndSettle();

    expect(controller.state.items.map((item) => item.blockId), [
      'existing-book-b',
      'woodpecker-15',
      'woodpecker-17',
    ]);
  });

  testWidgets('duplicate exercise IDs cannot be added to training sets', (
    tester,
  ) async {
    final controller = TrainingSetEditorController(
      repository: _SetRepository(),
      clock: FakeAppClock(initialWallTime: DateTime.utc(2026)),
      idGenerator: FakeIdGenerator(),
    );
    final duplicate = PgnBlockIndex(
      id: 'duplicate',
      sourceId: 'source',
      startOffset: 0,
      endOffset: 1,
      ordinal: 0,
      contentType: ContentType.puzzle,
      parseStatus: PgnBlockParseStatus.valid,
      diagnosticSummary: 'duplicateExerciseId',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingSetEditorPage(
          controller: controller,
          indexRepository: _IndexRepository([duplicate]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _reveal(tester, find.byKey(const ValueKey('candidate-duplicate')));
    expect(
      find.textContaining('Duplicate exercise ID; blocked until corrected'),
      findsOneWidget,
    );
    expect(find.byTooltip('Add item'), findsNothing);
    controller.add(duplicate);
    await tester.pump();
    expect(controller.state.items, isEmpty);
    expect(
      controller.state.validationMessage,
      contains('duplicate exercise ID'),
    );
  });

  testWidgets(
    'malformed indexed candidates show diagnostics and cannot be added',
    (tester) async {
      final controller = TrainingSetEditorController(
        repository: _SetRepository(),
        clock: FakeAppClock(initialWallTime: DateTime.utc(2026)),
        idGenerator: FakeIdGenerator(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingSetEditorPage(
            controller: controller,
            indexRepository: _IndexRepository([
              _block(
                'bad',
                ContentType.puzzle,
                parseStatus: PgnBlockParseStatus.malformed,
              ),
              _block(
                'deferred',
                ContentType.puzzle,
                parseStatus: PgnBlockParseStatus.notParsed,
              ),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _reveal(tester, find.byKey(const ValueKey('candidate-bad')));
      expect(find.textContaining('Malformed · Unavailable'), findsOneWidget);
      expect(find.byTooltip('Add item'), findsOneWidget);
      controller.add(
        _block(
          'bad',
          ContentType.puzzle,
          parseStatus: PgnBlockParseStatus.malformed,
        ),
      );
      await tester.pump();
      expect(controller.state.items, isEmpty);
    },
  );
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('training-set-scroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

PgnBlockIndex _block(
  String id,
  ContentType type, {
  String sourceId = 'source',
  String? section,
  int? sequence,
  PgnBlockParseStatus parseStatus = PgnBlockParseStatus.valid,
}) => PgnBlockIndex(
  id: id,
  sourceId: sourceId,
  startOffset: 0,
  endOffset: 1,
  ordinal: sequence ?? (id == 'p' ? 0 : 1),
  section: section,
  sequence: sequence,
  contentType: type,
  parseStatus: parseStatus,
);

PgnBlockIndex _woodpeckerBlock(
  String id,
  int ordinal, {
  required String black,
  ContentType contentType = ContentType.puzzle,
}) => PgnBlockIndex(
  id: id,
  sourceId: 'book-a',
  startOffset: ordinal,
  endOffset: ordinal + 1,
  ordinal: ordinal,
  event: '?',
  white: '4) Easy Exercises',
  black: black,
  contentType: contentType,
  exerciseId: 'generated-1234567890abcdef',
  parseStatus: PgnBlockParseStatus.valid,
);

final class _IndexRepository implements PgnIndexRepository {
  _IndexRepository(this.blocks);
  final List<PgnBlockIndex> blocks;
  final List<int> searchLimits = [];
  @override
  Future<int> countForSource(String sourceId) async => blocks.length;
  @override
  Future<PgnBlockIndex?> getById(String id) async =>
      blocks.where((b) => b.id == id).firstOrNull;
  @override
  Future<PgnIndexPage> search({
    PgnIndexFilter filter = const PgnIndexFilter(),
    PgnIndexSort sort = PgnIndexSort.sourceOrder,
    int offset = 0,
    required int limit,
  }) async {
    searchLimits.add(limit);
    final filtered = blocks
        .where(
          (block) =>
              filter.contentType == null ||
              block.contentType == filter.contentType,
        )
        .toList();
    final page = filtered.skip(offset).take(limit).toList();
    return PgnIndexPage(
      items: page,
      nextOffset: offset + page.length < filtered.length
          ? offset + page.length
          : null,
    );
  }
}

final class _SetRepository implements TrainingSetRepository {
  final List<TrainingSet> sets = [];
  @override
  Future<void> removeSet({
    required String id,
    required DateTime removedAt,
  }) async => sets.removeWhere((set) => set.id == id);
  @override
  Future<void> addItem(TrainingSetItem item) async {}
  @override
  Future<void> archiveSet({
    required String id,
    required DateTime archivedAt,
  }) async {
    final i = sets.indexWhere((set) => set.id == id);
    final set = sets[i];
    sets[i] = TrainingSet(
      id: set.id,
      name: set.name,
      status: TrainingSetStatus.archived,
      items: set.items,
      createdAt: set.createdAt,
      updatedAt: archivedAt,
      archivedAt: archivedAt,
    );
  }

  @override
  Future<void> createSet(TrainingSet set) async => sets.add(set);
  @override
  Future<TrainingSet?> getSet(String id) async =>
      sets.where((set) => set.id == id).firstOrNull;
  @override
  Future<List<TrainingSet>> listSets() async => List.of(sets);
  @override
  Future<void> removeItem({
    required String trainingSetId,
    required String itemId,
  }) async {}
  @override
  Future<void> renameSet({
    required String id,
    required String name,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> reorderItems({
    required String trainingSetId,
    required List<String> orderedItemIds,
  }) async {}
}

final class _PendingIndexRepository implements PgnIndexRepository {
  final page = Completer<PgnIndexPage>();
  int calls = 0;
  @override
  Future<PgnIndexPage> search({
    PgnIndexFilter filter = const PgnIndexFilter(),
    PgnIndexSort sort = PgnIndexSort.sourceOrder,
    int offset = 0,
    required int limit,
  }) {
    calls++;
    return page.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
