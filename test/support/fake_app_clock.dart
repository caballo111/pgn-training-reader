import 'package:pgntrainingreader/core/time/app_clock.dart';

/// A clock whose wall time and elapsed time can be controlled by tests.
final class FakeAppClock implements AppClock {
  FakeAppClock({required DateTime initialWallTime})
    : _utcNow = initialWallTime.toUtc();

  DateTime _utcNow;
  Duration _monotonicElapsed = Duration.zero;

  @override
  DateTime get utcNow => _utcNow;

  @override
  Duration get monotonicElapsed => _monotonicElapsed;

  /// Advances both clocks as ordinary time passes.
  void advance(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'Must not be negative');
    }

    _utcNow = _utcNow.add(duration);
    _monotonicElapsed += duration;
  }

  /// Simulates a manual wall-clock change.
  /// A negative offset is allowed and does not change elapsed time.
  void changeWallTime(Duration offset) {
    _utcNow = _utcNow.add(offset);
  }
}
