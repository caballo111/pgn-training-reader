/// Lifecycle phase reported while a PGN source is being imported.
///
/// A terminal phase is one of [completed], [cancelled], or [failed]. A
/// cancelled or failed import may still be resumable; that decision is
/// reported by [PgnImportResult.resumeDisposition].
enum PgnImportPhase {
  selecting,
  preparing,
  indexing,
  completed,
  cancelled,
  failed,
}

/// Severity of an import diagnostic.
enum PgnImportDiagnosticSeverity { info, warning, error }

/// Stable categories for actionable import diagnostics.
///
/// Implementations may add categories in a compatible release. They must not
/// put source PGN text, comments, or solution moves in a diagnostic message.
enum PgnImportDiagnosticCategory {
  malformedBlock,
  unsupportedContent,
  invalidEncoding,
  duplicateExerciseId,
  unresolvedFallbackIdentity,
  duplicateSource,
  sourceUnavailable,
  sourceChanged,
  storageFailure,
  other,
}

/// The recovery action available after an import stops before completion.
enum PgnImportResumeDisposition {
  /// The job has a safe checkpoint and the same source revision is available.
  resume,

  /// There is no safe continuation point; a fresh import can be started.
  restart,

  /// The source is missing, changed, or inaccessible and must be repaired.
  repairSource,

  /// The import completed, so no recovery action is needed.
  none,
}

/// Request to index a source already registered in the local library.
final class PgnImportRequest {
  PgnImportRequest({required this.sourceId}) {
    if (sourceId.isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'Must not be empty.');
    }
  }

  /// Registered source to import.
  final String sourceId;
}

/// A point-in-time view of import activity.
///
/// [bytesRead] and [totalBytes] are optional because some sources cannot
/// provide a reliable length. [fractionComplete] is null when progress cannot
/// be measured; consumers should still display phase and indexed counts.
final class PgnImportProgress {
  factory PgnImportProgress({
    required String jobId,
    required PgnImportPhase phase,
    int? bytesRead,
    int? totalBytes,
    required int indexedBlockCount,
    required int diagnosticCount,
    required bool cancellationRequested,
    int safeCheckpoint = 0,
  }) {
    if (jobId.isEmpty) {
      throw ArgumentError.value(jobId, 'jobId', 'Must not be empty.');
    }
    if (bytesRead != null && bytesRead < 0) {
      throw ArgumentError.value(
        bytesRead,
        'bytesRead',
        'Must not be negative.',
      );
    }
    if (totalBytes != null && totalBytes < 0) {
      throw ArgumentError.value(
        totalBytes,
        'totalBytes',
        'Must not be negative.',
      );
    }
    if (indexedBlockCount < 0) {
      throw ArgumentError.value(
        indexedBlockCount,
        'indexedBlockCount',
        'Must not be negative.',
      );
    }
    if (diagnosticCount < 0) {
      throw ArgumentError.value(
        diagnosticCount,
        'diagnosticCount',
        'Must not be negative.',
      );
    }
    if (safeCheckpoint < 0) {
      throw ArgumentError.value(
        safeCheckpoint,
        'safeCheckpoint',
        'Must not be negative.',
      );
    }
    return PgnImportProgress._(
      jobId: jobId,
      phase: phase,
      bytesRead: bytesRead,
      totalBytes: totalBytes,
      indexedBlockCount: indexedBlockCount,
      diagnosticCount: diagnosticCount,
      cancellationRequested: cancellationRequested,
      safeCheckpoint: safeCheckpoint,
    );
  }

  const PgnImportProgress._({
    required this.jobId,
    required this.phase,
    required this.bytesRead,
    required this.totalBytes,
    required this.indexedBlockCount,
    required this.diagnosticCount,
    required this.cancellationRequested,
    required this.safeCheckpoint,
  });

  final String jobId;
  final PgnImportPhase phase;
  final int? bytesRead;
  final int? totalBytes;
  final int indexedBlockCount;
  final int diagnosticCount;
  final bool cancellationRequested;

  /// Last committed boundary safe for a later resume, in source bytes.
  final int safeCheckpoint;

  /// Measurable progress from 0.0 through 1.0, or null when unavailable.
  double? get fractionComplete {
    final length = totalBytes;
    final consumed = bytesRead;
    if (length == null || length == 0 || consumed == null) return null;
    return (consumed / length).clamp(0.0, 1.0);
  }
}

/// Sanitized, user-visible information about a skipped or problematic item.
///
/// [sourceOffset] is a byte offset when known. [blockOrdinal] is zero-based.
/// At least one location may be absent when the problem concerns the source as
/// a whole. The message must explain a safe next action without exposing raw
/// PGN content or unnecessary personal data.
final class PgnImportDiagnostic {
  PgnImportDiagnostic({
    required this.severity,
    required this.category,
    required this.message,
    this.sourceId,
    this.sourceOffset,
    this.blockOrdinal,
  }) {
    if (message.isEmpty) {
      throw ArgumentError.value(message, 'message', 'Must not be empty.');
    }
    if (sourceId != null && sourceId!.isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'Must not be empty.');
    }
    if (sourceOffset != null && sourceOffset! < 0) {
      throw ArgumentError.value(
        sourceOffset,
        'sourceOffset',
        'Must not be negative.',
      );
    }
    if (blockOrdinal != null && blockOrdinal! < 0) {
      throw ArgumentError.value(
        blockOrdinal,
        'blockOrdinal',
        'Must not be negative.',
      );
    }
  }

  final PgnImportDiagnosticSeverity severity;
  final PgnImportDiagnosticCategory category;
  final String? sourceId;
  final int? sourceOffset;
  final int? blockOrdinal;
  final String message;
}

/// Final outcome and recovery guidance for an import job.
final class PgnImportResult {
  PgnImportResult({
    required this.jobId,
    required this.phase,
    required this.indexedBlockCount,
    required this.diagnosticCount,
    required this.resumeDisposition,
  }) {
    if (jobId.isEmpty) {
      throw ArgumentError.value(jobId, 'jobId', 'Must not be empty.');
    }
    if (phase != PgnImportPhase.completed &&
        phase != PgnImportPhase.cancelled &&
        phase != PgnImportPhase.failed) {
      throw ArgumentError.value(phase, 'phase', 'Must be terminal.');
    }
    if (indexedBlockCount < 0) {
      throw ArgumentError.value(
        indexedBlockCount,
        'indexedBlockCount',
        'Must not be negative.',
      );
    }
    if (diagnosticCount < 0) {
      throw ArgumentError.value(
        diagnosticCount,
        'diagnosticCount',
        'Must not be negative.',
      );
    }
    if ((phase == PgnImportPhase.completed) !=
        (resumeDisposition == PgnImportResumeDisposition.none)) {
      throw ArgumentError(
        'Completed imports use no recovery action; stopped imports require one.',
      );
    }
  }

  final String jobId;
  final PgnImportPhase phase;
  final int indexedBlockCount;
  final int diagnosticCount;
  final PgnImportResumeDisposition resumeDisposition;
}

/// Handle for observing and cancelling one import execution.
///
/// Both streams close when [result] completes. Diagnostics are also persisted
/// by the implementation so they remain available after the operation ends.
abstract interface class PgnImportOperation {
  /// Progress updates, including the terminal state.
  Stream<PgnImportProgress> get progress;

  /// Sanitized diagnostics produced by this execution.
  Stream<PgnImportDiagnostic> get diagnostics;

  /// Resolves to the completed, cancelled, or failed job outcome.
  Future<PgnImportResult> get result;

  /// Requests safe cancellation. Committed blocks are retained and the job
  /// stops at a safe checkpoint. Repeated calls are harmless.
  Future<void> cancel();
}

/// Starts or resumes incremental indexing for registered PGN sources.
abstract interface class PgnImportService {
  /// Starts a new import for [request]'s registered source.
  ///
  /// The operation emits phase and measurable progress, block and diagnostic
  /// counts, and its terminal outcome. If the source is already being
  /// imported, the implementation must report that conflict rather than
  /// creating ambiguous concurrent jobs.
  PgnImportOperation start(PgnImportRequest request);

  /// Re-scans a changed source and reconciles its blocks without removing
  /// existing block identities or their dependent training history.
  ///
  /// Existing locators become unavailable until the operation completes.
  /// Interrupted operations remain blocked and may be retried from the start.
  PgnImportOperation reindex(String sourceId);

  /// Resumes a cancelled or recoverably failed job from its last safe
  /// checkpoint.
  ///
  /// The implementation must verify that the source revision and scanner
  /// version still match the job before continuing. A missing or changed
  /// source yields a failed result with [PgnImportResumeDisposition.repairSource];
  /// it must not silently continue using stale offsets. Unknown job IDs or
  /// jobs that cannot be resumed are reported as a failed operation.
  PgnImportOperation resume(String jobId);
}
