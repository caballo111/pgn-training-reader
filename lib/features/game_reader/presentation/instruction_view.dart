import 'package:flutter/material.dart';

import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/content_type.dart';
import '../application/game_reader_controller.dart';
import '../application/reader_navigation_state.dart';
import 'move_tree_view.dart';
import 'reader_board.dart';

/// Presents an Instruction block as annotated study material.
///
/// This view only receives immutable chess content and owns local reader
/// navigation. It has no training repository or attempt service dependency,
/// so opening and navigating an instruction cannot create or change a puzzle
/// attempt.
final class InstructionView extends StatefulWidget {
  const InstructionView({required this.content, super.key});

  final ChessContent content;

  @override
  State<InstructionView> createState() => _InstructionViewState();
}

final class _InstructionViewState extends State<InstructionView> {
  late ReaderNavigationState _navigation = ReaderNavigationState.initial(
    widget.content,
  );

  @override
  void didUpdateWidget(covariant InstructionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _navigation = ReaderNavigationState.initial(widget.content);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.content.contentType != ContentType.instruction) {
      return const Center(child: Text('This content is not an instruction.'));
    }

    final reader = _readerAtNavigation();
    final title =
        widget.content.headers['X-Title'] ??
        widget.content.headers['Event'] ??
        'Instruction';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Instruction'),
          ),
          if (widget.content.instructionalPlaceholder != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${widget.content.instructionalPlaceholder} is an instructional placeholder. This entry has no playable moves.',
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
          if (widget.content.comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ReaderBoard(
              board: reader.current.forBoard(
                orientation: reader.current.sideToMove,
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              IconButton(
                tooltip: 'First position',
                onPressed: _navigation.canFirst
                    ? () => _move(_navigation.first())
                    : null,
                icon: const Icon(Icons.first_page),
              ),
              IconButton(
                tooltip: 'Previous move',
                onPressed: _navigation.canPrevious
                    ? () => _move(_navigation.previous())
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Next move',
                onPressed: _navigation.canNext
                    ? () => _move(_navigation.next())
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                tooltip: 'Last position',
                onPressed: _navigation.canFirst
                    ? () => _move(_navigation.last())
                    : null,
                icon: const Icon(Icons.last_page),
              ),
            ],
          ),
          if (widget.content.result != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Result: ${widget.content.result}',
                textAlign: TextAlign.center,
              ),
            ),
          MoveTreeView(
            content: widget.content,
            navigation: _navigation,
            onNavigationChanged: _move,
            shrinkWrap: true,
            scrollable: false,
          ),
        ],
      ),
    );
  }

  void _move(ReaderNavigationState navigation) {
    setState(() => _navigation = navigation);
  }

  GameReaderController _readerAtNavigation() {
    final reader = GameReaderController(widget.content);
    var moves = widget.content.rootMoves;
    for (final node in _navigation.path) {
      final index = moves.indexOf(node);
      if (index < 0) break;
      reader.selectVariation(index);
      moves = node.children;
    }
    return reader;
  }
}
