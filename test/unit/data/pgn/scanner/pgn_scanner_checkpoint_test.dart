import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/pgn/scanner/pgn_boundary_scanner.dart';

void main() {
  group('safe checkpoints', () {
    for (final sample in [
      ('tag', '[Event "A'),
      ('move token', '[Event "A"]\n1. e4'),
      ('brace comment', '[Event "A"]\n1. e4 {comment'),
      ('variation', '[Event "A"]\n1. e4 (1. d4'),
    ]) {
      test('cancelling in a ${sample.$1} resumes the candidate once', () {
        final source = utf8.encode('${sample.$2} e5 1-0');
        final scanner = PgnBoundaryScanner();
        final emitted = scanner.consume(utf8.encode(sample.$2));

        expect(emitted, isEmpty);
        expect(scanner.safeCheckpoint, 0);
        final checkpoint = scanner.safeCheckpoint;
        scanner.cancel();
        expect(scanner.safeCheckpoint, checkpoint);
        expect(() => scanner.consume(const []), throwsStateError);

        final resumed = PgnBoundaryScanner(startOffset: checkpoint);
        final ranges = resumed.consume(source.sublist(checkpoint))
          ..addAll(resumed.finish());
        expect(ranges, hasLength(1));
        expect(ranges.single.startOffset, checkpoint);
        expect(ranges.single.endOffset, source.length);
      });
    }

    test('checkpoint does not advance into leading comments', () {
      final prefix = utf8.encode(' {leading comment [Event "fake"]');
      final scanner = PgnBoundaryScanner();
      scanner.consume(prefix);

      expect(scanner.safeCheckpoint, 1);
      scanner.cancel();

      final source = utf8.encode(
        ' {leading comment [Event "fake"]} [Event "real"] 1. e4 *',
      );
      final resumed = PgnBoundaryScanner(startOffset: scanner.safeCheckpoint);
      final ranges = resumed.consume(source.sublist(scanner.safeCheckpoint))
        ..addAll(resumed.finish());
      expect(ranges, hasLength(1));
      expect(
        utf8.decode(source.sublist(ranges.single.startOffset)),
        contains('[Event "real"]'),
      );
      expect(
        utf8.decode(source.sublist(ranges.single.startOffset)),
        isNot(contains('fake')),
      );
    });

    test('semicolon comment checkpoint stays before comment until newline', () {
      final source = utf8.encode(
        '; comment [Event "fake"]\n[Event "real"] 1. e4 *',
      );
      final scanner = PgnBoundaryScanner();
      scanner.consume(source.sublist(0, source.indexOf(10)));
      expect(scanner.safeCheckpoint, 0);
      scanner.consume(
        source.sublist(source.indexOf(10), source.indexOf(10) + 1),
      );
      expect(scanner.safeCheckpoint, source.indexOf(10) + 1);
    });

    test('cancel is stable before input and after a completed result', () {
      final empty = PgnBoundaryScanner(startOffset: 17);
      empty.cancel();
      expect(empty.safeCheckpoint, 17);

      final scanner = PgnBoundaryScanner();
      final source = utf8.encode('[Event "A"] 1-0');
      final completed = scanner.consume(source)..addAll(scanner.finish());
      expect(completed, hasLength(1));
      expect(scanner.safeCheckpoint, source.length);
      scanner.cancel();
      expect(scanner.safeCheckpoint, source.length);
    });

    test('finish is idempotent and closes the final candidate', () {
      final scanner = PgnBoundaryScanner();
      final source = utf8.encode('[Event "A"] 1. e4');
      scanner.consume(source);
      expect(scanner.finish(), hasLength(1));
      expect(scanner.finish(), isEmpty);
      expect(scanner.safeCheckpoint, source.length);
    });

    test('nonzero start offsets are preserved by cancel and resume', () {
      const start = 23;
      final block = utf8.encode('[Event "A"] 1. e4 *');
      final scanner = PgnBoundaryScanner(startOffset: start);
      scanner.consume(block.sublist(0, 10));
      expect(scanner.safeCheckpoint, start);
      scanner.cancel();

      final resumed = PgnBoundaryScanner(startOffset: scanner.safeCheckpoint);
      final ranges = resumed.consume(block)..addAll(resumed.finish());
      expect(ranges.single.startOffset, start);
      expect(ranges.single.endOffset, start + block.length);
    });
  });
}
