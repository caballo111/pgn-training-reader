import 'progress_aggregate.dart';
import 'puzzle_attempt.dart';
import 'training_session.dart';

/// Raw progress inputs for one daily training session.
final class SessionProgressAggregate {
  const SessionProgressAggregate({
    required this.session,
    required this.progress,
  });

  final TrainingSession session;
  final ProgressAggregate progress;
}

/// Raw attempt history and metrics for one exercise in a cycle.
final class ExerciseProgressHistory {
  ExerciseProgressHistory({
    required this.exerciseId,
    required this.theme,
    required this.difficulty,
    required Iterable<PuzzleAttempt> attempts,
    required this.progress,
  }) : attempts = List.unmodifiable(attempts);

  final String exerciseId;
  final String? theme;
  final String? difficulty;
  final List<PuzzleAttempt> attempts;
  final ProgressAggregate progress;
}

/// Raw progress inputs for attempts grouped by available metadata.
final class MetadataProgressAggregate {
  const MetadataProgressAggregate({
    required this.value,
    required this.progress,
  });

  final String value;
  final ProgressAggregate progress;
}
