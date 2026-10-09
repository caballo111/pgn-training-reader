import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/material.dart';

import '../../../domain/analysis/exploration_session.dart';

/// Move navigation for the learner-owned tree. Authored moves are excluded;
/// the tree always starts at the workspace's captured origin.
final class ExplorationMoveTree extends StatelessWidget {
  const ExplorationMoveTree({
    required this.session,
    required this.onSelectPath,
    required this.onSelectBranch,
    super.key,
  });

  final ExplorationSession session;
  final ValueChanged<List<int>> onSelectPath;
  final ValueChanged<int> onSelectBranch;

  @override
  Widget build(BuildContext context) {
    final path = session.currentPath;
    final notation = _activeNotation(session);
    final branches = session.branches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your exploration',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (path.isEmpty)
          const Text('No personal moves yet. Play a legal move to begin.')
        else
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var index = 0; index < notation.length; index++)
                _MoveChip(
                  label: notation[index],
                  tooltip:
                      'Go to personal move ${index + 1}, ${notation[index]}',
                  selected: index == path.length - 1,
                  onPressed: () => onSelectPath(path.take(index + 1).toList()),
                ),
            ],
          ),
        if (branches.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            path.isEmpty ? 'Continue your exploration' : 'Other continuations',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var index = 0; index < branches.length; index++)
                _MoveChip(
                  label: _branchSan(session, branches[index]),
                  tooltip:
                      'Select personal branch ${_branchSan(session, branches[index])}',
                  selected: false,
                  onPressed: () => onSelectBranch(index),
                ),
            ],
          ),
        ],
      ],
    );
  }

  List<String> _activeNotation(ExplorationSession session) {
    var position = _originPosition(session.origin);
    for (final uci in session.origin.authoredMoves) {
      final move = chess.Move.parse(uci);
      if (move == null || !position.isLegal(move)) {
        return session.activeLine.map((node) => node.uci).toList();
      }
      position = position.play(move) as chess.Chess;
    }
    final result = <String>[];
    for (final node in session.activeLine) {
      final move = chess.Move.parse(node.uci);
      if (move == null || !position.isLegal(move)) {
        result.add(node.uci);
        continue;
      }
      final moveNumber = position.fullmoves;
      final moveSuffix = position.turn == chess.Side.white ? '.' : '...';
      result.add('$moveNumber$moveSuffix ${position.makeSan(move).$2}');
      position = position.play(move) as chess.Chess;
    }
    return result;
  }

  String _branchSan(ExplorationSession session, ExplorationMoveNode node) {
    final move = chess.Move.parse(node.uci);
    if (move == null || !session.position.isLegal(move)) return node.uci;
    return session.position.makeSan(move).$2;
  }

  chess.Chess _originPosition(ExplorationOrigin origin) =>
      chess.Chess.fromSetup(
        chess.Setup.parseFen(origin.startingFen),
        ignoreImpossibleCheck: true,
      );
}

final class _MoveChip extends StatelessWidget {
  const _MoveChip({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: tooltip,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: OutlinedButton(
        style: selected
            ? OutlinedButton.styleFrom(
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .secondaryContainer,
              )
            : null,
        onPressed: onPressed,
        child: Text(label),
      ),
    ),
  );
}
