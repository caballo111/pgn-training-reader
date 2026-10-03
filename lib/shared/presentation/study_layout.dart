import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps the position stationary while supporting material scrolls separately.
class StudyLayout extends StatelessWidget {
  const StudyLayout({
    required this.board,
    required this.details,
    this.header,
    this.actions,
    this.controls,
    this.controlCount = 5,
    this.actionTopPadding = 4,
    this.controlTrailingWidth = 0,
    this.controlCaption,
    super.key,
  });

  final Widget board;
  final Widget details;

  /// Compact context retained above the board and independently of details.
  final Widget? header;

  /// Essential actions pinned below scrollable details.
  final Widget? actions;

  /// Legacy board-adjacent controls; prefer [actions] for essential actions.
  final Widget? controls;
  final int controlCount;
  final double actionTopPadding;
  final double controlTrailingWidth;
  final String? controlCaption;

  double _controlHeight(BuildContext context, double width) {
    if (controls == null) return 0;
    var captionHeight = 0.0;
    if (controlCaption != null) {
      final painter = TextPainter(
        text: TextSpan(
          text: controlCaption,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: math.max(1, width - 96));
      captionHeight = painter.height;
      painter.dispose();
    }
    if (controlCount == 0) {
      return math.max(controlTrailingWidth > 0 ? 48 : 0, captionHeight);
    }
    final perRow = ((width - controlTrailingWidth) / 48).floor().clamp(
      1,
      controlCount,
    );
    return math.max(48.0 * (controlCount / perRow).ceil(), captionHeight);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final viewport = MediaQuery.sizeOf(context);
        final wide = viewport.width >= 840 || viewport.width > viewport.height;
        final compactWide = wide && constraints.maxHeight < 420;
        if (compactWide) {
          return Row(
            children: [
              Expanded(
                flex: 2,
                child: LayoutBuilder(
                  builder: (context, boardConstraints) {
                    final controlHeight = _controlHeight(
                      context,
                      boardConstraints.maxWidth,
                    );
                    final size = math.max(
                      24.0,
                      math.min(
                        boardConstraints.maxWidth,
                        boardConstraints.maxHeight - controlHeight,
                      ),
                    );
                    return Center(child: _position(size));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    if (header != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                        child: header,
                      ),
                    Expanded(child: details),
                    if (actions != null)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: actions,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        }
        final sideBySide = wide && actions == null && header == null;
        if (sideBySide) {
          final size = math.max(
            80.0,
            math.min(
              520.0,
              math.min(
                (constraints.maxWidth - 56) * .6,
                constraints.maxHeight - 80,
              ),
            ),
          );
          final position = _position(size);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(flex: 3, child: Center(child: position)),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: details),
              ],
            ),
          );
        }
        return Column(
          children: [
            if (header != null)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: wide ? 2 : 8,
                ),
                child: header,
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, mainConstraints) {
                  // Reserve control height before selecting the square size.
                  final controlHeight = _controlHeight(
                    context,
                    wide
                        ? (mainConstraints.maxWidth - 16) * .6
                        : mainConstraints.maxWidth,
                  );
                  // Include the gap between the board/control group and the
                  // details viewport in the reservation.
                  final detailReserve = math.min(
                    128.0,
                    mainConstraints.maxHeight * .25,
                  );
                  final boardSize = wide
                      ? math.max(
                          24.0,
                          math.min(
                            520.0,
                            math.min(
                              (mainConstraints.maxWidth * .6) - 24,
                              mainConstraints.maxHeight - controlHeight - 16,
                            ),
                          ),
                        )
                      : math.max(
                          24.0,
                          math.min(
                            mainConstraints.maxWidth,
                            mainConstraints.maxHeight -
                                controlHeight -
                                detailReserve,
                          ),
                        );
                  final position = _position(boardSize);
                  if (wide) {
                    return Row(
                      children: [
                        Expanded(flex: 3, child: Center(child: position)),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: details),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Center(child: position),
                      const SizedBox(height: 8),
                      Expanded(child: details),
                    ],
                  );
                },
              ),
            ),
            if (actions != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    wide ? 0 : actionTopPadding,
                    12,
                    wide ? 0 : 8,
                  ),
                  child: actions,
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _position(double size) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(width: size, child: board),
      ?controls,
    ],
  );
}
