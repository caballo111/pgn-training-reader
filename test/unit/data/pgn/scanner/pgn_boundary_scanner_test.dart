import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/pgn/scanner/pgn_boundary_scanner.dart';

void main() {
  const fixtureNames = [
    'simple_games.pgn',
    'chunk_boundaries.pgn',
    'malformed_neighbors.pgn',
  ];
  const finalResultBytes = {
    'simple_games.pgn': [0x30, 0x2d, 0x31],
    'chunk_boundaries.pgn': [0x30, 0x2d, 0x31],
    'malformed_neighbors.pgn': [0x31, 0x2f, 0x32, 0x2d, 0x31, 0x2f, 0x32],
  };
  const chunkSizes = [1, 2, 7, 64, 4096];

  for (final fixtureName in fixtureNames) {
    test('$fixtureName emits identical byte ranges for every chunk size', () {
      final source = File('test/fixtures/pgn/$fixtureName').readAsBytesSync();
      final expected = _scan(source, chunkSizes.last);

      for (final chunkSize in chunkSizes) {
        final actual = _scan(source, chunkSize);
        expect(
          _tuples(actual),
          _tuples(expected),
          reason: 'chunk size $chunkSize',
        );
      }

      expect(expected, isNotEmpty);
      final first = expected.first;
      final last = expected.last;
      expect(source.sublist(first.startOffset, first.endOffset).first, 0x5b);
      expect(
        source
            .sublist(last.startOffset, last.endOffset)
            .sublist(
              source.sublist(last.startOffset, last.endOffset).length -
                  finalResultBytes[fixtureName]!.length,
            ),
        finalResultBytes[fixtureName],
      );
      final finalBlock = utf8.decode(
        source.sublist(last.startOffset, last.endOffset),
      );
      expect(RegExp(r'(1-0|0-1|1/2-1/2|\*)$').hasMatch(finalBlock), isTrue);
    });
  }

  test(
    'malformed middle block is flagged and valid neighbors are retained',
    () {
      final source = File('test/fixtures/pgn/malformed_neighbors.pgn')
          .readAsBytesSync();
      final ranges = _scan(source, 7);

      expect(ranges, hasLength(3));
      expect(ranges.map((range) => range.isMalformed), [false, true, false]);
      expect(ranges[1].diagnosticCode, 'unterminated_tag_string');
      expect(
        _blockText(source, ranges.first),
        contains('Valid game before malformed block'),
      );
      expect(
        _blockText(source, ranges.last),
        contains('Valid game after malformed block'),
      );
    },
  );

  test('empty and comment-only input emits no ranges', () {
    for (final bytes in [
      <int>[],
      utf8.encode('  \n{comment [Event "fake"]} ; another comment\n'),
    ]) {
      expect(_scan(bytes, 1), isEmpty);
    }
  });

  test('a result token at EOF closes the final range', () {
    final source = utf8.encode('[Event "EOF"]\n1. e4 e5 1-0');
    final ranges = _scan(source, 2);
    expect(ranges, hasLength(1));
    expect(
      source.sublist(ranges.single.startOffset, ranges.single.endOffset),
      source,
    );
  });

  test('same-line tags, adjacent blocks, variations, and escaped Unicode stay intact', () {
    final source = utf8.encode(
      '[Result "1-0"][Event "Zoë \\"棋手\\""] 1. e4 (1. d4 0-1) e5 1-0'
      '[Event "next"][Result "*"] 1. d4 *',
    );
    final ranges = _scan(source, 1);

    expect(ranges, hasLength(2));
    expect(
      _blockText(source, ranges.first),
      contains('1. e4 (1. d4 0-1) e5 1-0'),
    );
    expect(_blockText(source, ranges.first), contains('Zoë'));
    expect(_blockText(source, ranges.last), contains('[Event "next"]'));
  });

  test('unfinished construct at EOF emits a malformed candidate', () {
    final source = utf8.encode('[Event "unfinished"]\n1. e4 {unfinished');
    final ranges = _scan(source, 2);

    expect(ranges, hasLength(1));
    expect(ranges.single.isMalformed, isTrue);
    expect(ranges.single.diagnosticCode, 'unterminated_brace_comment');
    expect(
      source.sublist(ranges.single.startOffset, ranges.single.endOffset),
      source,
    );
  });

  test('unclosed brace comment quarantines the tail without phantom games', () {
    final source = utf8.encode(
      '[Event "good"]\n1. e4 *\n\n[Event "bad"]\n1. d4 {unfinished\n'
      '[Event "phantom"]\n1. c4 *',
    );
    final ranges = _scan(source, 3);
    expect(ranges, hasLength(2));
    expect(ranges.last.isMalformed, isTrue);
    expect(ranges.last.diagnosticCode, 'unterminated_brace_comment');
  });

  test('missing result is malformed at a new header and EOF', () {
    for (final source in [
      utf8.encode('[Event "missing"]\n1. e4\n[Event "next"]\n1. d4 *'),
      utf8.encode('[Event "missing"]\n1. e4'),
    ]) {
      final ranges = _scan(source, 2);
      expect(ranges.first.isMalformed, isTrue);
      expect(ranges.first.diagnosticCode, 'missing_game_termination');
    }
  });
}

List<PgnBlockRange> _scan(List<int> source, int chunkSize) {
  final scanner = PgnBoundaryScanner();
  final ranges = <PgnBlockRange>[];
  for (var offset = 0; offset < source.length; offset += chunkSize) {
    final end = (offset + chunkSize < source.length)
        ? offset + chunkSize
        : source.length;
    ranges.addAll(scanner.consume(source.sublist(offset, end)));
  }
  ranges.addAll(scanner.finish());
  return ranges;
}

List<(int, int, bool, String?)> _tuples(List<PgnBlockRange> ranges) => ranges
    .map(
      (range) => (
        range.startOffset,
        range.endOffset,
        range.isMalformed,
        range.diagnosticCode,
      ),
    )
    .toList();

String _blockText(List<int> source, PgnBlockRange range) =>
    utf8.decode(source.sublist(range.startOffset, range.endOffset));
