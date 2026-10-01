import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/pgn/pgn_header_reader.dart';

void main() {
  const reader = PgnHeaderReader();

  test('reads Unicode and escaped tag values without parsing movetext', () {
    const source =
        r'[White "José \"The Rook\" \\ Knight"]'
        '\n'
        '[X-Theme "攻め"]\n'
        '1. e4 {ignored [Fake "tag"]} *';
    final result = reader.read(source);

    expect(result.isMalformed, isFalse);
    expect(result.headers['White'], 'José "The Rook" \\ Knight');
    expect(result.headers['X-Theme'], '攻め');
    expect(result.headers.containsKey('Fake'), isFalse);
    expect(source.substring(result.movetextOffset), startsWith('1. e4'));
  });

  test('rejects an unterminated leading comment and escaped newline', () {
    final leading = reader.read('{unfinished comment\n[Event "hidden"]');
    expect(leading.isMalformed, isTrue);
    expect(leading.headers, isEmpty);

    final escapedNewline = reader.read('[Event "bad\\\nvalue"]\n1. e4 *');
    expect(escapedNewline.isMalformed, isTrue);
  });

  test('skips leading comments and keeps custom headers', () {
    final result = reader.read(
      '{opening note}\n; another note\n[Event "Event"]\n[X-ExerciseId "p-1"]',
    );

    expect(result.headers, {'Event': 'Event', 'X-ExerciseId': 'p-1'});
    expect(result.isMalformed, isFalse);
  });

  test('reports malformed tags with diagnostics that omit source text', () {
    const secret = 'private raw value';
    final result = reader.read('[Event "$secret"\n1. e4');

    expect(result.isMalformed, isTrue);
    expect(result.diagnostics, isNotEmpty);
    expect(
      result.diagnostics.every((d) => !d.message.contains(secret)),
      isTrue,
    );
    expect(
      result.diagnostics.every((d) => !d.message.contains('[Event')),
      isTrue,
    );
  });

  test('caps oversized tag values and emitted diagnostics', () {
    final oversized = reader.read(
      '[Event "${List.filled(PgnHeaderReader.maximumTagCharacters, 'x').join()}x"]\n1. e4 *',
    );
    expect(oversized.isMalformed, isTrue);
    expect(oversized.diagnostics, hasLength(1));
    expect(oversized.diagnostics.single.message, isNot(contains('xxxx')));

    final manyTags = List.generate(100, (i) => '[X-$i "value"]').join('\n');
    expect(
      reader.read(manyTags).diagnostics.length,
      lessThanOrEqualTo(PgnHeaderReader.maximumDiagnostics),
    );
  });
}
