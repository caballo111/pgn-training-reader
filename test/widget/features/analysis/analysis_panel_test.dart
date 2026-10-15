import 'dart:async';

import 'package:chessground/chessground.dart' as chessground;
import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/analysis/analysis_engine.dart';
import 'package:pgntrainingreader/features/analysis/presentation/analysis_panel.dart';
import 'package:pgntrainingreader/shared/chessboard/move_arrows.dart';

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
    'numbers the engine line in SAN and previews selected moves before adding',
    (tester) async {
      final engine = _FakeEngine(
        result: const AnalysisResult(
          depth: 11,
          centipawns: -37,
          principalVariation: ['e7e5', 'g1f3', 'b8c6'],
          isComplete: true,
        ),
      );
      List<String>? added;
      await tester.pumpWidget(
        _host(
          moves: const ['e2e4'], // Black to move; score remains White-relative.
          engineFactory: () => engine,
          onExploreSuggestion: (moves) => added = moves,
          compact: true,
        ),
      );
      await _enable(tester);
      await tester.pumpAndSettle();

      expect(find.text('White −0.37 · Black to move'), findsOneWidget);
      expect(find.text('Depth 11'), findsOneWidget);
      expect(find.textContaining('e7e5'), findsNothing);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('compact-analysis-row')))
            .height,
        48,
      );

      await tester.tap(find.byKey(const ValueKey('view-engine-line')));
      await tester.pumpAndSettle();
      expect(find.text('Engine line preview'), findsOneWidget);
      expect(find.text('Start of engine line · Black to move'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('engine-line-preview-move-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('engine-line-preview-move-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('engine-line-preview-move-3')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('engine-line-preview-move-1')))
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(find.textContaining('e7e5'), findsNothing);
      expect(added, isNull);
      expect(
        tester
            .widget<chessground.StaticChessboard>(
              find.byKey(const ValueKey('engine-line-board')),
            )
            .fen,
        _positionFen(const ['e2e4']),
      );

      await tester.tap(
        find.byKey(const ValueKey('engine-line-preview-move-3')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChessboardMoveArrows>(find.byType(ChessboardMoveArrows))
            .moves,
        ['b8c6'],
      );
      expect(find.text('After 2... Nc6 · White to move'), findsOneWidget);
      expect(
        tester
            .widget<chessground.StaticChessboard>(
              find.byKey(const ValueKey('engine-line-board')),
            )
            .fen,
        _positionFen(const ['e2e4', 'e7e5', 'g1f3', 'b8c6']),
      );
      expect(added, isNull);

      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChessboardMoveArrows>(find.byType(ChessboardMoveArrows))
            .moves,
        ['g1f3'],
      );
      expect(find.text('After 2. Nf3 · Black to move'), findsOneWidget);
      expect(
        tester
            .widget<chessground.StaticChessboard>(
              find.byKey(const ValueKey('engine-line-board')),
            )
            .fen,
        _positionFen(const ['e2e4', 'e7e5', 'g1f3']),
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('After 2... Nc6 · White to move'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(added, isNull);

      await tester.tap(find.byKey(const ValueKey('view-engine-line')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add line to exploration'));
      await tester.pumpAndSettle();
      expect(added, ['e7e5', 'g1f3', 'b8c6']);
    },
  );

  testWidgets('does not expose a legal prefix of an invalid engine line', (
    tester,
  ) async {
    final engine = _FakeEngine(
      result: const AnalysisResult(
        depth: 9,
        centipawns: 20,
        principalVariation: ['e2e4', 'e2e4'],
        isComplete: true,
      ),
    );
    var addCalls = 0;
    await tester.pumpWidget(
      _host(
        engineFactory: () => engine,
        onExploreSuggestion: (_) => addCalls++,
      ),
    );
    await _enable(tester);
    await tester.pumpAndSettle();

    expect(find.text('Engine line unavailable.'), findsOneWidget);
    expect(find.byKey(const ValueKey('view-engine-line')), findsNothing);
    expect(find.byKey(const ValueKey('engine-line-move-1')), findsNothing);
    expect(find.text('Add line to exploration'), findsNothing);
    expect(addCalls, 0);
  });

  testWidgets('adding a line does not pop the parent route during handoff', (
    tester,
  ) async {
    final engine = _FakeEngine();
    final panelKey = GlobalKey<AnalysisPanelState>();
    List<String>? added;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: AnalysisPanel(
                  key: panelKey,
                  startingFen: _startFen,
                  moves: const [],
                  engineFactory: () => engine,
                  compact: true,
                  onExploreSuggestion: (moves) {
                    added = moves;
                    unawaited(panelKey.currentState!.prepareToLeave());
                  },
                ),
              ),
              const Text(
                'Parent route remains',
                key: ValueKey<String>('parent-route-remains'),
              ),
            ],
          ),
        ),
      ),
    );
    await _enable(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('view-engine-line')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add line to exploration'));
    await tester.pumpAndSettle();

    expect(added, ['e2e4', 'e7e5']);
    expect(find.byKey(const ValueKey('parent-route-remains')), findsOneWidget);
    expect(find.text('Engine line preview'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a position update closes only the owned line preview', (
    tester,
  ) async {
    final engine = _FakeEngine();
    final panelKey = GlobalKey<AnalysisPanelState>();
    Widget host(List<String> moves) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: AnalysisPanel(
                key: panelKey,
                startingFen: _startFen,
                moves: moves,
                engineFactory: () => engine,
                compact: true,
              ),
            ),
            const Text(
              'Parent route remains',
              key: ValueKey<String>('parent-route-remains'),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(host(const []));
    await _enable(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('view-engine-line')));
    await tester.pumpAndSettle();
    expect(find.text('Engine line preview'), findsOneWidget);

    await tester.pumpWidget(host(const ['e2e4']));
    await tester.pumpAndSettle();

    expect(find.text('Engine line preview'), findsNothing);
    expect(find.byKey(const ValueKey('parent-route-remains')), findsOneWidget);
    expect(panelKey.currentState, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact analysis stays a short row at narrow enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = _FakeEngine();
    await tester.pumpWidget(
      _host(
        engineFactory: () => engine,
        compact: true,
        textScaler: TextScaler.linear(2),
      ),
    );
    await _enable(tester);
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('compact-analysis-row'))).height,
      64,
    );
    expect(find.text('White +0.31'), findsOneWidget);
    expect(find.text('White to move'), findsOneWidget);
    expect(find.text('Depth 8'), findsNothing);
    expect(find.byKey(const ValueKey('view-engine-line')), findsOneWidget);
    expect(find.text('Analyze deeper'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('engine-controls-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Analyze deeper'), findsOneWidget);
    await tester.tap(find.text('Analyze deeper'));
    await tester.pumpAndSettle();
    expect(engine.requests, hasLength(2));
    expect(engine.requests.last.budget, const Duration(seconds: 5));
  });

  testWidgets('compact analysis keeps controls reachable in a narrow pane', (
    tester,
  ) async {
    final engine = _FakeEngine();
    await tester.pumpWidget(
      _host(engineFactory: () => engine, compact: true, panelWidth: 180),
    );
    await _enable(tester);
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('compact-analysis-row'))).height,
      96,
    );
    expect(find.byKey(const ValueKey('view-engine-line')), findsOneWidget);
    expect(find.byKey(const ValueKey('engine-controls-menu')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('engine preview board scales down for landscape height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = _FakeEngine();
    await tester.pumpWidget(_host(engineFactory: () => engine, compact: true));
    await _enable(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('view-engine-line')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<chessground.StaticChessboard>(
            find.byKey(const ValueKey('engine-line-board')),
          )
          .size,
      lessThanOrEqualTo(144),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps revealed suggestions through three moves and deeper analysis, then resets off',
    (tester) async {
      final engine = _FakeEngine(controlledStreams: true);
      AnalysisEngine engineFactory() => engine;
      final panelKey = GlobalKey<AnalysisPanelState>();
      await tester.pumpWidget(
        _host(engineFactory: engineFactory, panelKey: panelKey),
      );
      await _enableWithoutSettling(tester);
      expect(panelKey.currentState!.engineRequested, isTrue);
      expect(engine.requests, hasLength(1));

      engine.emit(0, _lineResult(const ['e2e4', 'e7e5', 'g1f3']));
      await tester.pump();
      await tester.tap(find.text('View engine line'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('engine-line-move-1')), findsOneWidget);

      final positions = <({List<String> moves, List<String> pv})>[
        (moves: const ['e2e4'], pv: const ['e7e5', 'g1f3', 'b8c6']),
        (
          moves: const ['e2e4', 'e7e5', 'g1f3'],
          pv: const ['b8c6', 'f1b5', 'a7a6'],
        ),
        (
          moves: const ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5'],
          pv: const ['a7a6', 'b5a4', 'g8f6'],
        ),
      ];
      for (var index = 0; index < positions.length; index++) {
        await tester.pumpWidget(
          _host(
            moves: positions[index].moves,
            engineFactory: engineFactory,
            panelKey: panelKey,
          ),
        );
        expect(find.byKey(const ValueKey('analysis-evaluation')), findsNothing);
        expect(find.byKey(const ValueKey('engine-line-move-1')), findsNothing);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 1));
        expect(engine.requests, hasLength(index + 2));
        engine.emit(index + 1, _lineResult(positions[index].pv));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('engine-line-move-1')),
          findsOneWidget,
        );
      }

      await tester.tap(find.byKey(const ValueKey('analyze-deeper')));
      await tester.pump();
      expect(find.byKey(const ValueKey('analysis-evaluation')), findsNothing);
      expect(find.byKey(const ValueKey('engine-line-move-1')), findsNothing);
      for (
        var attempt = 0;
        attempt < 10 && engine.requests.length < 5;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(engine.requests, hasLength(5));
      expect(engine.requests.last.budget, const Duration(seconds: 5));
      engine.emit(4, _lineResult(const ['a7a6', 'b5a4', 'g8f6']));
      await tester.pump();
      expect(find.byKey(const ValueKey('engine-line-move-1')), findsOneWidget);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(panelKey.currentState!.engineRequested, isFalse);
      expect(find.byKey(const ValueKey('engine-line-move-1')), findsNothing);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      for (
        var attempt = 0;
        attempt < 10 && engine.requests.length < 6;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(engine.requests, hasLength(6));
      engine.emit(5, _lineResult(const ['a7a6', 'b5a4', 'g8f6']));
      await tester.pump();
      expect(find.byKey(const ValueKey('engine-line-move-1')), findsNothing);
      expect(find.text('View engine line'), findsOneWidget);
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
    AnalysisEngine engineFactory() => engine;
    await tester.pumpWidget(_host(engineFactory: engineFactory));
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
    expect(find.text('White +0.12 · White to move'), findsOneWidget);

    await tester.pumpWidget(
      _host(moves: const ['d2d4'], engineFactory: engineFactory),
    );
    expect(find.byKey(const ValueKey('analysis-evaluation')), findsNothing);
    expect(find.text('Analyzing position…'), findsOneWidget);

    // A canceled request can still produce a late result. It must never
    // become visible on the newly selected position.
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
    expect(find.text('White −0.20 · Black to move'), findsOneWidget);
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

  testWidgets(
    'publishes one legal current engine move and clears stale arrows',
    (tester) async {
      final engine = _FakeEngine(controlledStreams: true);
      AnalysisEngine engineFactory() => engine;
      final arrowUpdates = <List<String>>[];
      final panelKey = GlobalKey<AnalysisPanelState>();
      Widget host(List<String> moves) => _host(
        moves: moves,
        engineFactory: engineFactory,
        panelKey: panelKey,
        compact: true,
        onSuggestionArrowsChanged: (moves) =>
            arrowUpdates.add(List.unmodifiable(moves)),
      );

      await tester.pumpWidget(host(const []));
      await _enableWithoutSettling(tester);
      engine.emit(0, _lineResult(const ['e2e4', 'e7e5', 'g1f3']));
      await tester.pump();
      expect(arrowUpdates.last, isEmpty);

      await tester.tap(find.byKey(const ValueKey('view-engine-line')));
      await tester.pumpAndSettle();
      expect(arrowUpdates.last, ['e2e4']);
      expect(arrowUpdates.last, isNot(contains('e7e5')));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('engine-controls-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide suggestions'));
      await tester.pumpAndSettle();
      expect(arrowUpdates.last, isEmpty);

      await tester.tap(find.byKey(const ValueKey('view-engine-line')));
      await tester.pumpAndSettle();
      expect(arrowUpdates.last, ['e2e4']);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(host(const ['e2e4']));
      await tester.pump();
      expect(arrowUpdates.last, isEmpty);
      engine.emit(0, _lineResult(const ['e2e4', 'e7e5']));
      await tester.pump();
      expect(arrowUpdates.last, isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1));
      expect(engine.requests, hasLength(2));
      engine.emit(1, _lineResult(const ['e7e5', 'g1f3']));
      await tester.pump();
      expect(arrowUpdates.last, ['e7e5']);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(arrowUpdates.last, isEmpty);
      final updatesBeforeLeave = arrowUpdates.length;
      unawaited(panelKey.currentState!.prepareToLeave());
      await tester.pumpAndSettle();
      expect(arrowUpdates.length, updatesBeforeLeave + 1);
      expect(arrowUpdates.last, isEmpty);
    },
  );

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
  await tester.tap(_engineToggle(tester));
  await tester.pumpAndSettle();
}

Future<void> _enableWithoutSettling(WidgetTester tester) async {
  await tester.tap(_engineToggle(tester));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

Finder _engineToggle(WidgetTester tester) {
  final tile = find.byType(SwitchListTile);
  return tile.evaluate().isNotEmpty ? tile : find.byType(Switch);
}

Widget _host({
  String startingFen = _startFen,
  List<String> moves = const [],
  AnalysisEngineFactory? engineFactory,
  ValueChanged<List<String>>? onExploreSuggestion,
  ValueChanged<List<String>>? onSuggestionArrowsChanged,
  bool enabled = true,
  TextScaler? textScaler,
  Key? panelKey,
  bool compact = false,
  double? panelWidth,
}) => MaterialApp(
  builder: (context, child) => textScaler == null
      ? child!
      : MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
  home: Scaffold(
    body: SizedBox(
      width: panelWidth,
      child: AnalysisPanel(
        key: panelKey,
        startingFen: startingFen,
        moves: moves,
        engineFactory: engineFactory,
        onExploreSuggestion: onExploreSuggestion,
        onSuggestionArrowsChanged: onSuggestionArrowsChanged,
        enabled: enabled,
        compact: compact,
      ),
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

AnalysisResult _lineResult(List<String> moves) => AnalysisResult(
  depth: 9,
  centipawns: 24,
  principalVariation: moves,
  isComplete: true,
);

String _positionFen(List<String> moves) {
  var position = chess.Chess.fromSetup(chess.Setup.parseFen(_startFen));
  for (final uci in moves) {
    final move = chess.Move.parse(uci)!;
    position = position.play(move) as chess.Chess;
  }
  return position.fen;
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
      // A local cancellation future keeps the controllable stream in the
      // widget test's fake-async zone, instead of the broadcast stream's
      // shared root-zone cancellation future.
      final stream = StreamController<AnalysisResult>(
        sync: true,
        onCancel: () => Future<void>.value(),
      );
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
