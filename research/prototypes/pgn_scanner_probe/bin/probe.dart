import 'dart:convert';

const fixture = r'''[Event "First"]
[Site "Chunk boundary test"]
[White "Alice"]
[Black "Bob"]

1. e4 {brace comment contains [Event "not a game"] and (parentheses)} e5 2. Nf3 ; semicolon comment contains [Event "not a game"]
Nc6 (2. Bc4 (2... Nf6) d6) 3. Bb5 *

[Event "Second"]
[White "Carol"]
[Black "Dan"]

1. d4 d5 2. c4 *

[Event "Third"]
[White "Eve"]
[Black "Fran"]

1. c4 e5 2. Nc3 *
''';

class BlockRange {
  const BlockRange(this.start, this.end);

  final int start;
  final int end;

  @override
  String toString() => '$start..$end';

  @override
  bool operator ==(Object other) =>
      other is BlockRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Deliberately small experiment. It emits a range when a top-level [Event
/// tag starts at the beginning of a line. It does not parse movetext.
class ChunkedProbeScanner {
  var _absoluteOffset = 0;
  var _lineStartOffset = 0;
  var _lineStart = true;
  var _inBraceComment = false;
  var _inSemicolonComment = false;
  var _variationDepth = 0;
  var _inTag = false;
  var _inTagQuote = false;
  var _tagEscape = false;
  var _line = StringBuffer();
  int? _candidateStart;
  final _ranges = <BlockRange>[];

  List<BlockRange> consume(List<int> bytes) {
    for (final byte in bytes) {
      final char = String.fromCharCode(byte);
      final offset = _absoluteOffset++;

      if (_inSemicolonComment) {
        _line.write(char);
        if (char == '\n') {
          _inSemicolonComment = false;
          _finishLine(offset + 1);
        }
        continue;
      }

      if (_inBraceComment) {
        _line.write(char);
        if (char == '}') _inBraceComment = false;
        if (char == '\n') _finishLine(offset + 1);
        continue;
      }

      if (_inTag) {
        _line.write(char);
        if (_inTagQuote) {
          if (_tagEscape) {
            _tagEscape = false;
          } else if (char == '\\') {
            _tagEscape = true;
          } else if (char == '"') {
            _inTagQuote = false;
          }
        } else if (char == '"') {
          _inTagQuote = true;
        } else if (char == ']') {
          _inTag = false;
        }
        if (char == '\n') _finishLine(offset + 1);
        continue;
      }

      _line.write(char);
      if (_lineStart && char == '[') _inTag = true;
      if (char == '{') {
        _inBraceComment = true;
      } else if (char == ';') {
        _inSemicolonComment = true;
      } else if (char == '(') {
        _variationDepth++;
      } else if (char == ')' && _variationDepth > 0) {
        _variationDepth--;
      }

      if (char == '\n') _finishLine(offset + 1);
      _lineStart = false;
    }
    return List.unmodifiable(_ranges);
  }

  List<BlockRange> finish() {
    if (_line.isNotEmpty) _finishLine(_absoluteOffset);
    if (_candidateStart != null &&
        (_ranges.isEmpty || _ranges.last.end != _absoluteOffset)) {
      _ranges.add(BlockRange(_candidateStart!, _absoluteOffset));
    }
    return List.unmodifiable(_ranges);
  }

  void _finishLine(int nextOffset) {
    final line = _line.toString();
    final isEventTag = line.startsWith('[Event ');
    if (isEventTag &&
        !_inBraceComment &&
        !_inSemicolonComment &&
        _variationDepth == 0) {
      if (_candidateStart != null) {
        _ranges.add(BlockRange(_candidateStart!, _lineStartOffset));
      }
      _candidateStart = _lineStartOffset;
    }
    _line = StringBuffer();
    _lineStartOffset = nextOffset;
    _lineStart = true;
  }
}

List<BlockRange> scanInChunks(List<int> bytes, int chunkSize) {
  final scanner = ChunkedProbeScanner();
  for (var start = 0; start < bytes.length; start += chunkSize) {
    final end = (start + chunkSize).clamp(0, bytes.length);
    scanner.consume(bytes.sublist(start, end));
  }
  return scanner.finish();
}

void check(bool condition, String message) {
  if (!condition) throw StateError('FAILED: $message');
}

void main() {
  final bytes = utf8.encode(fixture);
  final expected = scanInChunks(bytes, bytes.length);
  check(expected.length == 3, 'three blocks discovered');

  for (final chunkSize in [1, 2, 7, 64, 4096]) {
    check(
      scanInChunks(bytes, chunkSize).toString() == expected.toString(),
      'chunk size $chunkSize emits stable ranges',
    );
  }

  for (final marker in [
    '[Event "First"]',
    '{brace comment',
    '; semicolon comment',
    '2. Nf3',
    '(2. Bc4 (2... Nf6)',
  ]) {
    final split = fixture.indexOf(marker) + marker.length ~/ 2;
    check(split > 0, 'marker exists: $marker');
    check(
      scanInChunks(bytes, split).toString() == expected.toString(),
      'split inside $marker is safe',
    );
  }

  final first = fixture.substring(expected[0].start, expected[0].end);
  check(first.contains('[Event "First"]'), 'first block starts at Event tag');
  check(!first.contains('[Event "Second"]'), 'second block is not swallowed');
  check(
    first.contains('[Event "not a game"]'),
    'comment text remains inside block',
  );
  check(expected[2].end == bytes.length, 'last block ends at EOF');

  print('T007 chunked scanner stable ranges: PASS');
  print('T007 ranges: $expected');
  print(
    'T007 exercised splits inside tag, brace comment, semicolon comment, move token, recursive variation',
  );
}
