import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/errors/app_failure.dart';
import 'package:pgntrainingreader/data/pgn/dartchess_content_parser.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';

void main() {
  test('sole Z0 instruction preserves commentary and headers without a move', () {
    const pgn =
        '[White "1) Introduction"]\n[PlyCount "1"]\n\n{Read this first} 1. Z0 {Closing note} *';
    final content = const DartchessContentParser().parse(
      pgn,
      contentType: ContentType.demonstration,
    );
    expect(content.contentType, ContentType.instruction);
    expect(content.inferredClassification, isTrue);
    expect(content.instructionalPlaceholder, 'Z0');
    expect(content.rootMoves, isEmpty);
    expect(content.comments, ['Read this first', 'Closing note']);
    expect(content.headers['PlyCount'], '1');
    expect(pgn, contains('1. Z0'));
  });

  test('placeholder support excludes null moves, mixed trees and puzzles', () {
    for (final moves in [
      '1. 0000 *',
      '1. @@@@ *',
      '1. Z0 e5 *',
      '1. e4 Z0 *',
      '1. Z0 (1. e4) *',
      '1. Z0 junk *',
      '1. -- e5 *',
      '1. e4 -- *',
      '1. -- (1. e4) *',
      '1. -- junk *',
      '1. e5 *',
    ]) {
      expect(
        () => const DartchessContentParser().parse(
          '[Event "Invalid"]\n\n{Note} $moves',
          contentType: ContentType.demonstration,
        ),
        throwsA(isA<PgnFailure>()),
        reason: moves,
      );
    }
    expect(
      () => const DartchessContentParser().parse(
        '[X-ContentType "Puzzle"]\n\n{Note} 1. Z0 *',
        contentType: ContentType.puzzle,
      ),
      throwsA(isA<PgnFailure>()),
    );
  });

  test('foreword -- preserves original headers, comments and placeholder', () {
    const pgn =
        '[Event "?"]\n[Black "Foreword by Garry Kasparov"]\n\n'
        '{Foreword commentary} 1. -- {Closing note} *';
    final content = const DartchessContentParser().parse(
      pgn,
      contentType: ContentType.demonstration,
    );
    expect(content.contentType, ContentType.instruction);
    expect(content.inferredClassification, isTrue);
    expect(content.instructionalPlaceholder, '--');
    expect(content.rootMoves, isEmpty);
    expect(content.headers['Black'], 'Foreword by Garry Kasparov');
    expect(content.comments, ['Foreword commentary', 'Closing note']);
  });

  test('both spellings require commentary and exclude setup and authored games', () {
    for (final token in ['Z0', '--']) {
      for (final headers in [
        '[Event "No commentary"]',
        '[SetUp "1"]\n[FEN "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"]',
        '[X-ContentType "Demonstration"]',
        '[X-ContentType "Puzzle"]',
      ]) {
        expect(
          () => const DartchessContentParser().parse(
            '$headers\n\n${headers.contains('No commentary') ? '' : '{Note} '}1. $token *',
            contentType: ContentType.demonstration,
          ),
          throwsA(isA<PgnFailure>()),
          reason: '$headers / $token',
        );
      }
    }
  });

  test('saved reader override is respected for placeholder content', () {
    final content = const DartchessContentParser().parse(
      '[White "Introduction"]\n\n{Note} 1. Z0 *',
      contentType: ContentType.demonstration,
      inferredClassification: false,
    );
    expect(content.contentType, ContentType.demonstration);
    expect(content.inferredClassification, isFalse);
    expect(content.rootMoves, isEmpty);
  });

  test(
    'preserves headers, start FEN, comments, NAGs, and authored variations',
    () {
      const pgn = r'''
[Event "Parser fixture"]
[SetUp "1"]
[FEN "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"]
[X-ExerciseId "fixture-42"]
[X-Unknown "retained"]
[Result "*"]

{Opening note} 1. e4 {King pawn} e5 (1... c5 {Sicilian} 2. Nf3 d6 (2... Nc6)) 2. Nf3 $1 Nc6 *
''';
      final content = const DartchessContentParser().parse(
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
      final sicilianReply = e4.children[1];
      expect(sicilianReply.children.single.san, 'Nf3');
      expect(sicilianReply.children.single.children.map((move) => move.san), [
        'd6',
        'Nc6',
      ]);
      expect(content.headers['X-ExerciseId'], 'fixture-42');
      expect(content.headers['X-Unknown'], 'retained');
    },
  );

  test('rejects unsupported variants even when called directly', () {
    expect(
      () => const DartchessContentParser().parse(
        '[Variant "Crazyhouse"]\n1. e4 *',
        contentType: ContentType.demonstration,
      ),
      throwsA(isA<UnsupportedContentFailure>()),
    );
  });

  test('reports malformed move trees as typed PGN failures', () {
    expect(
      () => const DartchessContentParser().parse(
        '[Event "Broken"]\n\n1. e5 *',
        contentType: ContentType.demonstration,
      ),
      throwsA(isA<PgnFailure>()),
    );
  });
}
