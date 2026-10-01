/// One move and its authored annotations in an ordered chess move tree.
///
/// A node represents a position transition. [fenBefore] and [fenAfter] retain
/// the positions on either side of the move, while [san] and [uci] retain its
/// authored/display and machine-readable notation. This model preserves those
/// strings; chess notation and position validation belong in the chess adapter.
///
/// [children] are possible continuations in authored order. Parsers should
/// retain the principal continuation and variations in their source order.
final class MoveNode {
  factory MoveNode({
    required String san,
    required String uci,
    required String fenBefore,
    required String fenAfter,
    List<String> startingComments = const [],
    List<String> comments = const [],
    List<int> nags = const [],
    List<MoveNode> children = const [],
  }) {
    _requireNonEmpty(san, 'san');
    _requireNonEmpty(uci, 'uci');
    _requireNonEmpty(fenBefore, 'fenBefore');
    _requireNonEmpty(fenAfter, 'fenAfter');

    for (var index = 0; index < nags.length; index++) {
      final nag = nags[index];
      if (nag < 0 || nag > 255) {
        throw ArgumentError.value(
          nag,
          'nags[$index]',
          'Must be between 0 and 255.',
        );
      }
    }

    return MoveNode._(
      san: san,
      uci: uci,
      fenBefore: fenBefore,
      fenAfter: fenAfter,
      startingComments: List.unmodifiable(startingComments),
      comments: List.unmodifiable(comments),
      nags: List.unmodifiable(nags),
      children: List.unmodifiable(children),
    );
  }

  const MoveNode._({
    required this.san,
    required this.uci,
    required this.fenBefore,
    required this.fenAfter,
    required this.startingComments,
    required this.comments,
    required this.nags,
    required this.children,
  });

  /// Standard Algebraic Notation for this move, preserved as authored.
  final String san;

  /// Universal Chess Interface notation for this move, preserved as authored.
  final String uci;

  /// FEN position immediately before this move.
  final String fenBefore;

  /// FEN position immediately after this move.
  final String fenAfter;

  /// Comments authored before this move, typically introducing a variation.
  final List<String> startingComments;

  /// Comments authored after this move, preserved in their source order.
  ///
  /// Empty comments are retained because an empty PGN comment is valid input.
  final List<String> comments;

  /// Numeric annotation glyphs attached to this move, in source order.
  ///
  /// Values are kept as PGN's one-byte NAG values, including reserved values,
  /// so an importer can faithfully preserve annotations it does not interpret.
  final List<int> nags;

  /// Possible next moves, in authored order.
  final List<MoveNode> children;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoveNode &&
          other.san == san &&
          other.uci == uci &&
          other.fenBefore == fenBefore &&
          other.fenAfter == fenAfter &&
          _listEquals(other.startingComments, startingComments) &&
          _listEquals(other.comments, comments) &&
          _listEquals(other.nags, nags) &&
          _listEquals(other.children, children);

  @override
  int get hashCode => Object.hash(
    san,
    uci,
    fenBefore,
    fenAfter,
    Object.hashAll(startingComments),
    Object.hashAll(comments),
    Object.hashAll(nags),
    Object.hashAll(children),
  );
}

void _requireNonEmpty(String value, String name) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
