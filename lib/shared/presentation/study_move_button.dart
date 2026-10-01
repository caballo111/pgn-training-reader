import 'package:flutter/material.dart';

/// A selectable move token shared by the reader tree and solution review.
class StudyMoveButton extends StatelessWidget {
  const StudyMoveButton({
    required this.label,
    required this.onPressed,
    this.prefix,
    this.selected = false,
    this.annotation,
    super.key,
  });

  final String label;
  final String? prefix;
  final String? annotation;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label:
        '${prefix ?? ''}$label${annotation == null ? '' : ', annotation $annotation'}'
        '${selected ? ', current position' : ''}',
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prefix != null)
            Text(prefix!, style: Theme.of(context).textTheme.bodySmall),
          Text(label),
          if (annotation != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Text(annotation!),
            ),
        ],
      ),
    ),
  );
}
