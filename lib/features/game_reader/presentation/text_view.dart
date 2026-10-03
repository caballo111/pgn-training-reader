import 'package:flutter/material.dart';

import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/content_type.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../application/game_reader_controller.dart';
import '../application/reader_navigation_state.dart';
import 'move_tree_view.dart';
import 'reader_board.dart';
import '../../../shared/presentation/study_layout.dart';
import '../../../shared/presentation/study_navigation_controls.dart';

/// Readable study material. Positions and navigation appear only when the
/// PGN supplies a board position or moves.
final class TextView extends StatefulWidget {
  const TextView({
    required this.content,
    this.readPuzzle = false,
    this.initialState,
    this.onStateChanged,
    super.key,
  });

  final ChessContent content;
  final bool readPuzzle;
  final Map<String, dynamic>? initialState;
  final ValueChanged<Map<String, dynamic>>? onStateChanged;

  @override
  State<TextView> createState() => _TextViewState();
}

final class _TextViewState extends State<TextView> {
  late GameReaderController _controller = GameReaderController(widget.content);

  PuzzleSide _orientation = PuzzleSide.white;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final saved = widget.initialState;
    for (final index in (saved?['path'] as List? ?? const [])) {
      if (index is int) _controller.selectVariation(index);
    }
    _orientation = saved?['orientation'] == 'black'
        ? PuzzleSide.black
        : PuzzleSide.white;
    _scrollController = ScrollController(
      initialScrollOffset: (saved?['scroll'] as num?)?.toDouble() ?? 0,
    );
    _scrollController.addListener(_publishState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _publishState();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _publishState() {
    var choices = widget.content.rootMoves;
    final path = <int>[];
    for (final node in _controller.navigation.path) {
      final index = choices.indexOf(node);
      if (index < 0) break;
      path.add(index);
      choices = node.children;
    }
    widget.onStateChanged?.call({
      'path': path,
      'orientation': _orientation.name,
      'scroll': _scrollController.hasClients ? _scrollController.offset : 0.0,
    });
  }

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
    if (widget.content.contentType != ContentType.text && !widget.readPuzzle) {
      return const Center(child: Text('This content is not text material.'));
    }

    final navigation = _controller.navigation;
    final result = widget.content.result?.trim();
    final details = ListView(
      controller: _scrollController,
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
      controlCount: _hasMoves ? 4 : 0,
      controlTrailingWidth: 48,
      board: ReaderBoard(
        board: _controller.current.forBoard(orientation: _orientation),
        showOrientationControl: false,
      ),
      controls: StudyNavigationControls(
        showNavigation: _hasMoves,
        canPrevious: navigation.canPrevious,
        canNext: navigation.canNext,
        onFirst: _perform(_controller.first),
        onPrevious: _perform(_controller.previous),
        onNext: _perform(_controller.next),
        onLast: _perform(_controller.last),
        onFlip: () => setState(() {
          _orientation = _orientation == PuzzleSide.white
              ? PuzzleSide.black
              : PuzzleSide.white;
          _publishState();
        }),
      ),
      details: details,
    );
  }

  VoidCallback _perform(void Function() action) =>
      () => setState(() {
        action();
        _publishState();
      });

  void _acceptNavigation(ReaderNavigationState navigation) {
    setState(() {
      _controller.first();
      for (final node in navigation.path) {
        final index = _controller.navigation.availableMoves.indexOf(node);
        if (index < 0) return;
        _controller.selectVariation(index);
      }
      _publishState();
    });
  }
}
