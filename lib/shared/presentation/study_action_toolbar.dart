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
///
/// Block navigation is permanently anchored: previous on the leading edge and
/// next on the trailing edge. The center reserves up to two contextual actions,
/// which fade and crossfade in place without moving either navigation control.
/// Every other secondary action lives in the overflow menu.
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
    final centerCandidates = <_CenterAction>[
      if (onToggleMode != null)
        _CenterAction(
          label: solving ? 'Switch to read mode' : 'Switch to solve mode',
          icon: solving
              ? const Icon(Icons.menu_book_outlined)
              : const StudySolveIcon(),
          menuIcon: solving
              ? Icons.menu_book_outlined
              : Icons.extension_outlined,
          onPressed: onToggleMode!,
        ),
      if (onReset != null)
        _CenterAction(
          label: 'Reset board',
          icon: const Icon(Icons.restart_alt),
          menuIcon: Icons.restart_alt,
          onPressed: onReset!,
        ),
      if (onAnalyze != null)
        _CenterAction(
          label: 'Analyze position',
          icon: const Icon(Icons.biotech_outlined),
          menuIcon: Icons.biotech_outlined,
          onPressed: onAnalyze!,
        ),
    ];
    final secondary = <StudyMenuAction>[
      if (onFlip != null)
        StudyMenuAction(
          'Flip board',
          Icons.flip_camera_android_outlined,
          onFlip!,
        ),
      if (onToggleBoardSize != null)
        StudyMenuAction(
          compactBoard ? 'Expand board' : 'Compact board',
          compactBoard ? Icons.expand : Icons.compress,
          onToggleBoardSize!,
        ),
      ...extraMenuItems,
    ];
    if (onPreviousBlock == null &&
        onNextBlock == null &&
        centerCandidates.isEmpty &&
        secondary.isEmpty) {
      return const SizedBox.shrink();
    }
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centerCount = _centerSlotsThatFit(
            width: constraints.maxWidth,
            candidates: centerCandidates.length,
            secondaryCount: secondary.length,
          );
          final overflowItems = <StudyMenuAction>[
            for (final action in centerCandidates.skip(centerCount))
              StudyMenuAction(action.label, action.menuIcon, action.onPressed),
            ...secondary,
          ];
          return Stack(
            children: [
              Row(
                children: [
                  _AnchoredButton(
                    tooltip: 'Previous block',
                    icon: Icons.skip_previous,
                    onPressed: onPreviousBlock,
                  ),
                  const Spacer(),
                  _AnchoredButton(
                    tooltip: nextLabel,
                    icon: nextLabel == 'Back to book'
                        ? Icons.library_books_outlined
                        : Icons.skip_next,
                    onPressed: onNextBlock,
                  ),
                ],
              ),
              Center(
                child: _ContextualCluster(
                  actions: centerCandidates.take(centerCount).toList(),
                ),
              ),
              if (overflowItems.isNotEmpty)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 48,
                  child: Center(child: _OverflowMenu(items: overflowItems)),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Keeps up to two actions in the centered cluster. On panes too narrow for
  /// the cluster to clear the overflow and Next, the extra actions fall back to
  /// the overflow menu instead of overlapping the anchors.
  static int _centerSlotsThatFit({
    required double width,
    required int candidates,
    required int secondaryCount,
  }) {
    for (var slots = candidates < 2 ? candidates : 2; slots >= 0; slots--) {
      final overflow = candidates - slots + secondaryCount;
      if (overflow == 0 || width >= 192 + 48.0 * slots) return slots;
    }
    return 0;
  }
}

/// A navigation control that keeps its slot even when the action is disabled.
final class _AnchoredButton extends StatelessWidget {
  const _AnchoredButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    onPressed: onPressed,
    icon: Icon(icon),
  );
}

/// One candidate for the toolbar's centered contextual cluster.
final class _CenterAction {
  const _CenterAction({
    required this.label,
    required this.icon,
    required this.menuIcon,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final IconData menuIcon;
  final VoidCallback onPressed;
}

/// The centered contextual cluster: up to two actions that fade and rise into
/// place when the surface appears, then crossfade slot by slot whenever the
/// page swaps an action. The cluster width follows the action count; the
/// anchored navigation controls never move.
final class _ContextualCluster extends StatefulWidget {
  const _ContextualCluster({required this.actions});

  final List<_CenterAction> actions;

  @override
  State<_ContextualCluster> createState() => _ContextualClusterState();
}

final class _ContextualClusterState extends State<_ContextualCluster> {
  static const _entrance = Duration(milliseconds: 220);
  static const _crossfade = Duration(milliseconds: 180);

  var _entered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _entered = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final entrance = reduceMotion ? Duration.zero : _entrance;
    return AnimatedSlide(
      duration: entrance,
      curve: Curves.easeOutCubic,
      offset: _entered ? Offset.zero : const Offset(0, 0.18),
      child: AnimatedOpacity(
        duration: entrance,
        curve: Curves.easeOut,
        opacity: _entered ? 1 : 0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in widget.actions)
              SizedBox.square(
                dimension: 48,
                child: AnimatedSwitcher(
                  duration: reduceMotion ? Duration.zero : _crossfade,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: KeyedSubtree(
                    key: ValueKey(action.label),
                    child: IconButton(
                      tooltip: action.label,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: action.onPressed,
                      icon: action.icon,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.items});

  final List<StudyMenuAction> items;

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    tooltip: 'More board actions',
    style: const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
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
