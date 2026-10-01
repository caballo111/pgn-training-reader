import 'training_set.dart';

/// Separate practice/review persistence; never rewrites a scored result.
abstract interface class PuzzleInteractionRepository {
  Future<Map<String, dynamic>?> loadPuzzleInteraction(String attemptId);
  Future<void> savePuzzleInteraction(
    String attemptId,
    Map<String, dynamic> value,
  );
}

/// A cycle owns a fixed ordered selection, independent of later set edits.
abstract interface class CycleSnapshotRepository {
  Future<TrainingSet?> getCycleSet(String cycleId);
  Future<String?> getCyclePolicy(String cycleId);
  Future<void> setCyclePolicy(String cycleId, String policy);
  Future<String?> getCycleCursor(String cycleId);
  Future<void> setCycleCursor(String cycleId, String? attemptId);
}
