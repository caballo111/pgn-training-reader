/// Classification of one indexed PGN block.
///
/// Database values are an explicit persistence contract. They intentionally
/// do not use [Enum.name], so renaming a Dart enum value cannot silently change
/// stored data.
enum ContentType {
  puzzle,
  instruction,
  demonstration,
  unsupported;

  /// Returns the canonical string stored in the database.
  String toDatabaseValue() => switch (this) {
    ContentType.puzzle => 'Puzzle',
    ContentType.instruction => 'Instruction',
    ContentType.demonstration => 'Demonstration',
    ContentType.unsupported => 'Unsupported',
  };

  /// Parses a canonical database value.
  ///
  /// Parsing is deliberately case-sensitive and does not trim whitespace.
  /// Unknown values fail rather than being guessed as [ContentType.unsupported],
  /// so database corruption or a newer incompatible value remains visible to
  /// the caller.
  static ContentType fromDatabaseValue(String value) => switch (value) {
    'Puzzle' => ContentType.puzzle,
    'Instruction' => ContentType.instruction,
    'Demonstration' => ContentType.demonstration,
    'Unsupported' => ContentType.unsupported,
    _ => throw FormatException('Unknown content type database value.', value),
  };
}
