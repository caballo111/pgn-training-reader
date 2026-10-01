import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps the position stationary while supporting material scrolls separately.
class StudyLayout extends StatelessWidget {
  const StudyLayout({
    required this.board,
    required this.details,
    this.controls,
    super.key,
  });

  final Widget board;
  final Widget details;
  final Widget? controls;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 840 ||
            constraints.maxWidth > constraints.maxHeight;
        final portraitBoardLimit =
            constraints.maxHeight -
            (controls == null
                ? 0.0
                : 56.0 * MediaQuery.textScalerOf(context).scale(1.0)) -
            12 -
            140;
        final size = wide
            ? math.max(
                80.0,
                math.min(
                  520.0,
                  math.min(
                    (constraints.maxWidth - 56) * .6,
                    constraints.maxHeight - 140,
                  ),
                ),
              )
            : math.min(
                constraints.maxWidth,
                math.max(80.0, portraitBoardLimit),
              );
        final position = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: size, child: board),
            ?controls,
          ],
        );
        return Padding(
          padding: wide ? const EdgeInsets.all(16) : EdgeInsets.zero,
          child: wide
              ? Row(
                  children: [
                    Expanded(flex: 3, child: Center(child: position)),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: details),
                  ],
                )
              : Column(
                  children: [
                    Center(child: position),
                    const SizedBox(height: 12),
                    Expanded(child: details),
                  ],
                ),
        );
      },
    ),
  );
}
