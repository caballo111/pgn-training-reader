import 'package:flutter/material.dart';

/// Shared orientation action for study and puzzle boards.
class FlipBoardButton extends StatelessWidget {
  const FlipBoardButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Flip board',
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    onPressed: onPressed,
    icon: const Icon(Icons.flip_camera_android_outlined),
  );
}
