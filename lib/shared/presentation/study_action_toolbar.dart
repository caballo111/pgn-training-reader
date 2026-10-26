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
      if (onPreviousBlock != null)
        _button('Previous block', Icons.skip_previous, onPreviousBlock!),
      if (onToggleMode != null)
        IconButton(
          tooltip: solving ? 'Switch to read mode' : 'Switch to solve mode',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: onToggleMode,
          icon: solving
              ? const Icon(Icons.menu_book_outlined)
              : const StudySolveIcon(),
        ),
      if (onReset != null) _button('Reset board', Icons.restart_alt, onReset!),
      if (onAnalyze != null)
        _button('Analyze position', Icons.biotech_outlined, onAnalyze!),
      if (onNextBlock != null)
        _button(
          nextLabel,
          nextLabel == 'Back to book'
              ? Icons.library_books_outlined
              : Icons.skip_next,
          onNextBlock!,
        ),
      if (items.isNotEmpty)
        PopupMenuButton<int>(
          tooltip: 'More board actions',
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          ),
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
    if (buttons.isEmpty) return const SizedBox.shrink();
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
            children: items.isEmpty
                ? buttons
                : [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: buttons.take(buttons.length - 1).toList(),
                      ),
                    ),
                    buttons.last,
                  ],
          );
          final minimumWidth = buttons.length * 48.0;
          return constraints.maxWidth < minimumWidth
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: minimumWidth, child: row),
                )
              : row;
        },
      ),
    );
  }

  Widget _button(String label, IconData icon, VoidCallback onPressed) =>
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

/// Material Symbols Outlined `swords`, scaled from its 960-unit em box into a
/// 24x24 icon box. Glyph geometry © Google LLC, Apache License 2.0; see
/// THIRD_PARTY_NOTICES.md. Source:
/// https://fonts.google.com/icons?selected=Material+Symbols+Outlined:swords
final Path _swordsGlyph = Path()
  ..moveTo(19.05, 21.6)
  ..lineTo(16.125, 18.7)
  ..lineTo(13.925, 20.9)
  ..lineTo(13.225, 20.2)
  ..quadraticBezierTo(12.65, 19.625, 12.65, 18.775)
  ..quadraticBezierTo(12.65, 17.925, 13.225, 17.35)
  ..lineTo(17.45, 13.125)
  ..quadraticBezierTo(18.025, 12.55, 18.875, 12.55)
  ..quadraticBezierTo(19.725, 12.55, 20.3, 13.125)
  ..lineTo(21.0, 13.825)
  ..lineTo(18.8, 16.025)
  ..lineTo(21.7, 18.95)
  ..quadraticBezierTo(22.0, 19.25, 22.0, 19.65)
  ..quadraticBezierTo(22.0, 20.05, 21.7, 20.35)
  ..lineTo(20.45, 21.6)
  ..quadraticBezierTo(20.15, 21.9, 19.75, 21.9)
  ..quadraticBezierTo(19.35, 21.9, 19.05, 21.6)
  ..close()
  ..moveTo(22.0, 5.9)
  ..lineTo(10.65, 17.25)
  ..lineTo(10.775, 17.35)
  ..quadraticBezierTo(11.35, 17.925, 11.35, 18.775)
  ..quadraticBezierTo(11.35, 19.625, 10.775, 20.2)
  ..lineTo(10.075, 20.9)
  ..lineTo(7.875, 18.7)
  ..lineTo(4.95, 21.6)
  ..quadraticBezierTo(4.65, 21.9, 4.25, 21.9)
  ..quadraticBezierTo(3.85, 21.9, 3.55, 21.6)
  ..lineTo(2.3, 20.35)
  ..quadraticBezierTo(2.0, 20.05, 2.0, 19.65)
  ..quadraticBezierTo(2.0, 19.25, 2.3, 18.95)
  ..lineTo(5.2, 16.025)
  ..lineTo(3.0, 13.825)
  ..lineTo(3.7, 13.125)
  ..quadraticBezierTo(4.275, 12.55, 5.125, 12.55)
  ..quadraticBezierTo(5.975, 12.55, 6.55, 13.125)
  ..lineTo(6.65, 13.25)
  ..lineTo(18.0, 1.9)
  ..lineTo(22.0, 1.9)
  ..lineTo(22.0, 5.9)
  ..close()
  ..moveTo(8.35, 9.425)
  ..lineTo(8.95, 8.85)
  ..lineTo(9.525, 8.25)
  ..lineTo(8.95, 8.85)
  ..lineTo(8.35, 9.425)
  ..close()
  ..moveTo(6.95, 10.85)
  ..lineTo(2.0, 5.9)
  ..lineTo(2.0, 1.9)
  ..lineTo(6.0, 1.9)
  ..lineTo(10.95, 6.85)
  ..lineTo(9.525, 8.25)
  ..lineTo(5.175, 3.9)
  ..lineTo(4.0, 3.9)
  ..lineTo(4.0, 5.075)
  ..lineTo(8.35, 9.425)
  ..lineTo(6.95, 10.85)
  ..close()
  ..moveTo(9.25, 15.825)
  ..lineTo(20.0, 5.075)
  ..lineTo(20.0, 3.9)
  ..lineTo(18.825, 3.9)
  ..lineTo(8.075, 14.65)
  ..lineTo(9.25, 15.825)
  ..close()
  ..moveTo(9.25, 15.825)
  ..lineTo(8.65, 15.25)
  ..lineTo(8.075, 14.65)
  ..lineTo(8.65, 15.25)
  ..lineTo(9.25, 15.825)
  ..close();

final class _CrossedSwordsPainter extends CustomPainter {
  const _CrossedSwordsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      _swordsGlyph,
      Paint()
        ..color = color
        ..isAntiAlias = true
        ..style = PaintingStyle.fill,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CrossedSwordsPainter oldDelegate) =>
      color != oldDelegate.color;
}
