import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/pgn/chess_content_parser.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';

void main() {
  test(
    'preserves headers, start FEN, comments, NAGs, and authored variations',
    () {
      const pgn = r'''
[Event "Parser fixture"]
[SetUp "1"]
[FEN "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"]
[Result "*"]

{Opening note} 1. e4 {King pawn} e5 (1... c5 {Sicilian}) 2. Nf3 $1 Nc6 *
''';
      final content = const ChessContentParser().parse(
        pgn,
        contentType: ContentType.puzzle,
      );
      expect(content.headers['Event'], 'Parser fixture');
      expect(
        content.startingFen,
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      );
      expect(content.comments, ['Opening note']);
      final e4 = content.rootMoves.single;
      expect(e4.uci, 'e2e4');
      expect(e4.fenBefore, content.startingFen);
      expect(e4.comments, ['King pawn']);
      expect(e4.children.map((move) => move.san), ['e5', 'c5']);
      expect(e4.children[1].comments, ['Sicilian']);
      expect(e4.children.first.children.first.nags, [1]);
      expect(e4.children.first.children.first.children.single.uci, 'b8c6');
    },
  );
}
