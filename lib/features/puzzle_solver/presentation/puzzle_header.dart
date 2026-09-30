import 'package:flutter/material.dart';

import '../../../domain/training/puzzle_evaluator.dart';

/// Compact puzzle progress and active side-to-move header.
///
/// Progress is supplied by the caller because set and cycle ordering belong to
/// training state. The side label always comes from the evaluator's active
/// position.
final class PuzzleHeader extends StatelessWidget {
  const PuzzleHeader({
    required this.currentExercise,
    required this.totalExercises,
    required this.evaluation,
    super.key,
  }) : assert(currentExercise > 0),
       assert(totalExercises > 0),
       assert(currentExercise <= totalExercises);

  /// One-based position of the current exercise in the set or cycle.
  final int currentExercise;

  /// Number of exercises in the set or cycle.
  final int totalExercises;

  /// Active evaluator snapshot; its position determines the side label.
  final PuzzleEvaluationState evaluation;

  @override
  Widget build(BuildContext context) {
    final sideLabel = switch (evaluation.sideToMove) {
      PuzzleSide.white => 'White to move',
      PuzzleSide.black => 'Black to move',
    };
    final progressLabel = 'Exercise $currentExercise of $totalExercises';
    final progress = currentExercise / totalExercises;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(progressLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Semantics(
          label: 'Exercise progress',
          value: '$currentExercise of $totalExercises',
          child: LinearProgressIndicator(value: progress),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: sideLabel,
          excludeSemantics: true,
          child: Text(
            sideLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}
