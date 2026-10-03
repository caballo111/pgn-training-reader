import '../database/app_database.dart';

/// In-process exclusion between import/re-index and removal for one database.
/// Durable job checks remain authoritative across process boundaries.
final class PgnSourceOperationRegistry {
  PgnSourceOperationRegistry._();

  static final Expando<_Operations> _byDatabase = Expando<_Operations>();

  static _Operations _state(AppDatabase database) =>
      _byDatabase[database] ??= _Operations();

  static bool tryBeginImport(AppDatabase database, String sourceId) {
    final state = _state(database);
    if (state.removing.contains(sourceId) || !state.importing.add(sourceId)) {
      return false;
    }
    return true;
  }

  static void endImport(AppDatabase database, String sourceId) {
    _state(database).importing.remove(sourceId);
  }

  static bool tryBeginRemoval(AppDatabase database, String sourceId) {
    final state = _state(database);
    if (state.importing.contains(sourceId) || !state.removing.add(sourceId)) {
      return false;
    }
    return true;
  }

  static void endRemoval(AppDatabase database, String sourceId) {
    _state(database).removing.remove(sourceId);
  }
}

final class _Operations {
  final Set<String> importing = <String>{};
  final Set<String> removing = <String>{};
}
