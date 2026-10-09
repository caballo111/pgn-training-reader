import 'dart:async';

import 'package:chessground/chessground.dart' as chessground;
import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/analysis/exploration_repository.dart';
import 'package:pgntrainingreader/domain/analysis/exploration_session.dart';
import 'package:pgntrainingreader/features/analysis/presentation/exploration_workspace.dart';
import 'package:pgntrainingreader/domain/training/puzzle_evaluator.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

ExplorationOrigin _origin({
  String label = 'starting position',
  String startingFen = _startFen,
  List<String> authoredMoves = const [],
  String scopeId = 'book@revision-1:block-1',
}) => ExplorationOrigin(
  scopeId: scopeId,
  startingFen: startingFen,
  authoredPath: const [],
  authoredMoves: authoredMoves,
  label: label,
);

void main() {
  testWidgets('manual moves keep sibling personal branches navigable', (
    tester,
  ) async {
    await tester.pumpWidget(_workspace());
    await tester.pumpAndSettle();

    await _submit(tester, 'e2e4');
    await _submit(tester, 'e7e5');
    expect(find.text('1. e4'), findsOneWidget);
    expect(find.text('1... e5'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous personal move'));
    await tester.pumpAndSettle();
    await _submit(tester, 'e7e6');
    expect(find.text('1... e6'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous personal move'));
    await tester.pumpAndSettle();
    expect(find.text('e5'), findsWidgets);
    expect(find.text('e6'), findsWidgets);
  });

  testWidgets('notation uses the side and move number at a black origin', (
    tester,
  ) async {
    await tester.pumpWidget(
      _workspace(
        origin: _origin(authoredMoves: const ['e2e4'], label: '1. e4'),
      ),
    );
    await tester.pumpAndSettle();
    await _submit(tester, 'e7e5');
    await _submit(tester, 'g1f3');

    expect(find.text('1... e5'), findsOneWidget);
    expect(find.text('2. Nf3'), findsOneWidget);
  });

  testWidgets('return waits for the latest draft write', (tester) async {
    final repository = _FakeExplorationRepository();
    repository.saveGate = Completer<void>();
    var returned = false;
    await tester.pumpWidget(
      _workspace(repository: repository, onReturn: () => returned = true),
    );
    await tester.pumpAndSettle();
    await _submit(tester, 'e2e4');

    await tester.tap(find.text('Return to reading'));
    await tester.pump();
    expect(repository.saveCalls, 1);
    expect(returned, isFalse);

    repository.saveGate!.complete();
    await tester.pump(const Duration(milliseconds: 50));
    expect(returned, isTrue);
  });

  testWidgets('save error retains the tree and retry permits return', (
    tester,
  ) async {
    final repository = _FakeExplorationRepository()..failNextSave = true;
    var returns = 0;
    await tester.pumpWidget(
      _workspace(repository: repository, onReturn: () => returns++),
    );
    await tester.pumpAndSettle();
    await _submit(tester, 'e2e4', settle: false);
    await tester.tap(find.text('Return to reading'));
    await tester.pumpAndSettle();

    expect(returns, 0);
    expect(find.textContaining('Your moves are still here'), findsOneWidget);
    expect(find.text('1. e4'), findsOneWidget);

    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();
    expect(repository.saveCalls, 2);
    await tester.tap(find.text('Return to reading'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(returns, 1);
  });

  testWidgets(
    'late save from a replaced origin cannot change new draft state',
    (tester) async {
      final repository = _FakeExplorationRepository()
        ..saveGate = Completer<void>()
        ..failNextSave = true;
      var origin = _origin();
      late StateSetter updateHost;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                updateHost = setState;
                return ExplorationWorkspace(
                  origin: origin,
                  repository: repository,
                  orientation: PuzzleSide.white,
                  onReturn: () {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _submit(tester, 'e2e4', settle: false);
      await tester.pump(const Duration(milliseconds: 350));
      expect(repository.saveCalls, 1);

      origin = _origin(
        label: 'next origin',
        scopeId: 'book@revision-2:block-1',
      );
      updateHost(() {});
      await tester.pumpAndSettle();
      expect(find.text('Exploring from next origin'), findsOneWidget);
      expect(
        find.text('No personal moves yet. Play a legal move to begin.'),
        findsOneWidget,
      );

      repository.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('Exploration not saved'), findsNothing);
      expect(find.text('Exploring from next origin'), findsOneWidget);
    },
  );

  testWidgets('phone portrait and landscape preserve board and Return', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_workspace(textScaler: TextScaler.linear(2)));
    await tester.pumpAndSettle();

    expect(find.text('Return to reading'), findsOneWidget);
    expect(find.text('Your exploration'), findsOneWidget);
    expect(
      tester
          .widget<chessground.Chessboard>(find.byType(chessground.Chessboard))
          .interactive,
      isTrue,
    );
    await _tapSquare(tester, 'e2', orientation: chess.Side.white);
    await _tapSquare(tester, 'e4', orientation: chess.Side.white);

    await tester.binding.setSurfaceSize(const Size(640, 320));
    await tester.pumpWidget(_workspace(textScaler: TextScaler.linear(2)));
    await tester.pumpAndSettle();
    expect(find.text('Return to reading'), findsOneWidget);
    expect(
      tester
          .widget<chessground.Chessboard>(find.byType(chessground.Chessboard))
          .interactive,
      isTrue,
    );
    await _tapSquare(tester, 'e7', orientation: chess.Side.white);
    await _tapSquare(tester, 'e5', orientation: chess.Side.white);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'seeded suggestion selects its new branch and preserves a draft',
    (tester) async {
      final repository = _FakeExplorationRepository()
        ..loaded = ExplorationSession.initial(origin: _origin())
            .playUci('d2d4');
      await tester.pumpWidget(
        _workspace(
          repository: repository,
          initialMoves: const ['e2e4', 'e7e5'],
        ),
      );
      await tester.pumpAndSettle();

      // The explicitly requested line is selected, while the previous d4
      // branch remains available at the authored origin.
      expect(find.text('1. e4'), findsOneWidget);
      expect(find.text('1... e5'), findsOneWidget);
      await tester.tap(find.byTooltip('First personal move'));
      await tester.pumpAndSettle();
      expect(find.text('d4'), findsWidgets);
      expect(find.text('e4'), findsWidgets);
    },
  );
}

Widget _workspace({
  ExplorationOrigin? origin,
  ExplorationRepository? repository,
  List<String> initialMoves = const [],
  VoidCallback? onReturn,
  TextScaler? textScaler,
}) => MaterialApp(
  builder: (context, child) => textScaler == null
      ? child!
      : MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
  home: Scaffold(
    body: ExplorationWorkspace(
      origin: origin ?? _origin(),
      repository: repository,
      orientation: PuzzleSide.white,
      initialMoves: initialMoves,
      onReturn: onReturn ?? () {},
    ),
  ),
);

Future<void> _submit(
  WidgetTester tester,
  String uci, {
  bool settle = true,
}) async {
  final board = tester.widget<chessground.Chessboard>(
    find.byType(chessground.Chessboard),
  );
  board.onMove!(chess.Move.parse(uci)!);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _tapSquare(
  WidgetTester tester,
  String square, {
  required chess.Side orientation,
}) async {
  final rect = tester.getRect(find.byType(chessground.Chessboard));
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.parse(square[1]) - 1;
  final column = orientation == chess.Side.white ? file : 7 - file;
  final row = orientation == chess.Side.white ? 7 - rank : rank;
  await tester.tapAt(
    rect.topLeft +
        Offset((column + 0.5) * rect.width / 8, (row + 0.5) * rect.height / 8),
  );
  await tester.pump();
}

final class _FakeExplorationRepository implements ExplorationRepository {
  ExplorationSession? loaded;
  Completer<void>? saveGate;
  bool failNextSave = false;
  int saveCalls = 0;
  final List<ExplorationSession> saved = [];

  @override
  Future<ExplorationSession?> load(ExplorationOrigin origin) async => loaded;

  @override
  Future<void> save(ExplorationSession session) async {
    saveCalls++;
    final gate = saveGate;
    if (gate != null) await gate.future;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('disk is full');
    }
    saved.add(session);
    loaded = session;
  }
}
