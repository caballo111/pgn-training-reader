/// One contiguous active-solving interval for a puzzle attempt.
///
/// Open segments have neither [endedAt] nor [activeDuration]. Closed segments
/// record both, allowing paused and suspended time to remain excluded.
final class TimingSegment {
  factory TimingSegment({
    required String id,
    required String attemptId,
    String? sessionId,
    required DateTime startedAt,
    DateTime? endedAt,
    Duration? activeDuration,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (attemptId.isEmpty) {
      throw ArgumentError.value(attemptId, 'attemptId', 'Must not be empty.');
    }
    if (sessionId != null && sessionId.isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId', 'Must not be empty.');
    }
    if ((endedAt == null) != (activeDuration == null)) {
      throw ArgumentError(
        'End time and active duration must either both be present or both be absent.',
      );
    }
    if (endedAt != null && endedAt.isBefore(startedAt)) {
      throw ArgumentError.value(
        endedAt,
        'endedAt',
        'Must not be before startedAt.',
      );
    }
    if (activeDuration != null && activeDuration.isNegative) {
      throw ArgumentError.value(
        activeDuration,
        'activeDuration',
        'Must not be negative.',
      );
    }

    return TimingSegment._(
      id: id,
      attemptId: attemptId,
      sessionId: sessionId,
      startedAt: startedAt,
      endedAt: endedAt,
      activeDuration: activeDuration,
    );
  }

  const TimingSegment._({
    required this.id,
    required this.attemptId,
    required this.sessionId,
    required this.startedAt,
    required this.endedAt,
    required this.activeDuration,
  });

  final String id;
  final String attemptId;

  /// Session active during this interval, if known for a legacy record.
  final String? sessionId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration? activeDuration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimingSegment &&
          other.id == id &&
          other.attemptId == attemptId &&
          other.sessionId == sessionId &&
          other.startedAt == startedAt &&
          other.endedAt == endedAt &&
          other.activeDuration == activeDuration;

  @override
  int get hashCode =>
      Object.hash(id, attemptId, sessionId, startedAt, endedAt, activeDuration);
}
