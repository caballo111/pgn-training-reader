import 'package:flutter/material.dart';

import 'flip_board_button.dart';

/// Stable board-adjacent placement for orientation and position information.
class StudyBoardControls extends StatelessWidget {
  const StudyBoardControls({
    required this.onFlip,
    this.caption,
    this.navigation,
    super.key,
  });

  final VoidCallback? onFlip;
  final String? caption;
  final Widget? navigation;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (navigation == null) const SizedBox(width: 48),
      Expanded(
        child:
            navigation ??
            (caption == null
                ? const SizedBox.shrink()
                : ExcludeSemantics(
                    child: Text(
                      caption!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )),
      ),
      FlipBoardButton(
        key: const ValueKey('reader-board-orientation'),
        onPressed: onFlip,
      ),
    ],
  );
}
