/// Lifecycle state for one interaction with a puzzle.
///
/// Database values are explicit so this contract stays stable if Dart names
/// change. Active and paused attempts have no terminal result; finalized
/// attempts have both an outcome and completion time.
enum PuzzleAttemptStatus {
  active,
  paused,
  finalized;

  String toDatabaseValue() => switch (this) {
    PuzzleAttemptStatus.active => 'active',
    PuzzleAttemptStatus.paused => 'paused',
    PuzzleAttemptStatus.finalized => 'finalized',
  };

  static PuzzleAttemptStatus fromDatabaseValue(String value) => switch (value) {
    'active' => PuzzleAttemptStatus.active,
    'paused' => PuzzleAttemptStatus.paused,
    'finalized' => PuzzleAttemptStatus.finalized,
    _ => throw FormatException('Unknown puzzle attempt status.', value),
  };
}

/// Terminal result of one interaction with a puzzle.
///
/// Stored values are explicit so renaming Dart identifiers does not alter the
/// database contract.
enum PuzzleAttemptOutcome {
  passed,
  wrongMove,
  revealed,
  skipped,
  timedOut,
  abandoned;

  String toDatabaseValue() => switch (this) {
    PuzzleAttemptOutcome.passed => 'Passed',
    PuzzleAttemptOutcome.wrongMove => 'WrongMove',
    PuzzleAttemptOutcome.revealed => 'Revealed',
    PuzzleAttemptOutcome.skipped => 'Skipped',
    PuzzleAttemptOutcome.timedOut => 'TimedOut',
    PuzzleAttemptOutcome.abandoned => 'Abandoned',
  };

  static PuzzleAttemptOutcome fromDatabaseValue(String value) =>
      switch (value) {
        'Passed' => PuzzleAttemptOutcome.passed,
        'WrongMove' => PuzzleAttemptOutcome.wrongMove,
        'Revealed' => PuzzleAttemptOutcome.revealed,
        'Skipped' => PuzzleAttemptOutcome.skipped,
        'TimedOut' => PuzzleAttemptOutcome.timedOut,
        'Abandoned' => PuzzleAttemptOutcome.abandoned,
        _ => throw FormatException('Unknown puzzle attempt outcome.', value),
      };
}

/// Why a puzzle attempt did not pass.
enum PuzzleAttemptFailureReason {
  incorrectMove,
  illegalMove,
  timeLimitExceeded,
  userAbandoned;

  String toDatabaseValue() => switch (this) {
    PuzzleAttemptFailureReason.incorrectMove => 'IncorrectMove',
    PuzzleAttemptFailureReason.illegalMove => 'IllegalMove',
    PuzzleAttemptFailureReason.timeLimitExceeded => 'TimeLimitExceeded',
    PuzzleAttemptFailureReason.userAbandoned => 'UserAbandoned',
  };

  static PuzzleAttemptFailureReason fromDatabaseValue(String value) =>
      switch (value) {
        'IncorrectMove' => PuzzleAttemptFailureReason.incorrectMove,
        'IllegalMove' => PuzzleAttemptFailureReason.illegalMove,
        'TimeLimitExceeded' => PuzzleAttemptFailureReason.timeLimitExceeded,
        'UserAbandoned' => PuzzleAttemptFailureReason.userAbandoned,
        _ => throw FormatException(
          'Unknown puzzle attempt failure reason.',
          value,
        ),
      };
}

/// A user's interaction with one puzzle in one cycle.
///
/// An attempt is unfinished while [outcome] and [completedAt] are null. Once
/// finalized, both values are present and the record is retained as history.
final class PuzzleAttempt {
  factory PuzzleAttempt({
    required String id,
    required String blockId,
    required String cycleId,
    required String sessionId,
    PuzzleAttemptStatus status = PuzzleAttemptStatus.active,
    required DateTime startedAt,
    DateTime? completedAt,
    Duration activeDuration = Duration.zero,
    PuzzleAttemptOutcome? outcome,
    PuzzleAttemptFailureReason? failureReason,
    int wrongMoveCount = 0,
    int hintCount = 0,
    bool revealed = false,
  }) {
    for (final entry in <String, String>{
      'id': id,
      'blockId': blockId,
      'cycleId': cycleId,
      'sessionId': sessionId,
    }.entries) {
      if (entry.value.isEmpty) {
        throw ArgumentError.value(entry.value, entry.key, 'Must not be empty.');
      }
    }
    if (activeDuration.isNegative) {
      throw ArgumentError.value(
        activeDuration,
        'activeDuration',
        'Must not be negative.',
      );
    }
    if (wrongMoveCount < 0) {
      throw ArgumentError.value(
        wrongMoveCount,
        'wrongMoveCount',
        'Must not be negative.',
      );
    }
    if (hintCount < 0) {
      throw ArgumentError.value(
        hintCount,
        'hintCount',
        'Must not be negative.',
      );
    }
    if ((outcome == null) != (completedAt == null)) {
      throw ArgumentError(
        'Outcome and completion time must either both be present or both be absent.',
      );
    }
    if ((status == PuzzleAttemptStatus.finalized) != (outcome != null)) {
      throw ArgumentError(
        'Only finalized attempts may have an outcome and completion time.',
      );
    }
    if (failureReason != null &&
        outcome != PuzzleAttemptOutcome.wrongMove &&
        outcome != PuzzleAttemptOutcome.timedOut &&
        outcome != PuzzleAttemptOutcome.abandoned) {
      throw ArgumentError(
        'Failure reason is only valid for wrong, timed out, or abandoned attempts.',
      );
    }
    if ((outcome == PuzzleAttemptOutcome.wrongMove ||
            outcome == PuzzleAttemptOutcome.timedOut ||
            outcome == PuzzleAttemptOutcome.abandoned) !=
        (failureReason != null)) {
      throw ArgumentError(
        'Wrong, timed out, and abandoned attempts require a failure reason.',
      );
    }
    if (outcome == PuzzleAttemptOutcome.wrongMove &&
        failureReason != PuzzleAttemptFailureReason.incorrectMove &&
        failureReason != PuzzleAttemptFailureReason.illegalMove) {
      throw ArgumentError(
        'Wrong-move outcomes require an incorrect-move or illegal-move reason.',
      );
    }
    if (outcome == PuzzleAttemptOutcome.timedOut &&
        failureReason != PuzzleAttemptFailureReason.timeLimitExceeded) {
      throw ArgumentError('Timed-out outcomes require a time-limit reason.');
    }
    if (outcome == PuzzleAttemptOutcome.abandoned &&
        failureReason != PuzzleAttemptFailureReason.userAbandoned) {
      throw ArgumentError(
        'Abandoned outcomes require a user-abandoned reason.',
      );
    }
    if (outcome == PuzzleAttemptOutcome.revealed && !revealed) {
      throw ArgumentError('A revealed outcome must record revealed=true.');
    }
    if (revealed && outcome == null) {
      throw ArgumentError(
        'An unfinished attempt cannot have revealed its solution.',
      );
    }
    if (completedAt != null && completedAt.isBefore(startedAt)) {
      throw ArgumentError.value(
        completedAt,
        'completedAt',
        'Must not be before startedAt.',
      );
    }

    return PuzzleAttempt._(
      id: id,
      blockId: blockId,
      cycleId: cycleId,
      sessionId: sessionId,
      status: status,
      startedAt: startedAt,
      completedAt: completedAt,
      activeDuration: activeDuration,
      outcome: outcome,
      failureReason: failureReason,
      wrongMoveCount: wrongMoveCount,
      hintCount: hintCount,
      revealed: revealed,
    );
  }

  const PuzzleAttempt._({
    required this.id,
    required this.blockId,
    required this.cycleId,
    required this.sessionId,
    required this.status,
    required this.startedAt,
    required this.completedAt,
    required this.activeDuration,
    required this.outcome,
    required this.failureReason,
    required this.wrongMoveCount,
    required this.hintCount,
    required this.revealed,
  });

  final String id;
  final String blockId;
  final String cycleId;
  final String sessionId;
  final PuzzleAttemptStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final Duration activeDuration;
  final PuzzleAttemptOutcome? outcome;
  final PuzzleAttemptFailureReason? failureReason;
  final int wrongMoveCount;
  final int hintCount;
  final bool revealed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PuzzleAttempt &&
          other.id == id &&
          other.blockId == blockId &&
          other.cycleId == cycleId &&
          other.sessionId == sessionId &&
          other.status == status &&
          other.startedAt == startedAt &&
          other.completedAt == completedAt &&
          other.activeDuration == activeDuration &&
          other.outcome == outcome &&
          other.failureReason == failureReason &&
          other.wrongMoveCount == wrongMoveCount &&
          other.hintCount == hintCount &&
          other.revealed == revealed;

  @override
  int get hashCode => Object.hash(
    id,
    blockId,
    cycleId,
    sessionId,
    status,
    startedAt,
    completedAt,
    activeDuration,
    outcome,
    failureReason,
    wrongMoveCount,
    hintCount,
    revealed,
  );
}
