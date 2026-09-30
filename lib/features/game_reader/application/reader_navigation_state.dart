import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/move_node.dart';

/// Immutable cursor into the authored move tree of a [ChessContent].
///
/// The path is represented by child indexes from the implicit root. Index zero
/// follows the main line, while larger indexes select authored variations.
final class ReaderNavigationState {
  ReaderNavigationState._(this._rootMoves, this._path, this._startingFen);

  factory ReaderNavigationState.initial(ChessContent content) =>
      ReaderNavigationState._(content.rootMoves, const [], content.startingFen);

  final List<MoveNode> _rootMoves;
  final List<int> _path;
  final String _startingFen;

  /// Nodes from the starting position through the current move.
  List<MoveNode> get path {
    final nodes = <MoveNode>[];
    var moves = _rootMoves;
    for (final index in _path) {
      final node = moves[index];
      nodes.add(node);
      moves = node.children;
    }
    return List.unmodifiable(nodes);
  }

  /// The current move, or `null` at the starting position.
  MoveNode? get currentNode => _path.isEmpty ? null : path.last;

  /// Position before the current move, or the game's starting position.
  String get currentFen => currentNode?.fenAfter ?? _startingFen;

  /// Whether a move exists before the current position.
  bool get canPrevious => _path.isNotEmpty;

  /// Whether a main continuation exists from the current position.
  bool get canNext => _children.isNotEmpty;

  /// Whether any move exists in the content.
  bool get canFirst => _rootMoves.isNotEmpty;

  /// Move choices available from the current position, in authored order.
  List<MoveNode> get availableMoves => List.unmodifiable(_children);

  List<MoveNode> get _children {
    if (_path.isEmpty) return _rootMoves;
    return path.last.children;
  }

  /// Return to the starting position.
  ReaderNavigationState first() =>
      ReaderNavigationState._(_rootMoves, const [], _startingFen);

  /// Step back one move. At the starting position this is a no-op.
  ReaderNavigationState previous() {
    if (_path.isEmpty) return this;
    return ReaderNavigationState._(
      _rootMoves,
      List.unmodifiable(_path.sublist(0, _path.length - 1)),
      _startingFen,
    );
  }

  /// Step forward along the first authored continuation. At a terminal node
  /// this is a no-op.
  ReaderNavigationState next() {
    if (_children.isEmpty) return this;
    return _withChild(0);
  }

  /// Move to the end of the first authored line from the current position.
  ReaderNavigationState last() {
    var state = this;
    while (state.canNext) {
      state = state.next();
    }
    return state;
  }

  /// Select one authored continuation from the current position.
  ///
  /// The zero-based [childIndex] addresses [availableMoves], so zero selects
  /// the principal continuation and subsequent values select variations.
  /// Returns this state when the index is out of range.
  ReaderNavigationState selectVariation(int childIndex) {
    if (childIndex < 0 || childIndex >= _children.length) return this;
    return _withChild(childIndex);
  }

  /// Return from a variation to its nearest parent line.
  ///
  /// If the cursor is on a variation branch, this selects that branch's
  /// principal sibling. If it is already on the main line, the state is
  /// unchanged.
  ReaderNavigationState returnToParentLine() {
    for (var depth = _path.length - 1; depth >= 0; depth--) {
      if (_path[depth] == 0) continue;
      final parentPath = List<int>.of(_path)..[depth] = 0;
      return ReaderNavigationState._(
        _rootMoves,
        List.unmodifiable(parentPath.take(depth + 1)),
        _startingFen,
      );
    }
    return this;
  }

  ReaderNavigationState _withChild(int childIndex) => ReaderNavigationState._(
    _rootMoves,
    List.unmodifiable([..._path, childIndex]),
    _startingFen,
  );
}
