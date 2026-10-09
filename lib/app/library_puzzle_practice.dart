import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';

import '../domain/chess_content/chess_content.dart';
import '../domain/training/authored_line_puzzle_evaluator.dart';
import '../domain/training/puzzle_attempt.dart';
import '../domain/training/puzzle_completion_policy.dart';
import '../domain/training/puzzle_evaluator.dart';
import '../features/game_reader/presentation/text_view.dart';
import '../features/puzzle_solver/application/puzzle_presentation_state.dart';
import '../features/puzzle_solver/application/puzzle_solver_controller.dart';
import '../features/puzzle_solver/presentation/puzzle_solving_view.dart';
import '../features/puzzle_solver/presentation/puzzle_solution_review_view.dart';
import 'casual_training_repository.dart';
import 'dependencies.dart';
import 'study_presentation_store.dart';
import '../shared/presentation/study_mode.dart';
import '../shared/presentation/study_block_navigation.dart';

/// Embedded book study surface: reading, solving, and review share one route.
final class LibraryPuzzlePractice extends StatefulWidget {
  const LibraryPuzzlePractice({
    super.key,
    required this.dependencies,
    required this.blockId,
    required this.bookId,
    required this.puzzle,
    this.startAutomatically = false,
    this.initialCompletionPolicy,
    this.onNextPuzzle,
    this.onPreviousBlock,
    this.onModeChanged,
    this.sourceRevision,
    this.showSettingsButton = true,
    this.showModeInBody = true,
  });

  final AppDependencies dependencies;
  final String blockId;
  final String bookId;
  final String? sourceRevision;
  final bool showSettingsButton;
  final ChessContent puzzle;
  final bool startAutomatically;
  final PuzzleCompletionPolicy? initialCompletionPolicy;
  final Future<void> Function(PuzzleCompletionPolicy policy)? onNextPuzzle;
  final Future<void> Function()? onPreviousBlock;
  final ValueChanged<StudyMode>? onModeChanged;
  final bool showModeInBody;

  @override
  LibraryPuzzlePracticeState createState() => LibraryPuzzlePracticeState();
}

final class LibraryPuzzlePracticeState extends State<LibraryPuzzlePractice>
    with WidgetsBindingObserver {
  PuzzleSolverController? _controller;
  PuzzlePresentationState? _review;
  PuzzleCompletionPolicy? _policy;
  bool _reading = true;
  bool _ready = false;
  bool _busy = false;
  bool _allowPop = false;
  bool _backgroundPaused = false;
  bool _readDefault = true;
  String? _error;
  String? _pendingFreshId;
  Future<void> Function()? _retryAction;
  Completer<void>? _openingDone;
  Map<String, dynamic> _presentation = {'version': 1};
  Future<void> _presentationWrite = Future<void>.value();
  Timer? _readerSaveTimer;
  final _readerKey = GlobalKey<TextViewState>();
  final _reviewKey = GlobalKey<PuzzleSolutionReviewViewState>();

  String get _explorationScopeId =>
      jsonEncode([widget.bookId, widget.blockId, widget.sourceRevision]);

  bool get isExploring =>
      _readerKey.currentState?.isExploring == true ||
      _reviewKey.currentState?.isExploring == true;

  Future<void> returnFromExploration() async {
    await _readerKey.currentState?.returnFromExploration();
    await _reviewKey.currentState?.returnFromExploration();
  }

  Future<void> _flushAnalysis() async {
    await _readerKey.currentState?.prepareToLeave();
    await _reviewKey.currentState?.prepareToLeave();
  }

  String get _preferenceKey => 'library.read-puzzles.${widget.bookId}';
  StudyPresentationStore get _store =>
      StudyPresentationStore(widget.dependencies.database, widget.blockId);
  PuzzleCompletionPolicy get _defaultPolicy =>
      hasCompletionMarker(widget.puzzle.rootMoves)
      ? PuzzleCompletionPolicy.keyMoves
      : PuzzleCompletionPolicy.allMoves;

  StudyMode get _mode => _reading
      ? StudyMode.reading
      : _review != null
      ? StudyMode.review
      : StudyMode.solving;

  String get _modeLabel =>
      _reading ? _mode.label : 'Casual practice · ${_mode.label}';

  void _notifyModeChanged() => widget.onModeChanged?.call(_mode);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.dependencies.database
          .customSelect(
            'SELECT value FROM app_settings WHERE key = ?',
            variables: [Variable<String>(_preferenceKey)],
          )
          .get();
      _presentation = await _store.load();
      if (_presentation['sourceRevision'] != widget.sourceRevision) {
        _presentation = {'version': 1, 'sourceRevision': widget.sourceRevision};
      }
      final policyRows = await widget.dependencies.database
          .customSelect(
            'SELECT value FROM app_settings WHERE key = ?',
            variables: [
              Variable<String>('library.puzzle-policy.${widget.bookId}'),
            ],
          )
          .get();
      final savedPolicy = policyRows.firstOrNull?.data['value'];
      _readDefault = rows.firstOrNull?.data['value'] != 'solve';
      _policy =
          widget.initialCompletionPolicy ??
          (savedPolicy == 'keyMoves'
              ? PuzzleCompletionPolicy.keyMoves
              : savedPolicy == 'allMoves'
              ? PuzzleCompletionPolicy.allMoves
              : _defaultPolicy);
      if (!mounted) return;
      if (widget.startAutomatically || !_readDefault) {
        await _start();
      } else {
        await _markExposed();
      }
      if (mounted && (_readDefault || _controller != null)) {
        setState(() => _ready = true);
        _notifyModeChanged();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Study settings could not be loaded. Retry to preserve your saved position.';
        });
      }
    }
  }

  Future<void> _markExposed() async {
    // Keep the observed exposure marker locally if persistence fails. A retry
    // must never be described as unseen after answers have become visible.
    _presentation = {..._presentation, 'exposed': true};
    await _flushPresentation();
  }

  Future<void> _enterReview(PuzzlePresentationState value) async {
    if (!mounted) return;
    setState(() {
      _review = value;
      _presentation = {..._presentation, 'exposed': true};
    });
    _notifyModeChanged();
    try {
      await _markExposed();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Review is available, but its reading state could not be saved. Retry before leaving.';
          _retryAction = () async {
            await _markExposed();
            if (mounted) {
              setState(() {
                _error = null;
                _retryAction = null;
              });
            }
          };
        });
      }
    }
  }

  void _readerChanged(Map<String, dynamic> value) {
    _presentation = {..._presentation, 'reader': value};
    _readerSaveTimer?.cancel();
    _readerSaveTimer = Timer(const Duration(milliseconds: 150), () {
      final snapshot = Map<String, dynamic>.from(_presentation);
      _presentationWrite = _presentationWrite
          .catchError((Object _) {})
          .then((_) => _store.save(snapshot));
      _presentationWrite.catchError((Object _) {
        if (mounted) {
          setState(
            () => _error =
                'Reading position could not be saved. Retry before leaving.',
          );
        }
      });
    });
  }

  Future<void> _flushPresentation() async {
    await _flushAnalysis();
    _readerSaveTimer?.cancel();
    try {
      await _presentationWrite;
    } catch (_) {
      /* Retry the latest snapshot. */
    }
    _presentationWrite = _store.save(_presentation);
    await _presentationWrite;
  }

  Future<PuzzleSolverController> _createController({bool fresh = false}) async {
    final db = widget.dependencies.database;
    final previousId = fresh
        ? null
        : await CasualTrainingRepository.currentAttemptId(db, widget.blockId);
    final id =
        previousId ??
        (fresh
            ? _pendingFreshId ??=
                  'casual:${widget.blockId}:${widget.dependencies.idGenerator.generateId()}'
            : 'casual:${widget.blockId}:${widget.dependencies.idGenerator.generateId()}');
    final repository = CasualTrainingRepository(db, widget.blockId, id);
    await repository.restore();
    var attempt = await repository.getAttempt(id);
    if (attempt == null) {
      attempt = PuzzleAttempt(
        id: id,
        blockId: widget.blockId,
        cycleId: 'casual-cycle:$id',
        sessionId: 'casual-session:$id',
        startedAt: widget.dependencies.clock.utcNow,
      );
      await repository.createAttempt(attempt);
    }
    final controller = PuzzleSolverController(
      repository: repository,
      evaluatorFactory: () => AuthoredLinePuzzleEvaluator(
        clock: widget.dependencies.clock,
        idGenerator: widget.dependencies.idGenerator,
        completionPolicy: _policy ?? _defaultPolicy,
      ),
      completionPolicy: _policy ?? _defaultPolicy,
    );
    try {
      await controller.initialize(puzzle: widget.puzzle, attemptId: id);
      if (controller.state?.attemptStatus == PuzzleAttemptStatus.paused &&
          controller.state?.outcome == null) {
        await controller.resume();
      }
      return controller;
    } catch (_) {
      controller.dispose();
      rethrow;
    }
  }

  Future<void> _start({bool fresh = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final openingDone = Completer<void>();
    _openingDone = openingDone;
    PuzzleSolverController? candidate;
    try {
      await _flushPresentation();
      if (fresh) await _settleController();
      // Keep the current controller when returning from reading/review.
      final controller = candidate = fresh || _controller == null
          ? await _createController(fresh: fresh)
          : _controller!;
      if (!mounted) {
        if (!identical(controller, _controller)) controller.dispose();
        return;
      }
      if (controller.state?.attemptStatus == PuzzleAttemptStatus.paused &&
          controller.state?.outcome == null) {
        await controller.resume();
      }
      if (controller.state?.isSolutionVisible == true) await _markExposed();
      if (!identical(controller, _controller)) _controller?.dispose();
      if (fresh) _pendingFreshId = null;
      setState(() {
        _controller = controller;
        _reading = false;
        _review = controller.state?.isSolutionVisible == true
            ? controller.state
            : null;
        _error = null;
        _retryAction = null;
      });
      _notifyModeChanged();
    } catch (_) {
      if (!identical(candidate, _controller)) candidate?.dispose();
      if (mounted) {
        setState(() {
          _error =
              'Practice could not be opened. Your saved position is unchanged.';
          _retryAction = () => _start(fresh: fresh);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      if (identical(_openingDone, openingDone)) _openingDone = null;
      openingDone.complete();
    }
  }

  /// Called by the route before changing blocks or popping the book screen.
  Future<void> prepareToLeave() async {
    await _openingDone?.future;
    await _flushPresentation();
    final controller = _controller;
    if (controller == null) return;
    await _settleController();
    if (controller.state?.outcome == null &&
        controller.state?.attemptStatus == PuzzleAttemptStatus.active) {
      await controller.pause();
    }
  }

  Future<void> _settleController() async {
    final controller = _controller;
    if (controller == null) return;
    final path = controller.reviewPath;
    if (path != null) await controller.setReviewPath(path);
    final orientation = controller.reviewOrientation;
    if (orientation != null) await controller.setReviewOrientation(orientation);
    await controller.whenIdle();
  }

  Future<void> _leave(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await prepareToLeave();
      if (mounted) await action();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Study could not be saved. Retry before leaving.';
          _retryAction = () => _leave(action);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backToBook() async {
    if (isExploring) {
      try {
        await returnFromExploration();
      } catch (_) {
        // The workspace keeps its draft visible and provides save retry.
      }
      return;
    }
    await _leave(() async {
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop();
    });
  }

  /// Finalizes scoring before a classification change exposes authored text.
  Future<void> prepareForReading() async {
    await _openingDone?.future;
    await _flushAnalysis();
    await _settleController();
    await _controller?.reveal();
    await _markExposed();
  }

  Future<void> _read() async {
    if (_busy || (!_reading && _review == null)) return;
    setState(() => _busy = true);
    try {
      await prepareForReading();
      if (mounted) {
        setState(() {
          _reading = true;
          _error = null;
        });
        _notifyModeChanged();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Reading could not be opened. Your saved attempt result is preserved. Retry.';
          _retryAction = _read;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveReviewPath(List<int> path) async {
    try {
      await _controller?.setReviewPath(path);
      if (mounted) {
        setState(() {
          _error = null;
          _retryAction = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Review position could not be saved. Retry before leaving.';
          _retryAction = () => _saveReviewPath(path);
        });
      }
    }
  }

  Future<void> _pause() async {
    try {
      await _controller?.whenIdle();
      // PuzzleSolvingView has already paused the unfinished attempt.
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Practice could not be paused safely.');
      }
    }
  }

  Future<void> _saveReviewOrientation(PuzzleSide orientation) async {
    try {
      await _controller?.setReviewOrientation(orientation);
      if (mounted) {
        setState(() {
          _error = null;
          _retryAction = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Review orientation could not be saved. Retry.';
          _retryAction = () => _saveReviewOrientation(orientation);
        });
      }
    }
  }

  Future<void> _settings() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Book settings')),
            ListTile(
              title: const Text('Open puzzles for reading'),
              trailing: _readDefault ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, 'read'),
            ),
            ListTile(
              title: const Text('Open puzzles for solving'),
              trailing: !_readDefault ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, 'solve'),
            ),
            const Divider(),
            const ListTile(title: Text('New practice attempts')),
            ListTile(
              title: const Text('Key moves'),
              trailing: _policy == PuzzleCompletionPolicy.keyMoves
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, 'keyMoves'),
            ),
            ListTile(
              title: const Text('All moves'),
              trailing: _policy == PuzzleCompletionPolicy.allMoves
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, 'allMoves'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _saveSetting(choice);
  }

  /// Used by the owning book app bar to keep settings aligned with its actions.
  Future<void> openBookSettings() async {
    if (!_ready || _busy) return;
    await _settings();
  }

  Future<void> _saveSetting(String choice) async {
    try {
      if (choice == 'read' || choice == 'solve') {
        await widget.dependencies.database.customStatement(
          'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)',
          [_preferenceKey, choice],
        );
        if (mounted) setState(() => _readDefault = choice == 'read');
      } else {
        await widget.dependencies.database.customStatement(
          'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)',
          ['library.puzzle-policy.${widget.bookId}', choice],
        );
        if (mounted) {
          setState(
            () => _policy = PuzzleCompletionPolicy.values.byName(choice),
          );
        }
      }
      if (mounted) {
        setState(() {
          _error = null;
          _retryAction = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Book preference could not be saved. Retry.';
          _retryAction = () => _saveSetting(choice);
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _backgroundPause();
    } else if (state == AppLifecycleState.resumed && _backgroundPaused) {
      _backgroundResume();
    }
  }

  Future<void> _backgroundPause() async {
    try {
      await _flushPresentation();
      final controller = _controller;
      await controller?.whenIdle();
      if (!mounted ||
          controller == null ||
          controller.state?.outcome != null ||
          controller.state?.attemptStatus != PuzzleAttemptStatus.active) {
        return;
      }
      await controller.pause();
      _backgroundPaused = true;
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Practice could not be paused safely.');
      }
    }
  }

  Future<void> _backgroundResume() async {
    try {
      await _controller?.resume();
      _backgroundPaused = false;
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Practice could not resume. Your saved position is unchanged.',
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readerSaveTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _retrySave() async {
    try {
      if (_retryAction != null) {
        await _retryAction!();
      } else {
        await _flushPresentation();
        await _settleController();
        if (mounted) setState(() => _error = null);
      }
    } catch (_) {
      // Retain the message and retry action until the save succeeds.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return _error == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            );
    }
    final controller = _controller;
    final review = _review;
    final compactLandscape =
        MediaQuery.sizeOf(context).height < 420 &&
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final next = widget.onNextPuzzle;
    final side = widget.puzzle.startingFen.split(' ')[1] == 'b'
        ? PuzzleSide.black
        : PuzzleSide.white;
    final showModeRow =
        widget.showModeInBody ||
        _error != null ||
        (!_reading && review != null) ||
        (_error == null && widget.showSettingsButton);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToBook();
      },
      child: Column(
        children: [
          if (showModeRow)
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                compactLandscape ? 4 : 8,
                16,
                compactLandscape ? 4 : 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.showModeInBody)
                          Text(
                            _modeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        if (_error != null && !compactLandscape)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    TextButton(
                      onPressed: _retrySave,
                      child: const Text('Retry'),
                    ),
                    Semantics(
                      liveRegion: true,
                      label: _error!,
                      child: IconButton(
                        tooltip: 'Save error details',
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Save needed'),
                            content: SingleChildScrollView(
                              child: Text(_error!),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (!_reading && review != null && _error == null)
                    TextButton(
                      onPressed: _busy ? null : _read,
                      child: const Text('Read'),
                    ),
                  if (_error == null && widget.showSettingsButton)
                    IconButton(
                      tooltip: 'Book settings',
                      onPressed: _busy ? null : _settings,
                      icon: const Icon(Icons.settings_outlined),
                    ),
                ],
              ),
            ),
          Expanded(
            child: IgnorePointer(
              ignoring: _busy,
              child: _reading
                  ? TextView(
                      key: _readerKey,
                      content: widget.puzzle,
                      explorationScopeId: _explorationScopeId,
                      explorationRepository:
                          widget.dependencies.explorationRepository,
                      analysisEngineFactory:
                          widget.dependencies.analysisEngineFactory,
                      readPuzzle: true,
                      initialState: _presentation['reader'] is Map
                          ? Map<String, dynamic>.from(
                              _presentation['reader'] as Map,
                            )
                          : null,
                      onStateChanged: _readerChanged,
                    )
                  : review != null
                  ? PuzzleSolutionReviewView(
                      key: _reviewKey,
                      explorationScopeId: _explorationScopeId,
                      explorationRepository:
                          widget.dependencies.explorationRepository,
                      analysisEngineFactory:
                          widget.dependencies.analysisEngineFactory,
                      presentation: review,
                      showBlockNavigation: true,
                      nextLabel: next == null ? 'Back to book' : 'Next block',
                      canAdvance: !_busy,
                      initialPath: controller?.reviewPath,
                      onPathChanged: _saveReviewPath,
                      initialOrientation: controller?.reviewOrientation,
                      onOrientationChanged: _saveReviewOrientation,
                      onRetry: _busy ? null : () => _start(fresh: true),
                      onPrevious: _busy || widget.onPreviousBlock == null
                          ? null
                          : () => _leave(widget.onPreviousBlock!),
                      onNext: _busy
                          ? null
                          : () => next == null
                                ? _backToBook()
                                : _leave(() => next(_policy!)),
                    )
                  : PuzzleSolvingView(
                      controller: controller!,
                      isCasualPractice: true,
                      showBlockNavigation: true,
                      onPreviousBlock: _busy || widget.onPreviousBlock == null
                          ? null
                          : () => _leave(widget.onPreviousBlock!),
                      nextBlockLabel: next == null
                          ? 'Back to book'
                          : 'Next block',
                      onNextBlock: _busy
                          ? null
                          : () => next == null
                                ? _backToBook()
                                : _leave(() => next(_policy!)),
                      showProgress: false,
                      modeLabel: null,
                      currentExercise: 1,
                      totalExercises: 1,
                      orientation: side,
                      onPause: _pause,
                      onReview: _enterReview,
                    ),
            ),
          ),
          if (_reading)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(
                  children: [
                    StudyPreviousBlockButton(
                      showLabel: false,
                      onPressed: _busy || widget.onPreviousBlock == null
                          ? null
                          : () => _leave(widget.onPreviousBlock!),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _busy ? null : _start,
                        child: Text(
                          _busy ? 'Opening…' : 'Solve puzzle',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StudyNextBlockButton(
                        label: next == null ? 'Back to book' : 'Next block',
                        primary: false,
                        onPressed: _busy
                            ? null
                            : () => next == null
                                  ? _backToBook()
                                  : _leave(() => next(_policy!)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
