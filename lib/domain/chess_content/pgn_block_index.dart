import 'content_type.dart';

/// Whether a PGN block's full contents have been parsed successfully.
///
/// Database values are an explicit persistence contract. They intentionally
/// do not use [Enum.name], so renaming a Dart enum value cannot silently change
/// stored data.
enum PgnBlockParseStatus {
  /// The block is indexed, but its full move tree has not been parsed yet.
  notParsed,

  /// The block's full contents were parsed successfully.
  valid,

  /// The block is malformed and could not be parsed faithfully.
  malformed,

  /// The block uses content the application cannot interpret as standard
  /// chess.
  unsupported;

  /// Returns the canonical value stored in the database.
  String toDatabaseValue() => switch (this) {
    PgnBlockParseStatus.notParsed => 'NotParsed',
    PgnBlockParseStatus.valid => 'Valid',
    PgnBlockParseStatus.malformed => 'Malformed',
    PgnBlockParseStatus.unsupported => 'Unsupported',
  };

  /// Parses a canonical database value.
  ///
  /// Parsing is case-sensitive and does not trim whitespace. Unknown values
  /// fail rather than being guessed, so incompatible data remains visible to
  /// the caller.
  static PgnBlockParseStatus fromDatabaseValue(String value) => switch (value) {
    'NotParsed' => PgnBlockParseStatus.notParsed,
    'Valid' => PgnBlockParseStatus.valid,
    'Malformed' => PgnBlockParseStatus.malformed,
    'Unsupported' => PgnBlockParseStatus.unsupported,
    _ => throw FormatException('Unknown PGN block parse status.', value),
  };
}

/// Searchable metadata and a source locator for one PGN block.
///
/// Offsets are byte offsets into the source, with [startOffset] inclusive and
/// [endOffset] exclusive. [ordinal] preserves source order. The diagnostic
/// summary must be sanitized and must not contain raw PGN text.
final class PgnBlockIndex {
  factory PgnBlockIndex({
    required String id,
    required String sourceId,
    required int startOffset,
    required int endOffset,
    required int ordinal,
    String? event,
    String? site,
    String? date,
    String? round,
    String? white,
    String? black,
    String? result,
    required ContentType contentType,
    String? exerciseId,
    String? section,
    int? sequence,
    String? theme,
    String? difficulty,
    required PgnBlockParseStatus parseStatus,
    String? diagnosticSummary,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (sourceId.isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'Must not be empty.');
    }
    if (startOffset < 0) {
      throw ArgumentError.value(
        startOffset,
        'startOffset',
        'Must not be negative.',
      );
    }
    if (endOffset < startOffset) {
      throw ArgumentError.value(
        endOffset,
        'endOffset',
        'Must be greater than or equal to startOffset.',
      );
    }
    if (ordinal < 0) {
      throw ArgumentError.value(ordinal, 'ordinal', 'Must not be negative.');
    }

    return PgnBlockIndex._(
      id: id,
      sourceId: sourceId,
      startOffset: startOffset,
      endOffset: endOffset,
      ordinal: ordinal,
      event: event,
      site: site,
      date: date,
      round: round,
      white: white,
      black: black,
      result: result,
      contentType: contentType,
      exerciseId: exerciseId,
      section: section,
      sequence: sequence,
      theme: theme,
      difficulty: difficulty,
      parseStatus: parseStatus,
      diagnosticSummary: diagnosticSummary,
    );
  }

  const PgnBlockIndex._({
    required this.id,
    required this.sourceId,
    required this.startOffset,
    required this.endOffset,
    required this.ordinal,
    required this.event,
    required this.site,
    required this.date,
    required this.round,
    required this.white,
    required this.black,
    required this.result,
    required this.contentType,
    required this.exerciseId,
    required this.section,
    required this.sequence,
    required this.theme,
    required this.difficulty,
    required this.parseStatus,
    required this.diagnosticSummary,
  });

  final String id;
  final String sourceId;
  final int startOffset;
  final int endOffset;
  final int ordinal;
  final String? event;
  final String? site;
  final String? date;
  final String? round;
  final String? white;
  final String? black;
  final String? result;
  final ContentType contentType;
  final String? exerciseId;
  final String? section;
  final int? sequence;
  final String? theme;
  final String? difficulty;
  final PgnBlockParseStatus parseStatus;
  final String? diagnosticSummary;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PgnBlockIndex &&
          other.id == id &&
          other.sourceId == sourceId &&
          other.startOffset == startOffset &&
          other.endOffset == endOffset &&
          other.ordinal == ordinal &&
          other.event == event &&
          other.site == site &&
          other.date == date &&
          other.round == round &&
          other.white == white &&
          other.black == black &&
          other.result == result &&
          other.contentType == contentType &&
          other.exerciseId == exerciseId &&
          other.section == section &&
          other.sequence == sequence &&
          other.theme == theme &&
          other.difficulty == difficulty &&
          other.parseStatus == parseStatus &&
          other.diagnosticSummary == diagnosticSummary;

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    startOffset,
    endOffset,
    ordinal,
    event,
    site,
    date,
    round,
    white,
    black,
    result,
    contentType,
    exerciseId,
    section,
    sequence,
    theme,
    difficulty,
    parseStatus,
    diagnosticSummary,
  );
}
