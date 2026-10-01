import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/errors/app_failure.dart';
import 'package:pgntrainingreader/data/database/app_database.dart'
    hide TrainingSet, TrainingSetItem;
import 'package:pgntrainingreader/data/repositories/drift_training_set_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/training/training_set.dart';
import 'package:pgntrainingreader/domain/training/training_set_item.dart';

void main() {
  late AppDatabase database;
  late DriftTrainingSetRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftTrainingSetRepository(database);
    await database.customStatement('PRAGMA foreign_keys = ON');
    await database
        .into(database.pgnSources)
        .insert(
          PgnSourcesCompanion.insert(
            id: 'source',
            displayName: 'Source',
            accessMode: 'managedCopy',
            scannerVersion: 1,
            importState: 'ready',
            createdAtMicros: 1,
            updatedAtMicros: 1,
          ),
        );
    for (var i = 1; i <= 4; i++) {
      await database
          .into(database.pgnBlocks)
          .insert(
            PgnBlocksCompanion.insert(
              id: 'block-$i',
              sourceId: 'source',
              startOffset: i * 10,
              endOffset: i * 10 + 9,
              ordinal: i,
              contentType: i == 2 ? 'Text' : 'Puzzle',
              parseStatus: 'notParsed',
            ),
          );
    }
  });

  tearDown(() => database.close());

  test(
    'creates, lists, renames, and archives without deleting contents',
    () async {
      final set = _set(
        'set-b',
        name: 'Bravo',
        items: <TrainingSetItem>[
          _item('set-b', 'item-1', 'block-1', 0),
          _item('set-b', 'item-2', 'block-2', 1, ContentType.text),
        ],
      );
      await repository.createSet(set);
      await repository.createSet(_set('set-a', name: 'Alpha'));

      expect((await repository.listSets()).map((value) => value.id), <String>[
        'set-a',
        'set-b',
      ]);
      expect(await repository.getSet('set-b'), set);

      await repository.renameSet(
        id: 'set-b',
        name: 'Renamed',
        updatedAt: DateTime.utc(2026, 9, 4),
      );
      await repository.archiveSet(
        id: 'set-b',
        archivedAt: DateTime.utc(2026, 9, 5),
      );
      final archived = (await repository.getSet('set-b'))!;
      expect(archived.name, 'Renamed');
      expect(archived.status, TrainingSetStatus.archived);
      expect(archived.items, set.items);
      expect(await (database.select(database.pgnBlocks)).get(), hasLength(4));
    },
  );

  test(
    'adds, reorders, and removes stable items with contiguous order',
    () async {
      await repository.createSet(
        _set(
          'set',
          items: <TrainingSetItem>[
            _item('set', 'a', 'block-1', 0),
            _item('set', 'b', 'block-2', 1, ContentType.text),
            _item('set', 'c', 'block-3', 2),
          ],
        ),
      );
      await repository.reorderItems(
        trainingSetId: 'set',
        orderedItemIds: <String>['c', 'a', 'b'],
      );
      await repository.addItem(_item('set', 'd', 'block-4', 1));
      await database.customStatement(
        "INSERT INTO cycles (id, training_set_id, status, created_at_micros) "
        "VALUES ('cycle', 'set', 'completed', 1)",
      );
      await database.customStatement(
        "INSERT INTO training_sessions "
        "(id, cycle_id, status, started_at_micros, study_day_micros) "
        "VALUES ('session', 'cycle', 'closed', 1, 1)",
      );
      await database.customStatement(
        "INSERT INTO puzzle_attempts "
        "(id, block_id, cycle_id, session_id, status, outcome, "
        "started_at_micros, completed_at_micros) "
        "VALUES ('attempt', 'block-4', 'cycle', 'session', 'finalized', "
        "'passed', 1, 2)",
      );
      expect(
        (await repository.getSet('set'))!.items.map((item) => item.id),
        <String>['c', 'd', 'a', 'b'],
      );

      await repository.removeItem(trainingSetId: 'set', itemId: 'd');
      final items = (await repository.getSet('set'))!.items;
      expect(items.map((item) => item.id), <String>['c', 'a', 'b']);
      expect(items.map((item) => item.position), <int>[0, 1, 2]);
      expect(await (database.select(database.pgnBlocks)).get(), hasLength(4));
      expect(
        await (database.select(database.puzzleAttempts)).get(),
        hasLength(1),
      );
    },
  );

  test('removal retains items, history, snapshots, and imported content', () async {
    await repository.createSet(
      _set('set', items: [_item('set', 'item', 'block-1', 0)]),
    );
    await repository.createSet(_set('other'));
    await database.customStatement(
      "INSERT INTO cycles (id, training_set_id, status, created_at_micros) VALUES ('cycle', 'set', 'completed', 1)",
    );
    await database.customStatement(
      "INSERT INTO training_sessions (id, cycle_id, status, started_at_micros, study_day_micros) VALUES ('session', 'cycle', 'closed', 1, 1)",
    );
    await database.customStatement(
      "INSERT INTO puzzle_attempts (id, block_id, cycle_id, session_id, status, outcome, started_at_micros, completed_at_micros) VALUES ('attempt', 'block-1', 'cycle', 'session', 'finalized', 'passed', 1, 2)",
    );
    await database.customStatement(
      "INSERT INTO app_settings (key, value) VALUES ('cycle-set:cycle', 'snapshot')",
    );
    await repository.removeSet(id: 'set', removedAt: DateTime.utc(2026, 10));
    expect((await repository.listSets()).map((set) => set.id), ['other']);
    final retained = (await repository.getSet('set'))!;
    expect(retained.status, TrainingSetStatus.archived);
    expect(retained.items, hasLength(1));
    expect(await database.select(database.cycles).get(), hasLength(1));
    expect(
      await database.select(database.trainingSessions).get(),
      hasLength(1),
    );
    expect(await database.select(database.puzzleAttempts).get(), hasLength(1));
    expect(await database.select(database.pgnBlocks).get(), hasLength(4));
    expect(await database.select(database.pgnSources).get(), hasLength(1));
    expect(
      (await database
              .customSelect(
                "SELECT value FROM app_settings WHERE key = 'cycle-set:cycle'",
              )
              .getSingle())
          .read<String>('value'),
      'snapshot',
    );
    await expectLater(
      repository.addItem(_item('set', 'new', 'block-3', 1)),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('removal is atomic when writing the tombstone fails', () async {
    final original = _set('set');
    await repository.createSet(original);
    await database.customStatement(
      "CREATE TRIGGER reject_removal BEFORE INSERT ON app_settings WHEN NEW.key LIKE 'removed-training-set:%' BEGIN SELECT RAISE(ABORT, 'failure'); END",
    );
    await expectLater(
      repository.removeSet(id: 'set', removedAt: DateTime.utc(2026, 10)),
      throwsA(isA<DatabaseFailure>()),
    );
    expect(await repository.getSet('set'), original);
    expect(await repository.listSets(), [original]);
  });

  test('removing an archived set preserves its archive timestamp', () async {
    await repository.createSet(_set('set'));
    final archivedAt = DateTime.utc(2026, 9, 5);
    await repository.archiveSet(id: 'set', archivedAt: archivedAt);
    await repository.removeSet(id: 'set', removedAt: DateTime.utc(2026, 10));
    await repository.removeSet(id: 'set', removedAt: DateTime.utc(2026, 10, 2));
    expect(await repository.listSets(), isEmpty);
    expect((await repository.getSet('set'))!.archivedAt, archivedAt);
    await expectLater(
      repository.removeSet(id: 'missing', removedAt: archivedAt),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('removal persists after reopening the database', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp(
      'training-set-removal-',
    );
    final file = File('${directory.path}/test.sqlite');
    var persistent = AppDatabase(NativeDatabase(file));
    try {
      var sets = DriftTrainingSetRepository(persistent);
      await sets.createSet(_set('set'));
      await sets.removeSet(id: 'set', removedAt: DateTime.utc(2026, 10));
      await persistent.close();
      persistent = AppDatabase(NativeDatabase(file));
      sets = DriftTrainingSetRepository(persistent);
      expect(await sets.listSets(), isEmpty);
      expect((await sets.getSet('set'))!.status, TrainingSetStatus.archived);
    } finally {
      await persistent.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'rejects repeated blocks in one set and permits different sets',
    () async {
      await repository.createSet(
        _set(
          'one',
          items: <TrainingSetItem>[_item('one', 'first', 'block-1', 0)],
        ),
      );
      await repository.createSet(
        _set(
          'two',
          items: <TrainingSetItem>[
            _item('two', 'same-block-other-set', 'block-1', 0),
          ],
        ),
      );

      await expectLater(
        repository.addItem(_item('one', 'second', 'block-1', 1)),
        throwsA(isA<ValidationFailure>()),
      );
      expect((await repository.getSet('one'))!.items, hasLength(1));
      expect((await repository.getSet('two'))!.items, hasLength(1));
    },
  );

  test('rejects invalid order and edits to archived set', () async {
    await repository.createSet(
      _set('set', items: <TrainingSetItem>[_item('set', 'a', 'block-1', 0)]),
    );
    await expectLater(
      repository.reorderItems(
        trainingSetId: 'set',
        orderedItemIds: <String>['unknown'],
      ),
      throwsA(isA<ValidationFailure>()),
    );
    await repository.archiveSet(
      id: 'set',
      archivedAt: DateTime.utc(2026, 9, 5),
    );
    await expectLater(
      repository.addItem(_item('set', 'b', 'block-2', 1, ContentType.text)),
      throwsA(isA<ValidationFailure>()),
    );
  });
}

TrainingSet _set(
  String id, {
  String name = 'Set',
  List<TrainingSetItem> items = const <TrainingSetItem>[],
}) => TrainingSet(
  id: id,
  name: name,
  items: items,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
);

TrainingSetItem _item(
  String setId,
  String id,
  String blockId,
  int position, [
  ContentType contentType = ContentType.puzzle,
]) => TrainingSetItem(
  id: id,
  trainingSetId: setId,
  blockId: blockId,
  position: position,
  contentType: contentType,
  addedAt: DateTime.utc(2026, 9, 2),
);
