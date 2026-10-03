import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../domain/training/puzzle_evaluator.dart';
import '../application/puzzle_presentation_state.dart';

/// One attempted alternative, containing no future authored moves.
final class PuzzleAttemptVariation {
  const PuzzleAttemptVariation({required this.path, required this.label});

  final List<String> path;
  final String label;
}

List<PuzzleAttemptVariation> puzzleAttemptVariations(
  PuzzlePresentationState presentation,
) {
  final result = <PuzzleAttemptVariation>[];
  final seen = <String>{};
  if (presentation.rejections.isNotEmpty) {
    for (final rejection in presentation.rejections) {
      final key = '${rejection.authoredPath.join('/')}/${rejection.uci}';
      if (!seen.add(key)) continue;
      final fields = rejection.fenBefore.split(' ');
      final number = fields.length >= 6 ? int.tryParse(fields[5]) ?? 1 : 1;
      final prefix = '$number${fields.elementAtOrNull(1) == 'b' ? '...' : '.'}';
      result.add(
        PuzzleAttemptVariation(
          path: rejection.authoredPath,
          label: '$prefix ${rejection.san ?? rejection.uci}',
        ),
      );
    }
  } else {
    // Older projections may have interaction entries without rejection records.
    final path = <String>[];
    for (final move in presentation.entries) {
      if (move.accepted) {
        path.add(move.uci);
      } else if (seen.add('${path.join('/')}/${move.uci}')) {
        result.add(
          PuzzleAttemptVariation(
            path: List.of(path),
            label:
                '${move.moveNumber}${move.side == PuzzleSide.white ? '.' : '...'} ${move.san}',
          ),
        );
      }
    }
  }
  return result;
}

List<PuzzleAttemptVariation> puzzleVariationsAt(
  List<PuzzleAttemptVariation> variations,
  List<String> path,
) => [
  for (final variation in variations)
    if (listEquals(variation.path, path)) variation,
];

/// Informational alternatives, deliberately without button/selection semantics.
class PuzzleAttemptVariations extends StatelessWidget {
  const PuzzleAttemptVariations({required this.variations, super.key});

  final List<PuzzleAttemptVariation> variations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.only(start: 8, top: 2, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: BorderDirectional(
          start: BorderSide(color: theme.colorScheme.outlineVariant, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final variation in variations)
            Semantics(
              container: true,
              excludeSemantics: true,
              label: 'Incorrect attempt, ${variation.label}',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text(variation.label)),
                    const SizedBox(width: 4),
                    Icon(Icons.close, size: 16, color: theme.colorScheme.error),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
