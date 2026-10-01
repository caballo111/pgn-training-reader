import 'training_set.dart';
import 'training_set_item.dart';

/// Persists editable training set definitions without exposing database types.
abstract interface class TrainingSetRepository {
  /// Returns a set by stable ID, or `null` when absent.
  /// Removed sets remain available as archived definitions for history.
  Future<TrainingSet?> getSet(String id);

  /// Lists visible sets by name and then stable ID, excluding removed sets.
  Future<List<TrainingSet>> listSets();

  /// Creates a set and its ordered items atomically.
  Future<void> createSet(TrainingSet set);

  /// Changes the name and update timestamp while preserving set identity.
  Future<void> renameSet({
    required String id,
    required String name,
    required DateTime updatedAt,
  });

  /// Archives a set while retaining its items and history.
  Future<void> archiveSet({required String id, required DateTime archivedAt});

  /// Hides a set from the list and prevents editing or new cycles.
  /// Retains its archived definition, items, and training history by stable ID.
  Future<void> removeSet({required String id, required DateTime removedAt});

  /// Adds an indexed block at the item's explicit position.
  Future<void> addItem(TrainingSetItem item);

  /// Removes an item from future selection and compacts remaining positions.
  Future<void> removeItem({
    required String trainingSetId,
    required String itemId,
  });

  /// Reorders every item in the set by its stable item ID.
  Future<void> reorderItems({
    required String trainingSetId,
    required List<String> orderedItemIds,
  });
}
