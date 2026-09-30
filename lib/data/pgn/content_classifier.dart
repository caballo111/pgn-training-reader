import '../../domain/chess_content/content_type.dart';

/// Classifies one block from its PGN headers while retaining classification
/// provenance for callers that need to expose inferred values for editing.
final class ContentClassificationResult {
  const ContentClassificationResult({
    required this.contentType,
    required this.inferred,
    required this.authoredValue,
  });

  final ContentType contentType;
  final bool inferred;

  /// The exact authored `X-ContentType` value, or null when absent.
  final String? authoredValue;
}

/// Applies the custom content tag and conservative legacy fallback rules.
final class ContentClassifier {
  const ContentClassifier();

  ContentClassificationResult classify(Map<String, String> headers) {
    final authoredValue = headers['X-ContentType'];
    final variant = headers['Variant'];
    final standardVariant = variant == null || variant == 'Standard';

    // A variant the chess rules layer does not support cannot be passed through
    // as ordinary chess, even when the block otherwise looks like a puzzle.
    if (!standardVariant) {
      return ContentClassificationResult(
        contentType: ContentType.unsupported,
        inferred: false,
        authoredValue: authoredValue,
      );
    }

    if (authoredValue != null) {
      final contentType = switch (authoredValue) {
        'Puzzle' => ContentType.puzzle,
        'Instruction' => ContentType.instruction,
        'Demonstration' => ContentType.demonstration,
        _ => ContentType.unsupported,
      };
      return ContentClassificationResult(
        contentType: contentType,
        inferred: false,
        authoredValue: authoredValue,
      );
    }

    // Legacy setup positions commonly represent exercises. In the absence of
    // explicit semantics, ordinary games are safest to present as demos.
    final hasCustomStart =
        headers['SetUp'] == '1' && headers.containsKey('FEN');
    return ContentClassificationResult(
      contentType: hasCustomStart
          ? ContentType.puzzle
          : ContentType.demonstration,
      inferred: true,
      authoredValue: null,
    );
  }
}
