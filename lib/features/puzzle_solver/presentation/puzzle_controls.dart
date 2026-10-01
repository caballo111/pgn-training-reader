import 'package:flutter/material.dart';

/// Which set of puzzle actions is available to the current presentation.
enum PuzzleControlsMode { active, review }

/// Actions for an active puzzle and its solution review.
///
/// The control surface delegates transitions to its owner. It contains no
/// attempt state machine and never accepts or exposes solution content.
final class PuzzleControls extends StatelessWidget {
  const PuzzleControls({
    required this.mode,
    required this.onPause,
    required this.onShowSolution,
    required this.onSkip,
    this.enabled = true,
    this.onRetry,
    super.key,
  });

  final PuzzleControlsMode mode;
  final VoidCallback onPause;
  final VoidCallback onShowSolution;
  final VoidCallback onSkip;
  final bool enabled;

  /// Starts a fresh attempt from review; null hides retry when it is unavailable.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => switch (mode) {
    PuzzleControlsMode.active => _ActivePuzzleControls(
      onPause: onPause,
      onShowSolution: onShowSolution,
      onSkip: onSkip,
      enabled: enabled,
    ),
    PuzzleControlsMode.review => _ReviewPuzzleControls(onRetry: onRetry),
  };
}

final class _ActivePuzzleControls extends StatelessWidget {
  const _ActivePuzzleControls({
    required this.onPause,
    required this.onShowSolution,
    required this.onSkip,
    required this.enabled,
  });

  final VoidCallback onPause;
  final VoidCallback onShowSolution;
  final VoidCallback onSkip;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: enabled ? onPause : null,
        icon: const Icon(Icons.pause),
        label: const Text('Pause'),
      ),
      TextButton(
        onPressed: enabled ? onShowSolution : null,
        child: const Text('Show solution'),
      ),
      TextButton(onPressed: enabled ? onSkip : null, child: const Text('Skip')),
    ],
  );
}

final class _ReviewPuzzleControls extends StatelessWidget {
  const _ReviewPuzzleControls({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Solution review'),
      if (onRetry != null) ...[
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.replay),
          label: const Text('Try again'),
        ),
        const Text(
          'This starts a new attempt. Your previous result stays in history.',
          textAlign: TextAlign.center,
        ),
      ],
    ],
  );
}
