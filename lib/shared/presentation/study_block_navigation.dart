import 'package:flutter/material.dart';

/// Moves to the preceding block in a book.
final class StudyPreviousBlockButton extends StatelessWidget {
  const StudyPreviousBlockButton({
    required this.onPressed,
    this.showLabel = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    if (showLabel) {
      return TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        icon: const Icon(Icons.skip_previous),
        label: const Text('Previous block'),
      );
    }
    return IconButton(
      tooltip: 'Previous block',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: onPressed,
      icon: const Icon(Icons.skip_previous),
    );
  }
}

/// Moves to the next block in a book, or returns to the book when [label]
/// says "Back to book".
final class StudyNextBlockButton extends StatelessWidget {
  const StudyNextBlockButton({
    required this.onPressed,
    this.label = 'Next block',
    this.iconOnly = false,
    this.primary = true,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool iconOnly;
  final bool primary;

  bool get _returnsToBook => label == 'Back to book';

  IconData get _icon =>
      _returnsToBook ? Icons.menu_book_outlined : Icons.skip_next;

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return IconButton(
        tooltip: label,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: onPressed,
        icon: Icon(_icon),
      );
    }

    final style = primary
        ? FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          )
        : TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          );
    final child = Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
    if (_returnsToBook) {
      return primary
          ? FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: Icon(_icon),
              label: child,
            )
          : TextButton.icon(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: Icon(_icon),
              label: child,
            );
    }
    return primary
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : TextButton(onPressed: onPressed, style: style, child: child);
  }
}
