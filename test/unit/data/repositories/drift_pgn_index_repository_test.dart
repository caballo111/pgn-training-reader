import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/errors/app_failure.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';
import 'package:pgntrainingreader/data/repositories/drift_pgn_index_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/library/pgn_index_repository.dart';

void main() {
  late AppDatabase database;
  late DriftPgnIndexRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftPgnIndexRepository(database);
    await database.customStatement('PRAGMA foreign_keys = ON');
    for (final source in ['a', 'b']) {
      await database
          .into(database.pgnSources)
          .insert(
            PgnSourcesCompanion.insert(
              id: source,
              displayName: source,
              accessMode: 'managedCopy',
              scannerVersion: 1,
              importState: 'indexed',
              createdAtMicros: 1,
              updatedAtMicros: 1,
            ),
          );
    }
    await _seed(database);
  });

  tearDown(() => database.close());

  test(
    'classification override persists separately from authored source metadata',
    () async {
      await repository.overrideClassification('a1', ContentType.instruction);
      final block = await DriftPgnIndexRepository(database).getById('a1');
      expect(block!.contentType, ContentType.instruction);
      expect(block.inferredClassification, isFalse);
      expect(block.white, 'Alice');
      await (database.update(
        database.pgnBlocks,
      )..where((b) => b.id.equals('a1'))).write(
        const PgnBlocksCompanion(authoredContentType: Value('Puzzle')),
      );
      expect(
        () =>
            repository.overrideClassification('a1', ContentType.demonstration),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        (await repository.getById('a1'))!.contentType,
        ContentType.instruction,
      );
    },
  );

  test('filters all metadata and combines constraints with AND', () async {
    final cases = <PgnIndexFilter, String>{
      const PgnIndexFilter(sourceId: 'a', player: 'ALIce'): 'a1',
      const PgnIndexFilter(sourceId: 'a', event: 'open'): 'a1',
      const PgnIndexFilter(sourceId: 'a', result: '1-0'): 'a1',
      const PgnIndexFilter(sourceId: 'a', contentType: ContentType.puzzle):
          'a1',
      const PgnIndexFilter(sourceId: 'a', section: 'chapter'): 'a1,a2',
      const PgnIndexFilter(sourceId: 'a', theme: 'fork'): 'a1',
      const PgnIndexFilter(sourceId: 'a', difficulty: 'hard'): 'a1',
      const PgnIndexFilter(sourceId: 'a', query: 'alice'): 'a1',
      const PgnIndexFilter(sourceId: 'b'): 'b1',
      const PgnIndexFilter(sourceId: 'a', event: 'open', theme: 'fork'): 'a1',
    };
    for (final entry in cases.entries) {
      expect(
        (await repository.search(
          filter: entry.key,
          limit: 10,
        )).items.map((item) => item.id).toList(),
        entry.value.split(','),
        reason: entry.key.toString(),
      );
    }
    expect(
      (await repository.search(
        filter: const PgnIndexFilter(query: '2020'),
        limit: 10,
      )).items,
      isEmpty,
    );
  });

  test(
    'treats LIKE wildcard characters as literal substring content',
    () async {
      expect(
        (await repository.search(
          filter: const PgnIndexFilter(event: '100%_match\\'),
          limit: 10,
        )).items.map((item) => item.id),
        <String>['a2'],
      );
      expect(
        (await repository.search(
          filter: const PgnIndexFilter(event: '%'),
          limit: 10,
        )).items.map((item) => item.id),
        <String>['a2'],
      );
    },
  );

  test('orders across sources and pages with nullable next offset', () async {
    final first = await repository.search(limit: 2);
    expect(first.items.map((item) => item.id), ['a1', 'a2']);
    expect(first.nextOffset, 2);
    final second = await repository.search(offset: first.nextOffset!, limit: 2);
    expect(second.items.map((item) => item.id), ['a3', 'b1']);
    expect(second.nextOffset, isNull);
    expect(await repository.countForSource('a'), 3);
    expect(await repository.getById('missing'), isNull);
  });

  test('adjacent blocks stay in source and stop at both boundaries', () async {
    final first = (await repository.getById('a1'))!;
    final middle = (await repository.getById('a2'))!;
    final last = (await repository.getById('a3'))!;
    expect(await repository.getPreviousInSource(first), isNull);
    expect((await repository.getNextInSource(first))!.id, 'a2');
    expect((await repository.getPreviousInSource(middle))!.id, 'a1');
    expect((await repository.getNextInSource(middle))!.id, 'a3');
    expect((await repository.getPreviousInSource(last))!.id, 'a2');
    expect(await repository.getNextInSource(last), isNull);

    // Source ordinals can have gaps after invalid or retired blocks.
    await database.customStatement(
      "UPDATE pgn_blocks SET is_current = 0 WHERE id = 'a2'",
    );
    expect((await repository.getNextInSource(first))!.id, 'a3');
    expect((await repository.getPreviousInSource(last))!.id, 'a1');
  });

  test('rejects invalid page sizes and offsets', () async {
    for (final limit in [0, 1001, -1]) {
      await expectLater(
        repository.search(limit: limit),
        throwsA(isA<ValidationFailure>()),
      );
    }
    await expectLater(
      repository.search(limit: 1, offset: -1),
      throwsA(isA<ValidationFailure>()),
    );
  });
}

Future<void> _seed(AppDatabase database) async {
  final entries =
      <
        ({
          String id,
          String source,
          int ordinal,
          String event,
          String? white,
          String result,
          String type,
          String? section,
          String? theme,
          String? difficulty,
          String date,
        })
      >[
        (
          id: 'a1',
          source: 'a',
          ordinal: 0,
          event: 'City Open',
          white: 'Alice',
          result: '1-0',
          type: 'Puzzle',
          section: 'Chapter 1',
          theme: 'Fork',
          difficulty: 'Hard',
          date: '2025.01.01',
        ),
        (
          id: 'a2',
          source: 'a',
          ordinal: 1,
          event: r'100%_match\',
          white: 'Bob',
          result: '0-1',
          type: 'Instruction',
          section: 'Chapter 2',
          theme: 'Pin',
          difficulty: 'Easy',
          date: '2024.01.01',
        ),
        (
          id: 'a3',
          source: 'a',
          ordinal: 2,
          event: 'Other',
          white: 'Carl',
          result: '*',
          type: 'Demonstration',
          section: null,
          theme: null,
          difficulty: null,
          date: '2023.01.01',
        ),
        (
          id: 'b1',
          source: 'b',
          ordinal: 0,
          event: 'City Open',
          white: 'Alice',
          result: '1-0',
          type: 'Puzzle',
          section: 'Chapter 1',
          theme: 'Fork',
          difficulty: 'Hard',
          date: '2025.01.01',
        ),
      ];
  for (final entry in entries) {
    await database
        .into(database.pgnBlocks)
        .insert(
          PgnBlocksCompanion.insert(
            id: entry.id,
            sourceId: entry.source,
            startOffset: entry.ordinal * 20,
            endOffset: entry.ordinal * 20 + 10,
            ordinal: entry.ordinal,
            event: Value(entry.event),
            date: Value(entry.date),
            white: Value(entry.white),
            result: Value(entry.result),
            contentType: entry.type,
            section: Value(entry.section),
            theme: Value(entry.theme),
            difficulty: Value(entry.difficulty),
            parseStatus: 'NotParsed',
          ),
        );
  }
}
