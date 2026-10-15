import 'dart:math' as math;

import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Draws up to three UCI move arrows over [child] without intercepting input.
///
/// The caller is responsible for checking legality in the displayed position.
/// This widget rejects malformed UCI moves, removes duplicates, and keeps the
/// overlay passive so an interactive board beneath it remains usable.
final class ChessboardMoveArrows extends StatelessWidget {
  const ChessboardMoveArrows({
    required this.child,
    required this.moves,
    required this.orientation,
    super.key,
  });

  final Widget child;
  final List<String> moves;
  final chess.Side orientation;

  /// A normalized copy of valid, unique UCI moves, capped at three.
  @visibleForTesting
  static List<String> sanitizeMoves(Iterable<String> moves) {
    final seen = <String>{};
    final safe = <String>[];
    for (final uci in moves) {
      chess.Move? parsed;
      try {
        parsed = chess.Move.parse(uci);
      } on Object {
        continue;
      }
      if (parsed is! chess.NormalMove || !seen.add(parsed.uci)) continue;
      safe.add(parsed.uci);
      if (safe.length == 3) break;
    }
    return List.unmodifiable(safe);
  }

  /// Returns square-center coordinates in board-relative 0..1 space.
  @visibleForTesting
  static ({Offset start, Offset end})? normalizedEndpointsFor(
    String uci,
    chess.Side orientation,
  ) {
    chess.Move? move;
    try {
      move = chess.Move.parse(uci);
    } on Object {
      return null;
    }
    if (move is! chess.NormalMove) return null;

    Offset point(chess.Square square) {
      final file = square.value & 7;
      final rank = square.value >> 3;
      final column = orientation == chess.Side.white ? file : 7 - file;
      final row = orientation == chess.Side.white ? 7 - rank : rank;
      return Offset((column + 0.5) / 8, (row + 0.5) / 8);
    }

    return (start: point(move.from), end: point(move.to));
  }

  @override
  Widget build(BuildContext context) {
    final safeMoves = sanitizeMoves(moves);
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (safeMoves.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey<String>('chessboard-move-arrows'),
                painter: _MoveArrowPainter(
                  moves: safeMoves,
                  orientation: orientation,
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.78),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

final class _MoveArrowPainter extends CustomPainter {
  const _MoveArrowPainter({
    required this.moves,
    required this.orientation,
    required this.color,
  });

  final List<String> moves;
  final chess.Side orientation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final boardSize = math.min(size.width, size.height);
    if (boardSize <= 0) return;
    final boardOrigin = Offset(
      (size.width - boardSize) / 2,
      (size.height - boardSize) / 2,
    );
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = boardSize / 64
      ..strokeCap = StrokeCap.round;
    final headPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final uci in moves) {
      final endpoints = ChessboardMoveArrows.normalizedEndpointsFor(
        uci,
        orientation,
      );
      if (endpoints == null) continue;
      final start =
          boardOrigin +
          Offset(
            endpoints.start.dx * boardSize,
            endpoints.start.dy * boardSize,
          );
      final end =
          boardOrigin +
          Offset(endpoints.end.dx * boardSize, endpoints.end.dy * boardSize);
      final direction = end - start;
      final length = direction.distance;
      if (length == 0) continue;
      final unit = direction / length;
      final headLength = boardSize / 15;
      final shaftEnd = end - unit * headLength * 0.72;
      canvas.drawLine(start, shaftEnd, stroke);

      final perpendicular = Offset(-unit.dy, unit.dx);
      final base = end - unit * headLength;
      final arrowHead = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(
          base.dx + perpendicular.dx * headLength * 0.58,
          base.dy + perpendicular.dy * headLength * 0.58,
        )
        ..lineTo(
          base.dx - perpendicular.dx * headLength * 0.58,
          base.dy - perpendicular.dy * headLength * 0.58,
        )
        ..close();
      canvas.drawPath(arrowHead, headPaint);
    }
  }

  @override
  bool shouldRepaint(_MoveArrowPainter oldDelegate) =>
      !listEquals(moves, oldDelegate.moves) ||
      orientation != oldDelegate.orientation ||
      color != oldDelegate.color;
}
