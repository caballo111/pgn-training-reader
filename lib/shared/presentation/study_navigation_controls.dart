import 'package:flutter/material.dart';

import 'flip_board_button.dart';

/// Consistent icon navigation for a browsable study line.
class StudyNavigationControls extends StatelessWidget {
  const StudyNavigationControls({
    required this.canPrevious,
    required this.canNext,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
    required this.onFlip,
    this.showNavigation = true,
    super.key,
  });

  final bool canPrevious;
  final bool canNext;
  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLast;
  final VoidCallback onFlip;
  final bool showNavigation;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      if (showNavigation) ...[
        IconButton(
          tooltip: 'Starting position',
          onPressed: canPrevious ? onFirst : null,
          icon: const Icon(Icons.first_page),
        ),
        IconButton(
          tooltip: 'Previous move',
          onPressed: canPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Next move',
          onPressed: canNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          tooltip: 'Last move on main line',
          onPressed: canNext ? onLast : null,
          icon: const Icon(Icons.last_page),
        ),
      ],
      FlipBoardButton(
        key: const ValueKey('reader-board-orientation'),
        onPressed: onFlip,
      ),
    ],
  );
}
