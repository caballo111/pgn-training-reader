import 'dart:async';

import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/material.dart';

import '../../../domain/analysis/analysis_engine.dart';
import '../../../domain/analysis/exploration_repository.dart';
import '../../../domain/analysis/exploration_session.dart';
import '../../analysis/presentation/exploration_workspace.dart';
import '../../../domain/training/puzzle_attempt.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../../../shared/chessboard/chessboard_adapter.dart';
import '../../../shared/presentation/study_action_toolbar.dart';
import '../../../shared/presentation/study_layout.dart';
import '../../../shared/presentation/study_navigation_controls.dart';
import '../../game_reader/presentation/reader_board.dart';
import '../application/puzzle_presentation_state.dart';
import 'puzzle_attempt_variations.dart';
import '../../../shared/presentation/study_move_button.dart';

/// Read-only solution review. This surface accepts only the safe projection,
/// which contains authored content only after the attempt has finalized.
final class PuzzleSolutionReviewView extends StatefulWidget {
  const PuzzleSolutionReviewView({
    required this.presentation,
    this.onRetry,
    this.onNext,
    this.onPrevious,
    this.showBlockNavigation = false,
    this.canAdvance = true,
    this.isFinalExercise = false,
    this.nextLabel,
    this.showRetry = true,
    this.initialPath,
    this.onPathChanged,
    this.initialOrientation,
    this.onOrientationChanged,
    this.onToggleMode,
    this.explorationScopeId,
    this.explorationRepository,
    this.analysisEngineFactory,
    this.explorationEnabled = true,
    this.persistenceMessage,
    super.key,
  });

  final PuzzlePresentationState presentation;
  final VoidCallback? onRetry;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final bool showBlockNavigation;
  final bool canAdvance;
  final bool isFinalExercise;

  /// Overrides the cycle-oriented default label for an owning study context.
  final String? nextLabel;
  final bool showRetry;

  /// Selected authored branch, as child indices from the root.
  /// Null restores the accepted path; an empty path restores the start.
  final List<int>? initialPath;
  final ValueChanged<List<int>>? onPathChanged;
  final PuzzleSide? initialOrientation;
  final ValueChanged<PuzzleSide>? onOrientationChanged;
  final VoidCallback? onToggleMode;

  final String? explorationScopeId;
  final ExplorationRepository? explorationRepository;
  final AnalysisEngineFactory? analysisEngineFactory;
  final bool explorationEnabled;
  final String? persistenceMessage;

  @override
  PuzzleSolutionReviewViewState createState() =>
      PuzzleSolutionReviewViewState();
}

final class PuzzleSolutionReviewViewState
    extends State<PuzzleSolutionReviewView> {
  final _workspaceKey = GlobalKey<ExplorationWorkspaceState>();
  ExplorationOrigin? _exploration;
  List<String> _initialExplorationMoves = const [];
  List<String> _explorationComments = const [];
  bool _initialMovesAreEngine = false;
  bool _workspaceEngineWasEnabled = false;
  PuzzleSide? _workspaceOrientation;
  bool _openingWorkspace = false;
  double _returnScroll = 0;

  bool get isExploring => _exploration != null;

  Future<void> prepareToLeave() async {
    await _workspaceKey.currentState?.prepareToLeave();
  }

  Future<void> returnFromExploration() async {
    await prepareToLeave();
    if (mounted && isExploring) _restoreReview();
  }

  void _restoreReview() {
    setState(() {
      _exploration = null;
      _workspaceEngineWasEnabled = false;
      _workspaceOrientation = null;
      _initialMovesAreEngine = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _detailsController.hasClients) {
        _detailsController.jumpTo(
          _returnScroll.clamp(0, _detailsController.position.maxScrollExtent),
        );
      }
    });
  }

  void _explore() {
    if (!widget.presentation.isSolutionVisible ||
        _openingWorkspace ||
        _exploration != null ||
        !widget.explorationEnabled) {
      return;
    }
    final lineAtTap = List<PuzzlePresentationMove>.unmodifiable(_line);
    final plyAtTap = _plyIndex;
    final selected = plyAtTap < 0 ? null : lineAtTap[plyAtTap];
    _enterExploration(
      path: _pathThrough(plyAtTap),
      moves: [for (final move in lineAtTap.take(plyAtTap + 1)) move.uci],
      label: selected == null
          ? 'starting position'
          : '${_movePrefix(selected)}${selected.san}',
    );
  }

  void _enterExploration({
    required List<int> path,
    required List<String> moves,
    required String label,
    String? discriminator,
    List<String> initialMoves = const [],
    bool initialMovesAreEngine = false,
  }) {
    if (_openingWorkspace ||
        _exploration != null ||
        !widget.explorationEnabled ||
        !widget.presentation.isSolutionVisible) {
      return;
    }
    final presentationAtTap = widget.presentation;
    final scopeAtTap = widget.explorationScopeId;
    final repositoryAtTap = widget.explorationRepository;
    final engineFactoryAtTap = widget.analysisEngineFactory;
    final orientationAtTap = _orientation;
    final pathAtTap = List<int>.unmodifiable(path);
    final movesAtTap = List<String>.unmodifiable(moves);
    final initialMovesAtTap = List<String>.unmodifiable(initialMoves);
    final returnScrollAtTap = _detailsController.hasClients
        ? _detailsController.offset
        : 0.0;
    final comments = <String>[...presentationAtTap.comments];
    var siblings =
        presentationAtTap.solution ?? const <PuzzlePresentationMove>[];
    PuzzlePresentationMove? anchoredMove;
    for (final index in pathAtTap) {
      if (index < 0 || index >= siblings.length) break;
      anchoredMove = siblings[index];
      siblings = anchoredMove.children;
    }
    if (anchoredMove != null) comments.addAll(anchoredMove.comments);
    final originAtTap = ExplorationOrigin(
      scopeId: scopeAtTap ?? 'ephemeral-review',
      startingFen: presentationAtTap.startingFen,
      authoredPath: pathAtTap,
      authoredMoves: movesAtTap,
      label: label,
      discriminator: discriminator,
    );
    _openingWorkspace = true;
    if (!mounted ||
        !identical(widget.presentation, presentationAtTap) ||
        !widget.presentation.isSolutionVisible ||
        scopeAtTap != widget.explorationScopeId ||
        !identical(repositoryAtTap, widget.explorationRepository) ||
        !identical(engineFactoryAtTap, widget.analysisEngineFactory)) {
      _openingWorkspace = false;
      return;
    }
    setState(() {
      _returnScroll = returnScrollAtTap;
      _initialExplorationMoves = initialMovesAtTap;
      _explorationComments = comments;
      _workspaceEngineWasEnabled = false;
      _exploration = originAtTap;
      _initialMovesAreEngine = initialMovesAreEngine;
      _workspaceOrientation = orientationAtTap;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _openingWorkspace) {
        setState(() => _openingWorkspace = false);
      }
    });
  }

  void _exploreTry(PuzzleRejection rejection) {
    if (!widget.presentation.isSolutionVisible ||
        _openingWorkspace ||
        _exploration != null) {
      return;
    }
    final path = <int>[];
    var siblings = widget.presentation.solution!;
    for (final uci in rejection.authoredPath) {
      final index = siblings.indexWhere((move) => move.uci == uci);
      if (index < 0) return;
      path.add(index);
      siblings = siblings[index].children;
    }
    if (!rejection.legal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This try was illegal. Explore the position before it.',
          ),
        ),
      );
    }
    final prefix = _prefixForFen(rejection.fenBefore);
    final triedMove = rejection.san ?? rejection.uci;
    _enterExploration(
      path: path,
      moves: rejection.authoredPath,
      label: rejection.legal
          ? 'before $prefix$triedMove (your rejected try)'
          : 'before $prefix$triedMove (your illegal try)',
      discriminator: 'try:${rejection.uci}',
      initialMoves: rejection.legal ? [rejection.uci] : const [],
      initialMovesAreEngine: false,
    );
  }

  Widget _reviewOutcomeCard() {
    final label = _outcomeLabel(widget.presentation);
    final description = switch (widget.presentation.outcome) {
      PuzzleAttemptOutcome.passed => 'You completed the solution line.',
      PuzzleAttemptOutcome.assisted => 'You completed this puzzle with help.',
      PuzzleAttemptOutcome.wrongMove =>
        'Review the solution and the moves that were rejected.',
      PuzzleAttemptOutcome.revealed => 'The solution was shown to you.',
      PuzzleAttemptOutcome.skipped => 'This puzzle was skipped.',
      PuzzleAttemptOutcome.timedOut =>
        'Time ran out before the puzzle was complete.',
      PuzzleAttemptOutcome.abandoned => 'This attempt was left unfinished.',
      null => 'Continue reviewing the solution.',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(description),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _returnToPlayedLine,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Review solution'),
                ),
                if (widget.presentation.rejections.isNotEmpty)
                  TextButton.icon(
                    onPressed: _scrollToTries,
                    icon: const Icon(Icons.history),
                    label: const Text('Review my tries'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToTries() {
    final target = _triesKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 180),
      alignment: 0.2,
    );
  }

  Widget _reviewBookContext() {
    final line = _line;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Select an authored move to return to review there.'),
        ),
        if (line.isNotEmpty)
          Wrap(
            spacing: 2,
            runSpacing: 2,
            children: [
              for (var index = 0; index < line.length; index++)
                StudyMoveButton(
                  key: ValueKey('review-book-move-$index'),
                  prefix: _movePrefix(line[index]),
                  label: line[index].san,
                  onPressed: () =>
                      unawaited(_returnToBookPath(_pathThrough(index))),
                ),
            ],
          ),
        for (var depth = 0; depth < line.length; depth++)
          if (_siblingsAt(depth).length > 1)
            ExpansionTile(
              key: ValueKey('review-book-alternatives-$depth'),
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Other moves after ${_movePrefix(line[depth]).trim()}',
              ),
              children: [
                for (
                  var branch = 0;
                  branch < _siblingsAt(depth).length;
                  branch++
                )
                  if (branch != (_variationChoices[depth] ?? 0))
                    ListTile(
                      key: ValueKey('review-book-branch-$depth-$branch'),
                      title: Text(
                        '${_movePrefix(_siblingsAt(depth)[branch])}'
                        '${_siblingsAt(depth)[branch].san}',
                      ),
                      onTap: () => unawaited(
                        _returnToBookPath([..._pathThrough(depth - 1), branch]),
                      ),
                    ),
              ],
            ),
        if (_explorationComments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_explorationComments.join('\n\n')),
          ),
      ],
    );
  }

  Future<void> _returnToBookPath(List<int> path) async {
    if (_openingWorkspace || _exploration == null) return;
    try {
      await _workspaceKey.currentState?.prepareToLeave();
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
    if (!mounted || _exploration == null) return;
    var siblings = widget.presentation.solution ?? const [];
    for (final index in path) {
      if (index < 0 || index >= siblings.length) return;
      siblings = siblings[index].children;
    }
    setState(() {
      _variationChoices
        ..clear()
        ..addEntries([
          for (var depth = 0; depth < path.length; depth++)
            MapEntry(depth, path[depth]),
        ]);
      _plyIndex = path.length - 1;
      _exploration = null;
      _initialExplorationMoves = const [];
      _initialMovesAreEngine = false;
      _workspaceEngineWasEnabled = false;
      _workspaceOrientation = null;
    });
    widget.onPathChanged?.call(path);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _detailsController.hasClients) {
        _detailsController.jumpTo(
          _returnScroll.clamp(0, _detailsController.position.maxScrollExtent),
        );
      }
      _scrollSelectedMoveIntoView();
    });
  }

  final Map<int, int> _variationChoices = {};
  final Map<int, GlobalKey> _moveKeys = {};
  final GlobalKey _triesKey = GlobalKey();
  final ScrollController _detailsController = ScrollController();
  int _plyIndex = 0;
  bool _compactBoard = false;
  late PuzzleSide _orientation =
      widget.initialOrientation ??
      widget.presentation.boardOrientation ??
      _startingOrientation;

  PuzzleSide get _startingOrientation =>
      widget.presentation.startingFen.split(' ').elementAtOrNull(1) == 'b'
      ? PuzzleSide.black
      : PuzzleSide.white;

  @override
  void didUpdateWidget(covariant PuzzleSolutionReviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.presentation.isSolutionVisible ||
        oldWidget.explorationScopeId != widget.explorationScopeId) {
      _exploration = null;
    }
    if (!identical(oldWidget.presentation, widget.presentation)) {
      _variationChoices.clear();
      _orientation =
          widget.initialOrientation ??
          widget.presentation.boardOrientation ??
          _startingOrientation;
      _initializeReachedPath();
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeReachedPath();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _initializeReachedPath() {
    if (widget.initialPath != null) {
      for (var i = 0; i < widget.initialPath!.length; i++) {
        _variationChoices[i] = widget.initialPath![i];
      }
      _plyIndex = widget.initialPath!.length - 1;
      return;
    }
    final entries = widget.presentation.entries
        .where((entry) => entry.accepted)
        .toList();
    final acceptedMoves = entries.isEmpty
        ? widget.presentation.playedMoves
        : [for (final entry in entries) entry.uci];
    var siblings =
        widget.presentation.solution ?? const <PuzzlePresentationMove>[];
    for (
      var depth = 0;
      depth < acceptedMoves.length && siblings.isNotEmpty;
      depth++
    ) {
      final choice = siblings.indexWhere(
        (move) => move.uci == acceptedMoves[depth],
      );
      if (choice < 0) break;
      _variationChoices[depth] = choice;
      siblings = siblings[choice].children;
    }
    _plyIndex = _variationChoices.length - 1;
  }

  List<PuzzlePresentationMove> get _line {
    final nodes =
        widget.presentation.solution ?? const <PuzzlePresentationMove>[];
    final result = <PuzzlePresentationMove>[];
    var siblings = nodes;
    var depth = 0;
    while (siblings.isNotEmpty) {
      final choice = (_variationChoices[depth] ?? 0).clamp(
        0,
        siblings.length - 1,
      );
      final selected = siblings[choice];
      result.add(selected);
      siblings = selected.children;
      depth++;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.presentation.isSolutionVisible) {
      return const Center(child: Text('The solution is not available yet.'));
    }
    if (_exploration case final origin?) {
      return ExplorationWorkspace(
        key: _workspaceKey,
        origin: origin,
        repository: widget.explorationScopeId == null
            ? null
            : widget.explorationRepository,
        engineFactory: widget.analysisEngineFactory,
        engineWasEnabled: _workspaceEngineWasEnabled,
        persistenceMessage: widget.persistenceMessage,
        orientation: _workspaceOrientation ?? _orientation,
        initialMoves: _initialExplorationMoves,
        initialMovesAreEngine: _initialMovesAreEngine,
        returnLabel: 'Return to review',
        bookContext: _reviewBookContext(),
        onReturn: _restoreReview,
      );
    }
    final line = _line;
    if (line.isEmpty) {
      return const Center(child: Text('No solution moves are available.'));
    }
    _plyIndex = _plyIndex.clamp(-1, line.length - 1);
    final position = _positionAt(_plyIndex, line);
    final selected = _plyIndex < 0 ? null : line[_plyIndex];
    final legal = <String, Set<String>>{
      for (final entry in chess.makeLegalMoves(position).entries)
        entry.key.name: {
          for (final destination in entry.value) destination.name,
        },
    };
    final board = ChessboardAdapter.fromPosition(
      fen: position.fen,
      sideToMove: position.turn == chess.Side.white
          ? PuzzleSide.white
          : PuzzleSide.black,
      legalDestinations: legal,
      orientation: _orientation,
      lastMoveUci: selected?.uci,
    );

    return AbsorbPointer(
      absorbing: _openingWorkspace,
      child: StudyLayout(
        controlCount: 6,
        controlTrailingWidth: 0,
        compactBoard: _compactBoard,
        board: ReaderBoard(
          board: board,
          showOrientationControl: false,
          positionLabel: selected == null
              ? 'Starting position.'
              : 'Position after ${_movePrefix(selected)}${selected.san}.'
                    '${selected.nags.isEmpty ? '' : ' Annotations: ${selected.nags.map(_nagLabel).join(', ')}.'}',
        ),
        controls: Row(
          children: [
            Expanded(
              child: StudyNavigationControls(
                status: _outcomeIndicator(context),
                onReturnToPlayedLine: _returnToPlayedLine,
                canPrevious: _plyIndex >= 0,
                canNext: _plyIndex + 1 < line.length,
                onFirst: () => _setCursor(-1),
                onPrevious: () => _setCursor(_plyIndex - 1),
                onNext: () => _setCursor(_plyIndex + 1),
                onLast: () => _setCursor(line.length - 1),
                onFlip: _flipBoard,
                showFlip: false,
              ),
            ),
          ],
        ),
        actions: StudyActionToolbar(
          onPreviousBlock: widget.canAdvance ? widget.onPrevious : null,
          onToggleMode: widget.onToggleMode,
          solving: true,
          onReset: () => _setCursor(-1),
          onAnalyze: widget.explorationEnabled ? _explore : null,
          onNextBlock: widget.canAdvance ? widget.onNext : null,
          nextLabel:
              widget.nextLabel ??
              (widget.isFinalExercise ? 'Finish cycle' : 'Next exercise'),
          onFlip: _flipBoard,
          onToggleBoardSize: _toggleBoardSize,
          compactBoard: _compactBoard,
          extraMenuItems: widget.onRetry != null && widget.showRetry
              ? [StudyMenuAction('Try again', Icons.replay, widget.onRetry!)]
              : const [],
        ),
        details: ListView(
          key: const ValueKey('review-details'),
          controller: _detailsController,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          children: [
            _reviewOutcomeCard(),
            if (widget.presentation.comments.isNotEmpty)
              Semantics(
                container: true,
                key: const ValueKey('puzzle-notes'),
                label: 'Puzzle notes',
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(widget.presentation.comments.first),
                ),
              ),
            if (widget.presentation.rejections.isNotEmpty)
              Column(
                key: _triesKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Text(
                      'Your tries',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final rejection in widget.presentation.rejections)
                    ListTile(
                      key: ValueKey('rejected-try-${rejection.ordinal}'),
                      title: Text(
                        '${_prefixForFen(rejection.fenBefore)}${rejection.san ?? rejection.uci}',
                      ),
                      subtitle: Text(
                        rejection.legal
                            ? 'Explore after ${rejection.san ?? rejection.uci}'
                            : 'Explore before illegal ${rejection.san ?? rejection.uci}',
                      ),
                      onTap: widget.explorationEnabled
                          ? () => _exploreTry(rejection)
                          : null,
                    ),
                ],
              ),
            for (
              var index = 1;
              index < widget.presentation.comments.length;
              index++
            )
              Semantics(
                container: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(widget.presentation.comments[index]),
                ),
              ),
            if (widget.presentation.comments.isNotEmpty)
              const SizedBox(height: 4),
            Semantics(
              container: true,
              explicitChildNodes: true,
              label: 'Solution line',
              value: _plyIndex < 0
                  ? 'Starting position, ${line.length} solution moves'
                  : 'Move ${_plyIndex + 1} of ${line.length}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _solutionRows(line),
              ),
            ),
            if (widget.presentation.usedFullLineFallback)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Full line used: no completion marker on this continuation.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _flipBoard() {
    if (_openingWorkspace) return;
    setState(() {
      _orientation = _orientation == PuzzleSide.white
          ? PuzzleSide.black
          : PuzzleSide.white;
      widget.onOrientationChanged?.call(_orientation);
    });
  }

  void _toggleBoardSize() {
    if (_openingWorkspace) return;
    setState(() => _compactBoard = !_compactBoard);
  }

  Widget _outcomeIndicator(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final successColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.greenAccent.shade200
        : Colors.green.shade800;
    final (icon, color) = switch (widget.presentation.outcome) {
      PuzzleAttemptOutcome.passed => (Icons.check_circle_outline, successColor),
      PuzzleAttemptOutcome.wrongMove => (Icons.cancel_outlined, scheme.error),
      PuzzleAttemptOutcome.assisted => (
        Icons.lightbulb_outline,
        scheme.tertiary,
      ),
      PuzzleAttemptOutcome.revealed => (
        Icons.visibility_outlined,
        scheme.onSurfaceVariant,
      ),
      PuzzleAttemptOutcome.skipped => (
        Icons.skip_next_outlined,
        scheme.onSurfaceVariant,
      ),
      PuzzleAttemptOutcome.timedOut => (Icons.timer_off_outlined, scheme.error),
      PuzzleAttemptOutcome.abandoned => (
        Icons.stop_circle_outlined,
        scheme.onSurfaceVariant,
      ),
      null => (Icons.help_outline, scheme.onSurfaceVariant),
    };
    final label = _outcomeLabel(widget.presentation);
    return Semantics(
      label: 'Puzzle outcome',
      value: label,
      liveRegion: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: ExcludeSemantics(
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: color),
          ),
        ),
      ),
    );
  }

  // Keep uninterrupted notation together. Comments and alternatives terminate
  // a run, so each branch remains adjacent to its authored branching move.
  List<Widget> _solutionRows(List<PuzzlePresentationMove> line) {
    final rows = <Widget>[];
    final run = <Widget>[];
    final variations = puzzleAttemptVariations(widget.presentation);
    void flushRun() {
      if (run.isEmpty) return;
      rows.add(Wrap(spacing: 2, runSpacing: 0, children: List.of(run)));
      run.clear();
    }

    for (var index = 0; index < line.length; index++) {
      final move = line[index];
      run.add(
        StudyMoveButton(
          key: _moveKeys.putIfAbsent(index, GlobalKey.new),
          prefix: _movePrefix(move),
          label: move.san,
          selected: _plyIndex == index,
          annotation: move.nags.isEmpty
              ? null
              : move.nags.map(_nagLabel).join(' '),
          onPressed: () => _setCursor(index),
        ),
      );
      final siblings = _siblingsAt(index);
      final branches = puzzleVariationsAt(variations, [
        for (final preceding in line.take(index)) preceding.uci,
      ]);
      if (move.comments.isEmpty && siblings.length <= 1 && branches.isEmpty) {
        continue;
      }
      flushRun();
      if (branches.isNotEmpty) {
        rows.add(PuzzleAttemptVariations(variations: branches));
      }
      if (move.comments.isNotEmpty) {
        rows.add(
          Padding(
            padding: EdgeInsets.only(left: _branchIndent(index) + 8, bottom: 4),
            child: Text(move.comments.join('\n')),
          ),
        );
      }
      if (siblings.length > 1) {
        rows.add(
          ExpansionTile(
            key: ValueKey('alternatives-$index'),
            minTileHeight: 48,
            visualDensity: VisualDensity.compact,
            tilePadding: EdgeInsets.only(left: _branchIndent(index)),
            title: Text('Alternatives at ${_movePrefix(move).trim()}'),
            children: [
              for (var branch = 0; branch < siblings.length; branch++)
                if (branch != (_variationChoices[index] ?? 0))
                  ListTile(
                    key: ValueKey('alternative-$index-$branch'),
                    dense: true,
                    minTileHeight: 48,
                    contentPadding: EdgeInsets.only(
                      left: _branchIndent(index) + 8,
                    ),
                    title: Text(
                      '${_movePrefix(siblings[branch])}${siblings[branch].san}',
                    ),
                    subtitle: siblings[branch].comments.isEmpty
                        ? null
                        : Text(siblings[branch].comments.join('\n')),
                    onTap: () => _selectAlternative(index, branch),
                  ),
            ],
          ),
        );
      }
    }
    flushRun();
    final trailingBranches = puzzleVariationsAt(variations, [
      for (final move in line) move.uci,
    ]);
    if (trailingBranches.isNotEmpty) {
      rows.add(PuzzleAttemptVariations(variations: trailingBranches));
    }
    return rows;
  }

  void _selectAlternative(int depth, int index) {
    setState(() {
      _variationChoices[depth] = index;
      _variationChoices.removeWhere((key, _) => key > depth);
      _plyIndex = depth;
    });
    widget.onPathChanged?.call([
      for (var i = 0; i <= depth; i++) _variationChoices[i] ?? 0,
    ]);
    _scrollSelectedMoveIntoView();
  }

  void _setCursor(int index) {
    setState(() => _plyIndex = index.clamp(-1, _line.length - 1));
    widget.onPathChanged?.call(_pathThrough(_plyIndex));
    _scrollSelectedMoveIntoView();
  }

  void _scrollSelectedMoveIntoView() {
    final index = _plyIndex;
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index != _plyIndex) return;
      final target = _moveKeys[index]?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 160),
          alignment: 0.5,
        );
      }
    });
  }

  double _branchIndent(int depth) =>
      12.0 *
      _variationChoices.entries
          .where((entry) => entry.key < depth && entry.value != 0)
          .length
          .clamp(0, 3)
          .toInt();

  List<int> _pathThrough(int index) => [
    for (var depth = 0; depth <= index; depth++) _variationChoices[depth] ?? 0,
  ];

  void _returnToPlayedLine() {
    final choices = <int, int>{};
    var siblings =
        widget.presentation.solution ?? const <PuzzlePresentationMove>[];
    final accepted = widget.presentation.entries.where(
      (entry) => entry.accepted,
    );
    final acceptedMoves = accepted.isEmpty
        ? widget.presentation.playedMoves
        : [for (final entry in accepted) entry.uci];
    for (final uci in acceptedMoves) {
      final choice = siblings.indexWhere((move) => move.uci == uci);
      if (choice < 0 || siblings.isEmpty) break;
      choices[choices.length] = choice;
      siblings = siblings[choice].children;
    }
    setState(() {
      _variationChoices
        ..clear()
        ..addAll(choices);
      final line = _line;
      _plyIndex = acceptedMoves.isEmpty
          ? -1
          : (choices.length - 1).clamp(-1, line.length - 1);
    });
    widget.onPathChanged?.call(_pathThrough(_plyIndex));
    _scrollSelectedMoveIntoView();
  }

  List<PuzzlePresentationMove> _siblingsAt(int depth) {
    var siblings =
        widget.presentation.solution ?? const <PuzzlePresentationMove>[];
    for (var index = 0; index < depth; index++) {
      if (siblings.isEmpty) return const [];
      final choice = (_variationChoices[index] ?? 0).clamp(
        0,
        siblings.length - 1,
      );
      siblings = siblings[choice].children;
    }
    return siblings;
  }

  String _movePrefix(PuzzlePresentationMove move) {
    return _prefixForFen(move.fenBefore);
  }

  String _prefixForFen(String fen) {
    final fields = fen.split(' ');
    final number = fields.length >= 6 ? int.tryParse(fields[5]) ?? 1 : 1;
    final isBlack = fields.length >= 2 && fields[1] == 'b';
    return '$number${isBlack ? '...' : '.'} ';
  }

  chess.Chess _positionAt(int index, List<PuzzlePresentationMove> line) {
    var position = chess.Chess.fromSetup(
      chess.Setup.parseFen(widget.presentation.startingFen),
    );
    for (var ply = 0; ply <= index; ply++) {
      final move = chess.Move.parse(line[ply].uci);
      if (move == null || !position.isLegal(move)) {
        throw StateError(
          'The authored solution contains an invalid review move.',
        );
      }
      position = position.play(move) as chess.Chess;
    }
    return position;
  }

  String _outcomeLabel(PuzzlePresentationState presentation) =>
      switch (presentation.outcome) {
        PuzzleAttemptOutcome.passed => 'Passed',
        PuzzleAttemptOutcome.assisted => 'Assisted',
        PuzzleAttemptOutcome.wrongMove => 'First attempt failed',
        PuzzleAttemptOutcome.revealed => 'Solution revealed',
        PuzzleAttemptOutcome.skipped => 'Skipped',
        PuzzleAttemptOutcome.timedOut => 'Timed out',
        PuzzleAttemptOutcome.abandoned => 'Abandoned',
        null => 'In progress',
      };

  String _nagLabel(int nag) => switch (nag) {
    1 => '!',
    2 => '?',
    3 => '!!',
    4 => '??',
    5 => '!?',
    6 => '?!',
    _ => 'NAG $nag',
  };
}
