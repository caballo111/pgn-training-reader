import 'package:flutter/material.dart';

/// Common side-to-move label and square geometry for read-only and active study boards.
class StudyBoardFrame extends StatelessWidget {
  const StudyBoardFrame({
    required this.sideToMove,
    required this.child,
    super.key,
  });

  final String sideToMove;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        liveRegion: true,
        label: sideToMove,
        child: ExcludeSemantics(
          child: Text(sideToMove, textAlign: TextAlign.center),
        ),
      ),
      AspectRatio(aspectRatio: 1, child: child),
    ],
  );
}
