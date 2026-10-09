import 'dart:async';

import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/material.dart';

import '../../../domain/analysis/exploration_repository.dart';
import '../../../domain/analysis/exploration_session.dart';
import '../../analysis/presentation/analysis_panel.dart';
import '../../analysis/presentation/exploration_workspace.dart';
import '../../../domain/training/puzzle_attempt.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../../../shared/chessboard/chessboard_adapter.dart';
import '../../../shared/presentation/study_layout.dart';
import '../../../shared/presentation/study_block_navigation.dart';
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
    this.explorationScopeId,
    this.explorationRepository,
    this.analysisEngineFactory,
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

  final String? explorationScopeId;
  final ExplorationRepository? explorationRepository;
  final AnalysisEngineFactory? analysisEngineFactory;

  @override
  PuzzleSolutionReviewViewState createState() =>
      PuzzleSolutionReviewViewState();
}

final class PuzzleSolutionReviewViewState
    extends State<PuzzleSolutionReviewView> {
  final _workspaceKey = GlobalKey<ExplorationWorkspaceState>();
  final _analysisKey = GlobalKey<AnalysisPanelState>();
  ExplorationOrigin? _exploration;
  List<String> _initialExplorationMoves = const [];
  List<String> _explorationComments = const [];
  double _returnScroll = 0;
  String? _draftLookupKey;
  Future<ExplorationSession?>? _draftLookup;

  bool get isExploring => _exploration != null;

  Future<void> prepareToLeave() async {
    await _workspaceKey.currentState?.prepareToLeave();
    await _analysisKey.currentState?.prepareToLeave();
  }

  Future<void> returnFromExploration() async {
    await prepareToLeave();
    if (mounted && isExploring) _restoreReview();
  }

  void _restoreReview() {
    setState(() {
      _exploration = null;
      _draftLookupKey = null;
      _draftLookup = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _detailsController.hasClients) {
        _detailsController.jumpTo(
          _returnScroll.clamp(0, _detailsController.position.maxScrollExtent),
        );
      }
    });
  }

  Future<void> _explore({List<String> initialMoves = const []}) async {
    await _analysisKey.currentState?.prepareToLeave();
    if (!mounted || !widget.presentation.isSolutionVisible) return;
    final selected = _plyIndex < 0 ? null : _line[_plyIndex];
    _openExploration(
      path: _pathThrough(_plyIndex),
      moves: [for (final move in _line.take(_plyIndex + 1)) move.uci],
      label: selected == null
          ? 'starting position'
          : '${_movePrefix(selected)}${selected.san}',
      initialMoves: initialMoves,
    );
  }

  void _openExploration({
    required List<int> path,
    required List<String> moves,
    required String label,
    String? discriminator,
    List<String> initialMoves = const [],
  }) {
    final comments = <String>[...widget.presentation.comments];
    var siblings =
        widget.presentation.solution ?? const <PuzzlePresentationMove>[];
    PuzzlePresentationMove? anchoredMove;
    for (final index in path) {
      if (index < 0 || index >= siblings.length) break;
      anchoredMove = siblings[index];
      siblings = anchoredMove.children;
    }
    if (anchoredMove != null) comments.addAll(anchoredMove.comments);
    _returnScroll = _detailsController.hasClients
        ? _detailsController.offset
        : 0;
    setState(() {
      _initialExplorationMoves = initialMoves;
      _explorationComments = comments;
      _exploration = ExplorationOrigin(
        scopeId: widget.explorationScopeId ?? 'ephemeral-review',
        startingFen: widget.presentation.startingFen,
        authoredPath: path,
        authoredMoves: moves,
        label: label,
        discriminator: discriminator,
      );
    });
  }

  Future<void> _exploreTry(PuzzleRejection rejection) async {
    await _analysisKey.currentState?.prepareToLeave();
    if (!mounted || !widget.presentation.isSolutionVisible) return;
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
    _openExploration(
      path: path,
      moves: rejection.authoredPath,
      label: '${_prefixForFen(rejection.fenBefore)}before your try',
      discriminator: 'try:${rejection.uci}',
      initialMoves: rejection.legal ? [rejection.uci] : const [],
    );
  }

  final Map<int, int> _variationChoices = {};
  final Map<int, GlobalKey> _moveKeys = {};
  final ScrollController _detailsController = ScrollController();
  int _plyIndex = 0;
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
        orientation: _orientation,
        initialMoves: _initialExplorationMoves,
        returnLabel: 'Return to review',
        bookContext: Text(_explorationComments.join('\n\n')),
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
    final origin = ExplorationOrigin(
      scopeId: widget.explorationScopeId ?? 'ephemeral-review',
      startingFen: widget.presentation.startingFen,
      authoredPath: _pathThrough(_plyIndex),
      authoredMoves: [for (final move in line.take(_plyIndex + 1)) move.uci],
      label: selected == null
          ? 'starting position'
          : '${_movePrefix(selected)}${selected.san}',
    );
    if (_draftLookupKey != origin.identityKey) {
      _draftLookupKey = origin.identityKey;
      _draftLookup = widget.explorationScopeId == null
          ? null
          : widget.explorationRepository?.load(origin);
    }
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

    return StudyLayout(
      controlCount: 6,
      controlTrailingWidth: 48,
      board: ReaderBoard(
        board: board,
        showOrientationControl: false,
        positionLabel: selected == null
            ? 'Starting position.'
            : 'Position after ${_movePrefix(selected)}${selected.san}.'
                  '${selected.nags.isEmpty ? '' : ' Annotations: ${selected.nags.map(_nagLabel).join(', ')}.'}',
      ),
      controls: StudyNavigationControls(
        status: _outcomeIndicator(context),
        onReturnToPlayedLine: _returnToPlayedLine,
        canPrevious: _plyIndex >= 0,
        canNext: _plyIndex + 1 < line.length,
        onFirst: () => _setCursor(-1),
        onPrevious: () => _setCursor(_plyIndex - 1),
        onNext: () => _setCursor(_plyIndex + 1),
        onLast: () => _setCursor(line.length - 1),
        onFlip: () => setState(() {
          _orientation = _orientation == PuzzleSide.white
              ? PuzzleSide.black
              : PuzzleSide.white;
          widget.onOrientationChanged?.call(_orientation);
        }),
      ),
      details: ListView(
        controller: _detailsController,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FutureBuilder<ExplorationSession?>(
              key: ValueKey(_draftLookupKey),
              future: _draftLookup,
              builder: (context, snapshot) => TextButton.icon(
                onPressed: () => unawaited(_explore()),
                icon: const Icon(Icons.explore_outlined),
                label: Text(
                  snapshot.data == null
                      ? 'Explore position'
                      : 'Resume exploration',
                ),
              ),
            ),
          ),
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
          AnalysisPanel(
            key: _analysisKey,
            startingFen: widget.presentation.startingFen,
            moves: [for (final move in line.take(_plyIndex + 1)) move.uci],
            engineFactory: widget.analysisEngineFactory,
            onExploreSuggestion: (moves) =>
                unawaited(_explore(initialMoves: moves)),
          ),
          if (widget.presentation.rejections.isNotEmpty)
            ExpansionTile(
              title: const Text('Your tries'),
              children: [
                for (final rejection in widget.presentation.rejections)
                  ListTile(
                    title: Text(
                      '${_prefixForFen(rejection.fenBefore)}${rejection.san ?? rejection.uci}',
                    ),
                    subtitle: Text(
                      rejection.legal
                          ? 'Explore this try'
                          : 'Explore before this illegal try',
                    ),
                    onTap: () => unawaited(_exploreTry(rejection)),
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
      actions:
          (widget.onRetry == null || !widget.showRetry) &&
              widget.onNext == null &&
              widget.onPrevious == null &&
              !widget.showBlockNavigation
          ? null
          : Row(
              children: [
                if (widget.showBlockNavigation ||
                    widget.onPrevious != null) ...[
                  StudyPreviousBlockButton(
                    showLabel: false,
                    onPressed: widget.canAdvance ? widget.onPrevious : null,
                  ),
                  const SizedBox(width: 8),
                ],
                if (widget.onRetry != null && widget.showRetry) ...[
                  Flexible(
                    flex: 2,
                    fit: FlexFit.loose,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: widget.onRetry,
                      icon: const Icon(Icons.replay),
                      label: const Text(
                        'Try again',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (widget.onNext != null) const SizedBox(width: 8),
                ],
                if (widget.onNext != null)
                  Expanded(
                    flex: 3,
                    child: StudyNextBlockButton(
                      label:
                          widget.nextLabel ??
                          (widget.isFinalExercise
                              ? 'Finish cycle'
                              : 'Next exercise'),
                      primary: true,
                      onPressed: widget.canAdvance ? widget.onNext : null,
                    ),
                  ),
              ],
            ),
    );
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
