/// Lifecycle states for a pass through a training set.
///
/// The database representation is an explicit contract and must not depend on
/// Dart's [Enum.name].
enum CycleStatus {
  pending,
  active,
  completed,
  stopped;

  String toDatabaseValue() => switch (this) {
    CycleStatus.pending => 'pending',
    CycleStatus.active => 'active',
    CycleStatus.completed => 'completed',
    CycleStatus.stopped => 'stopped',
  };

  static CycleStatus fromDatabaseValue(String value) => switch (value) {
    'pending' => CycleStatus.pending,
    'active' => CycleStatus.active,
    'completed' => CycleStatus.completed,
    'stopped' => CycleStatus.stopped,
    _ => throw FormatException('Unknown cycle status.', value),
  };
}

/// Lifecycle states for a bounded study period within a cycle.
enum TrainingSessionStatus {
  active,
  paused,
  closed,
  recovered;

  String toDatabaseValue() => switch (this) {
    TrainingSessionStatus.active => 'active',
    TrainingSessionStatus.paused => 'paused',
    TrainingSessionStatus.closed => 'closed',
    TrainingSessionStatus.recovered => 'recovered',
  };

  static TrainingSessionStatus fromDatabaseValue(String value) =>
      switch (value) {
        'active' => TrainingSessionStatus.active,
        'paused' => TrainingSessionStatus.paused,
        'closed' => TrainingSessionStatus.closed,
        'recovered' => TrainingSessionStatus.recovered,
        _ => throw FormatException('Unknown training session status.', value),
      };
}
