/// Presentation and interaction state for solving one puzzle.
///
/// A finalized result enters review so the authored solution can be shown.
/// The review variants preserve whether the attempt passed, failed, or was
/// explicitly revealed; the other terminal variants retain their own outcome.
enum PuzzleState {
  notStarted,
  active,
  failedReview,
  passedReview,
  revealedReview,
  skipped,
  timedOut,
  abandoned;

  /// Stable serialized representation of this state.
  ///
  /// Keep these values independent of Dart's [Enum.name] so renaming a member
  /// does not change persisted or exchanged state.
  String toDatabaseValue() => switch (this) {
    PuzzleState.notStarted => 'not-started',
    PuzzleState.active => 'active',
    PuzzleState.failedReview => 'failed-review',
    PuzzleState.passedReview => 'passed-review',
    PuzzleState.revealedReview => 'revealed-review',
    PuzzleState.skipped => 'skipped',
    PuzzleState.timedOut => 'timed-out',
    PuzzleState.abandoned => 'abandoned',
  };

  /// Parses a stable serialized state value.
  static PuzzleState fromDatabaseValue(String value) => switch (value) {
    'not-started' => PuzzleState.notStarted,
    'active' => PuzzleState.active,
    'failed-review' => PuzzleState.failedReview,
    'passed-review' => PuzzleState.passedReview,
    'revealed-review' => PuzzleState.revealedReview,
    'skipped' => PuzzleState.skipped,
    'timed-out' => PuzzleState.timedOut,
    'abandoned' => PuzzleState.abandoned,
    _ => throw FormatException('Unknown puzzle state.', value),
  };
}
