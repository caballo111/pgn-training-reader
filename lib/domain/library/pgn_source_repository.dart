import '../chess_content/pgn_source.dart';

/// Persists metadata for user-owned PGN sources.
///
/// Implementations must preserve a source record when its reference becomes
/// unavailable or changes. Callers can then offer repair without discarding
/// the source's indexed blocks or associated training history.
abstract interface class PgnSourceRepository {
  /// Returns the source with [id], or `null` when it is not registered.
  Future<PgnSource?> getById(String id);

  /// Returns registered sources in a stable order.
  ///
  /// Implementations use a deterministic order (for example, display name and
  /// then ID); callers must not rely on database insertion order.
  Future<List<PgnSource>> list();

  /// Registers a new source.
  ///
  /// Fails if a source with the same ID already exists. The source's opaque
  /// storage reference must not be interpreted by this domain contract.
  Future<void> create(PgnSource source);

  /// Replaces mutable metadata for an existing source while preserving its
  /// identity and creation time.
  ///
  /// This supports import-state/checkpoint updates and source relinking or
  /// revision changes. Implementations must not silently remove dependent
  /// index or training records when metadata changes.
  Future<void> update(PgnSource source);
}
