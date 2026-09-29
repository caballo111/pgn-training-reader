/// Severity for a structured application log record.
enum AppLogLevel { debug, info, warning, error }

/// Events that may be written to application logs.
///
/// Keep this list descriptive but content-free. In particular, callers cannot
/// supply arbitrary messages or maps that might contain imported PGN data.
enum AppLogEvent {
  importStarted,
  importProgress,
  importCompleted,
  importCancelled,
  importFailed,
  databaseMigrationStarted,
  databaseMigrationCompleted,
  databaseMigrationFailed,
  attemptTimingClosed,
}

/// Allowlisted fields for logs. Values are operational counters and durations;
/// source text, comments, paths, URIs, IDs, and moves have no representation.
final class AppLogRecord {
  const AppLogRecord({
    required this.level,
    required this.event,
    this.itemCount,
    this.successCount,
    this.failureCount,
    this.duration,
    this.version,
    this.cancelled,
  });

  final AppLogLevel level;
  final AppLogEvent event;
  final int? itemCount;
  final int? successCount;
  final int? failureCount;
  final Duration? duration;
  final int? version;
  final bool? cancelled;
}

/// Receives operational events without exposing user supplied content.
abstract interface class AppLogger {
  void log(
    AppLogLevel level,
    AppLogEvent event, {
    int? itemCount,
    int? successCount,
    int? failureCount,
    Duration? duration,
    int? version,
    bool? cancelled,
  });
}

/// Structured logger that forwards allowlisted records to an injected sink.
///
/// The sink controls the destination (for example, a platform logger or a
/// test collector). It receives no arbitrary strings from the caller.
final class StructuredAppLogger implements AppLogger {
  const StructuredAppLogger(this._writeRecord);

  final void Function(AppLogRecord record) _writeRecord;

  @override
  void log(
    AppLogLevel level,
    AppLogEvent event, {
    int? itemCount,
    int? successCount,
    int? failureCount,
    Duration? duration,
    int? version,
    bool? cancelled,
  }) {
    _writeRecord(
      AppLogRecord(
        level: level,
        event: event,
        itemCount: itemCount,
        successCount: successCount,
        failureCount: failureCount,
        duration: duration,
        version: version,
        cancelled: cancelled,
      ),
    );
  }
}
