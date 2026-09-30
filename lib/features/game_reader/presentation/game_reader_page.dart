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
    String? meaningfulHeader(String name) {
      final value = content.headers[name]?.trim();
      return value == null || value.isEmpty || value == '?' ? null : value;
    }

    final white = meaningfulHeader('White');
    final black = meaningfulHeader('Black');
    final studyTitle =
        meaningfulHeader('X-Title') ??
        meaningfulHeader('Event') ??
        (white != null && black != null ? '$white vs $black' : null) ??
        (content.rootMoves.isNotEmpty ? 'Game' : 'Study text');
    final title = switch (content.contentType) {
      ContentType.puzzle => 'Puzzle',
      ContentType.unsupported => 'Unsupported content',
      ContentType.text => studyTitle,
    };
    final titleStyle = Theme.of(context).textTheme.headlineSmall!;
    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: titleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: MediaQuery.sizeOf(context).width - 32);
    final titleHeight = titlePainter.height + 24;
    titlePainter.dispose();
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(titleHeight),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Text(title, style: titleStyle),
            ),
          ),
        ),
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
          if (widget.onClassificationOverride != null)
            PopupMenuButton<ContentType>(
              tooltip: 'Change content type',
              enabled: !_saving,
              onSelected: _override,
              itemBuilder: (_) => [
                for (final type in const [ContentType.text, ContentType.puzzle])
                  CheckedPopupMenuItem(
                    value: type,
                    checked: content.contentType == type,
                    child: Text(
                      type == ContentType.text ? 'Study text / game' : 'Puzzle',
                    ),
                  ),
              ],
              icon: const Icon(Icons.more_vert),
            ),
        ],
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
