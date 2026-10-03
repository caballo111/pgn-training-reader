/// Outcome of removing a book from the active library.
enum LibraryRemovalStatus { removed, cleanupFailed }

/// Safe result suitable for presenting in the management surface.
final class LibraryRemovalResult {
  const LibraryRemovalResult({required this.status, required this.message});

  final LibraryRemovalStatus status;
  final String message;
}

/// Coordinates terminal source removal and cleanup of app-managed copies.
abstract interface class LibraryLifecycleService {
  /// Removes [sourceId] from active use. A repeated call retries failed
  /// cleanup while preserving the deleted source identity.
  Future<LibraryRemovalResult> removeBook(String sourceId);

  /// Source IDs whose app-managed copy still needs cleanup.
  Future<List<String>> pendingCleanupSourceIds();

  /// Retries cleanup for a source already removed from the active library.
  Future<LibraryRemovalResult> retryCleanup(String sourceId);
}
