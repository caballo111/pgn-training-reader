import '../chess_content/move_node.dart';

/// Author-defined calculation endpoint, independent of book identity.
enum PuzzleCompletionPolicy { keyMoves, allMoves }

bool isCompletionMarker(MoveNode node) => node.comments.any(
  (comment) => RegExp(r'(^|\s)✔(?=\s|$)').hasMatch(comment.trim()),
);

bool hasCompletionMarker(List<MoveNode> nodes) => nodes.any(
  (node) => isCompletionMarker(node) || hasCompletionMarker(node.children),
);
