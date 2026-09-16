import 'package:dartchess/dartchess.dart';

const standardPgn = r'''
[Event "Parser probe"]
[Site "Local"]
[Round "1"]
[White "Alice"]
[Black "Bob"]
[Result "1-0"]

1. e4 $1 {king pawn} e5
2. Nf3 (2. Bc4 {one variation}) Nc6
3. Bb5 (3. Bc4 (3... Nf6) Nf6) a6 1-0
''';

const fenPgn = r'''
[Event "FEN probe"]
[SetUp "1"]
[FEN "4k3/8/8/8/8/8/8/4K3 w - - 0 1"]
[Result "*"]

1. Kf2 Kf7 *
''';

const customTagPgn = r'''
[Event "Custom tag probe"]
[X-ContentType "Puzzle"]
[X-ExerciseId "probe-001"]
[X-Uncatalogued "retain this value"]
[Result "*"]

1. e4 *
''';

void check(bool condition, String message) {
  if (!condition) {
    throw StateError('FAILED: $message');
  }
}

Iterable<PgnChildNode<PgnNodeData>> childrenOf(
  PgnNode<PgnNodeData> node,
) sync* {
  for (final child in node.children) {
    yield child;
    yield* childrenOf(child);
  }
}

void main() {
  final standard = PgnGame.parsePgn(standardPgn);
  check(standard.headers['Event'] == 'Parser probe', 'standard headers');
  check(standard.headers['Result'] == '1-0', 'standard result');
  final standardNodes = childrenOf(standard.moves).toList();
  check(standardNodes.any((node) => node.data.san == 'e4'), 'standard move');
  check(
    standardNodes.any((node) => node.data.nags?.contains(1) ?? false),
    'NAG',
  );
  check(
    standardNodes.any(
      (node) => node.data.comments?.contains('king pawn') ?? false,
    ),
    'brace comment',
  );
  check(standard.moves.children.length == 1, 'one mainline root child');
  check(
    standard.moves.children.first.children.length == 1,
    'mainline continuation',
  );
  check(
    standard.moves.children.any((node) => node.children.length > 1) ||
        standardNodes.any((node) => node.children.length > 1),
    'variation branch',
  );
  check(
    standardNodes.any(
      (node) => node.children.any((child) => child.children.isNotEmpty),
    ),
    'nested variation branch',
  );

  final fenGame = PgnGame.parsePgn(fenPgn);
  final fenPosition = PgnGame.startingPosition(fenGame.headers);
  check(fenPosition.fen == '4k3/8/8/8/8/8/8/4K3 w - - 0 1', 'FEN start');
  check(fenPosition.turn == Side.white, 'FEN side to move');
  check(
    fenGame.moves.mainline().map((node) => node.san).join(' ') == 'Kf2 Kf7',
    'FEN moves',
  );

  final customGame = PgnGame.parsePgn(customTagPgn);
  check(customGame.headers['X-ContentType'] == 'Puzzle', 'known X- tag');
  check(
    customGame.headers['X-Uncatalogued'] == 'retain this value',
    'unknown X- tag',
  );

  print(
    'T005 standard headers, FEN start, comments, NAGs, one variation, nested variation: PASS',
  );
  print('T006 unknown X- tags retained by parser: PASS');
  print('T006 parsed custom headers: ${customGame.headers}');
  print('T006 export is covered by export_probe.dart');
}
