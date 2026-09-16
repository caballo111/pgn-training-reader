import 'package:dartchess/dartchess.dart';

const source = '''
[Event "Export probe"]
[X-ContentType "Puzzle"]
[X-ExerciseId "probe-001"]
[X-Uncatalogued "retain this value"]
[Result "*"]

1. e4 *
''';

void main() {
  final game = PgnGame.parsePgn(source);
  final exported = game.makePgn();
  final reparsed = PgnGame.parsePgn(exported);
  final preserved = reparsed.headers['X-Uncatalogued'] == 'retain this value';
  if (!preserved) {
    throw StateError('FAILED: exported PGN lost unknown X- tag\n$exported');
  }
  print('T006 unknown X- tag survives parse -> makePgn -> parse: PASS');
  print('--- exported PGN ---');
  print(exported);
}
