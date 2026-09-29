/// A safe, typed failure that can cross application layer boundaries.
///
/// [message] is suitable for presenting or recording after review. Callers
/// should not put source text, file paths, content URIs, or solution moves in
/// either [message] or [code].
sealed class AppFailure implements Exception {
  const AppFailure({required this.code, required this.message});

  /// Stable machine-readable identifier for the failure.
  final String code;

  /// Safe explanation of what went wrong.
  final String message;

  @override
  String toString() => '$runtimeType($code): $message';
}

/// A failure while selecting, reading, or storing a source file.
final class FileFailure extends AppFailure {
  const FileFailure({required super.code, required super.message});
}

/// A failure while scanning, parsing, or interpreting PGN content.
final class PgnFailure extends AppFailure {
  const PgnFailure({required super.code, required super.message});
}

/// A failure while reading or updating persistent application data.
final class DatabaseFailure extends AppFailure {
  const DatabaseFailure({required super.code, required super.message});
}

/// A failure caused by invalid input or a violated application constraint.
final class ValidationFailure extends AppFailure {
  const ValidationFailure({required super.code, required super.message});
}

/// A failure for content that the application cannot safely interpret.
final class UnsupportedContentFailure extends AppFailure {
  const UnsupportedContentFailure({
    required super.code,
    required super.message,
  });
}
