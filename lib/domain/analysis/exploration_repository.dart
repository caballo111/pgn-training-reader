import 'exploration_session.dart';

/// Stores personal analysis drafts independently of authored chess content.
abstract interface class ExplorationRepository {
  /// Loads the draft for this exact authored occurrence, if one exists.
  Future<ExplorationSession?> load(ExplorationOrigin origin);

  /// Durably saves a draft under its authored occurrence.
  Future<void> save(ExplorationSession session);
}
