import 'package:flutter/material.dart';

import '../../domain/training/puzzle_evaluator.dart';

/// A square board retaining turn information for assistive technology.
class StudyBoardFrame extends StatelessWidget {
  const StudyBoardFrame({
    required this.sideToMove,
    required this.child,
    super.key,
  });

  final PuzzleSide sideToMove;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('study-side-to-move'),
    liveRegion: true,
    label: sideToMove == PuzzleSide.white ? 'White to move' : 'Black to move',
    child: AspectRatio(aspectRatio: 1, child: child),
  );
}
