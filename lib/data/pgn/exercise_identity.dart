import 'dart:convert';

/// Resolves the durable identity hint for one indexed PGN block.
///
/// Duplicate detection belongs to the indexer/database: this resolver accepts
/// the database's duplicate decision for the current authored ID and never
/// keeps a process-wide set of IDs.
final class ExerciseIdentityResolver {
  const ExerciseIdentityResolver();

  static bool isValidAuthoredId(String? value) =>
      value != null && _isValidIdentity(value);

  ExerciseIdentityResult resolve({
    required String sourceId,
    required int startOffset,
    required Map<String, String> headers,
    required String authoredLine,
    String? importedMapping,
    bool duplicateAuthoredId = false,
  }) {
    if (sourceId.isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'Must not be empty.');
    }
    if (startOffset < 0) {
      throw ArgumentError.value(
        startOffset,
        'startOffset',
        'Must be nonnegative.',
      );
    }

    final authoredId = headers['X-ExerciseId'];
    if (authoredId != null && _isValidIdentity(authoredId)) {
      return ExerciseIdentityResult(
        exerciseId: authoredId,
        duplicate: duplicateAuthoredId,
        generated: false,
        authoredExerciseId: authoredId,
        fallbackIdentityKey: null,
      );
    }

    if (importedMapping != null && _isValidIdentity(importedMapping)) {
      return ExerciseIdentityResult(
        exerciseId: importedMapping,
        duplicate: false,
        generated: false,
        authoredExerciseId: null,
        fallbackIdentityKey: null,
      );
    }

    final fen = _normalizeWhitespace(headers['FEN'] ?? _standardStartingFen);
    final line = _normalizeWhitespace(authoredLine);
    final fingerprintInput = _frame(<String>[
      sourceId,
      startOffset.toString(),
      fen,
      line,
    ]);
    return ExerciseIdentityResult(
      exerciseId: 'generated-${_fnv1a64(fingerprintInput)}',
      duplicate: false,
      generated: true,
      authoredExerciseId: null,
      fallbackIdentityKey: _fnv1a64(
        _frame(<String>[
          _normalizeWhitespace(headers['FEN'] ?? _standardStartingFen),
          line,
        ]),
      ),
    );
  }
}

/// The identity and its provenance for one block.
final class ExerciseIdentityResult {
  const ExerciseIdentityResult({
    required this.exerciseId,
    required this.duplicate,
    required this.generated,
    required this.authoredExerciseId,
    required this.fallbackIdentityKey,
  });

  final String exerciseId;
  final bool duplicate;
  final bool generated;
  final String? authoredExerciseId;
  final String? fallbackIdentityKey;
}

const _standardStartingFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

bool _isValidIdentity(String value) {
  if (value.trim().isEmpty) return false;
  for (final rune in value.runes) {
    if (rune < 0x20 || (rune >= 0x7f && rune <= 0x9f)) return false;
  }
  return true;
}

String _normalizeWhitespace(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

String _frame(List<String> values) => values
    .map((value) {
      final bytes = value.codeUnits;
      return '${bytes.length}:$value';
    })
    .join('|');

/// Compact deterministic 64-bit FNV-1a fingerprint. It is an identity hint,
/// not a cryptographic digest; the database retains each block separately.
String _fnv1a64(String value) {
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = BigInt.parse('ffffffffffffffff', radix: 16);
  for (final byte in utf8.encode(value)) {
    hash = ((hash ^ BigInt.from(byte)) * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
