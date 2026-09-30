/// Reads PGN tag pairs without parsing the movetext or variation tree.
///
/// The reader expects one block (normally a scanner-emitted game range). It
/// stops at the first non-tag token after the headers. Diagnostic messages
/// are deliberately generic and never include tag values or source text.
final class PgnHeaderReader {
  const PgnHeaderReader();

  PgnHeaderReadResult read(String block) {
    final headers = <String, String>{};
    final diagnostics = <PgnHeaderDiagnostic>[];
    var cursor = block.startsWith('\uFEFF') ? 1 : 0;
    var movetextOffset = cursor;

    while (cursor < block.length) {
      cursor = _skipHeaderTrivia(block, cursor);
      if (cursor < block.length &&
          block.codeUnitAt(cursor) == 0x7b &&
          block.indexOf('}', cursor + 1) < 0) {
        diagnostics.add(
          const PgnHeaderDiagnostic(
            code: 'malformedTag',
            message: 'A PGN header comment is malformed.',
          ),
        );
        break;
      }
      if (cursor >= block.length || block.codeUnitAt(cursor) != 0x5b) break;

      cursor++;
      final nameStart = cursor;
      while (cursor < block.length && _isTagName(block.codeUnitAt(cursor))) {
        cursor++;
      }
      if (cursor == nameStart) {
        diagnostics.add(
          const PgnHeaderDiagnostic(
            code: 'malformedTag',
            message: 'A PGN header tag is malformed.',
          ),
        );
        break;
      }
      final name = block.substring(nameStart, cursor);
      if (cursor >= block.length ||
          !_isHeaderWhitespace(block.codeUnitAt(cursor))) {
        diagnostics.add(
          const PgnHeaderDiagnostic(
            code: 'malformedTag',
            message: 'A PGN header tag is malformed.',
          ),
        );
        break;
      }
      while (cursor < block.length &&
          _isHeaderWhitespace(block.codeUnitAt(cursor))) {
        cursor++;
      }
      if (cursor >= block.length || block.codeUnitAt(cursor) != 0x22) {
        diagnostics.add(
          const PgnHeaderDiagnostic(
            code: 'malformedTag',
            message: 'A PGN header tag is malformed.',
          ),
        );
        break;
      }
      cursor++;
      final value = StringBuffer();
      var closed = false;
      var invalid = false;
      while (cursor < block.length) {
        final unit = block.codeUnitAt(cursor++);
        if (unit == 0x22) {
          closed = true;
          break;
        }
        if (unit == 0x5c) {
          if (cursor >= block.length) {
            invalid = true;
            break;
          }
          final escaped = block.codeUnitAt(cursor++);
          if (escaped == 0x0a || escaped == 0x0d) {
            invalid = true;
            break;
          }
          if (escaped == 0x22 || escaped == 0x5c) {
            value.writeCharCode(escaped);
          } else {
            // PGN only defines escaping quote and backslash. Preserve an
            // unknown escaped character instead of silently changing it.
            value
              ..writeCharCode(0x5c)
              ..writeCharCode(escaped);
          }
          continue;
        }
        if (unit == 0x0a || unit == 0x0d || unit < 0x20) {
          invalid = true;
          break;
        }
        value.writeCharCode(unit);
      }
      if (!closed || invalid) {
        diagnostics.add(
          const PgnHeaderDiagnostic(
            code: 'malformedTag',
            message: 'A PGN header tag is malformed.',
          ),
        );
        break;
      }
      while (cursor < block.length &&
          _isHorizontalWhitespace(block.codeUnitAt(cursor))) {
        cursor++;
      }
      if (cursor >= block.length || block.codeUnitAt(cursor) != 0x5d) {
        diagnostics.add(
          const PgnHeaderDiagnostic(
            code: 'malformedTag',
            message: 'A PGN header tag is malformed.',
          ),
        );
        break;
      }
      cursor++;
      if (headers.containsKey(name)) {
        diagnostics.add(
          const PgnHeaderDiagnostic(
            code: 'duplicateTag',
            message: 'A PGN header tag is repeated; the last value was used.',
          ),
        );
      }
      headers[name] = value.toString();

      // Ordinary movetext ends header scanning on the next pass.
    }

    movetextOffset = cursor;

    return PgnHeaderReadResult(
      headers: Map.unmodifiable(headers),
      diagnostics: List.unmodifiable(diagnostics),
      isMalformed: diagnostics.any((d) => d.code == 'malformedTag'),
      movetextOffset: movetextOffset,
    );
  }

  static bool _isHeaderWhitespace(int unit) =>
      unit == 0x20 || unit == 0x09 || unit == 0x0a || unit == 0x0d;

  static bool _isHorizontalWhitespace(int unit) => unit == 0x20 || unit == 0x09;

  static int _skipHeaderTrivia(String block, int cursor) {
    while (cursor < block.length) {
      while (cursor < block.length &&
          _isHeaderWhitespace(block.codeUnitAt(cursor))) {
        cursor++;
      }
      if (cursor < block.length && block.codeUnitAt(cursor) == 0x7b) {
        final end = block.indexOf('}', cursor + 1);
        if (end < 0) return cursor;
        cursor = end + 1;
        continue;
      }
      if (cursor < block.length && block.codeUnitAt(cursor) == 0x3b) {
        while (cursor < block.length &&
            block.codeUnitAt(cursor) != 0x0a &&
            block.codeUnitAt(cursor) != 0x0d) {
          cursor++;
        }
        continue;
      }
      return cursor;
    }
    return cursor;
  }

  static bool _isTagName(int unit) =>
      (unit >= 0x41 && unit <= 0x5a) ||
      (unit >= 0x61 && unit <= 0x7a) ||
      (unit >= 0x30 && unit <= 0x39) ||
      unit == 0x5f ||
      unit == 0x2d;
}

/// Sanitized issue found while reading tag pairs.
final class PgnHeaderDiagnostic {
  const PgnHeaderDiagnostic({required this.code, required this.message});

  final String code;
  final String message;
}

/// Headers and safe diagnostics produced by [PgnHeaderReader.read].
final class PgnHeaderReadResult {
  const PgnHeaderReadResult({
    required this.headers,
    required this.diagnostics,
    required this.isMalformed,
    required this.movetextOffset,
  });

  /// Ordered by first occurrence; duplicate tags retain their last value.
  final Map<String, String> headers;
  final List<PgnHeaderDiagnostic> diagnostics;
  final bool isMalformed;

  /// Character offset of the first non-header token, after header trivia.
  final int movetextOffset;
}
