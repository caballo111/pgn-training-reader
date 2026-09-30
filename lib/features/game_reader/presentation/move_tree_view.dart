import 'package:flutter/material.dart';

import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/move_node.dart';
import '../application/reader_navigation_state.dart';

/// Displays all authored moves and annotations for normal reader mode.
///
/// Selecting a move reports the navigation cursor immediately after that
/// move. Variations remain visible as indented branches and use their source
/// order from the parsed move tree.
final class MoveTreeView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (content.rootMoves.isEmpty) {
      return const Center(child: Text('No moves in this game'));
    }

    final activePath = navigation.path;
    return ListView(
      shrinkWrap: shrinkWrap,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (var index = 0; index < content.rootMoves.length; index++) ...[
          if (index > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 10, top: 4),
              child: Text(
                'Variation $index',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          _MoveBranch(
            node: content.rootMoves[index],
            content: content,
            depth: index == 0 ? 0 : 1,
            path: [index],
            activePath: activePath,
            onSelected: onNavigationChanged,
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
    required this.onSelected,
  });

  final MoveNode node;
  final ChessContent content;
  final int depth;
  final List<int> path;
  final List<MoveNode> activePath;
  final ValueChanged<ReaderNavigationState> onSelected;

  @override
  Widget build(BuildContext context) {
    final isActive = _isCurrentPath();
    return Padding(
      padding: EdgeInsetsDirectional.only(start: depth * 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Semantics(
                  button: true,
                  selected: isActive,
                  label:
                      'Move ${node.san}${isActive ? ', current position' : ''}',
                  child: TextButton(
                    onPressed: () => onSelected(_navigationAfterPath()),
                    style: TextButton.styleFrom(
                      backgroundColor: isActive
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : null,
                      minimumSize: const Size(48, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    child: Text(node.san),
                  ),
                ),
              ),
              if (node.nags.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4, top: 12),
                  child: Text(
                    node.nags.map((nag) => '\$$nag').join(' '),
                    semanticsLabel: 'Annotations ${node.nags.join(', ')}',
                  ),
                ),
            ],
          ),
          for (final comment in node.comments)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 10, bottom: 6),
              child: Text(comment),
            ),
          if (node.children.isNotEmpty) ...[
            _MoveBranch(
              node: node.children.first,
              content: content,
              depth: depth,
              path: [...path, 0],
              activePath: activePath,
              onSelected: onSelected,
            ),
            for (var index = 1; index < node.children.length; index++) ...[
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 10, top: 4),
                child: Text(
                  'Variation $index',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              _MoveBranch(
                node: node.children[index],
                content: content,
                depth: depth + 1,
                path: [...path, index],
                activePath: activePath,
                onSelected: onSelected,
              ),
            ],
          ],
        ],
      ),
    );
  }

  bool _isCurrentPath() {
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

  ReaderNavigationState _navigationAfterPath() {
    var state = ReaderNavigationState.initial(content);
    for (final index in path) {
      state = state.selectVariation(index);
    }
    return state;
  }
}
