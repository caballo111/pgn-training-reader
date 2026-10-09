import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/analysis/analysis_engine.dart';
import 'package:pgntrainingreader/features/analysis/presentation/analysis_panel.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  testWidgets('starts off and does not create an engine until opted in', (
    tester,
  ) async {
    var factoryCalls = 0;
    await tester.pumpWidget(
      _host(
        engineFactory: () {
          factoryCalls++;
          return _FakeEngine();
        },
      ),
    );

    expect(find.text('Engine: Off'), findsOneWidget);
    expect(find.byKey(const ValueKey('analysis-evaluation')), findsNothing);
    expect(factoryCalls, 0);
    final engineSemantics = tester.getSemantics(
      find.bySemanticsLabel('Local engine analysis'),
    );
    expect(engineSemantics.getSemanticsData().value, 'Off');

    await _enable(tester);
    expect(factoryCalls, 1);
  });

  testWidgets('shows no analysis controls when the position is invalid', (
    tester,
  ) async {
    var factoryCalls = 0;
    await tester.pumpWidget(
      _host(
        startingFen: 'not a FEN',
        engineFactory: () {
          factoryCalls++;
          return _FakeEngine();
        },
      ),
    );

    expect(find.byType(SwitchListTile), findsNothing);
    expect(factoryCalls, 0);
  });

  testWidgets('invalidating the current position stops active analysis', (
    tester,
  ) async {
    final engine = _FakeEngine();
    await tester.pumpWidget(_host(engineFactory: () => engine));
    await _enable(tester);
    await tester.pumpAndSettle();
    final stopCalls = engine.stopCalls;

    await tester.pumpWidget(
      _host(startingFen: 'not a FEN', engineFactory: () => engine),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SwitchListTile), findsNothing);
    expect(engine.stopCalls, greaterThan(stopCalls));
  });

  testWidgets(
    'shows a fixed White-relative score and gates the PV explicitly',
    (tester) async {
      final engine = _FakeEngine(
        result: const AnalysisResult(
          depth: 11,
          centipawns: -37,
          principalVariation: ['e7e5', 'g1f3'],
          isComplete: true,
        ),
      );
      List<String>? explored;
      await tester.pumpWidget(
        _host(
          moves: const ['e2e4'], // Black to move; score remains White-relative.
          engineFactory: () => engine,
          onExploreSuggestion: (moves) => explored = moves,
        ),
      );
      await _enable(tester);
      await tester.pumpAndSettle();

      expect(find.text('Evaluation (White): −0.37'), findsOneWidget);
      expect(find.text('Depth 11'), findsOneWidget);
      expect(find.byKey(const ValueKey('analysis-suggestion')), findsNothing);

      await tester.tap(find.text('Show suggestion'));
      await tester.pumpAndSettle();
      expect(find.text('Suggested line: e7e5 g1f3'), findsOneWidget);
      expect(explored, isNull);

      await tester.tap(find.text('Explore suggestion'));
      await tester.pumpAndSettle();
      expect(explored, ['e7e5', 'g1f3']);
    },
  );

  testWidgets(
    'uses a finite deeper budget and retries failed engines in place',
    (tester) async {
      final engine = _FakeEngine(failuresRemaining: 1);
      await tester.pumpWidget(
        _host(moves: const ['e2e4', 'e7e5'], engineFactory: () => engine),
      );
      await _enable(tester);
      await tester.pumpAndSettle();

      expect(find.text('Engine unavailable.'), findsOneWidget);
      expect(
        find.textContaining('You can still explore moves'),
        findsOneWidget,
      );
      expect(find.text('Retry engine'), findsOneWidget);
      expect(engine.requests, hasLength(1));

      await tester.tap(find.text('Retry engine'));
      await tester.pumpAndSettle();
      expect(engine.requests, hasLength(2));
      expect(engine.requests.last.moves, ['e2e4', 'e7e5']);
      expect(find.text('Analysis ready.'), findsOneWidget);

      await tester.tap(find.text('Analyze deeper'));
      await tester.pumpAndSettle();
      expect(engine.requests, hasLength(3));
      expect(engine.requests.last.budget, const Duration(seconds: 5));
    },
  );

  testWidgets('turning engine off cancels a retry waiting for stop', (
    tester,
  ) async {
    final stopGate = Completer<void>();
    final engine = _FakeEngine(failuresRemaining: 1, stopGate: stopGate);
    await tester.pumpWidget(_host(engineFactory: () => engine));
    await _enable(tester);
    expect(find.text('Retry engine'), findsOneWidget);
    expect(engine.requests, hasLength(1));

    await tester.tap(find.text('Retry engine'));
    await tester.pump();
    expect(engine.stopCalls, 1);

    // The retry is suspended in setEnabled(false)'s native stop barrier.
    // Turning the engine off must invalidate its captured intent.
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(find.text('Engine: Off'), findsOneWidget);

    stopGate.complete();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Engine: Off'), findsOneWidget);
    expect(find.byKey(const ValueKey('analysis-evaluation')), findsNothing);
    expect(engine.requests, hasLength(1));
  });

  testWidgets('a position update clears old output and drops late results', (
    tester,
  ) async {
    final engine = _FakeEngine(controlledStreams: true);
    await tester.pumpWidget(_host(engineFactory: () => engine));
    await _enableWithoutSettling(tester);
    expect(engine.requests, hasLength(1));

    engine.emit(
      0,
      const AnalysisResult(
        depth: 7,
        centipawns: 12,
        principalVariation: ['e2e4'],
        isComplete: true,
      ),
    );
    await tester.pump();
    expect(find.text('Evaluation (White): +0.12'), findsOneWidget);

    await tester.pumpWidget(
      _host(moves: const ['d2d4'], engineFactory: () => engine),
    );
    expect(find.byKey(const ValueKey('analysis-evaluation')), findsNothing);
    expect(find.text('Analyzing position…'), findsOneWidget);

    // The canceled request can still deliver a late event from a broadcast
    // stream; its old generation must remain invisible on the new position.
    engine.emit(
      0,
      const AnalysisResult(
        depth: 99,
        centipawns: 900,
        principalVariation: ['e2e4'],
        isComplete: true,
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('analysis-evaluation')), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 1));
    expect(engine.requests, hasLength(2));
    expect(engine.requests.last.moves, ['d2d4']);
    engine.emit(
      1,
      const AnalysisResult(
        depth: 8,
        centipawns: -20,
        principalVariation: ['d2d4'],
        isComplete: true,
      ),
    );
    await tester.pump();
    expect(find.text('Evaluation (White): −0.20'), findsOneWidget);
  });

  testWidgets('background pauses and foreground requires explicit resume', (
    tester,
  ) async {
    final engine = _FakeEngine();
    await tester.pumpWidget(_host(engineFactory: () => engine));
    await _enable(tester);
    await tester.pumpAndSettle();
    expect(engine.requests, hasLength(1));
    expect(find.byKey(const ValueKey('analysis-evaluation')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('Analysis paused.'), findsOneWidget);
    expect(find.byKey(const ValueKey('analysis-evaluation')), findsNothing);
    expect(engine.stopCalls, greaterThan(0));
    final requestCount = engine.requests.length;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(engine.requests, hasLength(requestCount));
    expect(find.text('Resume analysis'), findsOneWidget);

    await tester.tap(find.text('Resume analysis'));
    await tester.pumpAndSettle();
    expect(engine.requests, hasLength(requestCount + 1));
    expect(find.text('Analysis ready.'), findsOneWidget);
  });

  testWidgets('disabling eligibility clears output and stops the engine', (
    tester,
  ) async {
    final engine = _FakeEngine();
    await tester.pumpWidget(_host(engineFactory: () => engine, enabled: true));
    await _enable(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('analysis-evaluation')), findsOneWidget);
    final stopCalls = engine.stopCalls;

    await tester.pumpWidget(_host(engineFactory: () => engine, enabled: false));
    await tester.pumpAndSettle();
    expect(find.text('Engine: Off'), findsOneWidget);
    expect(find.byKey(const ValueKey('analysis-evaluation')), findsNothing);
    expect(engine.stopCalls, greaterThan(stopCalls));
  });

  testWidgets('prepareToLeave stops and disposes the active engine', (
    tester,
  ) async {
    final engine = _FakeEngine();
    final panelKey = GlobalKey<AnalysisPanelState>();
    await tester.pumpWidget(
      _host(engineFactory: () => engine, panelKey: panelKey),
    );
    await _enable(tester);
    await tester.pumpAndSettle();

    await panelKey.currentState!.prepareToLeave();
    await tester.pumpAndSettle();

    expect(find.text('Analysis paused.'), findsOneWidget);
    expect(engine.stopCalls, 1);
    expect(engine.disposeCalls, 1);
  });

  testWidgets('fits a 320px surface with enlarged text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(textScaler: TextScaler.linear(2)));
    expect(find.text('Engine: Off'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Local engine analysis'))
          .getSemanticsData()
          .value,
      'Off',
    );
    expect(
      tester.getSize(find.byType(SwitchListTile)).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _enable(WidgetTester tester) async {
  await tester.tap(find.byType(SwitchListTile));
  await tester.pumpAndSettle();
}

Future<void> _enableWithoutSettling(WidgetTester tester) async {
  await tester.tap(find.byType(SwitchListTile));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

Widget _host({
  String startingFen = _startFen,
  List<String> moves = const [],
  AnalysisEngineFactory? engineFactory,
  ValueChanged<List<String>>? onExploreSuggestion,
  bool enabled = true,
  TextScaler? textScaler,
  Key? panelKey,
}) => MaterialApp(
  builder: (context, child) => textScaler == null
      ? child!
      : MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
  home: Scaffold(
    body: AnalysisPanel(
      key: panelKey,
      startingFen: startingFen,
      moves: moves,
      engineFactory: engineFactory,
      onExploreSuggestion: onExploreSuggestion,
      enabled: enabled,
    ),
  ),
);

class _Request {
  const _Request({
    required this.startingFen,
    required this.moves,
    required this.budget,
  });

  final String startingFen;
  final List<String> moves;
  final Duration budget;
}

class _FakeEngine implements AnalysisEngine {
  _FakeEngine({
    this.result = const AnalysisResult(
      depth: 8,
      centipawns: 31,
      principalVariation: ['e2e4', 'e7e5'],
      isComplete: true,
    ),
    this.failuresRemaining = 0,
    this.controlledStreams = false,
    this.stopGate,
  });

  final AnalysisResult result;
  int failuresRemaining;
  final bool controlledStreams;
  final Completer<void>? stopGate;
  final requests = <_Request>[];
  final streams = <StreamController<AnalysisResult>>[];
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<AnalysisResult> analyze({
    required String startingFen,
    required List<String> moves,
    required Duration budget,
  }) {
    requests.add(
      _Request(
        startingFen: startingFen,
        moves: List.unmodifiable(moves),
        budget: budget,
      ),
    );
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw UnsupportedError('No engine on this platform.');
    }
    if (controlledStreams) {
      final stream = StreamController<AnalysisResult>.broadcast(sync: true);
      streams.add(stream);
      return stream.stream;
    }
    return Stream<AnalysisResult>.fromIterable([result]);
  }

  void emit(int index, AnalysisResult result) => streams[index].add(result);

  @override
  Future<void> stop() async {
    stopCalls++;
    final gate = stopGate;
    if (gate != null && !gate.isCompleted) await gate.future;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    for (final stream in streams) {
      if (!stream.isClosed) await stream.close();
    }
  }
}
