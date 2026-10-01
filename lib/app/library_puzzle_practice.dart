import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';

import '../domain/chess_content/chess_content.dart';
import '../domain/training/authored_line_puzzle_evaluator.dart';
import '../domain/training/puzzle_attempt.dart';
import '../domain/training/puzzle_completion_policy.dart';
import '../domain/training/puzzle_evaluator.dart';
import '../features/game_reader/presentation/reader_board.dart';
import '../features/game_reader/presentation/text_view.dart';
import '../features/puzzle_solver/application/puzzle_presentation_state.dart';
import '../features/puzzle_solver/application/puzzle_solver_controller.dart';
import '../features/puzzle_solver/presentation/puzzle_solving_view.dart';
import '../features/puzzle_solver/presentation/puzzle_solution_review_view.dart';
import '../shared/chessboard/chessboard_adapter.dart';
import '../shared/presentation/flip_board_button.dart';
import '../shared/presentation/study_layout.dart';
import 'casual_training_repository.dart';
import 'dependencies.dart';

/// A library puzzle preview with per-book reading intent and standalone casual
/// solving. Casual attempts are stored in app_settings and never join a cycle.
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
  });

  final AppDependencies dependencies;
  final String blockId;
  final String bookId;
  final ChessContent puzzle;
  final bool startAutomatically;
  final PuzzleCompletionPolicy? initialCompletionPolicy;
  final Future<void> Function(PuzzleCompletionPolicy policy)? onNextPuzzle;

  @override
  State<LibraryPuzzlePractice> createState() => _LibraryPuzzlePracticeState();
}

final class _LibraryPuzzlePracticeState extends State<LibraryPuzzlePractice> {
  PuzzleSide? _orientation;
  bool _starting = false;
  String? _error;
  bool _readThisPuzzle = false;
  bool? _rememberReadPreference;
  PuzzleCompletionPolicy? _policy;
  bool _autoStartAttempted = false;

  String get _preferenceKey => 'library.read-puzzles.${widget.bookId}';

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final rows = await widget.dependencies.database
          .customSelect(
            'SELECT value FROM app_settings WHERE key = ?',
            variables: [Variable<String>(_preferenceKey)],
          )
          .get();
      if (mounted) {
        setState(() {
          _rememberReadPreference = rows.firstOrNull?.data['value'] == 'read';
          _readThisPuzzle =
              _rememberReadPreference! && !widget.startAutomatically;
          _policy = widget.initialCompletionPolicy ?? _policy ?? _defaultPolicy;
        });
        _startAutomaticallyIfRequested();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _rememberReadPreference = false;
          _policy = widget.initialCompletionPolicy ?? _policy ?? _defaultPolicy;
        });
        _startAutomaticallyIfRequested();
      }
    }
  }

  void _startAutomaticallyIfRequested() {
    if (!widget.startAutomatically || _autoStartAttempted) return;
    _autoStartAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openCasualPractice();
    });
  }

  PuzzleCompletionPolicy get _defaultPolicy =>
      hasCompletionMarker(widget.puzzle.rootMoves)
      ? PuzzleCompletionPolicy.keyMoves
      : PuzzleCompletionPolicy.allMoves;

  Future<void> _rememberRead(bool read) async {
    try {
      await widget.dependencies.database.customStatement(
        'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)',
        [_preferenceKey, read ? 'read' : 'solve'],
      );
      if (!mounted) return;
      setState(() {
        _rememberReadPreference = read;
        _readThisPuzzle = read;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Preference could not be saved.');
    }
  }

  Future<void> _openCasualPractice() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    PuzzleSolverController? controller;
    try {
      controller = await _createCasualController();
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _CasualPuzzlePage(
            controller: controller!,
            puzzle: widget.puzzle,
            initialPolicy: _policy ?? _defaultPolicy,
            onNextPuzzle: widget.onNextPuzzle,
            createFreshAttempt: () => _createCasualController(fresh: true),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Practice could not be opened. Try again.');
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<PuzzleSolverController> _createCasualController({
    bool fresh = false,
  }) async {
    final db = widget.dependencies.database;
    final previousId = fresh
        ? null
        : await CasualTrainingRepository.currentAttemptId(db, widget.blockId);
    final attemptId =
        previousId ??
        'casual:${widget.blockId}:${widget.dependencies.idGenerator.generateId()}';
    final repository = CasualTrainingRepository(db, widget.blockId, attemptId);
    await repository.restore();
    var attempt = await repository.getAttempt(attemptId);
    if (attempt == null) {
      attempt = PuzzleAttempt(
        id: attemptId,
        blockId: widget.blockId,
        cycleId: 'casual-cycle:$attemptId',
        sessionId: 'casual-session:$attemptId',
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
    await controller.initialize(puzzle: widget.puzzle, attemptId: attemptId);
    if (attempt.status == PuzzleAttemptStatus.paused &&
        attempt.outcome == null) {
      await controller.resume();
    }
    return controller;
  }

  @override
  void didUpdateWidget(covariant LibraryPuzzlePractice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blockId != widget.blockId ||
        oldWidget.bookId != widget.bookId) {
      _orientation = null;
      _readThisPuzzle = false;
      _rememberReadPreference = null;
      _policy = null;
      _autoStartAttempted = false;
      _loadPreference();
    } else if (oldWidget.puzzle != widget.puzzle) {
      _orientation = null;
      _policy = _defaultPolicy;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_rememberReadPreference == null || _policy == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_readThisPuzzle) {
      return Column(
        children: [
          MaterialBanner(
            content: const Text('Reading this puzzle without scoring.'),
            actions: [
              TextButton(
                onPressed: () => setState(() => _readThisPuzzle = false),
                child: const Text('Solve this puzzle'),
              ),
              TextButton(
                onPressed: () => _rememberRead(false),
                child: const Text('Solve puzzles in this book'),
              ),
            ],
          ),
          Expanded(child: TextView(content: widget.puzzle, readPuzzle: true)),
        ],
      );
    }
    final side = widget.puzzle.startingFen.split(' ')[1] == 'b'
        ? PuzzleSide.black
        : PuzzleSide.white;
    return StudyLayout(
      board: ReaderBoard(
        showOrientationControl: false,
        board: ChessboardAdapter.fromPosition(
          fen: widget.puzzle.startingFen,
          sideToMove: side,
          legalDestinations: const {},
          orientation: _orientation ?? side,
        ),
      ),
      controls: FlipBoardButton(
        onPressed: () => setState(() {
          _orientation = (_orientation ?? side) == PuzzleSide.white
              ? PuzzleSide.black
              : PuzzleSide.white;
        }),
      ),
      details: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Practice', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Choose how to engage with this puzzle. Casual solving is kept separate from cycle progress.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<PuzzleCompletionPolicy>(
            initialValue: _policy,
            decoration: const InputDecoration(labelText: 'Completion policy'),
            items: const [
              DropdownMenuItem(
                value: PuzzleCompletionPolicy.keyMoves,
                child: Text('Key Moves'),
              ),
              DropdownMenuItem(
                value: PuzzleCompletionPolicy.allMoves,
                child: Text('All Moves'),
              ),
            ],
            onChanged: _starting
                ? null
                : (value) => setState(() => _policy = value),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _starting ? null : _openCasualPractice,
            child: const Text('Solve this puzzle'),
          ),
          TextButton(
            onPressed: () => setState(() => _readThisPuzzle = true),
            child: const Text('Read this puzzle'),
          ),
          TextButton(
            onPressed: () => _rememberRead(true),
            child: const Text('Read puzzles in this book'),
          ),
          if (_rememberReadPreference == true)
            TextButton(
              onPressed: () => _rememberRead(false),
              child: const Text('Solve puzzles in this book'),
            ),
          if (_error != null) Text(_error!),
        ],
      ),
    );
  }
}

final class _CasualPuzzlePage extends StatefulWidget {
  const _CasualPuzzlePage({
    required this.controller,
    required this.puzzle,
    required this.createFreshAttempt,
    required this.initialPolicy,
    this.onNextPuzzle,
  });
  final PuzzleSolverController controller;
  final ChessContent puzzle;
  final Future<PuzzleSolverController> Function() createFreshAttempt;
  final PuzzleCompletionPolicy initialPolicy;
  final Future<void> Function(PuzzleCompletionPolicy policy)? onNextPuzzle;

  @override
  State<_CasualPuzzlePage> createState() => _CasualPuzzlePageState();
}

final class _CasualPuzzlePageState extends State<_CasualPuzzlePage>
    with WidgetsBindingObserver {
  late PuzzleSolverController _controller = widget.controller;
  PuzzlePresentationState? _review;
  bool _reading = false;
  bool _revealing = false;
  bool _closing = false;
  bool _allowPop = false;
  bool _backgroundPaused = false;
  String? _error;
  Future<void> Function()? _retryAction;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _pauseForBackground();
    } else if (state == AppLifecycleState.resumed && _backgroundPaused) {
      _resumeFromBackground();
    }
  }

  Future<void> _pauseForBackground() async {
    if (_backgroundPaused ||
        _controller.currentEvaluation?.attempt.outcome != null) {
      return;
    }
    try {
      await _controller.whenIdle();
      if (!mounted ||
          _backgroundPaused ||
          _controller.currentEvaluation?.attempt.outcome != null) {
        return;
      }
      await _controller.pause();
      _backgroundPaused = true;
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Practice could not be paused safely.';
          _retryAction = _pauseForBackground;
        });
      }
    }
  }

  Future<void> _resumeFromBackground() async {
    if (!_backgroundPaused) return;
    try {
      await _controller.resume();
      _backgroundPaused = false;
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Practice could not resume. Your saved position is unchanged.';
          _retryAction = _resumeFromBackground;
        });
      }
    }
  }

  Future<void> _closePractice() async {
    if (_closing) return;
    setState(() => _closing = true);
    try {
      // Continued practice can still be writing after its score is finalized.
      await _controller.whenIdle();
      final attempt = _controller.currentEvaluation?.attempt;
      if (attempt != null &&
          attempt.outcome == null &&
          attempt.status == PuzzleAttemptStatus.active) {
        await _controller.pause();
      }
      if (!mounted) return;
      setState(() {
        _allowPop = true;
        _error = null;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _closing = false;
          _error = 'Practice could not be saved. Retry before leaving.';
          _retryAction = _closePractice;
        });
      }
    }
  }

  Future<void> _tryAgain() async {
    try {
      final controller = await widget.createFreshAttempt();
      if (!mounted) {
        controller.dispose();
        return;
      }
      _controller.dispose();
      setState(() {
        _controller = controller;
        _review = null;
        _reading = false;
        _error = null;
        _retryAction = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'A new attempt could not be saved. Try again.';
          _retryAction = _tryAgain;
        });
      }
    }
  }

  Future<void> _readPuzzle() async {
    if (_revealing) return;
    setState(() => _revealing = true);
    try {
      await _controller.whenIdle();
      // Finalize an unfinished score before exposing authored answers. A prior
      // failure remains the recorded outcome because reveal is idempotent.
      await _controller.reveal();
      if (mounted) {
        setState(() {
          _reading = true;
          _review = null;
          _error = null;
          _retryAction = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'The reveal could not be saved. The answer is still concealed.';
          _retryAction = _readPuzzle;
        });
      }
    } finally {
      if (mounted) setState(() => _revealing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    late final Widget surface;
    final nextPuzzle = widget.onNextPuzzle;
    final selectedPolicy = widget.initialPolicy;
    if (_reading) {
      surface = Scaffold(
        appBar: AppBar(
          title: const Text('Read puzzle'),
          actions: [
            TextButton(
              onPressed: () => setState(() => _reading = false),
              child: const Text('Solve'),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_error != null) _errorBanner,
            Expanded(child: TextView(content: widget.puzzle, readPuzzle: true)),
          ],
        ),
      );
    } else if (_review case final review?) {
      surface = Scaffold(
        appBar: AppBar(
          title: const Text('Puzzle review'),
          actions: [
            TextButton(onPressed: _readPuzzle, child: const Text('Read')),
          ],
        ),
        body: Column(
          children: [
            if (_error != null) _errorBanner,
            Expanded(
              child: PuzzleSolutionReviewView(
                presentation: review,
                onRetry: _tryAgain,
                onNext: nextPuzzle == null
                    ? null
                    : () => _popThenAdvance(() => nextPuzzle(selectedPolicy)),
              ),
            ),
          ],
        ),
        bottomNavigationBar: widget.onNextPuzzle == null
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton(
                    onPressed: _closePractice,
                    child: const Text('Return to book'),
                  ),
                ),
              )
            : null,
      );
    } else {
      final side = widget.puzzle.startingFen.split(' ')[1] == 'b'
          ? PuzzleSide.black
          : PuzzleSide.white;
      surface = Scaffold(
        appBar: AppBar(
          title: const Text('Casual practice'),
          actions: [
            TextButton(
              onPressed: _revealing ? null : _readPuzzle,
              child: const Text('Read puzzle'),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_error != null) _errorBanner,
            Expanded(
              child: PuzzleSolvingView(
                controller: _controller,
                currentExercise: 1,
                totalExercises: 1,
                orientation: side,
                onPause: _closePractice,
                onReview: (presentation) {
                  if (mounted) setState(() => _review = presentation);
                },
              ),
            ),
          ],
        ),
      );
    }
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closePractice();
      },
      child: surface,
    );
  }

  Widget get _errorBanner => MaterialBanner(
    content: Text(_error!),
    actions: [
      if (_retryAction != null)
        TextButton(onPressed: _retryAction, child: const Text('Retry')),
      TextButton(
        onPressed: () => setState(() {
          _error = null;
          _retryAction = null;
        }),
        child: const Text('Dismiss'),
      ),
    ],
  );

  Future<void> _popThenAdvance(Future<void> Function() advance) async {
    if (_closing) return;
    setState(() {
      _closing = true;
      _allowPop = true;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).pop();
    await Future<void>.delayed(Duration.zero);
    await advance();
  }
}
