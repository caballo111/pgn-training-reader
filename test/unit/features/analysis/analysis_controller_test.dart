import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/analysis/analysis_engine.dart';
import 'package:pgntrainingreader/features/analysis/application/analysis_controller.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  group('AnalysisController', () {
    test(
      'debounces position changes, stops old work, and ignores stale output',
      () async {
        final engine = _FakeAnalysisEngine();
        final controller = AnalysisController(
          engineFactory: () => engine,
          debounce: const Duration(milliseconds: 1),
        );
        controller.updatePosition(startingFen: _startFen, moves: const []);
        await controller.setEnabled(true);
        await _waitFor(() => engine.requests.length == 1);

        controller.updatePosition(
          startingFen: _startFen,
          moves: const ['e2e4'],
        );
        expect(controller.result, isNull);
        await _waitFor(() => engine.requests.length == 2);

        engine.requests[1].controller.add(
          const AnalysisResult(
            centipawns: 42,
            depth: 8,
            principalVariation: ['e7e5'],
            isComplete: true,
          ),
        );
        await _waitFor(() => controller.status == AnalysisStatus.ready);
        engine.requests[0].controller.add(
          const AnalysisResult(
            centipawns: 99,
            depth: 30,
            principalVariation: ['e2e4'],
            isComplete: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(engine.stopCount, greaterThanOrEqualTo(1));
        expect(
          engine.events.indexOf('stop'),
          lessThan(engine.events.lastIndexOf('analyze')),
        );
        expect(controller.result?.centipawns, 42);
        expect(controller.status, AnalysisStatus.ready);
        await controller.disposeAsyncForTest();
      },
    );

    test(
      'disable clears output and stops analysis; lifecycle resume is explicit',
      () async {
        final engine = _FakeAnalysisEngine();
        final controller = AnalysisController(
          engineFactory: () => engine,
          debounce: Duration.zero,
        );
        controller.updatePosition(startingFen: _startFen, moves: const []);
        await controller.setEnabled(true);
        await _waitFor(() => engine.requests.length == 1);
        engine.requests.single.controller.add(
          const AnalysisResult(
            centipawns: 25,
            depth: 4,
            principalVariation: ['e2e4'],
            isComplete: false,
          ),
        );
        await _waitFor(() => controller.result != null);

        await controller.setEnabled(false);
        expect(controller.status, AnalysisStatus.off);
        expect(controller.result, isNull);
        expect(engine.stopCount, 1);

        await controller.setEnabled(true);
        await _waitFor(() => engine.requests.length == 2);
        await controller.pause();
        expect(controller.status, AnalysisStatus.paused);
        final countWhenPaused = engine.requests.length;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(engine.requests.length, countWhenPaused);
        controller.resume();
        await _waitFor(() => engine.requests.length == countWhenPaused + 1);
        await controller.disposeAsyncForTest();
      },
    );

    test(
      'a later Off intent cancels retry while shutdown is pending',
      () async {
        final engine = _FakeAnalysisEngine();
        final controller = AnalysisController(
          engineFactory: () => engine,
          debounce: Duration.zero,
        );
        controller.updatePosition(startingFen: _startFen, moves: const []);
        await controller.setEnabled(true);
        await _waitFor(() => engine.requests.length == 1);

        engine.stopGate = Completer<void>();
        final retry = controller.retry();
        await _waitFor(() => engine.stopCount >= 1);
        final disable = controller.setEnabled(false);
        engine.stopGate!.complete();
        await Future.wait([retry, disable]);

        expect(engine.requests, hasLength(1));
        expect(controller.status, AnalysisStatus.off);
        await controller.disposeAsyncForTest();
      },
    );
  });
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition was not met before the test deadline.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

class _FakeAnalysisEngine implements AnalysisEngine {
  final List<_Request> requests = [];
  final List<String> events = [];
  int stopCount = 0;
  Completer<void>? stopGate;

  @override
  Stream<AnalysisResult> analyze({
    required String startingFen,
    required List<String> moves,
    required Duration budget,
  }) {
    events.add('analyze');
    final request = _Request(startingFen, List.of(moves), budget);
    requests.add(request);
    return request.controller.stream;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    events.add('stop');
    await stopGate?.future;
  }

  @override
  Future<void> dispose() async {
    for (final request in requests) {
      if (!request.controller.isClosed) await request.controller.close();
    }
  }
}

class _Request {
  _Request(this.startingFen, this.moves, this.budget);

  final String startingFen;
  final List<String> moves;
  final Duration budget;
  final StreamController<AnalysisResult> controller =
      StreamController<AnalysisResult>.broadcast();
}

extension on AnalysisController {
  Future<void> disposeAsyncForTest() async {
    dispose();
    await Future<void>.delayed(Duration.zero);
  }
}
