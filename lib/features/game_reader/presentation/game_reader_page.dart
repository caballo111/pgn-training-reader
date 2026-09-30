import 'package:flutter/material.dart';

import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/content_type.dart';
import 'text_view.dart';

/// Builds the separately implemented puzzle-solving experience.
typedef PuzzleViewBuilder = Widget Function(
  BuildContext context,
  ChessContent puzzle,
);

/// Selects the reader presentation appropriate for one parsed PGN block.
final class GameReaderPage extends StatefulWidget {
  const GameReaderPage({
    required this.content,
    this.puzzleViewBuilder,
    this.onClassificationOverride,
    this.showBlockNavigation = false,
    this.onNextBlock,
    this.onPreviousBlock,
    super.key,
  });

  final ChessContent content;
  final bool showBlockNavigation;
  final VoidCallback? onNextBlock;
  final VoidCallback? onPreviousBlock;

  /// Injected puzzle presentation; no solution-bearing content is rendered
  /// when a puzzle view has not been supplied by the caller.
  final PuzzleViewBuilder? puzzleViewBuilder;

  final Future<void> Function(ContentType)? onClassificationOverride;

  @override
  State<GameReaderPage> createState() => _GameReaderPageState();
}

final class _GameReaderPageState extends State<GameReaderPage> {
  late ChessContent content = widget.content;
  bool _saving = false;

  @override
  void didUpdateWidget(covariant GameReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      content = widget.content;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (content.contentType) {
      ContentType.puzzle => 'Puzzle',
      ContentType.unsupported => 'Unsupported content',
      ContentType.text =>
        content.headers['X-Title'] ?? content.headers['Event'] ?? 'PGN Reader',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(title.isEmpty ? 'PGN Reader' : title),
        actions: [
          if (widget.showBlockNavigation)
            IconButton(
              tooltip: 'Previous PGN block',
              onPressed: _saving ? null : widget.onPreviousBlock,
              icon: const Icon(Icons.skip_previous),
            ),
          if (widget.showBlockNavigation)
            IconButton(
              tooltip: 'Next PGN block',
              onPressed: _saving ? null : widget.onNextBlock,
              icon: const Icon(Icons.skip_next),
            ),
        ],
        bottom:
            content.inferredClassification ||
                widget.onClassificationOverride != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Wrap(
                  children: [
                    const SizedBox(width: 16),
                    Text(
                      content.inferredClassification
                          ? 'Inferred classification: '
                          : 'Classification: ',
                    ),
                    if (widget.onClassificationOverride != null)
                      DropdownButton<ContentType>(
                        value: content.contentType == ContentType.unsupported
                            ? null
                            : content.contentType,
                        hint: Text(content.contentType.toDatabaseValue()),
                        onChanged: _saving ? null : _override,
                        items: [
                          for (final type in const [
                            ContentType.puzzle,
                            ContentType.text,
                          ])
                            DropdownMenuItem(
                              value: type,
                              child: Text(type.toDatabaseValue()),
                            ),
                        ],
                      )
                    else
                      Text(content.contentType.toDatabaseValue()),
                  ],
                ),
              )
            : null,
      ),
      body: switch (content.contentType) {
        ContentType.text => TextView(content: content),
        ContentType.puzzle =>
          widget.puzzleViewBuilder?.call(context, content) ??
              const _UnavailableMode(
                message: 'Puzzle practice is not available yet.',
              ),
        ContentType.unsupported => const _UnavailableMode(
          message: 'This content type is not supported for display.',
        ),
      },
    );
  }

  Future<void> _override(ContentType? type) async {
    if (type == null) return;
    setState(() => _saving = true);
    try {
      await widget.onClassificationOverride!(type);
      if (mounted) setState(() => content = content.withContentType(type));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Classification could not be saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
