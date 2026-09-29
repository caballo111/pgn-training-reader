import 'content_type.dart';
import 'move_node.dart';

/// Faithful domain representation of one parsed PGN block.
///
/// This model contains chess content only; source locators and training state
/// are owned by other domain models. Header entries and root moves retain their
/// authored order. Multiple [rootMoves] allow the tree to preserve alternative
/// first moves, which cannot be represented as children of an actual move.
final class ChessContent {
  factory ChessContent({
    required Map<String, String> headers,
    required String startingFen,
    List<MoveNode> rootMoves = const [],
    List<String> comments = const [],
    String? result,
    required ContentType contentType,
  }) {
    if (startingFen.isEmpty) {
      throw ArgumentError.value(
        startingFen,
        'startingFen',
        'Must not be empty.',
      );
    }

    for (final name in headers.keys) {
      if (name.isEmpty) {
        throw ArgumentError.value(name, 'headers', 'Names must not be empty.');
      }
    }

    return ChessContent._(
      headers: Map.unmodifiable(headers),
      startingFen: startingFen,
      rootMoves: List.unmodifiable(rootMoves),
      comments: List.unmodifiable(comments),
      result: result,
      contentType: contentType,
    );
  }

  const ChessContent._({
    required this.headers,
    required this.startingFen,
    required this.rootMoves,
    required this.comments,
    required this.result,
    required this.contentType,
  });

  /// PGN tag names and values, including custom tags, in source order.
  ///
  /// Values are preserved as authored. Validation and interpretation of
  /// standard tags belong to the parser or consuming feature.
  final Map<String, String> headers;

  /// FEN for the position before the first authored move.
  ///
  /// Standard games use the standard initial position's FEN. FEN validity and
  /// side-to-move interpretation are handled by the chess adapter.
  final String startingFen;

  /// Ordered first moves from the starting position.
  ///
  /// The list represents the children of an implicit tree root. It is empty
  /// for a block with no moves, and can contain multiple entries when authored
  /// variations branch before the first move.
  final List<MoveNode> rootMoves;

  /// Comments attached to the block rather than to a particular move.
  final List<String> comments;

  /// The PGN termination marker, or `null` when the block has no result.
  ///
  /// The value is preserved verbatim so unknown or malformed markers remain
  /// available for diagnostics and display.
  final String? result;

  /// Classification of this block as a puzzle, instruction, demonstration, or
  /// unsupported content.
  final ContentType contentType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChessContent &&
          _orderedMapEquals(other.headers, headers) &&
          other.startingFen == startingFen &&
          _listEquals(other.rootMoves, rootMoves) &&
          _listEquals(other.comments, comments) &&
          other.result == result &&
          other.contentType == contentType;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(headers.entries.expand((entry) => [entry.key, entry.value])),
    startingFen,
    Object.hashAll(rootMoves),
    Object.hashAll(comments),
    result,
    contentType,
  );
}

bool _orderedMapEquals<K, V>(Map<K, V> first, Map<K, V> second) {
  if (first.length != second.length) return false;

  final firstEntries = first.entries.iterator;
  final secondEntries = second.entries.iterator;
  while (firstEntries.moveNext() && secondEntries.moveNext()) {
    if (firstEntries.current.key != secondEntries.current.key ||
        firstEntries.current.value != secondEntries.current.value) {
      return false;
    }
  }
  return true;
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
