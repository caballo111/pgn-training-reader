import 'dart:convert';

import 'package:dartchess/dartchess.dart' as chess;

/// The authored position from which a personal exploration draft was opened.
///
/// [scopeId] is expected to identify the source block and its revision.
/// [authoredPath] distinguishes repeated occurrences (including equal FENs)
/// within that source. [discriminator] can distinguish a recorded-try origin
/// from the ordinary authored occurrence. Labels are descriptive and are not
/// used as an identity component.
final class ExplorationOrigin {
  factory ExplorationOrigin({
    required String scopeId,
    required String startingFen,
    required List<int> authoredPath,
    required List<String> authoredMoves,
    required String label,
    String? discriminator,
  }) {
    if (scopeId.trim().isEmpty || scopeId.length > _maxOriginTextLength) {
      throw ArgumentError.value(
        scopeId,
        'scopeId',
        'Must be non-empty and bounded.',
      );
    }
    if (startingFen.trim().isEmpty || startingFen.length > _maxFenLength) {
      throw ArgumentError.value(
        startingFen,
        'startingFen',
        'Must be non-empty and bounded.',
      );
    }
    if (label.length > _maxOriginTextLength) {
      throw ArgumentError.value(label, 'label', 'Must be bounded.');
    }
    if (discriminator != null && discriminator.length > _maxOriginTextLength) {
      throw ArgumentError.value(
        discriminator,
        'discriminator',
        'Must be bounded.',
      );
    }
    if (authoredPath.length > _maxAuthoredPlies ||
        authoredMoves.length > _maxAuthoredPlies) {
      throw ArgumentError('The authored origin is too deep to explore.');
    }
    for (var index = 0; index < authoredPath.length; index++) {
      if (authoredPath[index] < 0) {
        throw ArgumentError.value(
          authoredPath[index],
          'authoredPath[$index]',
          'Path indexes must be non-negative.',
        );
      }
    }
    for (var index = 0; index < authoredMoves.length; index++) {
      final move = authoredMoves[index];
      if (move.length < 4 || move.length > 5) {
        throw ArgumentError.value(
          move,
          'authoredMoves[$index]',
          'Expected a UCI move.',
        );
      }
    }

    return ExplorationOrigin._(
      scopeId: scopeId,
      startingFen: startingFen,
      authoredPath: List.unmodifiable(authoredPath),
      authoredMoves: List.unmodifiable(authoredMoves),
      label: label,
      discriminator: discriminator,
    );
  }

  const ExplorationOrigin._({
    required this.scopeId,
    required this.startingFen,
    required this.authoredPath,
    required this.authoredMoves,
    required this.label,
    required this.discriminator,
  });

  final String scopeId;
  final String startingFen;
  final List<int> authoredPath;
  final List<String> authoredMoves;
  final String label;
  final String? discriminator;

  /// Stable draft key material. Equal FENs at different occurrences remain
  /// distinct because the authored path and source scope are included.
  String get identityKey => base64Url
      .encode(
        utf8.encode(
          jsonEncode([
            scopeId,
            startingFen,
            authoredPath,
            authoredMoves,
            discriminator,
          ]),
        ),
      )
      .replaceAll('=', '');

  Map<String, Object?> toJson() => <String, Object?>{
    'scopeId': scopeId,
    'startingFen': startingFen,
    'authoredPath': List<int>.of(authoredPath),
    'authoredMoves': List<String>.of(authoredMoves),
    'label': label,
    'discriminator': discriminator,
  };

  factory ExplorationOrigin.fromJson(Map<String, Object?> json) {
    try {
      return ExplorationOrigin(
        scopeId: _readString(json, 'scopeId'),
        startingFen: _readString(json, 'startingFen'),
        authoredPath: _readIntList(json, 'authoredPath'),
        authoredMoves: _readStringList(json, 'authoredMoves'),
        label: _readString(json, 'label'),
        discriminator: _readNullableString(json, 'discriminator'),
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid exploration origin: $error');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExplorationOrigin &&
          other.scopeId == scopeId &&
          other.startingFen == startingFen &&
          _listEquals(other.authoredPath, authoredPath) &&
          _listEquals(other.authoredMoves, authoredMoves) &&
          other.discriminator == discriminator;

  @override
  int get hashCode => Object.hash(
    scopeId,
    startingFen,
    Object.hashAll(authoredPath),
    Object.hashAll(authoredMoves),
    discriminator,
  );
}

/// One learner-authored move and its personal continuations.
///
/// Nodes contain no source PGN comments, annotations, or links to authored
/// moves. Their position is determined by replaying the origin and its path.
final class ExplorationMoveNode {
  const ExplorationMoveNode._({required this.uci, required this.children});

  final String uci;
  final List<ExplorationMoveNode> children;
}

/// An immutable, legal personal move tree rooted at an authored position.
///
/// Every navigation or move operation returns another session snapshot. The
/// authored history is replayed before the personal tree, preserving chess
/// repetition context at the origin.
final class ExplorationSession {
  factory ExplorationSession.initial({required ExplorationOrigin origin}) {
    final session = ExplorationSession._(
      origin: origin,
      root: const [],
      currentPath: const [],
    );
    // Validate the starting FEN and all authored UCI history eagerly.
    session.position;
    return session;
  }

  const ExplorationSession._({
    required this.origin,
    required this.root,
    required this.currentPath,
  });

  static const int codecVersion = 1;

  final ExplorationOrigin origin;

  /// Root moves of the personal variation tree, in learner-created order.
  final List<ExplorationMoveNode> root;

  /// Child indexes from the implicit root to the selected personal position.
  final List<int> currentPath;

  /// The current chess position after authored and selected personal moves.
  chess.Chess get position => _positionFor(currentPath);

  /// Full UCI history from [origin.startingFen] to [position].
  List<String> get moves => List.unmodifiable([
    ...origin.authoredMoves,
    ...activeLine.map((node) => node.uci),
  ]);

  /// Learner-created moves on the path to the selected personal position.
  List<ExplorationMoveNode> get activeLine {
    final line = <ExplorationMoveNode>[];
    var siblings = root;
    for (final index in currentPath) {
      final node = siblings[index];
      line.add(node);
      siblings = node.children;
    }
    return List.unmodifiable(line);
  }

  /// Personal continuations available at the selected position.
  List<ExplorationMoveNode> get branches =>
      currentPath.isEmpty ? root : activeLine.last.children;

  bool get canPrevious => currentPath.isNotEmpty;
  bool get canNext => branches.isNotEmpty;

  /// Adds [uci] as a personal branch, reusing an identical sibling if present.
  ///
  /// Invalid or illegal moves throw [ArgumentError] without changing this
  /// session or any source content.
  ExplorationSession playUci(String uci) {
    if (currentPath.length >= _maxPersonalPlies) {
      throw ArgumentError('The personal exploration line is too deep.');
    }
    final currentPosition = position;
    if (currentPosition.isGameOver) {
      throw ArgumentError.value(
        uci,
        'uci',
        'The current position is terminal.',
      );
    }
    final move = _parseUci(uci, argumentName: 'uci');
    if (!currentPosition.isLegal(move)) {
      throw ArgumentError.value(
        uci,
        'uci',
        'Move is illegal in this position.',
      );
    }

    final existing = branches.indexWhere((node) => node.uci == move.uci);
    if (existing < 0 && _countTreeNodes(root) >= _maxTreeNodes) {
      throw ArgumentError(
        'The personal exploration tree contains too many moves.',
      );
    }
    final nextIndex = existing >= 0 ? existing : branches.length;
    final nextRoot = existing >= 0
        ? root
        : _appendAtPath(
            root,
            currentPath,
            ExplorationMoveNode._(uci: move.uci, children: const []),
          );
    return _with(root: nextRoot, currentPath: [...currentPath, nextIndex]);
  }

  /// Moves the personal cursor back one learner-created ply.
  ExplorationSession previous() => currentPath.isEmpty
      ? this
      : _with(currentPath: currentPath.sublist(0, currentPath.length - 1));

  /// Follows the first stored branch by one learner-created ply.
  ExplorationSession next() =>
      branches.isEmpty ? this : _with(currentPath: [...currentPath, 0]);

  /// Returns to the authored origin while keeping every personal branch.
  ExplorationSession first() =>
      currentPath.isEmpty ? this : _with(currentPath: const []);

  /// Follows the first stored branch to its leaf, preserving all siblings.
  ExplorationSession last() {
    var result = this;
    while (result.canNext) {
      result = result.next();
    }
    return result;
  }

  /// Selects a personal-tree path. Empty selects the authored origin.
  ExplorationSession selectPath(List<int> path) {
    if (path.length > _maxPersonalPlies) {
      throw ArgumentError.value(path, 'path', 'The selected path is too deep.');
    }
    var siblings = root;
    for (var index = 0; index < path.length; index++) {
      final childIndex = path[index];
      if (childIndex < 0 || childIndex >= siblings.length) {
        throw ArgumentError.value(
          path,
          'path',
          'The selected path does not exist in the personal tree.',
        );
      }
      siblings = siblings[childIndex].children;
    }
    return _with(currentPath: path);
  }

  /// Encodes this personal draft as versioned, source-independent JSON data.
  Map<String, Object?> toJson() => <String, Object?>{
    'version': codecVersion,
    'origin': origin.toJson(),
    'tree': _treeToJson(root),
    'cursorPath': List<int>.of(currentPath),
  };

  /// Decodes and fully replays a stored personal draft.
  ///
  /// Unsupported versions, malformed trees, illegal moves, impossible cursor
  /// paths, and drafts beyond the defensive size limits throw [FormatException].
  factory ExplorationSession.fromJson(Map<String, Object?> json) {
    try {
      final version = json['version'];
      if (version != codecVersion) {
        throw FormatException(
          'Unsupported exploration draft version: $version',
        );
      }
      final originValue = json['origin'];
      if (originValue is! Map) {
        throw const FormatException('Exploration origin must be an object.');
      }
      final origin = ExplorationOrigin.fromJson(_objectMap(originValue));
      final counter = _NodeCounter();
      final root = _readTree(json['tree'], depth: 0, counter: counter);
      final cursorPath = _readIntList(json, 'cursorPath');
      if (cursorPath.length > _maxPersonalPlies) {
        throw const FormatException('Exploration cursor is too deep.');
      }
      final session = ExplorationSession._(
        origin: origin,
        root: root,
        currentPath: cursorPath,
      );
      session._validateTree();
      session.position;
      return session;
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid exploration draft: $error');
    }
  }

  ExplorationSession _with({
    List<ExplorationMoveNode>? root,
    List<int>? currentPath,
  }) => ExplorationSession._(
    origin: origin,
    root: root ?? this.root,
    currentPath: List.unmodifiable(currentPath ?? this.currentPath),
  );

  chess.Chess _positionFor(List<int> personalPath) {
    var position = _positionFromFen(origin.startingFen);
    for (final uci in origin.authoredMoves) {
      final move = _parseUci(uci, argumentName: 'origin.authoredMoves');
      if (!position.isLegal(move)) {
        throw FormatException('Illegal authored origin move: $uci');
      }
      position = position.play(move) as chess.Chess;
    }
    var siblings = root;
    for (final index in personalPath) {
      if (index < 0 || index >= siblings.length) {
        throw FormatException('Exploration cursor path is invalid.');
      }
      final node = siblings[index];
      final move = _parseUci(node.uci, argumentName: 'tree');
      if (position.isGameOver || !position.isLegal(move)) {
        throw FormatException('Illegal personal exploration move: ${node.uci}');
      }
      position = position.play(move) as chess.Chess;
      siblings = node.children;
    }
    return position;
  }

  void _validateTree() {
    final counter = _NodeCounter();
    final initialPosition = _positionFromFen(origin.startingFen);
    var authoredPosition = initialPosition;
    for (final uci in origin.authoredMoves) {
      final move = _parseUci(uci, argumentName: 'origin.authoredMoves');
      if (!authoredPosition.isLegal(move)) {
        throw FormatException('Illegal authored origin move: $uci');
      }
      authoredPosition = authoredPosition.play(move) as chess.Chess;
    }
    _validateSiblings(root, authoredPosition, depth: 0, counter: counter);

    var siblings = root;
    for (final childIndex in currentPath) {
      if (childIndex < 0 || childIndex >= siblings.length) {
        throw const FormatException('Exploration cursor path is invalid.');
      }
      siblings = siblings[childIndex].children;
    }
  }

  void _validateSiblings(
    List<ExplorationMoveNode> siblings,
    chess.Chess before, {
    required int depth,
    required _NodeCounter counter,
  }) {
    if (depth > _maxPersonalPlies) {
      throw const FormatException('Exploration tree is too deep.');
    }
    final seenMoves = <String>{};
    for (final node in siblings) {
      counter.add();
      if (!seenMoves.add(node.uci)) {
        throw FormatException('Duplicate personal sibling move: ${node.uci}');
      }
      final move = _parseUci(node.uci, argumentName: 'tree');
      if (before.isGameOver || !before.isLegal(move)) {
        throw FormatException('Illegal personal exploration move: ${node.uci}');
      }
      final after = before.play(move) as chess.Chess;
      _validateSiblings(
        node.children,
        after,
        depth: depth + 1,
        counter: counter,
      );
    }
  }
}

const int _maxOriginTextLength = 4096;
const int _maxFenLength = 256;
const int _maxAuthoredPlies = 512;
const int _maxPersonalPlies = 512;
const int _maxTreeNodes = 20000;

class _NodeCounter {
  int value = 0;

  void add() {
    value++;
    if (value > _maxTreeNodes) {
      throw const FormatException('Exploration tree contains too many moves.');
    }
  }
}

chess.Chess _positionFromFen(String fen) {
  try {
    return chess.Chess.fromSetup(chess.Setup.parseFen(fen));
  } on FormatException catch (error) {
    throw FormatException('Invalid exploration starting FEN: $error', fen);
  } on chess.PositionSetupException catch (error) {
    throw FormatException('Invalid exploration starting FEN: $error', fen);
  }
}

chess.Move _parseUci(String uci, {required String argumentName}) {
  if (uci.length < 4 || uci.length > 5) {
    throw ArgumentError.value(uci, argumentName, 'Expected a UCI move.');
  }
  final move = chess.Move.parse(uci);
  if (move == null || move is! chess.NormalMove || move.uci != uci) {
    throw ArgumentError.value(
      uci,
      argumentName,
      'Expected a normalized UCI move.',
    );
  }
  return move;
}

List<ExplorationMoveNode> _appendAtPath(
  List<ExplorationMoveNode> siblings,
  List<int> path,
  ExplorationMoveNode addition,
) {
  if (path.isEmpty) return List.unmodifiable([...siblings, addition]);
  final index = path.first;
  final old = siblings[index];
  final replaced = ExplorationMoveNode._(
    uci: old.uci,
    children: _appendAtPath(old.children, path.sublist(1), addition),
  );
  final result = List<ExplorationMoveNode>.of(siblings);
  result[index] = replaced;
  return List.unmodifiable(result);
}

int _countTreeNodes(List<ExplorationMoveNode> roots) {
  var count = 0;
  final pending = <ExplorationMoveNode>[...roots];
  while (pending.isNotEmpty) {
    final node = pending.removeLast();
    count++;
    if (count >= _maxTreeNodes) return count;
    pending.addAll(node.children);
  }
  return count;
}

List<Map<String, Object?>> _treeToJson(List<ExplorationMoveNode> nodes) =>
    List<Map<String, Object?>>.unmodifiable(
      nodes.map(
        (node) => <String, Object?>{
          'uci': node.uci,
          'children': _treeToJson(node.children),
        },
      ),
    );

List<ExplorationMoveNode> _readTree(
  Object? value, {
  required int depth,
  required _NodeCounter counter,
}) {
  if (depth > _maxPersonalPlies) {
    throw const FormatException('Exploration tree is too deep.');
  }
  if (value is! List) {
    throw const FormatException('Exploration tree branches must be arrays.');
  }
  final result = <ExplorationMoveNode>[];
  for (final child in value) {
    if (child is! Map) {
      throw const FormatException('Exploration tree move must be an object.');
    }
    counter.add();
    final data = _objectMap(child);
    final uci = _readString(data, 'uci');
    // Check notation and bound it before recursing into untrusted structures.
    if (uci.length < 4 || uci.length > 5) {
      throw FormatException('Invalid UCI move in exploration tree: $uci');
    }
    final children = _readTree(
      data['children'],
      depth: depth + 1,
      counter: counter,
    );
    result.add(ExplorationMoveNode._(uci: uci, children: children));
  }
  return List.unmodifiable(result);
}

Map<String, Object?> _objectMap(Map<dynamic, dynamic> value) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw const FormatException('JSON object keys must be strings.');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

String _readString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('Expected string field "$key".');
  return value;
}

String? _readNullableString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Expected string or null field "$key".');
  }
  return value;
}

List<int> _readIntList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List || value.length > _maxPersonalPlies) {
    throw FormatException('Expected a bounded integer array field "$key".');
  }
  final result = <int>[];
  for (final item in value) {
    if (item is! int) throw FormatException('Expected integers in "$key".');
    result.add(item);
  }
  return List.unmodifiable(result);
}

List<String> _readStringList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List || value.length > _maxAuthoredPlies) {
    throw FormatException('Expected a bounded string array field "$key".');
  }
  final result = <String>[];
  for (final item in value) {
    if (item is! String) throw FormatException('Expected strings in "$key".');
    result.add(item);
  }
  return List.unmodifiable(result);
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
