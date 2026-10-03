import '../../core/errors/app_failure.dart';
import '../../domain/chess_content/pgn_source.dart';
import '../../domain/library/library_lifecycle_service.dart';
import '../../domain/library/pgn_source_repository.dart';
import '../database/app_database.dart' hide PgnSource;
import '../file_access/managed_file_source.dart';

/// Coordinates a durable library tombstone with best-effort managed-copy
/// cleanup. Cleanup status is persisted so the operation can be retried.
final class DriftLibraryLifecycleService implements LibraryLifecycleService {
  factory DriftLibraryLifecycleService({
    required AppDatabase database,
    required PgnSourceRepository sourceRepository,
    required ManagedFileSource managedFileSource,
    DateTime Function()? now,
  }) => DriftLibraryLifecycleService._(
    database: database,
    sourceRepository: sourceRepository,
    managedFileSource: managedFileSource,
    now: now,
  );

  DriftLibraryLifecycleService._({
    required this._database,
    required this._sourceRepository,
    required this._managedFileSource,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _database;
  final PgnSourceRepository _sourceRepository;
  final ManagedFileSource _managedFileSource;
  final DateTime Function() _now;

  @override
  Future<LibraryRemovalResult> removeBook(String sourceId) async {
    final source = await _sourceRepository.getById(sourceId);
    if (source == null) {
      throw const DatabaseFailure(
        code: 'source_not_found',
        message: 'This book is no longer available in the library.',
      );
    }
    if (source.importState != 'deleted') {
      await _sourceRepository.remove(id: sourceId, removedAt: _now().toUtc());
    }

    final deleted = await _sourceRepository.getById(sourceId);
    if (deleted == null || deleted.importState != 'deleted') {
      throw const DatabaseFailure(
        code: 'source_remove_failed',
        message: 'The book could not be removed from the library. Retry.',
      );
    }
    return _cleanupDeletedSource(deleted);
  }

  @override
  Future<List<String>> pendingCleanupSourceIds() async {
    final rows = await _database
        .customSelect(
          "SELECT key FROM app_settings WHERE key LIKE 'managed-pgn-cleanup:%' "
          "AND value IN ('pending', 'failed') ORDER BY key",
        )
        .get();
    return List.unmodifiable(
      rows.map(
        (row) =>
            row.read<String>('key').substring('managed-pgn-cleanup:'.length),
      ),
    );
  }

  @override
  Future<LibraryRemovalResult> retryCleanup(String sourceId) async {
    final source = await _sourceRepository.getById(sourceId);
    if (source == null || source.importState != 'deleted') {
      throw const DatabaseFailure(
        code: 'source_not_deleted',
        message: 'Only a removed book can have its saved copy cleanup retried.',
      );
    }
    return _cleanupDeletedSource(source);
  }

  Future<LibraryRemovalResult> _cleanupDeletedSource(PgnSource deleted) async {
    try {
      if (deleted.accessMode == PgnSourceAccessMode.managedCopy) {
        final token = deleted.managedPath;
        if (token == null) {
          throw const FileFailure(
            code: 'managed_reference_invalid',
            message: 'The saved local copy reference is invalid.',
          );
        }
        await _managedFileSource.deleteManagedCopy(token);
      }
      await _setCleanupState(deleted.id, 'complete');
      return const LibraryRemovalResult(
        status: LibraryRemovalStatus.removed,
        message: 'The book was removed from the library.',
      );
    } catch (_) {
      await _setCleanupState(deleted.id, 'failed');
      return const LibraryRemovalResult(
        status: LibraryRemovalStatus.cleanupFailed,
        message: 'The book was removed, but its saved copy could not be deleted. Retry cleanup from Manage library.',
      );
    }
  }

  Future<void> _setCleanupState(String sourceId, String state) async {
    await _database.customStatement(
      'INSERT INTO app_settings (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      ['managed-pgn-cleanup:$sourceId', state],
    );
  }
}
