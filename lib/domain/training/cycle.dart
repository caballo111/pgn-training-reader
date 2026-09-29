import 'lifecycle_status.dart';

/// One pass through the exercises in a training set.
///
/// A cycle can span multiple sessions and days. Its identity and history are
/// retained when it is completed or stopped.
final class Cycle {
  factory Cycle({
    required String id,
    required String trainingSetId,
    required CycleStatus status,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? stoppedAt,
    required DateTime createdAt,
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
    if (completedAt != null && stoppedAt != null) {
      throw ArgumentError('A cycle cannot be completed and stopped.');
    }
    if (status == CycleStatus.pending && startedAt != null) {
      throw ArgumentError('A pending cycle must not have a start time.');
    }
    if (status == CycleStatus.active && startedAt == null) {
      throw ArgumentError('An active cycle must have a start time.');
    }
    if (status == CycleStatus.completed && completedAt == null) {
      throw ArgumentError('A completed cycle must have a completion time.');
    }
    if (status == CycleStatus.stopped && stoppedAt == null) {
      throw ArgumentError('A stopped cycle must have a stop time.');
    }
    if ((status == CycleStatus.completed || status == CycleStatus.stopped) &&
        startedAt == null) {
      throw ArgumentError('A terminal cycle must have a start time.');
    }
    if (status != CycleStatus.completed && completedAt != null) {
      throw ArgumentError('Only a completed cycle may have a completion time.');
    }
    if (status != CycleStatus.stopped && stoppedAt != null) {
      throw ArgumentError('Only a stopped cycle may have a stop time.');
    }
    if (startedAt != null &&
        completedAt != null &&
        completedAt.isBefore(startedAt)) {
      throw ArgumentError.value(
        completedAt,
        'completedAt',
        'Must not precede startedAt.',
      );
    }
    if (startedAt != null &&
        stoppedAt != null &&
        stoppedAt.isBefore(startedAt)) {
      throw ArgumentError.value(
        stoppedAt,
        'stoppedAt',
        'Must not precede startedAt.',
      );
    }

    return Cycle._(
      id: id,
      trainingSetId: trainingSetId,
      status: status,
      startedAt: startedAt,
      completedAt: completedAt,
      stoppedAt: stoppedAt,
      createdAt: createdAt,
    );
  }

  const Cycle._({
    required this.id,
    required this.trainingSetId,
    required this.status,
    required this.startedAt,
    required this.completedAt,
    required this.stoppedAt,
    required this.createdAt,
  });

  final String id;
  final String trainingSetId;
  final CycleStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? stoppedAt;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cycle &&
          other.id == id &&
          other.trainingSetId == trainingSetId &&
          other.status == status &&
          other.startedAt == startedAt &&
          other.completedAt == completedAt &&
          other.stoppedAt == stoppedAt &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    trainingSetId,
    status,
    startedAt,
    completedAt,
    stoppedAt,
    createdAt,
  );
}
