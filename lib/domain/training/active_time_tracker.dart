// ignore_for_file: prefer_initializing_formals

import '../../core/time/app_clock.dart';
import '../../core/utilities/id_generator.dart';
import 'timing_segment.dart';

/// Measures puzzle work with monotonic time while retaining wall timestamps
/// for the persisted segment history.
///
/// This tracker is process-local. Callers persist each returned segment and
/// the accumulated duration as part of the corresponding lifecycle write.
/// Recovery closes an open segment at its last durable boundary, so elapsed
/// time that cannot be measured safely is discarded.
final class ActiveTimeTracker {
  ActiveTimeTracker({required AppClock clock, required IdGenerator idGenerator})
    : _clock = clock,
      _idGenerator = idGenerator;

  final AppClock _clock;
  final IdGenerator _idGenerator;
  final Map<String, _OpenSegment> _openSegments = {};
  final Map<String, Duration> _accumulated = {};

  /// Starts the first active segment for an attempt.
  TimingSegment startSegment({
    required String attemptId,
    String? sessionId,
    required DateTime startedAt,
  }) => _open(attemptId: attemptId, sessionId: sessionId, startedAt: startedAt);

  /// Opens a fresh active segment after a pause or recovery.
  TimingSegment resumeSegment({
    required String attemptId,
    String? sessionId,
    required DateTime startedAt,
  }) => _open(attemptId: attemptId, sessionId: sessionId, startedAt: startedAt);

  /// Restores a previously persisted total before tracking more work.
  void restoreAccumulatedDuration({
    required String attemptId,
    required Duration duration,
  }) {
    if (attemptId.isEmpty) {
      throw ArgumentError.value(attemptId, 'attemptId', 'Must not be empty.');
    }
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'Must not be negative.');
    }
    if (_openSegments.containsKey(attemptId)) {
      throw StateError('Cannot restore an attempt with an open segment.');
    }
    _accumulated[attemptId] = duration;
  }

  /// Adopts a durable open segment during in-process service restoration.
  ///
  /// Time before adoption is not measured. This also makes adoption safe when
  /// a process restarted and the old monotonic reading is unavailable.
  void adoptOpenSegment(TimingSegment segment) {
    if (segment.endedAt != null || segment.activeDuration != null) {
      throw ArgumentError.value(segment, 'segment', 'Must be open.');
    }
    if (_openSegments.containsKey(segment.attemptId)) {
      throw StateError('Attempt already has an active timing segment.');
    }
    _openSegments[segment.attemptId] = _OpenSegment(
      segmentId: segment.id,
      startedAt: segment.startedAt,
      sessionId: segment.sessionId,
      monotonicStartedAt: _clock.monotonicElapsed,
    );
  }

  /// Closes the open segment and adds its monotonic elapsed time to the total.
  TimingSegment closeSegment({
    required String attemptId,
    required DateTime endedAt,
  }) {
    final open = _openSegments.remove(attemptId);
    if (open == null) {
      throw StateError('Attempt has no active timing segment.');
    }
    if (endedAt.isBefore(open.startedAt)) {
      _openSegments[attemptId] = open;
      throw ArgumentError.value(endedAt, 'endedAt', 'Must not precede start.');
    }

    final elapsed = _elapsedSince(open.monotonicStartedAt);
    _accumulated[attemptId] = accumulatedDuration(attemptId) + elapsed;
    return TimingSegment(
      id: open.segmentId,
      attemptId: attemptId,
      sessionId: open.sessionId,
      startedAt: open.startedAt,
      endedAt: endedAt.toUtc(),
      activeDuration: elapsed,
    );
  }

  /// Closes at the last durable boundary and excludes unmeasurable time.
  ///
  /// The resulting segment has zero duration and ends at its start timestamp.
  /// Returns null when the attempt has no open segment.
  TimingSegment? recover({required String attemptId}) {
    final open = _openSegments.remove(attemptId);
    if (open == null) return null;
    return TimingSegment(
      id: open.segmentId,
      attemptId: attemptId,
      sessionId: open.sessionId,
      startedAt: open.startedAt,
      endedAt: open.startedAt,
      activeDuration: Duration.zero,
    );
  }

  /// Returns completed active time, excluding any currently open segment.
  Duration accumulatedDuration(String attemptId) =>
      _accumulated[attemptId] ?? Duration.zero;

  /// Returns current monotonic time in the open segment, or zero if paused.
  Duration currentSegmentDuration(String attemptId) {
    final open = _openSegments[attemptId];
    return open == null
        ? Duration.zero
        : _elapsedSince(open.monotonicStartedAt);
  }

  TimingSegment _open({
    required String attemptId,
    String? sessionId,
    required DateTime startedAt,
  }) {
    if (attemptId.isEmpty) {
      throw ArgumentError.value(attemptId, 'attemptId', 'Must not be empty.');
    }
    if (_openSegments.containsKey(attemptId)) {
      throw StateError('Attempt already has an active timing segment.');
    }
    final utcStartedAt = startedAt.toUtc();
    final segmentId = _idGenerator.generateId();
    _openSegments[attemptId] = _OpenSegment(
      segmentId: segmentId,
      startedAt: utcStartedAt,
      sessionId: sessionId,
      monotonicStartedAt: _clock.monotonicElapsed,
    );
    return TimingSegment(
      id: segmentId,
      attemptId: attemptId,
      sessionId: sessionId,
      startedAt: utcStartedAt,
    );
  }

  Duration _elapsedSince(Duration started) {
    final elapsed = _clock.monotonicElapsed - started;
    if (elapsed.isNegative) {
      throw StateError('Monotonic clock moved backwards.');
    }
    return elapsed;
  }
}

final class _OpenSegment {
  const _OpenSegment({
    required this.segmentId,
    required this.startedAt,
    required this.sessionId,
    required this.monotonicStartedAt,
  });

  final String segmentId;
  final DateTime startedAt;
  final String? sessionId;
  final Duration monotonicStartedAt;
}
