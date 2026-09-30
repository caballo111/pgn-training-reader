import 'package:flutter/material.dart';

import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/content_type.dart';
import 'demonstration_view.dart';
import 'instruction_view.dart';

/// Builds the separately implemented puzzle-solving experience.
typedef PuzzleViewBuilder = Widget Function(
  BuildContext context,
  ChessContent puzzle,
);

/// Selects the reader presentation appropriate for one parsed PGN block.
final class GameReaderPage extends StatelessWidget {
  const GameReaderPage({
    required this.content,
    this.puzzleViewBuilder,
    super.key,
  });

  final ChessContent content;

  /// Injected puzzle presentation; no solution-bearing content is rendered
  /// when a puzzle view has not been supplied by the caller.
  final PuzzleViewBuilder? puzzleViewBuilder;

  @override
  Widget build(BuildContext context) {
    final title = switch (content.contentType) {
      ContentType.puzzle => 'Puzzle',
      ContentType.unsupported => 'Unsupported content',
      ContentType.instruction || ContentType.demonstration =>
        content.headers['X-Title'] ?? content.headers['Event'] ?? 'PGN Reader',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title.isEmpty ? 'PGN Reader' : title)),
      body: switch (content.contentType) {
        ContentType.instruction => InstructionView(content: content),
        ContentType.demonstration => DemonstrationView(content: content),
        ContentType.puzzle =>
          puzzleViewBuilder?.call(context, content) ??
              const _UnavailableMode(
                message: 'Puzzle practice is not available yet.',
              ),
        ContentType.unsupported => const _UnavailableMode(
          message: 'This content type is not supported for display.',
        ),
      },
    );
  }
}

final class _UnavailableMode extends StatelessWidget {
  const _UnavailableMode({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
