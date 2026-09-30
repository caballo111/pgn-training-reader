import 'training_set_item.dart';

/// Lifecycle state for a set definition.
enum TrainingSetStatus {
  active,
  archived;

  String toDatabaseValue() => switch (this) {
    TrainingSetStatus.active => 'active',
    TrainingSetStatus.archived => 'archived',
  };

  static TrainingSetStatus fromDatabaseValue(String value) => switch (value) {
    'active' => TrainingSetStatus.active,
    'archived' => TrainingSetStatus.archived,
    _ => throw FormatException('Unknown training set status.', value),
  };
}

/// An ordered selection of stable content identities for training.
final class TrainingSet {
  factory TrainingSet({
    required String id,
    required String name,
    TrainingSetStatus status = TrainingSetStatus.active,
    required List<TrainingSetItem> items,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty.');
    }
    if ((status == TrainingSetStatus.archived) != (archivedAt != null)) {
      throw ArgumentError(
        'Archived sets must have archivedAt; active sets must not.',
      );
    }

    final orderedItems = List<TrainingSetItem>.of(items)
      ..sort((a, b) => a.position.compareTo(b.position));
    final ids = <String>{};
    final positions = <int>{};
    for (final item in orderedItems) {
      if (item.trainingSetId != id) {
        throw ArgumentError('Every item must belong to this training set.');
      }
      if (!ids.add(item.id)) {
        throw ArgumentError('Training set item IDs must be unique.');
      }
      if (!positions.add(item.position)) {
        throw ArgumentError('Training set item positions must be unique.');
      }
    }

    return TrainingSet._(
      id: id,
      name: name,
      status: status,
      items: List.unmodifiable(orderedItems),
      createdAt: createdAt,
      updatedAt: updatedAt,
      archivedAt: archivedAt,
    );
  }

  const TrainingSet._({
    required this.id,
    required this.name,
    required this.status,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    required this.archivedAt,
  });

  final String id;
  final String name;
  final TrainingSetStatus status;

  /// Ordered Puzzle and Text content.
  final List<TrainingSetItem> items;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingSet &&
          other.id == id &&
          other.name == name &&
          other.status == status &&
          _sameItems(other.items, items) &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          other.archivedAt == archivedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    status,
    Object.hashAll(items),
    createdAt,
    updatedAt,
    archivedAt,
  );
}

bool _sameItems(List<TrainingSetItem> left, List<TrainingSetItem> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
