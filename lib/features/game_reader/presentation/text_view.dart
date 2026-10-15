import 'dart:async';

import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/material.dart';

import '../../../domain/analysis/analysis_engine.dart';
import '../../../domain/analysis/exploration_repository.dart';
import '../../../domain/analysis/exploration_session.dart';
import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/content_type.dart';
import '../../../domain/chess_content/move_node.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../../analysis/presentation/exploration_workspace.dart';
import '../application/game_reader_controller.dart';
import '../application/reader_navigation_state.dart';
import 'move_tree_view.dart';
import 'reader_board.dart';
import '../../../shared/presentation/study_action_toolbar.dart';
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
    this.explorationScopeId,
    this.explorationRepository,
    this.analysisEngineFactory,
    this.explorationEnabled = true,
    this.persistenceMessage,
    this.blockActions,
    super.key,
  });

  final ChessContent content;
  final bool readPuzzle;
  final Map<String, dynamic>? initialState;
  final ValueChanged<Map<String, dynamic>>? onStateChanged;
  final String? explorationScopeId;
  final ExplorationRepository? explorationRepository;
  final AnalysisEngineFactory? analysisEngineFactory;
  final bool explorationEnabled;
  final String? persistenceMessage;
  final StudyBlockActions? blockActions;

  @override
  TextViewState createState() => TextViewState();
}

/// Reader state is public so containing pages can save an open exploration
/// before replacing or leaving the reader surface.
final class TextViewState extends State<TextView> {
  late GameReaderController _controller = GameReaderController(widget.content);

  PuzzleSide _orientation = PuzzleSide.white;
  bool _compactBoard = false;
  late final ScrollController _scrollController;
  final GlobalKey<ExplorationWorkspaceState> _workspaceKey =
      GlobalKey<ExplorationWorkspaceState>();
  String _ephemeralScopeId = _newEphemeralScopeId();
  ExplorationOrigin? _workspaceOrigin;
  double _scrollOffsetBeforeExploration = 0;
  Future<void>? _returningFromExploration;
  Future<void>? _workspacePreparation;
  ChessContent? _workspaceContentSnapshot;
  ReaderNavigationState? _workspaceNavigationSnapshot;
  PuzzleSide? _workspaceOrientation;
  ExplorationRepository? _workspaceRepository;
  AnalysisEngineFactory? _workspaceEngineFactory;
  bool _contentReplacementPending = false;
  bool _workspaceContentSuperseded = false;
  bool _openingWorkspace = false;
  bool _workspaceEngineWasEnabled = false;
  int _contentGeneration = 0;

  static int _nextEphemeralScope = 0;

  static String _newEphemeralScopeId() =>
      'reader-session-${DateTime.now().microsecondsSinceEpoch}-${_nextEphemeralScope++}';

  bool get isExploring => _workspaceOrigin != null;

  /// Saves the active personal tree before this reading surface is replaced.
  /// A workspace persistence failure propagates so callers can block exit.
  Future<void> prepareToLeave() async {
    _publishState();
    await _prepareWorkspace();
  }

  Future<void> _prepareWorkspace() {
    final activePreparation = _workspacePreparation;
    if (activePreparation != null) return activePreparation;
    final operation =
        _workspaceKey.currentState?.prepareToLeave() ?? Future<void>.value();
    _workspacePreparation = operation;
    return operation.whenComplete(() {
      if (identical(_workspacePreparation, operation)) {
        _workspacePreparation = null;
      }
    });
  }

  /// Returns to authored reading after the workspace has been safely saved.
  Future<void> returnFromExploration() {
    final activeReturn = _returningFromExploration;
    if (activeReturn != null) return activeReturn;
    final operation = _returnFromExploration();
    _returningFromExploration = operation;
    return operation.whenComplete(() {
      if (identical(_returningFromExploration, operation)) {
        _returningFromExploration = null;
      }
    });
  }

  Future<void> _returnFromExploration() async {
    if (_workspaceOrigin == null) return;
    await _prepareWorkspace();
    if (mounted) {
      _onWorkspaceReturn();
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) _publishState();
    }
  }

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
      if (mounted) {
        _publishState();
      }
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
      'scroll': _workspaceOrigin != null
          ? _scrollOffsetBeforeExploration
          : _scrollController.hasClients
          ? _scrollController.offset
          : 0.0,
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
      final generation = ++_contentGeneration;
      _controller = GameReaderController(widget.content);
      _orientation = PuzzleSide.white;
      _ephemeralScopeId = _newEphemeralScopeId();
      _scrollOffsetBeforeExploration = 0;
      if (_workspaceOrigin != null) {
        _workspaceContentSuperseded = true;
        _contentReplacementPending = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_saveWorkspaceBeforeContentReplacement(generation));
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_scrollController.hasClients) _scrollController.jumpTo(0);
          _publishState();
        });
      }
    }
  }

  Future<void> _saveWorkspaceBeforeContentReplacement(int generation) async {
    try {
      await _prepareWorkspace();
    } catch (_) {
      if (!mounted || generation != _contentGeneration) return;
      setState(() => _contentReplacementPending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Exploration could not be saved. Retry before returning to the new reading.',
          ),
        ),
      );
      return;
    }
    if (!mounted || generation != _contentGeneration) return;
    _onWorkspaceReturn();
  }

  @override
  Widget build(BuildContext context) {
    final origin = _workspaceOrigin;
    if (origin != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            final messenger = ScaffoldMessenger.of(context);
            unawaited(
              returnFromExploration().catchError((Object _) {
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Exploration could not be saved. Retry before returning.',
                      ),
                    ),
                  );
                }
              }),
            );
          }
        },
        child: Stack(
          children: [
            AbsorbPointer(
              absorbing: _contentReplacementPending,
              child: ExplorationWorkspace(
                key: _workspaceKey,
                origin: origin,
                repository: _workspaceRepository,
                engineFactory: _workspaceEngineFactory,
                engineWasEnabled: _workspaceEngineWasEnabled,
                persistenceMessage: widget.persistenceMessage,
                orientation: _workspaceOrientation ?? _orientation,
                bookContext: _bookContext,
                onReturn: _onWorkspaceReturn,
                returnLabel: 'Return to reading',
              ),
            ),
            if (_contentReplacementPending)
              const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(
                  semanticsLabel: 'Saving exploration before content changes',
                ),
              ),
          ],
        ),
      );
    }
    if (widget.content.contentType != ContentType.text && !widget.readPuzzle) {
      return const Center(child: Text('This content is not text material.'));
    }

    final navigation = _controller.navigation;
    final result = widget.content.result?.trim();
    final details = ListView(
      key: const ValueKey('reader-details'),
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
      return SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: details,
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: StudyActionToolbar(
                  onPreviousBlock: widget.blockActions?.onPrevious,
                  onToggleMode: widget.blockActions?.onToggleMode,
                  solving: widget.blockActions?.solving ?? false,
                  onNextBlock: widget.blockActions?.onNext,
                  nextLabel: widget.blockActions?.nextLabel ?? 'Next block',
                  extraMenuItems:
                      widget.blockActions?.extraMenuItems ?? const [],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return AbsorbPointer(
      absorbing: _openingWorkspace,
      child: StudyLayout(
        controlCount: _hasMoves ? 4 : 0,
        controlTrailingWidth: 0,
        compactBoard: _compactBoard,
        board: ReaderBoard(
          board: _controller.current.forBoard(orientation: _orientation),
          showOrientationControl: false,
        ),
        controls: Row(
          children: [
            Expanded(
              child: StudyNavigationControls(
                showNavigation: _hasMoves,
                canPrevious: navigation.canPrevious,
                canNext: navigation.canNext,
                onFirst: _perform(_controller.first),
                onPrevious: _perform(_controller.previous),
                onNext: _perform(_controller.next),
                onLast: _perform(_controller.last),
                onFlip: _flipBoard,
                showFlip: false,
              ),
            ),
          ],
        ),
        actions: StudyActionToolbar(
          onPreviousBlock: widget.blockActions?.onPrevious,
          onToggleMode: widget.blockActions?.onToggleMode,
          solving: widget.blockActions?.solving ?? false,
          onReset: (_hasMoves || _hasPosition) ? _resetBoard : null,
          onAnalyze: _canExplore ? _openExploration : null,
          onNextBlock: widget.blockActions?.onNext,
          nextLabel: widget.blockActions?.nextLabel ?? 'Next block',
          onFlip: _flipBoard,
          onToggleBoardSize: _toggleBoardSize,
          compactBoard: _compactBoard,
          extraMenuItems: widget.blockActions?.extraMenuItems ?? const [],
        ),
        details: details,
      ),
    );
  }

  bool get _canExplore =>
      widget.explorationEnabled && (_hasMoves || _hasPosition);

  void _flipBoard() {
    if (_openingWorkspace) return;
    setState(() {
      _orientation = _orientation == PuzzleSide.white
          ? PuzzleSide.black
          : PuzzleSide.white;
      _publishState();
    });
  }

  void _resetBoard() {
    if (_openingWorkspace) return;
    setState(() {
      _controller.first();
      _publishState();
    });
  }

  void _toggleBoardSize() {
    if (_openingWorkspace) return;
    setState(() => _compactBoard = !_compactBoard);
  }

  List<int> _pathIndices(
    ChessContent content,
    ReaderNavigationState navigation,
  ) {
    var choices = content.rootMoves;
    final result = <int>[];
    for (final node in navigation.path) {
      final index = choices.indexOf(node);
      if (index < 0) break;
      result.add(index);
      choices = node.children;
    }
    return result;
  }

  ExplorationOrigin _originForPosition(
    ChessContent content,
    ReaderNavigationState navigation,
  ) {
    final path = navigation.path;
    final node = path.isEmpty ? null : path.last;
    final authoredPath = _pathIndices(content, navigation);
    final label = node == null
        ? 'Starting position'
        : '${_prefixBeforeMove(content.startingFen, path)}${node.san}';
    return ExplorationOrigin(
      scopeId: widget.explorationScopeId ?? _ephemeralScopeId,
      startingFen: content.startingFen,
      authoredPath: authoredPath,
      authoredMoves: path.map((move) => move.uci).toList(),
      label: label,
    );
  }

  String _prefixBeforeMove(String startingFen, List<MoveNode> path) {
    var position = chess.Chess.fromSetup(chess.Setup.parseFen(startingFen));
    for (final node in path.take(path.length - 1)) {
      final move = chess.Move.parse(node.uci);
      if (move == null || !position.isLegal(move)) break;
      position = position.play(move) as chess.Chess;
    }
    final fields = position.fen.split(' ');
    final moveNumber = fields.length >= 6 ? int.tryParse(fields[5]) ?? 1 : 1;
    final sidePrefix = position.turn == chess.Side.black ? '...' : '.';
    return '$moveNumber$sidePrefix ';
  }

  void _openExploration() {
    if (!_canExplore || _workspaceOrigin != null || _openingWorkspace) return;
    final contentAtTap = widget.content;
    final scopeAtTap = widget.explorationScopeId;
    final repositoryAtTap = widget.explorationRepository;
    final engineFactoryAtTap = widget.analysisEngineFactory;
    final navigationAtTap = _controller.navigation;
    final originAtTap = _originForPosition(contentAtTap, navigationAtTap);
    final orientationAtTap = _orientation;
    final contentGenerationAtTap = _contentGeneration;
    _publishState();
    _scrollOffsetBeforeExploration = _scrollController.hasClients
        ? _scrollController.offset
        : 0;
    _openingWorkspace = true;
    if (!mounted ||
        contentGenerationAtTap != _contentGeneration ||
        contentAtTap != widget.content ||
        scopeAtTap != widget.explorationScopeId ||
        !identical(repositoryAtTap, widget.explorationRepository) ||
        !identical(engineFactoryAtTap, widget.analysisEngineFactory)) {
      _openingWorkspace = false;
      return;
    }
    setState(() {
      _workspaceOrigin = originAtTap;
      _workspaceContentSnapshot = contentAtTap;
      _workspaceNavigationSnapshot = navigationAtTap;
      _workspaceOrientation = orientationAtTap;
      _workspaceRepository = repositoryAtTap;
      _workspaceEngineFactory = engineFactoryAtTap;
      _workspaceEngineWasEnabled = false;
      _workspaceContentSuperseded = false;
      _contentReplacementPending = false;
    });
    _openingWorkspace = false;
  }

  Widget get _bookContext {
    if (_workspaceContentSuperseded) {
      return const Text(
        'This reading source changed. Return to reading to continue.',
      );
    }
    final contextContent = _workspaceContentSnapshot ?? widget.content;
    final contextNavigation =
        _workspaceNavigationSnapshot ?? _controller.navigation;
    final comments = <String>[
      ...contextContent.comments,
      for (final move in contextNavigation.path) ...[
        ...move.startingComments,
        ...move.comments,
      ],
    ].where((comment) => comment.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comments.isNotEmpty)
          for (final comment in comments)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(comment),
            ),
        if (contextContent.rootMoves.isNotEmpty)
          MoveTreeView(
            content: contextContent,
            navigation: contextNavigation,
            onNavigationChanged: _selectAuthoredPosition,
            shrinkWrap: true,
            scrollable: false,
          ),
        if (comments.isEmpty && contextContent.rootMoves.isEmpty)
          const Text('No authored notes for this position.'),
      ],
    );
  }

  Future<void> _selectAuthoredPosition(ReaderNavigationState navigation) async {
    if (_workspaceContentSuperseded) return;
    try {
      await _prepareWorkspace();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Exploration could not be saved. Retry before returning.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted || _workspaceContentSuperseded) return;
    _setNavigation(navigation);
    _onWorkspaceReturn();
  }

  void _setNavigation(ReaderNavigationState navigation) {
    _controller.first();
    for (final node in navigation.path) {
      final index = _controller.navigation.availableMoves.indexOf(node);
      if (index < 0) return;
      _controller.selectVariation(index);
    }
    _publishState();
  }

  void _onWorkspaceReturn() {
    if (!mounted || _workspaceOrigin == null) return;
    setState(() {
      _workspaceOrigin = null;
      _workspaceContentSnapshot = null;
      _workspaceNavigationSnapshot = null;
      _workspaceOrientation = null;
      _workspaceRepository = null;
      _workspaceEngineFactory = null;
      _workspaceEngineWasEnabled = false;
      _contentReplacementPending = false;
      _workspaceContentSuperseded = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(_scrollOffsetBeforeExploration.clamp(0, max));
      }
      _publishState();
    });
  }

  VoidCallback _perform(void Function() action) => () {
    if (_openingWorkspace) return;
    setState(() {
      action();
      _publishState();
    });
  };

  void _acceptNavigation(ReaderNavigationState navigation) {
    if (_openingWorkspace) return;
    setState(() {
      _setNavigation(navigation);
      _publishState();
    });
  }
}
