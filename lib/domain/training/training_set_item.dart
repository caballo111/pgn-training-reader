import '../chess_content/content_type.dart';

/// State stored for an item in its training set.
enum TrainingSetItemState {
  pending;

  String toDatabaseValue() => switch (this) {
    TrainingSetItemState.pending => 'pending',
  };

  static TrainingSetItemState fromDatabaseValue(String value) =>
      switch (value) {
        'pending' => TrainingSetItemState.pending,
        _ => throw FormatException('Unknown training set item state.', value),
      };
}

/// One stably identified content block in an explicitly ordered set.
final class TrainingSetItem {
  factory TrainingSetItem({
    required String id,
    required String trainingSetId,
    required String blockId,
    required int position,
    required ContentType contentType,
    TrainingSetItemState state = TrainingSetItemState.pending,
    required DateTime addedAt,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (trainingSetId.isEmpty) {
      throw ArgumentError.value(
        trainingSetId,
        'trainingSetId',
        'Must not be empty.',
      );
    }
    if (blockId.isEmpty) {
      throw ArgumentError.value(blockId, 'blockId', 'Must not be empty.');
    }
    if (position < 0) {
      throw ArgumentError.value(position, 'position', 'Must not be negative.');
    }
    if (contentType == ContentType.unsupported) {
      throw ArgumentError.value(
        contentType,
        'contentType',
        'Unsupported content cannot be added to a training set.',
      );
    }

    return TrainingSetItem._(
      id: id,
      trainingSetId: trainingSetId,
      blockId: blockId,
      position: position,
      contentType: contentType,
      state: state,
      addedAt: addedAt,
    );
  }

  const TrainingSetItem._({
    required this.id,
    required this.trainingSetId,
    required this.blockId,
    required this.position,
    required this.contentType,
    required this.state,
    required this.addedAt,
  });

  final String id;
  final String trainingSetId;
  final String blockId;
  final int position;
  final ContentType contentType;
  final TrainingSetItemState state;
  final DateTime addedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingSetItem &&
          other.id == id &&
          other.trainingSetId == trainingSetId &&
          other.blockId == blockId &&
          other.position == position &&
          other.contentType == contentType &&
          other.state == state &&
          other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(
    id,
    trainingSetId,
    blockId,
    position,
    contentType,
    state,
    addedAt,
  );
}
