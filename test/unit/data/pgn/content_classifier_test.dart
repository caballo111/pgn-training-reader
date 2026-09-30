import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/pgn/content_classifier.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';

void main() {
  const classifier = ContentClassifier();

  test('valid authored values are exact and authoritative', () {
    for (final entry in <String, ContentType>{
      'Puzzle': ContentType.puzzle,
      'Instruction': ContentType.instruction,
      'Demonstration': ContentType.demonstration,
    }.entries) {
      final result = classifier.classify({'X-ContentType': entry.key});
      expect(result.contentType, entry.value);
      expect(result.inferred, isFalse);
      expect(result.authoredValue, entry.key);
    }
  });

  test('unknown authored value is retained and unsupported', () {
    final result = classifier.classify({'X-ContentType': 'puzzle-v2'});
    expect(result.contentType, ContentType.unsupported);
    expect(result.inferred, isFalse);
    expect(result.authoredValue, 'puzzle-v2');
  });

  test('fallback infers puzzle only for a setup position with FEN', () {
    final result = classifier.classify({'SetUp': '1', 'FEN': 'position'});
    expect(result.contentType, ContentType.puzzle);
    expect(result.inferred, isTrue);
    expect(result.authoredValue, isNull);
  });

  test('ordinary block fallback is inferred demonstration', () {
    final result = classifier.classify(const {});
    expect(result.contentType, ContentType.demonstration);
    expect(result.inferred, isTrue);
    expect(result.authoredValue, isNull);
  });

  test('unsupported variants are never classified as supported chess', () {
    final result = classifier.classify({
      'Variant': 'Crazyhouse',
      'X-ContentType': 'Puzzle',
    });
    expect(result.contentType, ContentType.unsupported);
    expect(result.inferred, isFalse);
    expect(result.authoredValue, 'Puzzle');
  });
}
