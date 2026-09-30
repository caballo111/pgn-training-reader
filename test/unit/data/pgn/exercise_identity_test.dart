import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/pgn/exercise_identity.dart';

void main() {
  const resolver = ExerciseIdentityResolver();

  group('ExerciseIdentityResolver', () {
    test('keeps a valid authored ID exactly, including duplicate status', () {
      final result = resolver.resolve(
        sourceId: 'source',
        startOffset: 0,
        headers: const {'X-ExerciseId': '  authored-id '},
        authoredLine: '1. e4 *',
        duplicateAuthoredId: true,
      );

      expect(result.exerciseId, '  authored-id ');
      expect(result.duplicate, isTrue);
      expect(result.generated, isFalse);
    });

    test('falls through invalid authored ID to explicit imported mapping', () {
      final result = resolver.resolve(
        sourceId: 'source',
        startOffset: 0,
        headers: const {'X-ExerciseId': ' \t'},
        importedMapping: 'mapped-id',
        authoredLine: '1. e4 *',
      );

      expect(result.exerciseId, 'mapped-id');
      expect(result.generated, isFalse);
      expect(result.duplicate, isFalse);
    });

    test('invalid IDs fall through to a deterministic fingerprint', () {
      final args = <String, Object>{
        'sourceId': 'source',
        'startOffset': 12,
        'headers': const {'X-ExerciseId': 'bad\u0000id'},
        'authoredLine': '1. e4   e5  2. Nf3 *',
      };
      final first = resolver.resolve(
        sourceId: args['sourceId']! as String,
        startOffset: args['startOffset']! as int,
        headers: args['headers']! as Map<String, String>,
        authoredLine: args['authoredLine']! as String,
      );
      final same = resolver.resolve(
        sourceId: 'source',
        startOffset: 12,
        headers: const {},
        authoredLine: ' 1. e4\ne5 2. Nf3 * ',
      );
      expect(first.exerciseId, startsWith('generated-'));
      expect(first.exerciseId, matches(RegExp(r'^generated-[0-9a-f]{16}$')));
      expect(first.exerciseId, same.exerciseId);
      expect(first.generated, isTrue);
    });

    test(
      'uses stable UTF-8 fingerprint bytes for non-ASCII authored lines',
      () {
        final result = resolver.resolve(
          sourceId: 's',
          startOffset: 0,
          headers: const {},
          authoredLine: '1. e4 ♞ *',
        );

        expect(result.exerciseId, 'generated-203ee749cf103be1');
        expect(result.exerciseId, matches(RegExp(r'^generated-[0-9a-f]{16}$')));
      },
    );

    test('fallback incorporates source, offset, FEN, and normalized line', () {
      final baseline = resolver.resolve(
        sourceId: 'source',
        startOffset: 12,
        headers: const {},
        authoredLine: '1. e4 *',
      );
      final changedOffset = resolver.resolve(
        sourceId: 'source',
        startOffset: 13,
        headers: const {},
        authoredLine: '1. e4 *',
      );
      final changedFen = resolver.resolve(
        sourceId: 'source',
        startOffset: 12,
        headers: const {'FEN': '8/8/8/8/8/8/4k3/4K3 w - - 0 1'},
        authoredLine: '1. e4 *',
      );
      final changedSource = resolver.resolve(
        sourceId: 'other',
        startOffset: 12,
        headers: const {},
        authoredLine: '1. e4 *',
      );
      expect(changedOffset.exerciseId, isNot(baseline.exerciseId));
      expect(changedFen.exerciseId, isNot(baseline.exerciseId));
      expect(changedSource.exerciseId, isNot(baseline.exerciseId));
    });

    test('rejects negative offsets', () {
      expect(
        () => resolver.resolve(
          sourceId: 'source',
          startOffset: -1,
          headers: const {},
          authoredLine: '',
        ),
        throwsArgumentError,
      );
    });
  });
}
