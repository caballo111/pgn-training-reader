import 'package:flutter/material.dart';

import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/content_type.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../application/game_reader_controller.dart';
import '../application/reader_navigation_state.dart';
import 'move_tree_view.dart';
import 'reader_board.dart';

/// Readable study material. Positions and navigation appear only when the
/// PGN supplies a board position or moves.
final class TextView extends StatefulWidget {
  const TextView({required this.content, super.key});

  final ChessContent content;

  @override
  State<TextView> createState() => _TextViewState();
}

final class _TextViewState extends State<TextView> {
  late GameReaderController _controller = GameReaderController(widget.content);

  bool get _hasMoves => widget.content.rootMoves.isNotEmpty;
  bool get _hasPosition =>
      widget.content.headers.containsKey('FEN') ||
      widget.content.headers['SetUp'] == '1';

  @override
  void didUpdateWidget(covariant TextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _controller = GameReaderController(widget.content);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.content.contentType != ContentType.text) {
      return const Center(child: Text('This content is not text material.'));
    }

    final title =
        widget.content.headers['X-Title'] ?? widget.content.headers['Event'];
    final navigation = _controller.navigation;
    final hasBoard = _hasMoves || _hasPosition;

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardLimit = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight * 0.52;
        final treeHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight * 0.42).clamp(220.0, 420.0)
            : 320.0;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            if (title != null && title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            if (widget.content.instructionalPlaceholder != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${widget.content.instructionalPlaceholder} is an instructional placeholder. This entry has no playable moves.',
                ),
              ),
            if (widget.content.comments.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final comment in widget.content.comments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(comment),
                      ),
                  ],
                ),
              ),
            if (hasBoard)
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: boardLimit),
                  child: ReaderBoard(
                    board: _controller.current.forBoard(
                      orientation: PuzzleSide.white,
                    ),
                  ),
                ),
              ),
            if (_hasMoves) ...[
              _NavigationControls(
                navigation: navigation,
                onFirst: _perform(_controller.first),
                onPrevious: _perform(_controller.previous),
                onNext: _perform(_controller.next),
                onLast: _perform(_controller.last),
              ),
              SizedBox(
                height: treeHeight,
                child: MoveTreeView(
                  content: widget.content,
                  navigation: navigation,
                  onNavigationChanged: _acceptNavigation,
                ),
              ),
            ],
            if (widget.content.result != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Result: ${widget.content.result}',
                  textAlign: TextAlign.center,
                ),
              ),
            if (widget.content.headers.isNotEmpty)
              ExpansionTile(
                title: const Text('Content details'),
                children: [
                  for (final entry in widget.content.headers.entries)
                    ListTile(
                      dense: true,
                      title: Text(entry.key),
                      subtitle: Text(entry.value),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  VoidCallback _perform(void Function() action) =>
      () => setState(action);

  void _acceptNavigation(ReaderNavigationState navigation) {
    setState(() {
      _controller.first();
      for (final node in navigation.path) {
        final index = _controller.navigation.availableMoves.indexOf(node);
        if (index < 0) return;
        _controller.selectVariation(index);
      }
    });
  }
}

final class _NavigationControls extends StatelessWidget {
  const _NavigationControls({
    required this.navigation,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
  });

  final ReaderNavigationState navigation;
  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLast;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: 'Starting position',
        onPressed: navigation.canPrevious ? onFirst : null,
        icon: const Icon(Icons.first_page),
      ),
      IconButton(
        tooltip: 'Previous move',
        onPressed: navigation.canPrevious ? onPrevious : null,
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        tooltip: 'Next move',
        onPressed: navigation.canNext ? onNext : null,
        icon: const Icon(Icons.chevron_right),
      ),
      IconButton(
        tooltip: 'Last move on main line',
        onPressed: navigation.canNext ? onLast : null,
        icon: const Icon(Icons.last_page),
      ),
    ],
  );
}
