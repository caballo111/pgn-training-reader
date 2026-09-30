import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/training/active_time_tracker.dart';
import 'package:pgntrainingreader/domain/training/timing_segment.dart';

import '../../support/fake_app_clock.dart';
import '../../support/fake_id_generator.dart';

void main() {
  group('ActiveTimeTracker', () {
    late FakeAppClock clock;
    late ActiveTimeTracker tracker;
    final start = DateTime.utc(2026, 9, 30, 12);

    setUp(() {
      clock = FakeAppClock(initialWallTime: start);
      tracker = ActiveTimeTracker(
        clock: clock,
        idGenerator: FakeIdGenerator(prefix: 'segment'),
      );
    });

    test('wall clock changes do not affect monotonic active duration', () {
      final open = tracker.startSegment(
        attemptId: 'attempt-1',
        startedAt: start,
      );
      expect(open.endedAt, isNull);
      clock.advance(const Duration(seconds: 8));
      clock.changeWallTime(const Duration(hours: 5));
      expect(
        tracker.currentSegmentDuration('attempt-1'),
        const Duration(seconds: 8),
      );

      clock.advance(const Duration(seconds: 4));
      clock.changeWallTime(const Duration(hours: -4));
      final closed = tracker.closeSegment(
        attemptId: 'attempt-1',
        endedAt: clock.utcNow,
      );

      expect(closed.activeDuration, const Duration(seconds: 12));
      expect(
        tracker.accumulatedDuration('attempt-1'),
        const Duration(seconds: 12),
      );
    });

    test('pause and resume exclude the inactive gap', () {
      tracker.startSegment(attemptId: 'attempt-1', startedAt: start);
      clock.advance(const Duration(seconds: 9));
      tracker.closeSegment(attemptId: 'attempt-1', endedAt: clock.utcNow);
      clock.advance(const Duration(minutes: 3));

      final resumedAt = clock.utcNow;
      final resumed = tracker.resumeSegment(
        attemptId: 'attempt-1',
        startedAt: resumedAt,
      );
      expect(resumed, isA<TimingSegment>());
      clock.advance(const Duration(seconds: 6));
      tracker.closeSegment(attemptId: 'attempt-1', endedAt: clock.utcNow);

      expect(
        tracker.accumulatedDuration('attempt-1'),
        const Duration(seconds: 15),
      );
    });

    test('recovery excludes elapsed time after the durable boundary', () {
      tracker.startSegment(attemptId: 'attempt-1', startedAt: start);
      clock.advance(const Duration(seconds: 7));

      final recovered = tracker.recover(attemptId: 'attempt-1');

      expect(recovered, isNotNull);
      expect(recovered!.endedAt, start);
      expect(recovered.activeDuration, Duration.zero);
      expect(tracker.accumulatedDuration('attempt-1'), Duration.zero);
      expect(tracker.recover(attemptId: 'attempt-1'), isNull);
    });
  });
}
