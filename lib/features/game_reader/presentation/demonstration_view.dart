import 'package:flutter/material.dart';

import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/content_type.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../application/game_reader_controller.dart';
import '../application/reader_navigation_state.dart';
import 'move_tree_view.dart';
import 'reader_board.dart';

/// Board, navigation controls, and annotations for Demonstration content.
final class DemonstrationView extends StatefulWidget {
  const DemonstrationView({required this.content, super.key});

  final ChessContent content;

  @override
  State<DemonstrationView> createState() => _DemonstrationViewState();
}

final class _DemonstrationViewState extends State<DemonstrationView> {
  late GameReaderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createController(widget.content);
  }

  @override
  void didUpdateWidget(covariant DemonstrationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _controller = _createController(widget.content);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _controller.current;
    final board = current.forBoard(orientation: PuzzleSide.white);
    final navigation = _controller.navigation;

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
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: boardLimit),
                child: ReaderBoard(board: board),
              ),
            ),
            _NavigationControls(
              navigation: navigation,
              onFirst: _perform(_controller.first),
              onPrevious: _perform(_controller.previous),
              onNext: _perform(_controller.next),
              onLast: _perform(_controller.last),
            ),
            if (widget.content.comments.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final comment in widget.content.comments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(comment),
                      ),
                  ],
                ),
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
        );
      },
    );
  }

  GameReaderController _createController(ChessContent content) {
    if (content.contentType != ContentType.demonstration) {
      throw ArgumentError.value(
        content.contentType,
        'content.contentType',
        'DemonstrationView requires Demonstration content.',
      );
    }
    return GameReaderController(content);
  }

  VoidCallback _perform(void Function() action) => () {
    setState(action);
  };

  void _acceptNavigation(ReaderNavigationState navigation) {
    setState(() {
      // Rebuild the controller through its public navigation methods so the
      // same legality and position reconstruction checks remain in force.
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
