import 'lifecycle_status.dart';

/// A bounded study period within a cycle.
///
/// [studyDay] identifies the calendar day used to group multi-day training
/// sessions. Wall-clock end time is absent while the session remains open.
final class TrainingSession {
  factory TrainingSession({
    required String id,
    required String cycleId,
    required TrainingSessionStatus status,
    required DateTime startedAt,
    DateTime? endedAt,
    required DateTime studyDay,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (cycleId.isEmpty) {
      throw ArgumentError.value(cycleId, 'cycleId', 'Must not be empty.');
    }
    if (endedAt != null && endedAt.isBefore(startedAt)) {
      throw ArgumentError.value(
        endedAt,
        'endedAt',
        'Must not precede startedAt.',
      );
    }
    final isEnded =
        status == TrainingSessionStatus.closed ||
        status == TrainingSessionStatus.recovered;
    if (isEnded != (endedAt != null)) {
      throw ArgumentError(
        'Closed or recovered sessions require an end time; active or paused sessions must not have one.',
      );
    }

    return TrainingSession._(
      id: id,
      cycleId: cycleId,
      status: status,
      startedAt: startedAt,
      endedAt: endedAt,
      studyDay: studyDay,
    );
  }

  const TrainingSession._({
    required this.id,
    required this.cycleId,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.studyDay,
  });

  final String id;
  final String cycleId;
  final TrainingSessionStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime studyDay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingSession &&
          other.id == id &&
          other.cycleId == cycleId &&
          other.status == status &&
          other.startedAt == startedAt &&
          other.endedAt == endedAt &&
          other.studyDay == studyDay;

  @override
  int get hashCode =>
      Object.hash(id, cycleId, status, startedAt, endedAt, studyDay);
}
