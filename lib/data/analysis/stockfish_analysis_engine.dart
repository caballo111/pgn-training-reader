import 'dart:async';

import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/foundation.dart';
import 'package:multistockfish/multistockfish.dart';

import '../../domain/analysis/analysis_engine.dart';

/// Default engine factory for product composition. Native Stockfish is
/// available on Android; other targets return an engine that reports an
/// actionable unavailable error when analysis is requested.
AnalysisEngine defaultAnalysisEngineFactory() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return StockfishAnalysisEngine();
  }
  return const _UnavailableAnalysisEngine();
}

/// Injectable seam around the native UCI session, used by controller tests.
abstract interface class StockfishUciTransport {
  Future<void> start(void Function(String line) onLine);
  bool get isReady;
  void send(String command);
  Future<void> dispose();
}

/// Creates the UCI transport used by a [StockfishAnalysisEngine].
typedef StockfishUciTransportFactory = StockfishUciTransport Function();

/// Local Stockfish 19 adapter using the package's native UCI engine.
///
/// The engine is started lazily on the first request. Each request is validated
/// against dartchess before any data is placed in a UCI command.
final class StockfishAnalysisEngine implements AnalysisEngine {
  StockfishAnalysisEngine({
    StockfishUciTransportFactory? transportFactory,
    this.cancellationGrace = const Duration(seconds: 3),
    this.watchdogGrace = const Duration(seconds: 2),
  }) : _transportFactory = transportFactory ?? _NativeStockfishTransport.new;

  final StockfishUciTransportFactory _transportFactory;
  final Duration cancellationGrace;
  final Duration watchdogGrace;

  StockfishUciTransport? _transport;
  Future<StockfishUciTransport>? _starting;
  _StockfishSearch? _activeSearch;
  Completer<void>? _readyWaiter;
  bool _configured = false;
  bool _disposed = false;
  int _generation = 0;

  static StockfishAnalysisEngine? _nativeOwner;
  static Future<void> _nativeLifecycle = Future<void>.value();

  /// Exposed for tests and diagnostics without initializing the native engine.
  static const int workerCount = 1;
  static const int principalVariationCount = 1;
  static const int hashMegabytes = 16;
  static const Duration maximumBudget = Duration(seconds: 5);

  @override
  Stream<AnalysisResult> analyze({
    required String startingFen,
    required List<String> moves,
    required Duration budget,
  }) {
    if (_disposed) {
      return Stream.error(StateError('Analysis engine is disposed.'));
    }
    final validated = _validateRequest(startingFen, moves);
    final requestedMilliseconds = budget.inMilliseconds;
    final boundedMilliseconds = requestedMilliseconds < 1
        ? 1
        : requestedMilliseconds > maximumBudget.inMilliseconds
        ? maximumBudget.inMilliseconds
        : requestedMilliseconds;
    final safeBudget = Duration(milliseconds: boundedMilliseconds);

    final previous = _activeSearch;
    if (previous != null && !previous.isFinished) {
      return Stream.error(
        StateError('Stop the active analysis before starting another search.'),
      );
    }

    late final _StockfishSearch search;
    final generation = ++_generation;
    final controller = StreamController<AnalysisResult>(
      onListen: () => unawaited(_runSearch(search)),
      onCancel: () => _stopSearch(search),
    );
    search = _StockfishSearch(
      generation: generation,
      startingFen: startingFen,
      moves: List<String>.unmodifiable(moves),
      finalPosition: validated.position,
      whiteToMove: validated.whiteToMove,
      budget: safeBudget,
      output: controller,
    );
    _activeSearch = search;
    return controller.stream;
  }

  @override
  Future<void> stop() {
    final search = _activeSearch;
    if (search == null) return Future<void>.value();
    return _stopSearch(search);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    await stop();
    await _withNativeLifecycle(() async {
      await _disposeNativeHandleLocked();
    });
  }

  Future<void> _runSearch(_StockfishSearch search) async {
    try {
      final engine = await _ensureEngine();
      if (!_isCurrent(search) || search.cancelled) {
        _finish(search);
        return;
      }

      if (!_configured) {
        engine.send('setoption name Threads value $workerCount');
        engine.send('setoption name MultiPV value $principalVariationCount');
        engine.send('setoption name Hash value $hashMegabytes');
        _configured = true;
        final ready = Completer<void>();
        _readyWaiter = ready;
        engine.send('isready');
        await ready.future.timeout(const Duration(seconds: 5));
        if (identical(_readyWaiter, ready)) _readyWaiter = null;
      }

      // Cancellation during native startup or option setup must not send a
      // position or go command after stop() has completed.
      if (!_isCurrent(search) || search.cancelled) {
        _finish(search);
        return;
      }

      final moves = search.moves.isEmpty
          ? ''
          : ' moves ${search.moves.join(' ')}';
      engine.send('position fen ${search.startingFen}$moves');
      search.started = true;
      engine.send('go movetime ${search.budget.inMilliseconds}');
      search.watchdog = Timer(
        search.budget + watchdogGrace,
        () => unawaited(_stopSearch(search, reportTimeout: true)),
      );
    } on Object catch (error, stackTrace) {
      _fail(search, error, stackTrace);
    }
  }

  Future<StockfishUciTransport> _ensureEngine() {
    if (_disposed) {
      return Future<StockfishUciTransport>.error(
        StateError('Analysis engine is disposed.'),
      );
    }
    final current = _transport;
    if (current != null) return Future<StockfishUciTransport>.value(current);
    final inProgress = _starting;
    if (inProgress != null) return inProgress;

    final starting = _withNativeLifecycle(() async {
      if (_disposed) throw StateError('Analysis engine is disposed.');
      final alreadyCreated = _transport;
      if (alreadyCreated != null) return alreadyCreated;

      final previousOwner = _nativeOwner;
      if (previousOwner != null && !identical(previousOwner, this)) {
        previousOwner._disposed = true;
        await previousOwner._disposeNativeHandleLocked();
      }
      if (_disposed) throw StateError('Analysis engine is disposed.');

      _nativeOwner = this;
      StockfishUciTransport? transport;
      try {
        transport = _transportFactory();
        _transport = transport;
        await transport.start(_handleLine);
        if (_disposed) {
          await transport.dispose();
          if (identical(_transport, transport)) _transport = null;
          if (identical(_nativeOwner, this)) _nativeOwner = null;
          throw StateError('Analysis engine was disposed while starting.');
        }
        _configured = false;
        return transport;
      } on Object {
        if (transport != null && identical(_transport, transport)) {
          _transport = null;
          await transport.dispose();
        }
        if (identical(_nativeOwner, this)) _nativeOwner = null;
        rethrow;
      }
    });
    _starting = starting;
    unawaited(
      starting.then<void>(
        (_) {
          if (identical(_starting, starting)) _starting = null;
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_starting, starting)) _starting = null;
        },
      ),
    );
    return starting;
  }

  Future<void> _stopSearch(
    _StockfishSearch search, {
    bool retireOnTimeout = true,
    bool reportTimeout = false,
  }) async {
    if (search.isFinished) return;
    search.cancelled = true;
    search.watchdog?.cancel();

    if (search.started && !search.stopSent) {
      search.stopSent = true;
      final engine = _transport;
      if (engine != null && engine.isReady) {
        try {
          engine.send('stop');
        } on Object catch (error, stackTrace) {
          _fail(search, error, stackTrace);
        }
      }
    }

    if (!search.done.isCompleted) {
      try {
        await search.done.future.timeout(cancellationGrace);
      } on TimeoutException {
        // UCI stop is cooperative. If a native search will not report its end,
        // retire the engine with Stockfish's bounded quit path.
        if (retireOnTimeout) {
          await _withNativeLifecycle(
            () => _disposeNativeHandleLocked(stopSearch: false),
          );
        }
        if (!search.isFinished) {
          final error = TimeoutException(
            'Stockfish did not stop the active search.',
          );
          if (reportTimeout) {
            _fail(search, error, StackTrace.current, reportWhenCancelled: true);
          } else {
            _finish(search);
          }
        }
      }
    }
  }

  void _handleLine(String line) {
    final ready = _readyWaiter;
    if (line.trim() == 'readyok' && ready != null && !ready.isCompleted) {
      ready.complete();
      return;
    }

    final search = _activeSearch;
    if (search == null || search.isFinished || !search.started) return;
    final trimmed = line.trim();
    if (trimmed.startsWith('info ')) {
      final result = _parseInfo(trimmed, search);
      if (result != null && !search.cancelled && _isCurrent(search)) {
        search.latest = result;
        search.output.add(result);
      }
    } else if (trimmed.startsWith('bestmove ')) {
      final result = _completeResult(trimmed, search);
      if (!search.cancelled && _isCurrent(search)) search.output.add(result);
      _finish(search);
    }
  }

  AnalysisResult? _parseInfo(String line, _StockfishSearch search) {
    final tokens = line.split(RegExp(r'\s+'));
    if (tokens.contains('lowerbound') || tokens.contains('upperbound')) {
      return null;
    }
    final depthIndex = tokens.indexOf('depth');
    final scoreIndex = tokens.indexOf('score');
    final pvIndex = tokens.indexOf('pv');
    if (depthIndex < 0 || scoreIndex < 0 || pvIndex < 0) return null;
    if (depthIndex + 1 >= tokens.length || scoreIndex + 2 >= tokens.length) {
      return null;
    }
    final depth = int.tryParse(tokens[depthIndex + 1]);
    if (depth == null || depth < 0) return null;

    int? centipawns;
    int? mate;
    final value = int.tryParse(tokens[scoreIndex + 2]);
    if (value == null) return null;
    switch (tokens[scoreIndex + 1]) {
      case 'cp':
        centipawns = value;
      case 'mate':
        mate = value;
      default:
        return null;
    }

    final variation = tokens.skip(pvIndex + 1).toList(growable: false);
    if (variation.isEmpty ||
        !_isLegalVariation(search.finalPosition, variation)) {
      return null;
    }
    return AnalysisResult(
      centipawns: centipawns == null
          ? null
          : (search.whiteToMove ? centipawns : -centipawns),
      mate: mate == null ? null : (search.whiteToMove ? mate : -mate),
      depth: depth,
      principalVariation: variation,
      isComplete: false,
    );
  }

  AnalysisResult _completeResult(String line, _StockfishSearch search) {
    final tokens = line.split(RegExp(r'\s+'));
    final bestMove = tokens.length > 1 ? tokens[1] : '';
    var result = search.latest;
    if (result == null) {
      final variation =
          _isUciMove(bestMove) &&
              _isLegalVariation(search.finalPosition, [bestMove])
          ? [bestMove]
          : const <String>[];
      result = AnalysisResult(
        depth: 0,
        principalVariation: variation,
        isComplete: true,
      );
    } else if (result.principalVariation.isEmpty &&
        _isUciMove(bestMove) &&
        _isLegalVariation(search.finalPosition, [bestMove])) {
      result = AnalysisResult(
        centipawns: result.centipawns,
        mate: result.mate,
        depth: result.depth,
        principalVariation: [bestMove],
        isComplete: true,
      );
    } else {
      result = AnalysisResult(
        centipawns: result.centipawns,
        mate: result.mate,
        depth: result.depth,
        principalVariation: result.principalVariation,
        isComplete: true,
      );
    }
    return result;
  }

  bool _isLegalVariation(chess.Chess position, List<String> moves) {
    var current = position;
    for (final uci in moves) {
      if (!_isUciMove(uci)) return false;
      final move = chess.Move.parse(uci);
      if (move == null || !current.isLegal(move)) return false;
      current = current.play(move) as chess.Chess;
    }
    return true;
  }

  Future<void> _disposeNativeHandleLocked({bool stopSearch = true}) async {
    final search = _activeSearch;
    if (stopSearch && search != null && !search.isFinished) {
      await _stopSearch(search, retireOnTimeout: false);
    }
    final engine = _transport;
    _transport = null;
    _configured = false;
    if (engine != null) await engine.dispose();
    if (identical(_nativeOwner, this)) _nativeOwner = null;
  }

  static Future<T> _withNativeLifecycle<T>(Future<T> Function() action) {
    final previous = _nativeLifecycle;
    final released = Completer<void>();
    final operation = Completer<T>();
    _nativeLifecycle = released.future;
    unawaited(() async {
      await previous;
      try {
        operation.complete(await action());
      } on Object catch (error, stackTrace) {
        operation.completeError(error, stackTrace);
      } finally {
        released.complete();
      }
    }());
    return operation.future;
  }

  void _finish(_StockfishSearch search) {
    if (search.isFinished) return;
    search.isFinished = true;
    search.watchdog?.cancel();
    if (identical(_activeSearch, search)) _activeSearch = null;
    if (!search.output.isClosed) unawaited(search.output.close());
    if (!search.done.isCompleted) search.done.complete();
  }

  void _fail(
    _StockfishSearch search,
    Object error,
    StackTrace stackTrace, {
    bool reportWhenCancelled = false,
  }) {
    if (search.isFinished) return;
    if ((!search.cancelled || reportWhenCancelled) &&
        !search.output.isClosed &&
        search.output.hasListener) {
      search.output.addError(error, stackTrace);
    }
    _finish(search);
  }

  bool _isCurrent(_StockfishSearch search) =>
      !_disposed &&
      !search.isFinished &&
      search.generation == _generation &&
      identical(_activeSearch, search);
}

class _StockfishSearch {
  _StockfishSearch({
    required this.generation,
    required this.startingFen,
    required this.moves,
    required this.finalPosition,
    required this.whiteToMove,
    required this.budget,
    required this.output,
  });

  final int generation;
  final String startingFen;
  final List<String> moves;
  final chess.Chess finalPosition;
  final bool whiteToMove;
  final Duration budget;
  final StreamController<AnalysisResult> output;
  final Completer<void> done = Completer<void>();
  AnalysisResult? latest;
  Timer? watchdog;
  bool started = false;
  bool stopSent = false;
  bool cancelled = false;
  bool isFinished = false;
}

class _ValidatedPosition {
  const _ValidatedPosition(this.position, this.whiteToMove);

  final chess.Chess position;
  final bool whiteToMove;
}

_ValidatedPosition _validateRequest(String startingFen, List<String> moves) {
  if (startingFen.length > 256 ||
      startingFen.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
    throw const FormatException(
      'The starting FEN contains invalid characters.',
    );
  }
  final fields = startingFen.trim().split(RegExp(r'\s+'));
  if (startingFen.trim() != startingFen ||
      fields.length != 6 ||
      (fields[1] != 'w' && fields[1] != 'b')) {
    throw const FormatException('Expected a complete six-field FEN.');
  }

  late chess.Chess position;
  try {
    position = chess.Chess.fromSetup(chess.Setup.parseFen(startingFen));
  } on Object catch (error) {
    throw FormatException('Invalid starting FEN: $error');
  }
  final whiteToMoveAtStart = fields[1] == 'w';
  for (var index = 0; index < moves.length; index++) {
    final uci = moves[index];
    if (!_isUciMove(uci)) {
      throw FormatException('Invalid UCI move at ply ${index + 1}.');
    }
    final move = chess.Move.parse(uci);
    if (move == null || !position.isLegal(move)) {
      throw FormatException('Illegal UCI move at ply ${index + 1}.');
    }
    position = position.play(move) as chess.Chess;
  }

  return _ValidatedPosition(
    position,
    whiteToMoveAtStart == moves.length.isEven,
  );
}

bool _isUciMove(String move) =>
    RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$').hasMatch(move);

final class _NativeStockfishTransport implements StockfishUciTransport {
  Stockfish? _engine;

  @override
  Future<void> start(void Function(String line) onLine) async {
    _engine = await Stockfish.create(
      flavor: StockfishFlavor.light,
      onStdout: onLine,
    );
  }

  @override
  bool get isReady => _engine?.state.value == StockfishState.ready;

  @override
  void send(String command) {
    final engine = _engine;
    if (engine == null) throw StateError('Stockfish has not started.');
    engine.stdin = command;
  }

  @override
  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    await engine?.dispose();
  }
}

final class _UnavailableAnalysisEngine implements AnalysisEngine {
  const _UnavailableAnalysisEngine();

  @override
  Stream<AnalysisResult> analyze({
    required String startingFen,
    required List<String> moves,
    required Duration budget,
  }) => Stream.error(
    UnsupportedError('Local Stockfish analysis is available on Android.'),
  );

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
