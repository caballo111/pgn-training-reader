import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/analysis/exploration_session.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

ExplorationOrigin _origin({
  String fen = _startFen,
  List<int> path = const [],
  List<String> moves = const [],
  String scope = 'source-v1:block-1',
  String? discriminator,
}) => ExplorationOrigin(
  scopeId: scope,
  startingFen: fen,
  authoredPath: path,
  authoredMoves: moves,
  label: 'Main line',
  discriminator: discriminator,
);

void main() {
  group('ExplorationOrigin', () {
    test('snapshots lists and keys origins by source occurrence', () {
      final path = <int>[0, 2, 1];
      final moves = <String>['e2e4', 'e7e5', 'g1f3'];
      final origin = ExplorationOrigin(
        scopeId: 'source-v1:block-1',
        startingFen: _startFen,
        authoredPath: path,
        authoredMoves: moves,
        label: 'Main line',
      );
      path.add(4);
      moves.add('b8c6');

      expect(origin.authoredPath, [0, 2, 1]);
      expect(origin.authoredMoves, ['e2e4', 'e7e5', 'g1f3']);
      expect(
        _origin(path: [0, 2, 1], moves: ['e2e4', 'e7e5', 'g1f3']).identityKey,
        origin.identityKey,
      );
      expect(
        _origin(path: [0, 2, 2], moves: ['e2e4', 'e7e5', 'g1f3']).identityKey,
        isNot(origin.identityKey),
      );
      expect(
        _origin(
          path: [0, 2, 1],
          moves: ['e2e4', 'e7e5', 'g1f3'],
          discriminator: 'try-1',
        ).identityKey,
        isNot(origin.identityKey),
      );
      expect(
        _origin(
          path: [0, 2, 1],
          moves: ['e2e4', 'e7e5', 'g1f3'],
          scope: 'source-v2:block-1',
        ).identityKey,
        isNot(origin.identityKey),
      );
    });

    test('round-trips its durable representation', () {
      final origin = _origin(
        path: [1, 0],
        moves: ['e2e4', 'c7c5'],
        discriminator: 'recorded-try-17',
      );

      expect(ExplorationOrigin.fromJson(origin.toJson()), origin);
    });
  });

  group('ExplorationSession', () {
    test('keeps source origin independent and retains sibling branches', () {
      final origin = _origin();
      final initial = ExplorationSession.initial(origin: origin);
      final withE4 = initial.playUci('e2e4');
      final e4e5 = withE4.playUci('e7e5');
      final e4c5 = e4e5.previous().playUci('c7c5');

      expect(initial.root, isEmpty);
      expect(initial.currentPath, isEmpty);
      expect(withE4.currentPath, [0]);
      expect(e4e5.currentPath, [0, 0]);
      expect(e4c5.currentPath, [0, 1]);
      expect(e4c5.root.single.uci, 'e2e4');
      expect(e4c5.root.single.children.map((node) => node.uci), [
        'e7e5',
        'c7c5',
      ]);
      expect(e4c5.activeLine.map((node) => node.uci), ['e2e4', 'c7c5']);
      expect(e4c5.moves, ['e2e4', 'c7c5']);
      expect(e4c5.position.fen.split(' ')[1], 'w');
      expect(origin.authoredMoves, isEmpty);
    });

    test(
      'reuses a duplicate sibling and navigation preserves every branch',
      () {
        final session = ExplorationSession.initial(origin: _origin())
            .playUci('e2e4')
            .playUci('e7e5')
            .previous()
            .playUci('c7c5');

        final selectedE5 = session.selectPath([0, 0]);
        final selectedE4Again = selectedE5.first().playUci('e2e4');
        expect(selectedE4Again.currentPath, [0]);
        expect(selectedE4Again.branches.map((node) => node.uci), [
          'e7e5',
          'c7c5',
        ]);
        expect(selectedE4Again.last().currentPath, [0, 0]);
        expect(selectedE4Again.first().currentPath, isEmpty);
        expect(selectedE4Again.first().next().currentPath, [0]);
        expect(selectedE4Again.selectPath([0, 1]).moves, ['e2e4', 'c7c5']);
        expect(() => selectedE4Again.selectPath([1]), throwsArgumentError);
      },
    );

    test('replays authored history before personal moves', () {
      final session = ExplorationSession.initial(
        origin: _origin(
          moves: ['e2e4', 'e7e5', 'g1f3', 'b8c6'],
          path: [0, 1, 0],
        ),
      );
      final afterBb5 = session.playUci('f1b5');

      expect(session.moves, ['e2e4', 'e7e5', 'g1f3', 'b8c6']);
      expect(
        session.position.fen,
        'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
      );
      expect(afterBb5.moves, ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5']);
      expect(afterBb5.position.fen.split(' ')[1], 'b');
    });

    test('supports legal promotion, castling, and en passant from FEN', () {
      final promotion = ExplorationSession.initial(
        origin: _origin(fen: '7k/P7/8/8/8/8/8/7K w - - 0 1'),
      ).playUci('a7a8q');
      expect(promotion.position.fen, 'Q6k/8/8/8/8/8/8/7K b - - 0 1');

      final castling = ExplorationSession.initial(
        origin: _origin(fen: 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1'),
      ).playUci('e1g1');
      expect(castling.position.fen, 'r3k2r/8/8/8/8/8/8/R4RK1 b kq - 1 1');

      final enPassant = ExplorationSession.initial(
        origin: _origin(fen: '4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2'),
      ).playUci('e5d6');
      expect(enPassant.position.fen, '4k3/8/3P4/8/8/8/8/4K3 b - - 0 2');
    });

    test(
      'rejects illegal and terminal moves without changing prior snapshots',
      () {
        final initial = ExplorationSession.initial(origin: _origin());
        expect(() => initial.playUci('e2e5'), throwsArgumentError);
        expect(() => initial.playUci('bad'), throwsArgumentError);
        expect(initial.root, isEmpty);

        final checkmate = ExplorationSession.initial(
          origin: _origin(fen: '7k/6Q1/5K2/8/8/8/8/8 b - - 0 1'),
        );
        expect(() => checkmate.playUci('h8h7'), throwsArgumentError);

        final insufficientMaterial = ExplorationSession.initial(
          origin: _origin(fen: '8/8/8/8/8/8/4B3/4K2k w - - 0 1'),
        );
        expect(insufficientMaterial.position.isGameOver, isTrue);
        expect(() => insufficientMaterial.playUci('e2f3'), throwsArgumentError);
      },
    );

    test('serializes a branched tree and cursor, then validates replay', () {
      final session = ExplorationSession.initial(origin: _origin())
          .playUci('e2e4')
          .playUci('e7e5')
          .previous()
          .playUci('c7c5')
          .playUci('g1f3');
      final restored = ExplorationSession.fromJson(session.toJson());

      expect(restored.origin, session.origin);
      expect(restored.currentPath, session.currentPath);
      expect(restored.moves, session.moves);
      expect(restored.position.fen, session.position.fen);
      expect(restored.root.single.children.map((node) => node.uci), [
        'e7e5',
        'c7c5',
      ]);
      expect(jsonEncode(restored.toJson()), jsonEncode(session.toJson()));
    });

    test('rejects unknown versions, malformed data, illegal trees, and bad cursors', () {
      final json = ExplorationSession.initial(origin: _origin()).toJson();
      expect(
        () => ExplorationSession.fromJson({...json, 'version': 2}),
        throwsFormatException,
      );
      expect(
        () => ExplorationSession.fromJson({...json, 'tree': 'not a tree'}),
        throwsFormatException,
      );
      expect(
        () => ExplorationSession.fromJson({
          ...json,
          'tree': <Object?>[
            <String, Object?>{'uci': 'e2e5', 'children': <Object?>[]},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => ExplorationSession.fromJson({
          ...json,
          'cursorPath': [0],
        }),
        throwsFormatException,
      );
      expect(
        () => ExplorationSession.fromJson({
          ...json,
          'origin': {'scopeId': 3},
        }),
        throwsFormatException,
      );
    });

    test('bounds malicious tree depth before deep replay', () {
      Object? tree = <Object?>[];
      for (var index = 0; index < 514; index++) {
        tree = <Object?>[
          <String, Object?>{'uci': 'e2e4', 'children': tree},
        ];
      }
      final json = ExplorationSession.initial(origin: _origin()).toJson();
      expect(
        () => ExplorationSession.fromJson({...json, 'tree': tree}),
        throwsFormatException,
      );
    });
  });
}
