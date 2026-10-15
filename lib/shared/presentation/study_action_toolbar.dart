import 'package:flutter/material.dart';

/// Actions supplied by the book that owns a reading surface.
final class StudyBlockActions {
  const StudyBlockActions({
    this.onPrevious,
    this.onToggleMode,
    this.onNext,
    this.nextLabel = 'Next block',
    this.solving = false,
    this.extraMenuItems = const [],
  });

  final VoidCallback? onPrevious;
  final VoidCallback? onToggleMode;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool solving;
  final List<StudyMenuAction> extraMenuItems;
}

/// Stable, accessible icon actions shared by reading and puzzle boards.
final class StudyActionToolbar extends StatelessWidget {
  const StudyActionToolbar({
    this.onPreviousBlock,
    this.onToggleMode,
    this.solving = false,
    this.onReset,
    this.onAnalyze,
    this.onNextBlock,
    this.nextLabel = 'Next block',
    this.onFlip,
    this.onToggleBoardSize,
    this.compactBoard = false,
    this.extraMenuItems = const [],
    super.key,
  });

  final VoidCallback? onPreviousBlock;
  final VoidCallback? onToggleMode;
  final bool solving;
  final VoidCallback? onReset;
  final VoidCallback? onAnalyze;
  final VoidCallback? onNextBlock;
  final String nextLabel;
  final VoidCallback? onFlip;
  final VoidCallback? onToggleBoardSize;
  final bool compactBoard;
  final List<StudyMenuAction> extraMenuItems;

  @override
  Widget build(BuildContext context) {
    final items = <StudyMenuAction>[
      if (onFlip != null)
        StudyMenuAction('Flip board', Icons.flip_camera_android, onFlip!),
      if (onToggleBoardSize != null)
        StudyMenuAction(
          compactBoard ? 'Expand board' : 'Compact board',
          compactBoard ? Icons.expand : Icons.compress,
          onToggleBoardSize!,
        ),
      ...extraMenuItems,
    ];
    final buttons = <Widget>[
      _button('Previous block', Icons.skip_previous, onPreviousBlock),
      IconButton(
        tooltip: solving ? 'Switch to read mode' : 'Switch to solve mode',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: onToggleMode,
        icon: solving
            ? const Icon(Icons.menu_book_outlined)
            : const StudySolveIcon(),
      ),
      _button('Reset board', Icons.restart_alt, onReset),
      _button('Analyze position', Icons.analytics_outlined, onAnalyze),
      _button(
        nextLabel,
        nextLabel == 'Back to book'
            ? Icons.library_books_outlined
            : Icons.skip_next,
        onNextBlock,
      ),
      PopupMenuButton<int>(
        tooltip: 'More board actions',
        enabled: items.isNotEmpty,
        position: PopupMenuPosition.over,
        icon: const Icon(Icons.more_vert),
        constraints: const BoxConstraints(minWidth: 200),
        onSelected: (index) => items[index].onSelected(),
        itemBuilder: (context) => [
          for (var i = 0; i < items.length; i++)
            PopupMenuItem(
              value: i,
              child: Row(
                children: [
                  Icon(items[i].icon, size: 20),
                  const SizedBox(width: 12),
                  Flexible(child: Text(items[i].label)),
                ],
              ),
            ),
        ],
      ),
    ];
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Six 48px targets fit a 320px phone with standard page padding.
          // Exceptionally narrow embedded panes can scroll without shrinking
          // the controls or creating two visually unrelated action rows.
          final row = Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: buttons,
          );
          return constraints.maxWidth < 288
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: 288, child: row),
                )
              : row;
        },
      ),
    );
  }

  Widget _button(String label, IconData icon, VoidCallback? onPressed) =>
      IconButton(
        tooltip: label,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: onPressed,
        icon: Icon(icon),
      );
}

final class StudyMenuAction {
  const StudyMenuAction(this.label, this.icon, this.onSelected);

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
}

/// Crossed swords distinguish puzzle solving from passive reading.
final class StudySolveIcon extends StatelessWidget {
  const StudySolveIcon({super.key});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 24,
    child: CustomPaint(
      painter: _CrossedSwordsPainter(
        IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}

final class _CrossedSwordsPainter extends CustomPainter {
  const _CrossedSwordsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final mirrored in [false, true]) {
      canvas.save();
      if (mirrored) {
        canvas.translate(24, 0);
        canvas.scale(-1, 1);
      }
      canvas.drawPath(
        Path()
          ..moveTo(7, 16)
          ..lineTo(17, 6)
          ..lineTo(21, 3)
          ..lineTo(18, 9)
          ..lineTo(9, 18),
        paint,
      );
      canvas.drawLine(const Offset(5, 14), const Offset(11, 20), paint);
      canvas.drawLine(const Offset(7, 18), const Offset(4, 21), paint);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CrossedSwordsPainter oldDelegate) =>
      color != oldDelegate.color;
}
