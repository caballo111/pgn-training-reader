import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/time/app_clock.dart';

import '../../../support/fake_app_clock.dart';

void main() {
  test('system clock returns UTC time and nondecreasing elapsed time', () {
    final AppClock clock = SystemAppClock();

    final firstElapsed = clock.monotonicElapsed;
    final secondElapsed = clock.monotonicElapsed;

    expect(clock.utcNow.isUtc, isTrue);
    expect(firstElapsed, greaterThanOrEqualTo(Duration.zero));
    expect(secondElapsed, greaterThanOrEqualTo(firstElapsed));
  });

  test('wall-clock jumps do not change monotonic elapsed time', () {
    final fake = FakeAppClock(
      initialWallTime: DateTime.utc(2026, 9, 28, 23, 59),
    );
    final AppClock clock = fake;

    final start = clock.monotonicElapsed;
    fake.advance(const Duration(minutes: 2));
    fake.changeWallTime(const Duration(hours: -3));

    expect(clock.utcNow, DateTime.utc(2026, 9, 28, 21, 1));
    expect(clock.monotonicElapsed - start, const Duration(minutes: 2));
  });

  test('fake rejects backward elapsed time without moving either clock', () {
    final fake = FakeAppClock(initialWallTime: DateTime.utc(2026, 9, 28));

    expect(
      () => fake.advance(const Duration(seconds: -1)),
      throwsArgumentError,
    );
    expect(fake.utcNow, DateTime.utc(2026, 9, 28));
    expect(fake.monotonicElapsed, Duration.zero);
  });
}
