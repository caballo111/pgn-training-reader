import 'package:flutter/material.dart';

import 'study_board_controls.dart';

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
    this.status,
    this.onReturnToPlayedLine,
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
  final Widget? status;
  final VoidCallback? onReturnToPlayedLine;

  @override
  Widget build(BuildContext context) => StudyBoardControls(
    onFlip: onFlip,
    navigation: Wrap(
      alignment: WrapAlignment.center,
      children: [
        if (showNavigation) ...[
          IconButton(
            tooltip: 'Starting position',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: canPrevious ? onFirst : null,
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            tooltip: 'Previous move',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: canPrevious ? onPrevious : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next move',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: canNext ? onNext : null,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: 'Last move on main line',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: canNext ? onLast : null,
            icon: const Icon(Icons.last_page),
          ),
        ],
        if (onReturnToPlayedLine != null)
          IconButton(
            key: const ValueKey('return-to-played-line'),
            tooltip: 'Return to played line',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onReturnToPlayedLine,
            icon: const Icon(Icons.undo),
          ),
        if (status != null)
          SizedBox(
            width: 48,
            height: 48,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: status,
            ),
          ),
      ],
    ),
  );
}
