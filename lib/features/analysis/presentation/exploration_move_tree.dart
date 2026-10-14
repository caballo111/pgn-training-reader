import 'dart:async';

import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/material.dart';

import '../../../domain/analysis/exploration_session.dart';

/// Move navigation for the learner-owned tree. Authored moves are excluded;
/// the tree always starts at the workspace's captured origin.
final class ExplorationMoveTree extends StatefulWidget {
  const ExplorationMoveTree({
    required this.session,
    required this.onSelectPath,
    required this.onSelectBranch,
    this.onDeleteBranch,
    this.onClearExploration,
    super.key,
  });

  final ExplorationSession session;
  final ValueChanged<List<int>> onSelectPath;
  final ValueChanged<int> onSelectBranch;
  final ValueChanged<List<int>>? onDeleteBranch;
  final VoidCallback? onClearExploration;

  @override
  State<ExplorationMoveTree> createState() => _ExplorationMoveTreeState();
}

final class _ExplorationMoveTreeState extends State<ExplorationMoveTree> {
  final GlobalKey _currentMoveKey = GlobalKey();

  @override
  void didUpdateWidget(ExplorationMoveTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_samePath(oldWidget.session.currentPath, widget.session.currentPath)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final context = _currentMoveKey.currentContext;
        if (context != null) {
          unawaited(
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 180),
              alignment: 0.5,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final selectedLine = session.selectedLine;
    final notation = _notation(session, selectedLine);
    final selectedPath = session.selectedPath;
    final variations = <Widget>[];

    for (var depth = 0; depth < selectedLine.length; depth++) {
      final siblings = _siblingsAtDepth(session, depth);
      if (siblings.length > 1) {
        variations.add(
          _variationRow(
            session: session,
            depth: depth,
            siblings: siblings,
            position: notation.positions[depth],
            parentLabel: depth == 0
                ? 'the exploration origin'
                : notation.labels[depth - 1],
          ),
        );
      }
    }

    final atCursor = _siblingsAtDepth(session, session.currentPath.length);
    if (session.currentPath.length >= selectedLine.length &&
        atCursor.isNotEmpty &&
        atCursor.length == 1) {
      variations.add(
        _variationRow(
          session: session,
          depth: session.currentPath.length,
          siblings: atCursor,
          position: session.position,
          parentLabel: session.currentPath.isEmpty
              ? 'the exploration origin'
              : notation.labels[session.currentPath.length - 1],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your exploration',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (selectedLine.any((node) => node.engineOrigin))
          Row(
            children: [
              const Icon(Icons.memory, size: 14),
              const SizedBox(width: 4),
              Text(
                'Engine suggestion',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        const SizedBox(height: 8),
        if (selectedLine.isEmpty)
          const Text('No personal moves yet. Play a legal move to begin.')
        else
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              for (var index = 0; index < selectedLine.length; index++)
                KeyedSubtree(
                  key: index == session.currentPath.length - 1
                      ? _currentMoveKey
                      : null,
                  child: _MoveChip(
                    label: notation.labels[index],
                    tooltip:
                        'Go to personal move ${index + 1}, ${notation.labels[index]}',
                    selected: index == session.currentPath.length - 1,
                    engineOrigin: selectedLine[index].engineOrigin,
                    onPressed: () => widget.onSelectPath(
                      selectedPath.take(index + 1).toList(),
                    ),
                  ),
                ),
            ],
          ),
        if (variations.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...variations,
        ],
        if (widget.onDeleteBranch != null && session.currentPath.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('delete-from-current-move'),
              onPressed: () =>
                  widget.onDeleteBranch!(session.currentPath.toList()),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(
                'Delete from ${notation.labels[session.currentPath.length - 1]}',
              ),
            ),
          ),
        if (widget.onClearExploration != null && session.root.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('clear-exploration'),
              onPressed: widget.onClearExploration,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Clear exploration'),
            ),
          ),
      ],
    );
  }

  Widget _variationRow({
    required ExplorationSession session,
    required int depth,
    required List<ExplorationMoveNode> siblings,
    required chess.Chess position,
    required String parentLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Variations after $parentLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              for (var index = 0; index < siblings.length; index++)
                _VariationChoice(
                  label: _san(position, siblings[index]),
                  parentLabel: parentLabel,
                  selected:
                      depth < session.selectedPath.length &&
                      session.selectedPath[depth] == index,
                  engineOrigin: siblings[index].engineOrigin,
                  onPressed: () {
                    if (depth == session.currentPath.length) {
                      widget.onSelectBranch(index);
                    } else {
                      widget.onSelectPath([
                        ...session.selectedPath.take(depth),
                        index,
                      ]);
                    }
                  },
                  onDelete: widget.onDeleteBranch == null
                      ? null
                      : () => widget.onDeleteBranch!([
                          ...session.selectedPath.take(depth),
                          index,
                        ]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _MoveNotation {
  const _MoveNotation(this.labels, this.positions);

  final List<String> labels;
  final List<chess.Chess> positions;
}

_MoveNotation _notation(
  ExplorationSession session,
  List<ExplorationMoveNode> line,
) {
  var position = _originPosition(session.origin);
  for (final uci in session.origin.authoredMoves) {
    final move = chess.Move.parse(uci);
    if (move == null || !position.isLegal(move)) {
      return _MoveNotation(
        line.map((node) => node.uci).toList(growable: false),
        List<chess.Chess>.filled(line.length, position),
      );
    }
    position = position.play(move) as chess.Chess;
  }
  final labels = <String>[];
  final positions = <chess.Chess>[];
  for (final node in line) {
    positions.add(position);
    final move = chess.Move.parse(node.uci);
    if (move == null || !position.isLegal(move)) {
      labels.add(node.uci);
      continue;
    }
    final moveNumber = position.fullmoves;
    final moveSuffix = position.turn == chess.Side.white ? '.' : '...';
    labels.add('$moveNumber$moveSuffix ${position.makeSan(move).$2}');
    position = position.play(move) as chess.Chess;
  }
  return _MoveNotation(labels, positions);
}

List<ExplorationMoveNode> _siblingsAtDepth(
  ExplorationSession session,
  int depth,
) {
  var siblings = session.root;
  for (var index = 0; index < depth; index++) {
    siblings = siblings[session.selectedPath[index]].children;
  }
  return siblings;
}

String _san(chess.Chess position, ExplorationMoveNode node) {
  final move = chess.Move.parse(node.uci);
  if (move == null || !position.isLegal(move)) return node.uci;
  return position.makeSan(move).$2;
}

chess.Chess _originPosition(ExplorationOrigin origin) => chess.Chess.fromSetup(
  chess.Setup.parseFen(origin.startingFen),
  ignoreImpossibleCheck: true,
);

bool _samePath(List<int> first, List<int> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

final class _VariationChoice extends StatelessWidget {
  const _VariationChoice({
    required this.label,
    required this.parentLabel,
    required this.selected,
    required this.engineOrigin,
    required this.onPressed,
    required this.onDelete,
  });

  final String label;
  final String parentLabel;
  final bool selected;
  final bool engineOrigin;
  final VoidCallback onPressed;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final description = 'Select personal variation $label after $parentLabel';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MoveChip(
          label: label,
          tooltip: engineOrigin ? '$description · From engine' : description,
          selected: selected,
          engineOrigin: engineOrigin,
          onPressed: onPressed,
        ),
        if (onDelete != null)
          Tooltip(
            message: 'Delete variation $label after $parentLabel',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 36, height: 48),
              padding: EdgeInsets.zero,
              iconSize: 18,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
      ],
    );
  }
}

final class _MoveChip extends StatelessWidget {
  const _MoveChip({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.engineOrigin,
    required this.onPressed,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final bool engineOrigin;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: engineOrigin ? '$tooltip · From engine suggestion' : tooltip,
    child: Tooltip(
      message: tooltip,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: onPressed,
            child: Center(
              widthFactor: 1,
              child: Ink(
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label),
                        if (engineOrigin) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.memory,
                            size: 14,
                            semanticLabel: 'From engine suggestion',
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
