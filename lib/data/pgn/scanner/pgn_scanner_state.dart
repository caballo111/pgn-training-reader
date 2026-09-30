/// Bounded lexical state carried between chunks by [PgnBoundaryScanner].
///
/// Offsets are byte offsets into the original PGN. The state deliberately
/// stores no PGN text, so its memory use does not depend on source size or on
/// the length of a tag, comment, or movetext line.
class PgnScannerState {
  PgnScannerState({
    this.absoluteOffset = 0,
    this.lineStartOffset = 0,
    this.atLineStart = true,
    this.inTag = false,
    this.inTagString = false,
    this.tagEscapePending = false,
    this.inBraceComment = false,
    this.inSemicolonComment = false,
    this.variationDepth = 0,
    this.candidateBlockStartOffset,
    this.previousByteWasCarriageReturn = false,
  });

  /// Absolute offset of the next byte to consume.
  int absoluteOffset;

  /// Absolute offset of the first byte of the current line.
  int lineStartOffset;

  /// Whether no non-line-ending byte has been consumed on this line.
  bool atLineStart;

  /// Whether the scanner is inside a tag pair (`[...]`).
  bool inTag;

  /// Whether the scanner is inside the quoted value of a tag pair.
  bool inTagString;

  /// Whether a backslash was the last byte in a quoted tag value.
  bool tagEscapePending;

  /// Whether the scanner is inside a brace comment (`{...}`).
  bool inBraceComment;

  /// Whether the scanner is inside a semicolon comment through end of line.
  bool inSemicolonComment;

  /// Nesting depth of recursive annotation variations.
  int variationDepth;

  /// Start offset of the current candidate block, if one has been found.
  int? candidateBlockStartOffset;

  /// Tracks CRLF so it is treated as one line ending across chunk edges.
  bool previousByteWasCarriageReturn;

  /// Records a byte for line tracking and returns true at a line boundary.
  ///
  /// The caller should pass the byte's absolute offset before incrementing
  /// [absoluteOffset]. Both LF and CR are supported; CRLF advances the next
  /// line start after LF while reporting a single line boundary at CR.
  bool recordLineByte(int byte, int byteOffset) {
    if (byte == 0x0a) {
      final isNewBoundary = !previousByteWasCarriageReturn;
      if (!previousByteWasCarriageReturn) {
        lineStartOffset = byteOffset + 1;
        atLineStart = true;
      } else {
        // CR already marked the boundary. Move the start past LF as well.
        lineStartOffset = byteOffset + 1;
        atLineStart = true;
      }
      previousByteWasCarriageReturn = false;
      return isNewBoundary;
    }

    if (byte == 0x0d) {
      lineStartOffset = byteOffset + 1;
      atLineStart = true;
      previousByteWasCarriageReturn = true;
      return true;
    }

    previousByteWasCarriageReturn = false;
    atLineStart = false;
    return false;
  }

  /// Returns an independent snapshot suitable for a resumable checkpoint.
  PgnScannerState copy() => PgnScannerState(
    absoluteOffset: absoluteOffset,
    lineStartOffset: lineStartOffset,
    atLineStart: atLineStart,
    inTag: inTag,
    inTagString: inTagString,
    tagEscapePending: tagEscapePending,
    inBraceComment: inBraceComment,
    inSemicolonComment: inSemicolonComment,
    variationDepth: variationDepth,
    candidateBlockStartOffset: candidateBlockStartOffset,
    previousByteWasCarriageReturn: previousByteWasCarriageReturn,
  );
}
