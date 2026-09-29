/// A timestamped move submitted by the user during a puzzle attempt.
final class AttemptMove {
  factory AttemptMove({
    required String id,
    required String attemptId,
    required int ordinal,
    required String move,
    required bool legal,
    required bool accepted,
    required DateTime submittedAt,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (attemptId.isEmpty) {
      throw ArgumentError.value(attemptId, 'attemptId', 'Must not be empty.');
    }
    if (ordinal < 0) {
      throw ArgumentError.value(ordinal, 'ordinal', 'Must not be negative.');
    }
    if (move.isEmpty) {
      throw ArgumentError.value(move, 'move', 'Must not be empty.');
    }
    if (accepted && !legal) {
      throw ArgumentError('An illegal move cannot be accepted.');
    }

    return AttemptMove._(
      id: id,
      attemptId: attemptId,
      ordinal: ordinal,
      move: move,
      legal: legal,
      accepted: accepted,
      submittedAt: submittedAt,
    );
  }

  const AttemptMove._({
    required this.id,
    required this.attemptId,
    required this.ordinal,
    required this.move,
    required this.legal,
    required this.accepted,
    required this.submittedAt,
  });

  final String id;
  final String attemptId;
  final int ordinal;

  /// The submitted move in the application's canonical move notation.
  final String move;
  final bool legal;
  final bool accepted;
  final DateTime submittedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttemptMove &&
          other.id == id &&
          other.attemptId == attemptId &&
          other.ordinal == ordinal &&
          other.move == move &&
          other.legal == legal &&
          other.accepted == accepted &&
          other.submittedAt == submittedAt;

  @override
  int get hashCode =>
      Object.hash(id, attemptId, ordinal, move, legal, accepted, submittedAt);
}
