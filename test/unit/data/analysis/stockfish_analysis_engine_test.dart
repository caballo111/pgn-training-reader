import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/analysis/stockfish_analysis_engine.dart';
import 'package:pgntrainingreader/domain/analysis/analysis_engine.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  group('StockfishAnalysisEngine', () {
    test(
      'sends bounded UCI commands and returns White-relative scores',
      () async {
        final transport = _FakeTransport(
          onGo: (emit) {
            emit('info depth 8 score cp 34 pv e7e5 g1f3');
            emit('bestmove e7e5 ponder g1f3');
          },
        );
        final engine = StockfishAnalysisEngine(
          transportFactory: () => transport,
        );

        final results = await engine
            .analyze(
              startingFen: _startFen,
              moves: const ['e2e4'],
              budget: const Duration(milliseconds: 1000),
            )
            .toList();

        expect(results, hasLength(2));
        expect(results.first.centipawns, -34);
        expect(results.first.principalVariation, ['e7e5', 'g1f3']);
        expect(results.last.isComplete, isTrue);
        expect(results.last.centipawns, -34);
        expect(transport.commands, contains('setoption name Threads value 1'));
        expect(transport.commands, contains('setoption name MultiPV value 1'));
        expect(transport.commands, contains('setoption name Hash value 16'));
        expect(
          transport.commands,
          contains('position fen $_startFen moves e2e4'),
        );
        expect(transport.commands, contains('go movetime 1000'));

        await engine.dispose();
        expect(transport.isDisposed, isTrue);
      },
    );

    test(
      'caps externally supplied budgets at the deeper-search limit',
      () async {
        final transport = _FakeTransport(onGo: (emit) => emit('bestmove e2e4'));
        final engine = StockfishAnalysisEngine(
          transportFactory: () => transport,
        );

        await engine
            .analyze(
              startingFen: _startFen,
              moves: const [],
              budget: const Duration(minutes: 1),
            )
            .toList();

        expect(transport.commands, contains('go movetime 5000'));
        await engine.dispose();
      },
    );

    test(
      'rejects malformed FEN, illegal moves, and UCI injection before start',
      () async {
        var created = false;
        final engine = StockfishAnalysisEngine(
          transportFactory: () {
            created = true;
            return _FakeTransport();
          },
        );

        expect(
          () => engine.analyze(
            startingFen: '$_startFen\nquit',
            moves: const [],
            budget: const Duration(seconds: 1),
          ),
          throwsFormatException,
        );
        expect(
          () => engine.analyze(
            startingFen: _startFen,
            moves: const ['e2e5'],
            budget: const Duration(seconds: 1),
          ),
          throwsFormatException,
        );
        expect(
          () => engine.analyze(
            startingFen: _startFen,
            moves: const ['e2e4\nquit'],
            budget: const Duration(seconds: 1),
          ),
          throwsFormatException,
        );
        expect(created, isFalse);
        await engine.dispose();
      },
    );

    test(
      'ignores bound or illegal PV output and completes from bestmove',
      () async {
        final transport = _FakeTransport(
          onGo: (emit) {
            emit('info depth 10 score cp 50 lowerbound pv e7e5');
            emit('info depth 11 score cp 60 pv e7e6 a1a8');
            emit('bestmove e7e5');
          },
        );
        final engine = StockfishAnalysisEngine(
          transportFactory: () => transport,
        );

        final results = await engine
            .analyze(
              startingFen: _startFen,
              moves: const ['e2e4'],
              budget: const Duration(seconds: 1),
            )
            .toList();

        expect(results, hasLength(1));
        expect(results.single.isComplete, isTrue);
        expect(results.single.centipawns, isNull);
        expect(results.single.principalVariation, ['e7e5']);
        await engine.dispose();
      },
    );

    test(
      'stop during initialization prevents position and go commands',
      () async {
        final transport = _FakeTransport(waitForStart: true);
        final engine = StockfishAnalysisEngine(
          transportFactory: () => transport,
        );
        final done = Completer<void>();
        final subscription = engine
            .analyze(
              startingFen: _startFen,
              moves: const [],
              budget: const Duration(seconds: 1),
            )
            .listen((_) {}, onDone: done.complete);

        await transport.startBegan.future;
        final stopping = engine.stop();
        transport.allowStart.complete();
        await stopping;
        await done.future;

        expect(
          transport.commands.where((line) => line.startsWith('position ')),
          isEmpty,
        );
        expect(
          transport.commands.where((line) => line.startsWith('go ')),
          isEmpty,
        );
        await subscription.cancel();
        await engine.dispose();
      },
    );

    test('stop cancels the active UCI search before returning', () async {
      final transport = _FakeTransport();
      final engine = StockfishAnalysisEngine(transportFactory: () => transport);
      final done = Completer<void>();
      final seen = <AnalysisResult>[];
      final subscription = engine
          .analyze(
            startingFen: _startFen,
            moves: const [],
            budget: const Duration(seconds: 1),
          )
          .listen(seen.add, onDone: done.complete);

      await transport.goSent.future;
      await engine.stop();
      await done.future;

      expect(transport.commands, contains('stop'));
      expect(seen, isEmpty);
      await subscription.cancel();
      await engine.dispose();
    });

    test('watchdog bounds a search that ignores UCI stop', () async {
      final transport = _FakeTransport(respondToStop: false);
      final engine = StockfishAnalysisEngine(
        transportFactory: () => transport,
        cancellationGrace: const Duration(milliseconds: 10),
        watchdogGrace: Duration.zero,
      );

      await expectLater(
        engine
            .analyze(
              startingFen: _startFen,
              moves: const [],
              budget: const Duration(milliseconds: 1),
            )
            .toList(),
        throwsA(isA<TimeoutException>()),
      );
      expect(transport.commands, contains('stop'));
      expect(transport.isDisposed, isTrue);
      await engine.dispose();
    });
  });
}

typedef _GoOutput = void Function(void Function(String) emit);

class _FakeTransport implements StockfishUciTransport {
  _FakeTransport({
    this.onGo,
    this.respondToStop = true,
    this.waitForStart = false,
  });

  final _GoOutput? onGo;
  final bool respondToStop;
  final bool waitForStart;
  final List<String> commands = [];
  final Completer<void> startBegan = Completer<void>();
  final Completer<void> allowStart = Completer<void>();
  final Completer<void> goSent = Completer<void>();
  void Function(String)? _onLine;
  bool isDisposed = false;

  @override
  bool get isReady => _onLine != null && !isDisposed;

  @override
  Future<void> start(void Function(String line) onLine) async {
    _onLine = onLine;
    if (!startBegan.isCompleted) startBegan.complete();
    if (waitForStart) await allowStart.future;
  }

  @override
  void send(String command) {
    commands.add(command);
    if (command == 'isready') {
      _emit('readyok');
    } else if (command.startsWith('go ')) {
      if (!goSent.isCompleted) goSent.complete();
      onGo?.call(_emit);
    } else if (command == 'stop' && respondToStop) {
      _emit('bestmove e2e4');
    }
  }

  void _emit(String line) => _onLine?.call(line);

  @override
  Future<void> dispose() async {
    isDisposed = true;
    _onLine = null;
  }
}
