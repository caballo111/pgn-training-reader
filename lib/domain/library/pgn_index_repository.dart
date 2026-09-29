import '../chess_content/content_type.dart';
import '../chess_content/pgn_block_index.dart';

/// Optional metadata constraints for searching indexed PGN blocks.
///
/// Text constraints are case-insensitive substring matches. [player] matches
/// either the White or Black header. When more than one constraint is set,
/// they are combined with AND semantics. A null or empty text constraint is
/// ignored.
final class PgnIndexFilter {
  const PgnIndexFilter({
    this.sourceId,
    this.query,
    this.player,
    this.event,
    this.result,
    this.contentType,
    this.section,
    this.theme,
    this.difficulty,
  });

  /// Restricts results to one registered source.
  final String? sourceId;

  /// Searches available player, event, and date metadata.
  final String? query;

  /// Matches either player header.
  final String? player;

  final String? event;
  final String? result;
  final ContentType? contentType;
  final String? section;
  final String? theme;
  final String? difficulty;
}

/// A bounded page of indexed metadata.
final class PgnIndexPage {
  PgnIndexPage({required List<PgnBlockIndex> items, required this.nextOffset})
    : items = List.unmodifiable(items) {
    if ((nextOffset ?? 0) < 0) {
      throw ArgumentError.value(
        nextOffset,
        'nextOffset',
        'Must not be negative.',
      );
    }
  }

  /// The requested page's entries in stable order.
  final List<PgnBlockIndex> items;

  /// Offset to request the next page, or `null` when this is the final page.
  final int? nextOffset;
}

/// Reads the searchable metadata index without loading full PGN move trees.
abstract interface class PgnIndexRepository {
  /// Returns one indexed block, or `null` when no block has [id].
  Future<PgnBlockIndex?> getById(String id);

  /// Returns a bounded page matching [filter].
  ///
  /// Results use a stable source-order key: source ID, then block ordinal.
  /// [limit] must be positive and implementations may impose a documented
  /// upper bound. [offset] is zero-based and must not be negative. A page's
  /// [PgnIndexPage.nextOffset] is null when there are no more results.
  Future<PgnIndexPage> search({
    PgnIndexFilter filter = const PgnIndexFilter(),
    int offset = 0,
    required int limit,
  });

  /// Returns the number of indexed blocks belonging to [sourceId].
  Future<int> countForSource(String sourceId);
}
