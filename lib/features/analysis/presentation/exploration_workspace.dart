import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/analysis/exploration_repository.dart';
import '../../../domain/analysis/exploration_session.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../../../shared/presentation/flip_board_button.dart';
import '../../../shared/presentation/study_layout.dart';
import 'analysis_panel.dart';
import 'exploration_board.dart';
import 'exploration_move_tree.dart';

/// A nested, personal analysis workspace anchored at one authored occurrence.
///
/// The parent remains responsible for preserving and restoring its authored
/// cursor and scroll position. This widget only owns the independent personal
/// tree and asks its parent to return after pending saves finish.
final class ExplorationWorkspace extends StatefulWidget {
  const ExplorationWorkspace({
    required this.origin,
    required this.orientation,
    required this.onReturn,
    this.repository,
    this.engineFactory,
    this.initialMoveUci,
    this.initialMoves = const [],
    this.bookContext,
    this.returnLabel = 'Return to reading',
    super.key,
  });

  final ExplorationOrigin origin;
  final ExplorationRepository? repository;
  final AnalysisEngineFactory? engineFactory;
  final PuzzleSide orientation;
  final String? initialMoveUci;
  final List<String> initialMoves;
  final Widget? bookContext;
  final VoidCallback onReturn;
  final String returnLabel;

  @override
  ExplorationWorkspaceState createState() => ExplorationWorkspaceState();
}

/// Public state so a parent block-navigation action can await persistence.
final class ExplorationWorkspaceState extends State<ExplorationWorkspace> {
  ExplorationSession? _session;
  late PuzzleSide _orientation = widget.orientation;
  bool _loading = true;
  bool _loadFailed = false;
  bool _returning = false;
  bool _dirty = false;
  bool _saveFailed = false;
  String? _failureMessage;
  int _changeGeneration = 0;
  Timer? _saveDebounce;
  Future<void> _saveTail = Future<void>.value();
  Future<void>? _pendingSave;
  int? _pendingSaveGeneration;
  Future<void>? _loadFuture;
  final GlobalKey<AnalysisPanelState> _analysisKey =
      GlobalKey<AnalysisPanelState>();

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadDraft();
  }

  @override
  void didUpdateWidget(covariant ExplorationWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.origin.identityKey != widget.origin.identityKey) {
      _session = null;
      _loading = true;
      _loadFailed = false;
      _dirty = false;
      _saveFailed = false;
      _failureMessage = null;
      _changeGeneration++;
      _saveDebounce?.cancel();
      _loadFuture = _loadDraft();
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  /// Flushes pending draft writes before the parent leaves this workspace.
  /// Throws if the durable write fails so route navigation can be blocked.
  Future<void> prepareToLeave() async {
    final wasReturning = _returning;
    if (!wasReturning && mounted) setState(() => _returning = true);
    try {
      await _prepareToLeave();
    } finally {
      if (!wasReturning && mounted) setState(() => _returning = false);
    }
  }

  Future<void> _prepareToLeave() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    final analysis = _analysisKey.currentState;
    if (analysis != null) await analysis.prepareToLeave();
    if (_loading) await _loadFuture;
    if (_loadFailed) {
      return; // Unknown or unreadable data must never be replaced.
    }
    if (widget.repository == null || !_dirty) {
      await _saveTail;
      return;
    }
    await _saveNow();
  }

  Future<void> _loadDraft() async {
    final origin = widget.origin;
    try {
      final loaded = await widget.repository?.load(origin);
      if (!mounted || widget.origin.identityKey != origin.identityKey) return;
      var next = loaded ?? ExplorationSession.initial(origin: origin);
      var seeded = false;
      final initial = <String>[
        if (widget.initialMoveUci != null) widget.initialMoveUci!,
        ...widget.initialMoves,
      ];
      if (widget.initialMoveUci != null &&
          widget.initialMoves.isNotEmpty &&
          widget.initialMoves.first == widget.initialMoveUci) {
        initial.removeAt(0);
      }
      if (initial.isNotEmpty) {
        final savedPath = next.currentPath;
        var seed = next.first();
        for (final move in initial) {
          try {
            seed = seed.playUci(move);
            seeded = true;
          } on ArgumentError {
            break;
          }
        }
        next = seeded ? seed : seed.selectPath(savedPath);
      }
      setState(() {
        _session = next;
        _loading = false;
        _loadFailed = false;
        _dirty = seeded && widget.repository != null;
      });
      if (seeded && widget.repository != null) _scheduleSave();
    } on Object catch (error) {
      if (!mounted || widget.origin.identityKey != origin.identityKey) return;
      setState(() {
        _session = ExplorationSession.initial(origin: origin);
        _loading = false;
        _loadFailed = true;
        _failureMessage =
            'Could not load this saved exploration. '
            'Nothing was overwritten. ${_messageFor(error)}';
      });
    }
  }

  void _retryLoad() {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _failureMessage = null;
    });
    _loadFuture = _loadDraft();
  }

  void _accept(ExplorationSession session) {
    setState(() {
      _session = session;
      _changeGeneration++;
      _dirty = widget.repository != null;
      _saveFailed = false;
      _failureMessage = null;
    });
    if (widget.repository != null) _scheduleSave();
  }

  void _play(String uci) {
    final session = _session;
    if (session == null || _loadFailed || _returning) return;
    try {
      _accept(session.playUci(uci));
    } on ArgumentError catch (error) {
      setState(() => _failureMessage = _messageFor(error));
    }
  }

  void _playSuggestedMoves(List<String> moves) {
    final current = _session;
    if (current == null || _loadFailed || _returning) return;
    var session = current;
    for (final move in moves) {
      try {
        session = session.playUci(move);
      } on ArgumentError {
        break;
      }
    }
    if (session != current) _accept(session);
  }

  void _navigate(ExplorationSession Function(ExplorationSession) transform) {
    final session = _session;
    if (session == null || _loadFailed || _returning) return;
    _accept(transform(session));
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_saveNow().catchError((Object _) {}));
    });
  }

  Future<void> _saveNow() {
    final repository = widget.repository;
    final session = _session;
    if (repository == null || session == null || !_dirty || _loadFailed) {
      return Future<void>.value();
    }
    final generation = _changeGeneration;
    final originKey = session.origin.identityKey;
    final pending = _pendingSave;
    if (pending != null && _pendingSaveGeneration == generation) {
      return pending;
    }
    final operation = _saveTail.then((_) => repository.save(session));
    _pendingSave = operation;
    _pendingSaveGeneration = generation;
    _saveTail = operation.catchError((Object _) {});
    unawaited(
      operation.then<void>(
        (_) {
          if (identical(_pendingSave, operation)) {
            _pendingSave = null;
            _pendingSaveGeneration = null;
          }
          if (!mounted ||
              widget.origin.identityKey != originKey ||
              _changeGeneration != generation) {
            return;
          }
          setState(() {
            _dirty = false;
            _saveFailed = false;
            _failureMessage = null;
          });
        },
        onError: (Object error, StackTrace stack) {
          if (identical(_pendingSave, operation)) {
            _pendingSave = null;
            _pendingSaveGeneration = null;
          }
          if (!mounted ||
              widget.origin.identityKey != originKey ||
              _changeGeneration != generation) {
            return;
          }
          setState(() {
            _saveFailed = true;
            _dirty = true;
            _failureMessage =
                'Exploration not saved. Your moves are still '
                'here. Retry the save before returning. ${_messageFor(error)}';
          });
        },
      ),
    );
    return operation;
  }

  Future<void> _retrySave() async {
    _saveDebounce?.cancel();
    try {
      await _saveNow();
    } on Object {
      // The failure text remains visible and the in-memory tree is retained.
    }
  }

  Future<void> _return() async {
    if (_returning || !mounted) return;
    setState(() => _returning = true);
    try {
      await prepareToLeave();
      if (!mounted) return;
      if (_saveFailed) {
        setState(() => _returning = false);
        return;
      }
      widget.onReturn();
    } on Object {
      if (!mounted) return;
      setState(() => _returning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (_loading || session == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final from = widget.origin.label.trim().isEmpty
        ? 'starting position'
        : widget.origin.label;
    final fromTitle = 'Exploring from $from';
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_return());
      },
      child: StudyLayout(
        header: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            fromTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        board: ExplorationBoard(
          session: session,
          orientation: _orientation,
          enabled: !_loadFailed && !_returning,
          onMove: _play,
        ),
        controls: Row(
          children: [
            Expanded(child: _treeControls(session)),
            FlipBoardButton(
              onPressed: _returning || _loadFailed
                  ? null
                  : () => setState(() {
                      _orientation = _orientation == PuzzleSide.white
                          ? PuzzleSide.black
                          : PuzzleSide.white;
                    }),
            ),
          ],
        ),
        controlCount: 4,
        controlTrailingWidth: 48,
        details: _details(session, from),
        actions: _returnActions(),
      ),
    );
  }

  Widget _treeControls(ExplorationSession session) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      _navigationButton(
        tooltip: 'First personal move',
        icon: Icons.first_page,
        enabled: session.currentPath.isNotEmpty,
        onPressed: () => _navigate((session) => session.first()),
      ),
      _navigationButton(
        tooltip: 'Previous personal move',
        icon: Icons.chevron_left,
        enabled: session.canPrevious,
        onPressed: () => _navigate((session) => session.previous()),
      ),
      _navigationButton(
        tooltip: 'Next personal move',
        icon: Icons.chevron_right,
        enabled: session.canNext,
        onPressed: () => _navigate((session) => session.next()),
      ),
      _navigationButton(
        tooltip: 'Last personal move',
        icon: Icons.last_page,
        enabled: session.canNext,
        onPressed: () => _navigate((session) => session.last()),
      ),
    ],
  );

  Widget _navigationButton({
    required String tooltip,
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) => IconButton(
    tooltip: tooltip,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    onPressed: enabled && !_loadFailed && !_returning ? onPressed : null,
    icon: Icon(icon),
  );

  Widget _details(ExplorationSession session, String from) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        ExplorationMoveTree(
          session: session,
          onSelectPath: (path) =>
              _navigate((session) => session.selectPath(path)),
          onSelectBranch: (index) => _navigate(
            (session) => session.selectPath([...session.currentPath, index]),
          ),
        ),
        if (_failureMessage case final message?) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          if (_loadFailed)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _retryLoad,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry loading draft'),
              ),
            ),
          if (_saveFailed)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _retrySave,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Retry save'),
              ),
            ),
        ],
        if (widget.bookContext != null) ...[
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Book context at $from'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: widget.bookContext!,
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        AbsorbPointer(
          absorbing: _returning,
          child: Semantics(
            enabled: !_returning,
            child: AnalysisPanel(
              key: _analysisKey,
              startingFen: widget.origin.startingFen,
              moves: session.moves,
              engineFactory: widget.engineFactory,
              onExploreSuggestion: _playSuggestedMoves,
            ),
          ),
        ),
      ],
    );
  }

  Widget _returnActions() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: _returning ? null : _return,
        icon: _returning
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_back),
        label: Text(widget.returnLabel),
      ),
    ],
  );

  String _messageFor(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.length > 180 ? '${message.substring(0, 177)}…' : message;
  }
}
