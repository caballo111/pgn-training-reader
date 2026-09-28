/// Supplies timestamps and elapsed time without coupling callers to a clock.
///
/// [utcNow] is for persisted history; convert it to local time for calendar
/// grouping. Subtract readings from [monotonicElapsed] to measure active time;
/// wall-clock changes must not affect that duration. Monotonic readings are
/// relative to this clock instance and must not be persisted or compared across
/// process restarts.
abstract interface class AppClock {
  DateTime get utcNow;

  Duration get monotonicElapsed;
}

/// The clock used by the running application.
final class SystemAppClock implements AppClock {
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  DateTime get utcNow => DateTime.now().toUtc();

  @override
  Duration get monotonicElapsed => _stopwatch.elapsed;
}
