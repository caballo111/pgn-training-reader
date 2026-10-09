import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/analysis/exploration_repository.dart';
import '../../../domain/analysis/exploration_session.dart';
import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/content_type.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../../analysis/presentation/analysis_panel.dart';
import '../../analysis/presentation/exploration_workspace.dart';
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
    this.explorationScopeId,
    this.explorationRepository,
    this.analysisEngineFactory,
    super.key,
  });

  final ChessContent content;
  final bool readPuzzle;
  final Map<String, dynamic>? initialState;
  final ValueChanged<Map<String, dynamic>>? onStateChanged;
  final String? explorationScopeId;
  final ExplorationRepository? explorationRepository;
  final AnalysisEngineFactory? analysisEngineFactory;

  @override
  TextViewState createState() => TextViewState();
}

/// Reader state is public so containing pages can save an open exploration
/// before replacing or leaving the reader surface.
final class TextViewState extends State<TextView> {
  late GameReaderController _controller = GameReaderController(widget.content);

  PuzzleSide _orientation = PuzzleSide.white;
  late final ScrollController _scrollController;
  final GlobalKey<AnalysisPanelState> _analysisPanelKey =
      GlobalKey<AnalysisPanelState>();
  final GlobalKey<ExplorationWorkspaceState> _workspaceKey =
      GlobalKey<ExplorationWorkspaceState>();
  String _ephemeralScopeId = _newEphemeralScopeId();
  ExplorationOrigin? _workspaceOrigin;
  List<String>? _suggestionMoves;
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
  bool _resumeAvailable = false;
  String? _resumeLookupKey;
  ExplorationRepository? _resumeLookupRepository;
  int _resumeLookupGeneration = 0;
  int _contentGeneration = 0;

  static int _nextEphemeralScope = 0;

  static String _newEphemeralScopeId() =>
      'reader-session-${DateTime.now().microsecondsSinceEpoch}-${_nextEphemeralScope++}';

  bool get isExploring => _workspaceOrigin != null;

  /// Saves the active personal tree before this reading surface is replaced.
  /// A workspace persistence failure propagates so callers can block exit.
  Future<void> prepareToLeave() async {
    _publishState();
    await _analysisPanelKey.currentState?.prepareToLeave();
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
        unawaited(_refreshResumeStatus());
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
      _resumeLookupGeneration++;
      _resumeLookupKey = null;
      _resumeAvailable = false;
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
          unawaited(_refreshResumeStatus(force: true));
        });
      }
    } else if (oldWidget.explorationScopeId != widget.explorationScopeId ||
        oldWidget.explorationRepository != widget.explorationRepository) {
      _resumeLookupGeneration++;
      _resumeLookupKey = null;
      _resumeAvailable = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_refreshResumeStatus(force: true));
      });
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
                orientation: _workspaceOrientation ?? _orientation,
                initialMoves: _suggestionMoves ?? const [],
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
        if (_canExplore)
          AnalysisPanel(
            key: _analysisPanelKey,
            // The widget key is stable while the authored cursor changes so
            // its controller can debounce navigation and suppress stale work.
            startingFen: widget.content.startingFen,
            moves: navigation.path.map((node) => node.uci).toList(),
            engineFactory: widget.analysisEngineFactory,
            onExploreSuggestion: _exploreSuggestion,
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
      actions: _canExplore
          ? Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                key: const ValueKey('explore-position'),
                onPressed: _openingWorkspace
                    ? null
                    : () => unawaited(_openExploration()),
                icon: const Icon(Icons.explore_outlined),
                label: Text(
                  _resumeAvailable ? 'Resume exploration' : 'Explore position',
                ),
              ),
            )
          : null,
      details: details,
    );
  }

  bool get _canExplore => _hasMoves || _hasPosition;

  Future<void> _refreshResumeStatus({bool force = false}) async {
    final repository = widget.explorationRepository;
    if (!_canExplore || repository == null || _workspaceOrigin != null) {
      if (_resumeAvailable && mounted) {
        setState(() => _resumeAvailable = false);
      }
      _resumeLookupGeneration++;
      _resumeLookupKey = null;
      _resumeLookupRepository = repository;
      return;
    }
    final origin = _originForCurrentPosition();
    final lookupKey = origin.identityKey;
    if (!force &&
        identical(repository, _resumeLookupRepository) &&
        lookupKey == _resumeLookupKey) {
      return;
    }
    _resumeLookupRepository = repository;
    _resumeLookupKey = lookupKey;
    final generation = ++_resumeLookupGeneration;
    if (_resumeAvailable && mounted) {
      setState(() => _resumeAvailable = false);
    }
    try {
      final saved = await repository.load(origin);
      if (!mounted || generation != _resumeLookupGeneration) return;
      final hasTree = saved != null && saved.root.isNotEmpty;
      if (_resumeAvailable != hasTree) {
        setState(() => _resumeAvailable = hasTree);
      }
    } on Object {
      if (!mounted || generation != _resumeLookupGeneration) return;
      if (_resumeAvailable) setState(() => _resumeAvailable = false);
      // Opening still proceeds normally; the workspace presents its
      // recoverable load error and retry action when the learner enters.
    }
  }

  List<int> get _currentPathIndices {
    var choices = widget.content.rootMoves;
    final result = <int>[];
    for (final node in _controller.navigation.path) {
      final index = choices.indexOf(node);
      if (index < 0) break;
      result.add(index);
      choices = node.children;
    }
    return result;
  }

  ExplorationOrigin _originForCurrentPosition() {
    final path = _controller.navigation.path;
    final node = path.isEmpty ? null : path.last;
    return ExplorationOrigin(
      scopeId: widget.explorationScopeId ?? _ephemeralScopeId,
      startingFen: widget.content.startingFen,
      authoredPath: _currentPathIndices,
      authoredMoves: path.map((move) => move.uci).toList(),
      label: node == null ? 'Starting position' : 'After ${node.san}',
    );
  }

  Future<void> _openExploration({List<String> initialMoves = const []}) async {
    if (!_canExplore || _workspaceOrigin != null || _openingWorkspace) return;
    final contentAtTap = widget.content;
    final scopeAtTap = widget.explorationScopeId;
    final repositoryAtTap = widget.explorationRepository;
    final engineFactoryAtTap = widget.analysisEngineFactory;
    final contentGenerationAtTap = _contentGeneration;
    _publishState();
    _scrollOffsetBeforeExploration = _scrollController.hasClients
        ? _scrollController.offset
        : 0;
    _openingWorkspace = true;
    setState(() {});
    try {
      await _analysisPanelKey.currentState?.prepareToLeave();
      if (!mounted ||
          contentGenerationAtTap != _contentGeneration ||
          contentAtTap != widget.content ||
          scopeAtTap != widget.explorationScopeId ||
          !identical(repositoryAtTap, widget.explorationRepository) ||
          !identical(engineFactoryAtTap, widget.analysisEngineFactory)) {
        return;
      }
      setState(() {
        _workspaceOrigin = _originForCurrentPosition();
        _suggestionMoves = List.unmodifiable(initialMoves);
        _workspaceContentSnapshot = widget.content;
        _workspaceNavigationSnapshot = _controller.navigation;
        _workspaceOrientation = _orientation;
        _workspaceRepository = widget.explorationRepository;
        _workspaceEngineFactory = widget.analysisEngineFactory;
        _workspaceContentSuperseded = false;
        _contentReplacementPending = false;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Engine analysis could not be stopped.'),
          ),
        );
      }
    } finally {
      _openingWorkspace = false;
      if (mounted && _workspaceOrigin == null) setState(() {});
    }
  }

  void _exploreSuggestion(List<String> moves) {
    unawaited(_openExploration(initialMoves: moves));
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
      _suggestionMoves = null;
      _workspaceContentSnapshot = null;
      _workspaceNavigationSnapshot = null;
      _workspaceOrientation = null;
      _workspaceRepository = null;
      _workspaceEngineFactory = null;
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
      unawaited(_refreshResumeStatus(force: true));
    });
  }

  VoidCallback _perform(void Function() action) => () {
    setState(() {
      action();
      _publishState();
    });
    unawaited(_refreshResumeStatus());
  };

  void _acceptNavigation(ReaderNavigationState navigation) {
    setState(() {
      _setNavigation(navigation);
      _publishState();
    });
    unawaited(_refreshResumeStatus());
  }
}
