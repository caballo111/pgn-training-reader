import 'package:drift/drift.dart';

import '../../core/errors/app_failure.dart';
import '../../domain/chess_content/content_type.dart';
import '../../domain/training/training_set.dart';
import '../../domain/training/training_set_item.dart';
import '../../domain/training/training_set_repository.dart';
import '../database/app_database.dart' hide TrainingSet, TrainingSetItem;
import '../database/app_database.dart' as db show TrainingSet, TrainingSetItem;

/// Drift-backed training set definitions and ordered items.
final class DriftTrainingSetRepository implements TrainingSetRepository {
  DriftTrainingSetRepository(this._database);

  final AppDatabase _database;

  @override
  Future<TrainingSet?> getSet(String id) => _guard(() async {
    final row = await (_database.select(
      _database.trainingSets,
    )..where((set) => set.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _loadSet(row);
  });

  @override
  Future<List<TrainingSet>> listSets() => _guard(() async {
    final removed = await _database
        .customSelect(
          "SELECT key FROM app_settings WHERE key LIKE 'removed-training-set:%'",
        )
        .get();
    final removedIds = removed
        .map(
          (row) =>
              row.read<String>('key').substring('removed-training-set:'.length),
        )
        .toSet();
    final rows =
        await (_database.select(_database.trainingSets)..orderBy([
              (set) => OrderingTerm.asc(set.name),
              (set) => OrderingTerm.asc(set.id),
            ]))
            .get();
    final result = <TrainingSet>[];
    for (final row in rows) {
      if (removedIds.contains(row.id)) continue;
      result.add(await _loadSet(row));
    }
    return List.unmodifiable(result);
  });

  @override
  Future<void> createSet(TrainingSet set) => _guard(() async {
    final blockIds = set.items.map((item) => item.blockId).toSet();
    if (blockIds.length != set.items.length) {
      throw const ValidationFailure(
        code: 'duplicate_training_set_block',
        message: 'A content block can appear only once in a training set.',
      );
    }
    await _database.transaction(() async {
      await _database
          .into(_database.trainingSets)
          .insert(
            TrainingSetsCompanion.insert(
              id: set.id,
              name: set.name.trim(),
              status: Value(set.status.toDatabaseValue()),
              createdAtMicros: _micros(set.createdAt),
              updatedAtMicros: _micros(set.updatedAt),
              archivedAtMicros: Value(_nullableMicros(set.archivedAt)),
            ),
          );
      for (final item in set.items) {
        await _validateIndexedItem(item);
        await _database
            .into(_database.trainingSetItems)
            .insert(_toInsert(item));
      }
    });
  });

  @override
  Future<void> renameSet({
    required String id,
    required String name,
    required DateTime updatedAt,
  }) => _guard(() async {
    if (name.trim().isEmpty) {
      throw const ValidationFailure(
        code: 'empty_training_set_name',
        message: 'Enter a name for the training set.',
      );
    }
    final changed =
        await (_database.update(_database.trainingSets)
              ..where((set) => set.id.equals(id) & set.status.equals('active')))
            .write(
              TrainingSetsCompanion(
                name: Value(name.trim()),
                updatedAtMicros: Value(_micros(updatedAt)),
              ),
            );
    if (changed == 0) _missingSet();
  });

  @override
  Future<void> archiveSet({required String id, required DateTime archivedAt}) =>
      _guard(() async {
        final changed =
            await (_database.update(_database.trainingSets)..where(
                  (set) => set.id.equals(id) & set.status.equals('active'),
                ))
                .write(
                  TrainingSetsCompanion(
                    status: const Value('archived'),
                    archivedAtMicros: Value(_micros(archivedAt)),
                    updatedAtMicros: Value(_micros(archivedAt)),
                  ),
                );
        if (changed == 0) _missingSet();
      });

  @override
  Future<void> removeSet({required String id, required DateTime removedAt}) =>
      _guard(() async {
        await _database.transaction(() async {
          final set = await getSet(id);
          if (set == null) _missingSet();
          if (set!.status == TrainingSetStatus.active) {
            await archiveSet(id: id, archivedAt: removedAt);
          }
          await _database.customStatement(
            'INSERT INTO app_settings (key, value) VALUES (?, ?) '
            'ON CONFLICT(key) DO NOTHING',
            ['removed-training-set:$id', _micros(removedAt).toString()],
          );
        });
      });

  @override
  Future<void> addItem(TrainingSetItem item) => _guard(() async {
    await _database.transaction(() async {
      await _requireActiveSet(item.trainingSetId);
      await _validateIndexedItem(item);
      final existing = await _items(item.trainingSetId);
      if (existing.any((row) => row.blockId == item.blockId)) {
        throw const ValidationFailure(
          code: 'duplicate_training_set_block',
          message: 'This content is already in the training set.',
        );
      }
      if (item.position > existing.length) _invalidOrder();
      final reordered = existing.map(_toDomain).toList()
        ..insert(item.position, item);
      await _writeOrder(item.trainingSetId, reordered);
    });
  });

  @override
  Future<void> removeItem({
    required String trainingSetId,
    required String itemId,
  }) => _guard(() async {
    await _database.transaction(() async {
      await _requireActiveSet(trainingSetId);
      final rows = await _items(trainingSetId);
      final remaining = rows.where((row) => row.id != itemId).toList();
      if (remaining.length == rows.length) _missingItem();
      await (_database.delete(_database.trainingSetItems)..where(
            (item) =>
                item.id.equals(itemId) &
                item.trainingSetId.equals(trainingSetId),
          ))
          .go();
      await _writeOrder(
        trainingSetId,
        remaining.map(_toDomain).toList(growable: false),
      );
    });
  });

  @override
  Future<void> reorderItems({
    required String trainingSetId,
    required List<String> orderedItemIds,
  }) => _guard(() async {
    await _database.transaction(() async {
      await _requireActiveSet(trainingSetId);
      final rows = await _items(trainingSetId);
      final currentIds = rows.map((item) => item.id).toSet();
      if (orderedItemIds.length != rows.length ||
          orderedItemIds.toSet().length != orderedItemIds.length ||
          !orderedItemIds.toSet().containsAll(currentIds)) {
        _invalidOrder();
      }
      final byId = {for (final row in rows) row.id: row};
      await _writeOrder(
        trainingSetId,
        orderedItemIds
            .map((id) => _toDomain(byId[id]!))
            .toList(growable: false),
      );
    });
  });

  Future<TrainingSet> _loadSet(db.TrainingSet row) async {
    final items = await _items(row.id);
    return TrainingSet(
      id: row.id,
      name: row.name,
      status: TrainingSetStatus.fromDatabaseValue(row.status),
      items: items.map(_toDomain).toList(growable: false),
      createdAt: _date(row.createdAtMicros),
      updatedAt: _date(row.updatedAtMicros),
      archivedAt: row.archivedAtMicros == null
          ? null
          : _date(row.archivedAtMicros!),
    );
  }

  Future<List<db.TrainingSetItem>> _items(String setId) =>
      (_database.select(_database.trainingSetItems)
            ..where((item) => item.trainingSetId.equals(setId))
            ..orderBy([
              (item) => OrderingTerm.asc(item.position),
              (item) => OrderingTerm.asc(item.id),
            ]))
          .get();

  Future<void> _requireActiveSet(String id) async {
    final set = await (_database.select(
      _database.trainingSets,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (set == null) _missingSet();
    if (set!.status != 'active') {
      throw const ValidationFailure(
        code: 'training_set_archived',
        message: 'Archived training sets cannot be edited.',
      );
    }
  }

  Future<void> _validateIndexedItem(TrainingSetItem item) async {
    final block = await (_database.select(
      _database.pgnBlocks,
    )..where((row) => row.id.equals(item.blockId))).getSingleOrNull();
    if (block == null) {
      throw const ValidationFailure(
        code: 'training_set_block_missing',
        message: 'The selected library content is no longer available.',
      );
    }
    final source = await (_database.select(
      _database.pgnSources,
    )..where((row) => row.id.equals(block.sourceId))).getSingleOrNull();
    if (source == null ||
        source.importState == 'deleted' ||
        source.importState == 'sourceMissing' ||
        source.importState == 'sourceChanged') {
      throw const ValidationFailure(
        code: 'training_set_source_unavailable',
        message: 'This book is unavailable for new training set items.',
      );
    }
    final contentType = ContentType.fromDatabaseValue(block.contentType);
    if (contentType == ContentType.unsupported ||
        contentType != item.contentType) {
      throw const ValidationFailure(
        code: 'training_set_content_type_changed',
        message: 'The selected content is unsupported or has changed type.',
      );
    }
  }

  Future<void> _writeOrder(String setId, List<TrainingSetItem> ordered) async {
    final oldRows = await _items(setId);
    final offset =
        oldRows.length +
        oldRows.fold<int>(
          0,
          (max, row) => row.position > max ? row.position : max,
        ) +
        ordered.length +
        1;
    for (final row in oldRows) {
      await (_database.update(
        _database.trainingSetItems,
      )..where((item) => item.id.equals(row.id))).write(
        TrainingSetItemsCompanion(position: Value(row.position + offset)),
      );
    }
    for (var position = 0; position < ordered.length; position++) {
      final item = ordered[position];
      if (oldRows.any((row) => row.id == item.id)) {
        await (_database.update(_database.trainingSetItems)
              ..where((row) => row.id.equals(item.id)))
            .write(TrainingSetItemsCompanion(position: Value(position)));
      } else {
        await _database
            .into(_database.trainingSetItems)
            .insert(_toInsert(item.copyWithPosition(position)));
      }
    }
  }

  static TrainingSetItemsCompanion _toInsert(TrainingSetItem item) =>
      TrainingSetItemsCompanion.insert(
        id: item.id,
        trainingSetId: item.trainingSetId,
        blockId: item.blockId,
        position: item.position,
        contentType: item.contentType.toDatabaseValue(),
        state: Value(item.state.toDatabaseValue()),
        addedAtMicros: _micros(item.addedAt),
      );

  static TrainingSetItem _toDomain(db.TrainingSetItem row) => TrainingSetItem(
    id: row.id,
    trainingSetId: row.trainingSetId,
    blockId: row.blockId,
    position: row.position,
    contentType: ContentType.fromDatabaseValue(row.contentType),
    state: TrainingSetItemState.fromDatabaseValue(row.state),
    addedAt: _date(row.addedAtMicros),
  );

  static Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const DatabaseFailure(
        code: 'training_set_persistence_failed',
        message:
            'Training sets could not be saved or loaded. Retry the operation.',
      );
    }
  }

  static int _micros(DateTime value) => value.toUtc().microsecondsSinceEpoch;
  static int? _nullableMicros(DateTime? value) =>
      value?.toUtc().microsecondsSinceEpoch;
  static DateTime _date(int value) =>
      DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true);

  static void _missingSet() => throw const ValidationFailure(
    code: 'training_set_missing',
    message: 'The training set no longer exists.',
  );

  static void _missingItem() => throw const ValidationFailure(
    code: 'training_set_item_missing',
    message: 'The selected item no longer belongs to this training set.',
  );

  static void _invalidOrder() => throw const ValidationFailure(
    code: 'invalid_training_set_order',
    message: 'The item order must include every set item exactly once.',
  );
}

extension on TrainingSetItem {
  TrainingSetItem copyWithPosition(int position) => TrainingSetItem(
    id: id,
    trainingSetId: trainingSetId,
    blockId: blockId,
    position: position,
    contentType: contentType,
    state: state,
    addedAt: addedAt,
  );
}
