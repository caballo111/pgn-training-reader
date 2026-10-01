import 'pgn_scanner_state.dart';

/// A byte range containing one PGN game (end offset is exclusive).
class PgnBlockRange {
  const PgnBlockRange({
    required this.startOffset,
    required this.endOffset,
    this.isMalformed = false,
    this.diagnosticCode,
  });

  final int startOffset;
  final int endOffset;
  final bool isMalformed;
  final String? diagnosticCode;
}

/// Incrementally finds game boundaries without retaining source text.
///
/// Feed source bytes to [consume]. Only newly completed ranges are returned.
/// [startOffset] supports resuming at a previously saved safe checkpoint.
class PgnBoundaryScanner {
  /// Import bounds selected for predictable memory and parser stack use.
  static const int maximumTagBytes = 64 * 1024;
  static const int maximumCommentBytes = 1024 * 1024;
  static const int maximumVariationDepth = 256;

  PgnBoundaryScanner({int startOffset = 0})
    : state = PgnScannerState(
        absoluteOffset: startOffset,
        lineStartOffset: startOffset,
      ),
      _safeCheckpoint = startOffset;

  final PgnScannerState state;
  int _safeCheckpoint = 0;
  bool _closed = false;
  int? _candidateStart;
  int? _triviaStart;
  bool _hasMovetext = false;
  bool _malformed = false;
  String? _diagnostic;
  final StringBuffer _token = StringBuffer();
  int _tokenLength = 0;
  int _lexicalBytes = 0;

  /// Last offset known not to lie inside an unresolved game.
  int get safeCheckpoint => _candidateStart ?? _triviaStart ?? _safeCheckpoint;

  List<PgnBlockRange> consume(List<int> bytes) {
    if (_closed) throw StateError('Scanner is closed');
    final emitted = <PgnBlockRange>[];
    for (final byte in bytes) {
      final offset = state.absoluteOffset;
      final inLexical =
          state.inTag ||
          state.inBraceComment ||
          state.inSemicolonComment ||
          state.variationDepth > 0;

      // A UTF-8 BOM belongs to the source encoding, not to a game range.
      if ((offset == 0 && byte == 0xef) ||
          (offset == 1 && byte == 0xbb) ||
          (offset == 2 && byte == 0xbf)) {
        state.recordLineByte(32, offset);
        state.absoluteOffset++;
        if (_candidateStart == null) _safeCheckpoint = state.absoluteOffset;
        continue;
      }

      final c = String.fromCharCode(byte);
      if (state.inSemicolonComment) {
        _lexicalBytes++;
        if (_lexicalBytes > maximumCommentBytes) {
          _markMalformed('comment_too_large');
        }
        if (byte == 10 || byte == 13) {
          state.inSemicolonComment = false;
          _triviaStart = null;
          _lexicalBytes = 0;
        }
      } else if (state.inBraceComment) {
        _lexicalBytes++;
        if (_lexicalBytes > maximumCommentBytes) {
          _markMalformed('comment_too_large');
        }
        if (byte == 125) {
          state.inBraceComment = false;
          _triviaStart = null;
          _lexicalBytes = 0;
        }
      } else if (state.inTagString) {
        _lexicalBytes++;
        if (_lexicalBytes > maximumTagBytes) _markMalformed('tag_too_large');
        if (state.tagEscapePending) {
          state.tagEscapePending = false;
          if (byte == 10 || byte == 13) {
            _malformed = true;
            _diagnostic ??= 'unterminated_tag_string';
            state.inTag = false;
            state.inTagString = false;
            _lexicalBytes = 0;
          }
        } else if (byte == 92) {
          state.tagEscapePending = true;
        } else if (byte == 34) {
          state.inTagString = false;
          if (!state.inTag) _lexicalBytes = 0;
        } else if (byte == 10 || byte == 13) {
          _malformed = true;
          _diagnostic ??= 'unterminated_tag_string';
          state.inTag = false;
          state.inTagString = false;
        }
      } else if (state.inTag) {
        _lexicalBytes++;
        if (_lexicalBytes > maximumTagBytes) _markMalformed('tag_too_large');
        if (byte == 34) state.inTagString = true;
        if (byte == 93) {
          state.inTag = false;
          _lexicalBytes = 0;
        }
        if ((byte == 10 || byte == 13) && state.inTag) {
          _malformed = true;
          _diagnostic ??= 'unterminated_tag';
          state.inTag = false;
          _lexicalBytes = 0;
        }
      } else if (byte == 123) {
        _flushToken(emitted, offset);
        if (_candidateStart == null) _triviaStart = offset;
        state.inBraceComment = true;
        _lexicalBytes = 1;
      } else if (byte == 59) {
        _flushToken(emitted, offset);
        if (_candidateStart == null) _triviaStart = offset;
        state.inSemicolonComment = true;
        _lexicalBytes = 1;
      } else if (byte == 40) {
        _flushToken(emitted, offset);
        if (_candidateStart != null) {
          state.variationDepth++;
          if (state.variationDepth > maximumVariationDepth) {
            _markMalformed('variation_too_deep');
          }
        }
      } else if (byte == 41) {
        _flushToken(emitted, offset);
        if (state.variationDepth > 0) {
          state.variationDepth--;
        } else if (_candidateStart != null) {
          _malformed = true;
          _diagnostic ??= 'unmatched_variation_close';
        }
      } else if (byte == 91) {
        _flushToken(emitted, offset);
        if (_candidateStart != null &&
            _hasMovetext &&
            state.variationDepth == 0) {
          if (!_malformed) {
            _malformed = true;
            _diagnostic ??= 'missing_game_termination';
          }
          _emit(emitted, offset);
        }
        if (_candidateStart == null) _begin(offset);
        state.inTag = true;
        _hasMovetext = false;
      } else if (_isSpace(byte)) {
        _flushToken(emitted, offset);
      } else {
        if (_candidateStart == null) _begin(offset);
        if (byte == 42 || byte == 49 || byte == 48) {
          // Token collection below covers all movetext symbols, including results.
        }
        _appendToken(c);
        if (!state.inTag && !inLexical) _hasMovetext = true;
      }

      state.recordLineByte(byte, offset);
      state.absoluteOffset++;
      if (_candidateStart == null) _safeCheckpoint = state.absoluteOffset;
    }
    return emitted;
  }

  /// Completes at EOF. Incomplete lexical constructs are reported malformed.
  List<PgnBlockRange> finish() {
    if (_closed) return const [];
    final out = <PgnBlockRange>[];
    _flushToken(out, state.absoluteOffset);
    if (_candidateStart != null) {
      if (_hasMovetext &&
          !_malformed &&
          !state.inTag &&
          !state.inTagString &&
          !state.inBraceComment &&
          state.variationDepth == 0) {
        _malformed = true;
        _diagnostic ??= 'missing_game_termination';
      }
      if (state.inTag ||
          state.inTagString ||
          state.inBraceComment ||
          state.variationDepth > 0) {
        _malformed = true;
        _diagnostic ??= state.inBraceComment
            ? 'unterminated_brace_comment'
            : state.variationDepth > 0
            ? 'unterminated_variation'
            : 'unterminated_tag';
      }
      _emit(out, state.absoluteOffset);
    }
    _closed = true;
    _safeCheckpoint = state.absoluteOffset;
    return out;
  }

  /// Discards an unresolved candidate, leaving no pending range to emit.
  void cancel() {
    final unresolvedStart = _candidateStart;
    _candidateStart = null;
    state.candidateBlockStartOffset = null;
    _token.clear();
    _tokenLength = 0;
    _closed = true;
    if (unresolvedStart != null) _safeCheckpoint = unresolvedStart;
  }

  void _begin(int offset) {
    _candidateStart = offset;
    state.candidateBlockStartOffset = offset;
    _hasMovetext = false;
    _malformed = false;
    _diagnostic = null;
  }

  void _markMalformed(String code) {
    _malformed = true;
    _diagnostic ??= code;
  }

  void _appendToken(String c) {
    if (_tokenLength < 32) _token.write(c);
    _tokenLength++;
  }

  void _flushToken(List<PgnBlockRange> emitted, int end) {
    if (_tokenLength == 0) return;
    final token = _token.toString();
    _token.clear();
    _tokenLength = 0;
    if (state.variationDepth == 0 &&
        (token == '1-0' ||
            token == '0-1' ||
            token == '1/2-1/2' ||
            token == '*')) {
      if (_candidateStart != null) {
        _emit(emitted, end);
      }
    }
  }

  void _emit(List<PgnBlockRange> out, int end) {
    final start = _candidateStart;
    if (start == null || end <= start) return;
    out.add(
      PgnBlockRange(
        startOffset: start,
        endOffset: end,
        isMalformed: _malformed,
        diagnosticCode: _diagnostic,
      ),
    );
    _candidateStart = null;
    state.candidateBlockStartOffset = null;
    _safeCheckpoint = end;
    _hasMovetext = false;
    _malformed = false;
    _diagnostic = null;
    state.variationDepth = 0;
  }

  bool _isSpace(int b) => b == 9 || b == 10 || b == 13 || b == 32;
}
