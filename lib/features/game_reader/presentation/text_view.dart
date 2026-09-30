import 'package:flutter/material.dart';

import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/content_type.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../application/game_reader_controller.dart';
import '../application/reader_navigation_state.dart';
import 'move_tree_view.dart';
import 'reader_board.dart';
import '../../../shared/presentation/study_layout.dart';
import '../../../shared/presentation/flip_board_button.dart';

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

  PuzzleSide _orientation = PuzzleSide.white;

  bool get _hasMoves => widget.content.rootMoves.isNotEmpty;
  bool get _hasPosition =>
      widget.content.headers.containsKey('FEN') ||
      widget.content.headers['SetUp'] == '1';

  @override
  void didUpdateWidget(covariant TextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _controller = GameReaderController(widget.content);
      _orientation = PuzzleSide.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.content.contentType != ContentType.text) {
      return const Center(child: Text('This content is not text material.'));
    }

    final navigation = _controller.navigation;
    final result = widget.content.result?.trim();
    final details = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        if (!_hasMoves &&
            !_hasPosition &&
            widget.content.comments.every((comment) => comment.trim().isEmpty))
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No study content available.'),
          ),
        for (final comment in widget.content.comments)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(comment),
          ),
        if (_hasMoves)
          MoveTreeView(
            content: widget.content,
            navigation: navigation,
            onNavigationChanged: _acceptNavigation,
            shrinkWrap: true,
            scrollable: false,
          ),
        if (const {'1-0', '0-1', '1/2-1/2'}.contains(result))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Result: $result'),
          ),
        if (widget.content.headers.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Game Info'),
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
    if (!_hasMoves && !_hasPosition) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: details,
        ),
      );
    }
    return StudyLayout(
      board: ReaderBoard(
        board: _controller.current.forBoard(orientation: _orientation),
        showOrientationControl: false,
      ),
      controls: _NavigationControls(
        navigation: navigation,
        hasMoves: _hasMoves,
        onFirst: _perform(_controller.first),
        onPrevious: _perform(_controller.previous),
        onNext: _perform(_controller.next),
        onLast: _perform(_controller.last),
        onFlip: () => setState(() {
          _orientation = _orientation == PuzzleSide.white
              ? PuzzleSide.black
              : PuzzleSide.white;
        }),
      ),
      details: details,
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
    required this.onFlip,
    required this.hasMoves,
  });

  final ReaderNavigationState navigation;
  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLast;
  final VoidCallback onFlip;
  final bool hasMoves;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      if (hasMoves) ...[
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
      FlipBoardButton(
        key: const ValueKey('reader-board-orientation'),
        onPressed: onFlip,
      ),
    ],
  );
}
