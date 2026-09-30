import 'package:flutter/material.dart';

import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/move_node.dart';
import '../application/reader_navigation_state.dart';

/// Displays all authored moves and annotations for normal reader mode.
///
/// Selecting a move reports the navigation cursor immediately after that
/// move. Variations remain visible as indented branches and use their source
/// order from the parsed move tree.
final class MoveTreeView extends StatefulWidget {
  const MoveTreeView({
    required this.content,
    required this.navigation,
    required this.onNavigationChanged,
    this.shrinkWrap = false,
    this.scrollable = true,
    super.key,
  });

  final ChessContent content;
  final ReaderNavigationState navigation;
  final ValueChanged<ReaderNavigationState> onNavigationChanged;
  final bool shrinkWrap;
  final bool scrollable;

  @override
  State<MoveTreeView> createState() => _MoveTreeViewState();
}

class _MoveTreeViewState extends State<MoveTreeView> {
  final _activeMoveKey = GlobalKey();

  @override
  void didUpdateWidget(covariant MoveTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeContext = _activeMoveKey.currentContext;
      if (mounted && activeContext != null) {
        Scrollable.ensureVisible(
          activeContext,
          alignment: .5,
          duration: const Duration(milliseconds: 180),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.content.rootMoves.isEmpty) {
      return const Center(child: Text('No moves in this game'));
    }

    final activePath = widget.navigation.path;
    return ListView(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.scrollable ? null : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (
          var index = 0;
          index < widget.content.rootMoves.length;
          index++
        ) ...[
          if (index > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 10, top: 4),
              child: Text(
                'Variation $index',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          _MoveBranch(
            node: widget.content.rootMoves[index],
            content: widget.content,
            depth: index == 0 ? 0 : 1,
            path: [index],
            activePath: activePath,
            activeMoveKey: _activeMoveKey,
            onSelected: widget.onNavigationChanged,
          ),
        ],
      ],
    );
  }
}

final class _MoveBranch extends StatelessWidget {
  const _MoveBranch({
    required this.node,
    required this.content,
    required this.depth,
    required this.path,
    required this.activePath,
    required this.activeMoveKey,
    required this.onSelected,
  });

  final MoveNode node;
  final ChessContent content;
  final int depth;
  final List<int> path;
  final List<MoveNode> activePath;
  final GlobalKey activeMoveKey;
  final ValueChanged<ReaderNavigationState> onSelected;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];
    var inlineMoves = <Widget>[];

    void flushMoves() {
      if (inlineMoves.isEmpty) return;
      sections.add(Wrap(children: inlineMoves));
      inlineMoves = <Widget>[];
    }

    void appendLine(MoveNode move, List<int> movePath) {
      inlineMoves.add(_moveButton(context, move, movePath));
      if (move.comments.isNotEmpty) {
        flushMoves();
        for (final comment in move.comments) {
          sections.add(
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 10, bottom: 6),
              child: Text(comment),
            ),
          );
        }
      }
      if (move.children.isNotEmpty) {
        appendLine(move.children.first, [...movePath, 0]);
        for (var index = 1; index < move.children.length; index++) {
          flushMoves();
          sections.add(
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 10, top: 4),
              child: Text(
                'Variation $index',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          );
          sections.add(
            _MoveBranch(
              node: move.children[index],
              content: content,
              depth: 1,
              path: [...movePath, index],
              activePath: activePath,
              activeMoveKey: activeMoveKey,
              onSelected: onSelected,
            ),
          );
        }
      }
    }

    appendLine(node, path);
    flushMoves();
    return Padding(
      padding: EdgeInsetsDirectional.only(start: depth * 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections,
      ),
    );
  }

  Widget _moveButton(BuildContext context, MoveNode move, List<int> movePath) {
    final isActive = _isCurrentPath(movePath);
    final fen = move.fenBefore.split(' ');
    final number = fen.length >= 6
        ? int.tryParse(fen[5]) ?? (movePath.length + 1) ~/ 2
        : (movePath.length + 1) ~/ 2;
    final isBlack = fen.length >= 6 ? fen[1] == 'b' : movePath.length.isEven;
    final prefix = '$number${isBlack ? '...' : '.'}';
    return Semantics(
      key: isActive ? activeMoveKey : null,
      button: true,
      selected: isActive,
      label: 'Move $prefix ${move.san}${isActive ? ', current position' : ''}',
      child: TextButton(
        onPressed: () => onSelected(_navigationAfterPath(movePath)),
        style: TextButton.styleFrom(
          backgroundColor: isActive
              ? Theme.of(context).colorScheme.secondaryContainer
              : null,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$prefix ', style: Theme.of(context).textTheme.bodySmall),
            Text(move.san),
            if (move.nags.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: Text(
                  move.nags.map((nag) => '\$$nag').join(' '),
                  semanticsLabel: 'Annotations ${move.nags.join(', ')}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isCurrentPath(List<int> path) {
    if (path.length != activePath.length) return false;
    var moves = content.rootMoves;
    for (var depth = 0; depth < path.length; depth++) {
      final index = path[depth];
      if (index >= moves.length || moves[index] != activePath[depth]) {
        return false;
      }
      moves = moves[index].children;
    }
    return true;
  }

  ReaderNavigationState _navigationAfterPath(List<int> path) {
    var state = ReaderNavigationState.initial(content);
    for (final index in path) {
      state = state.selectVariation(index);
    }
    return state;
  }
}
