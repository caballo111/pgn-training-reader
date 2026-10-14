import 'package:flutter/material.dart';

import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/analysis/exploration_session.dart';
import 'package:pgntrainingreader/features/analysis/presentation/exploration_move_tree.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

ExplorationOrigin _origin() => ExplorationOrigin(
  scopeId: 'book@revision-1:block-1',
  startingFen: _startFen,
  authoredPath: const [],
  authoredMoves: const [],
  label: 'Starting position',
);

ExplorationSession _sessionAtLeaf() =>
    ExplorationSession.initial(origin: _origin())
        .playUci('e2e4')
        .playUci('e7e5')
        .playUci('g1f3')
        .previous()
        .previous()
        .playUci('c7c5')
        .playUci('g1f3');

void main() {
  testWidgets(
    'rewind keeps the full line visible and earlier siblings selectable',
    (tester) async {
      final session = _sessionAtLeaf().previous();
      List<int>? selectedPath;

      await tester.pumpWidget(
        _treeApp(session, onSelectPath: (path) => selectedPath = path),
      );

      expect(find.text('2. Nf3'), findsOneWidget);
      expect(find.text('Variations after 1. e4'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byTooltip('Go to personal move 2, 1... c5'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(
              find.byTooltip('Select personal variation c5 after 1. e4'),
            )
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        find.byTooltip('Select personal variation e5 after 1. e4'),
        findsOneWidget,
      );

      await tester.tap(
        find.byTooltip('Select personal variation e5 after 1. e4'),
      );
      expect(selectedPath, [0, 0]);

      await tester.tap(find.byTooltip('Go to personal move 3, 2. Nf3'));
      expect(selectedPath, [0, 1, 0]);
    },
  );

  testWidgets('shows engine provenance and provides delete and clear actions', (
    tester,
  ) async {
    final session = ExplorationSession.initial(origin: _origin())
        .playUci('e2e4', engineOrigin: true)
        .first()
        .playUci('d2d4');
    final deletedPaths = <List<int>>[];
    var clearCalls = 0;

    await tester.pumpWidget(
      _treeApp(
        session,
        onDeleteBranch: deletedPaths.add,
        onClearExploration: () => clearCalls++,
      ),
    );

    expect(find.byIcon(Icons.memory), findsOneWidget);
    expect(
      find.byTooltip('Delete variation e4 after the exploration origin'),
      findsOneWidget,
    );
    expect(find.text('Delete from 1. d4'), findsOneWidget);
    expect(find.text('Clear exploration'), findsOneWidget);
    final selectedLabel = find.text('1. d4');
    final selectedVisual = find.ancestor(
      of: selectedLabel,
      matching: find.byType(Ink),
    );
    final selectedTarget = find.ancestor(
      of: selectedLabel,
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(selectedVisual.first).height, lessThanOrEqualTo(40));
    expect(
      tester.getSize(selectedTarget.first).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(
      find.byTooltip('Delete variation e4 after the exploration origin'),
    );
    expect(deletedPaths, [
      [0],
    ]);
    await tester.tap(find.text('Delete from 1. d4'));
    expect(deletedPaths, [
      [0],
      [1],
    ]);
    await tester.tap(find.text('Clear exploration'));
    expect(clearCalls, 1);
  });

  testWidgets('delete selected sibling variation preserves the other branch', (
    tester,
  ) async {
    final session = ExplorationSession.initial(origin: _origin())
        .playUci('e2e4')
        .playUci('e7e5')
        .previous()
        .playUci('c7c5');
    List<int>? deletedPath;

    await tester.pumpWidget(
      _treeApp(session, onDeleteBranch: (path) => deletedPath = path),
    );
    await tester.tap(find.byTooltip('Delete variation c5 after 1. e4'));

    expect(deletedPath, [0, 1]);
    final afterDelete = session.deleteVariation(deletedPath!);
    expect(afterDelete.root.single.children.map((node) => node.uci), ['e7e5']);
  });

  testWidgets(
    'delete from the current move prunes an unbranched continuation',
    (tester) async {
      final session = ExplorationSession.initial(origin: _origin())
          .playUci('e2e4')
          .playUci('e7e5');
      List<int>? deletedPath;

      await tester.pumpWidget(
        _treeApp(session, onDeleteBranch: (path) => deletedPath = path),
      );
      await tester.tap(find.text('Delete from 1... e5'));

      expect(deletedPath, [0, 0]);
      final afterDelete = session.deleteVariation(deletedPath!);
      expect(afterDelete.currentPath, [0]);
      expect(afterDelete.moves, ['e2e4']);
      expect(afterDelete.root.single.children, isEmpty);
    },
  );

  testWidgets('navigation scrolls the current move into view', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var session = ExplorationSession.initial(origin: _origin());
    late StateSetter updateHost;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                updateHost = setState;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [const SizedBox(height: 720), _tree(session)],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    session = session.playUci('e2e4');
    updateHost(() {});
    await tester.pumpAndSettle();

    final moveRect = tester.getRect(find.text('1. e4'));
    final viewportRect = tester.getRect(find.byType(Scrollable).first);
    expect(moveRect.overlaps(viewportRect), isTrue);
  });
}

Widget _treeApp(
  ExplorationSession session, {
  ValueChanged<List<int>>? onSelectPath,
  ValueChanged<List<int>>? onDeleteBranch,
  VoidCallback? onClearExploration,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: _tree(
        session,
        onSelectPath: onSelectPath,
        onDeleteBranch: onDeleteBranch,
        onClearExploration: onClearExploration,
      ),
    ),
  ),
);

Widget _tree(
  ExplorationSession session, {
  ValueChanged<List<int>>? onSelectPath,
  ValueChanged<List<int>>? onDeleteBranch,
  VoidCallback? onClearExploration,
}) => ExplorationMoveTree(
  session: session,
  onSelectPath: onSelectPath ?? (_) {},
  onSelectBranch: (_) {},
  onDeleteBranch: onDeleteBranch,
  onClearExploration: onClearExploration,
);
