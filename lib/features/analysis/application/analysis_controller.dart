import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/analysis/analysis_engine.dart';

/// Visible state of the optional local analysis service.
enum AnalysisStatus { off, analyzing, ready, paused, unavailable }

/// Coordinates a single bounded request and discards output from stale work.
final class AnalysisController extends ChangeNotifier {
  AnalysisController({
    required this.engineFactory,
    this.debounce = const Duration(milliseconds: 200),
    this.defaultBudget = const Duration(milliseconds: 1000),
    this.deeperBudget = const Duration(seconds: 5),
  });

  static const defaultSearchBudget = Duration(milliseconds: 1000);
  static const deeperSearchBudget = Duration(seconds: 5);
  static const positionDebounce = Duration(milliseconds: 200);

  final AnalysisEngineFactory engineFactory;
  final Duration debounce;
  final Duration defaultBudget;
  final Duration deeperBudget;

  String _startingFen = '';
  List<String> _moves = const [];
  AnalysisEngine? _engine;
  StreamSubscription<AnalysisResult>? _subscription;
  Timer? _debounceTimer;
  Future<void> _stopBarrier = Future<void>.value();
  AnalysisResult? _result;
  AnalysisStatus _status = AnalysisStatus.off;
  bool _enabled = false;
  bool _paused = false;
  bool _disposed = false;
  bool _useDeeperBudget = false;
  String? _message;
  int _generation = 0;

  AnalysisStatus get status => _status;
  AnalysisResult? get result => _result;
  bool get isEnabled => _enabled;
  bool get isPaused => _paused;
  String? get message => _message;

  /// Changes the searched position. Obsolete output is cleared immediately;
  /// the settled position is searched after [_debounce].
  void updatePosition({
    required String startingFen,
    required List<String> moves,
  }) {
    final nextMoves = List<String>.unmodifiable(moves);
    if (_startingFen == startingFen && listEquals(_moves, nextMoves)) return;
    _startingFen = startingFen;
    _moves = nextMoves;
    _useDeeperBudget = false;
    _result = null;
    _message = null;
    if (!_enabled) {
      _setStatus(AnalysisStatus.off);
      return;
    }
    if (_paused) {
      _setStatus(AnalysisStatus.paused);
      return;
    }
    _scheduleSearch(debounce: debounce);
  }

  /// Enables or disables analysis. Disabling clears all engine output and
  /// waits for active UCI work to stop.
  Future<void> setEnabled(bool enabled) async {
    if (_disposed || _enabled == enabled) return;
    _enabled = enabled;
    _paused = false;
    _useDeeperBudget = false;
    if (!enabled) {
      _generation++;
      _debounceTimer?.cancel();
      _result = null;
      _message = null;
      _setStatus(AnalysisStatus.off);
      await _stopCurrent();
      return;
    }
    _result = null;
    _message = null;
    _scheduleSearch(debounce: Duration.zero);
  }

  /// Repeats the current position with the finite deeper-search budget.
  void analyzeDeeper() {
    if (_disposed || !_enabled || _paused || _startingFen.isEmpty) return;
    _useDeeperBudget = true;
    _result = null;
    _message = null;
    _scheduleSearch(debounce: Duration.zero);
  }

  /// Releases a failed session and retries the current position with defaults.
  Future<void> retry() async {
    if (_disposed || !_enabled || _paused || _startingFen.isEmpty) return;
    final retryGeneration = ++_generation;
    _debounceTimer?.cancel();
    _result = null;
    _message = null;
    await _stopCurrent(disposeEngine: true);
    // A user toggle, position change, lifecycle pause, or route transition
    // during shutdown supersedes this retry request.
    if (_disposed ||
        retryGeneration != _generation ||
        !_enabled ||
        _paused ||
        _startingFen.isEmpty) {
      return;
    }
    _useDeeperBudget = false;
    _result = null;
    _message = null;
    _scheduleSearch(debounce: Duration.zero);
  }

  /// Stops analysis while the app is inactive. The user must call [resume]
  /// explicitly; returning to the foreground does not start native work.
  Future<void> pause({bool disposeEngine = false}) async {
    if (_disposed) return;
    _generation++;
    _debounceTimer?.cancel();
    _paused = true;
    _result = null;
    _message = null;
    if (_enabled) _setStatus(AnalysisStatus.paused);
    await _stopCurrent(disposeEngine: disposeEngine);
  }

  /// Explicitly resumes an enabled engine after a lifecycle pause.
  void resume() {
    if (_disposed || !_enabled || !_paused) return;
    _paused = false;
    _result = null;
    _message = null;
    _scheduleSearch(debounce: Duration.zero);
  }

  /// Stops and releases the native engine before a route or workspace leaves.
  Future<void> prepareToLeave() => pause(disposeEngine: true);

  void _scheduleSearch({required Duration debounce}) {
    _generation++;
    final generation = _generation;
    _debounceTimer?.cancel();
    unawaited(_stopCurrent());
    _setStatus(AnalysisStatus.analyzing);
    _debounceTimer = Timer(debounce, () {
      unawaited(_startSearch(generation));
    });
  }

  Future<void> _startSearch(int generation) async {
    if (!_isCurrent(generation)) return;
    try {
      await _stopBarrier;
      if (!_isCurrent(generation)) return;
      final engine = _engine ??= engineFactory();
      final stream = engine.analyze(
        startingFen: _startingFen,
        moves: _moves,
        budget: _useDeeperBudget ? deeperBudget : defaultBudget,
      );
      _subscription = stream.listen(
        (value) {
          if (!_isCurrent(generation)) return;
          _result = value;
          _message = null;
          if (value.isComplete) {
            _setStatus(AnalysisStatus.ready);
          } else if (_status != AnalysisStatus.analyzing) {
            _setStatus(AnalysisStatus.analyzing);
          } else {
            notifyListeners();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!_isCurrent(generation)) return;
          _message = _friendlyError(error);
          _result = null;
          _setStatus(AnalysisStatus.unavailable);
          _subscription = null;
        },
        onDone: () {
          if (!_isCurrent(generation)) return;
          if (_result == null || !_result!.isComplete) {
            _message = 'Engine ended before analysis completed.';
            _setStatus(AnalysisStatus.unavailable);
          } else {
            _setStatus(AnalysisStatus.ready);
          }
          _subscription = null;
        },
        cancelOnError: true,
      );
    } on Object catch (error) {
      if (!_isCurrent(generation)) return;
      _message = _friendlyError(error);
      _result = null;
      _setStatus(AnalysisStatus.unavailable);
    }
  }

  bool _isCurrent(int generation) =>
      !_disposed &&
      generation == _generation &&
      _enabled &&
      !_paused &&
      _startingFen.isNotEmpty;

  Future<void> _stopCurrent({bool disposeEngine = false}) {
    final previous = _stopBarrier;
    final subscription = _subscription;
    final engine = _engine;
    final generation = _generation;
    _subscription = null;
    final next = () async {
      await previous;
      if (subscription != null) await subscription.cancel();
      if (engine != null) {
        await engine.stop();
        if (disposeEngine) {
          await engine.dispose();
          if (identical(_engine, engine)) _engine = null;
        }
      }
    }();
    _stopBarrier = next.catchError((Object error, StackTrace stackTrace) {
      if (!_disposed && generation == _generation && _enabled && !_paused) {
        _message = _friendlyError(error);
        _setStatus(AnalysisStatus.unavailable);
      }
    });
    return _stopBarrier;
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('UnsupportedError')) {
      return 'Local analysis is unavailable on this device.';
    }
    return 'Engine unavailable. You can still explore moves. Retry analysis.';
  }

  void _setStatus(AnalysisStatus status) {
    if (_status == status) {
      notifyListeners();
      return;
    }
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _debounceTimer?.cancel();
    final subscription = _subscription;
    _subscription = null;
    final engine = _engine;
    _engine = null;
    if (subscription != null) unawaited(subscription.cancel());
    if (engine != null) unawaited(engine.dispose());
    super.dispose();
  }
}
