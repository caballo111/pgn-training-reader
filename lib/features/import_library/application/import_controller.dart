import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/utilities/id_generator.dart';
import '../../../data/file_access/file_source.dart';
import '../../../data/file_access/file_source_picker.dart';
import '../../../data/file_access/managed_file_source.dart';
import '../../../data/file_access/source_fingerprint.dart';
import '../../../data/pgn/pgn_indexer.dart';
import '../../../domain/chess_content/pgn_source.dart';
import '../../../domain/library/pgn_import_service.dart';
import '../../../domain/library/pgn_source_repository.dart';

/// Current user-visible phase of an import operation.
enum ImportStatus {
  idle,
  selecting,
  copying,
  indexing,
  cancelled,
  failed,
  completed,
}

/// Result of replacing an unavailable source reference with a selected PGN.
enum SourceRelinkOutcome { sameRevision, changedRevision }

/// Immutable snapshot of import activity for presentation and accessibility.
final class ImportState {
  factory ImportState({
    ImportStatus status = ImportStatus.idle,
    SelectedFileSource? selectedSource,
    PgnImportProgress? progress,
    int? copyBytesRead,
    int? copyTotalBytes,
    List<PgnImportDiagnostic> diagnostics = const [],
    PgnImportResult? result,
    String? errorMessage,
    AppFailure? failure,
    bool cancellationRequested = false,
  }) => ImportState._(
    status: status,
    selectedSource: selectedSource,
    progress: progress,
    copyBytesRead: copyBytesRead,
    copyTotalBytes: copyTotalBytes,
    diagnostics: List.unmodifiable(diagnostics),
    result: result,
    errorMessage: errorMessage,
    failure: failure,
    cancellationRequested: cancellationRequested,
  );

  const ImportState._({
    required this.status,
    required this.selectedSource,
    required this.progress,
    required this.copyBytesRead,
    required this.copyTotalBytes,
    required this.diagnostics,
    required this.result,
    required this.errorMessage,
    required this.failure,
    required this.cancellationRequested,
  });

  final ImportStatus status;
  final SelectedFileSource? selectedSource;
  final PgnImportProgress? progress;
  final int? copyBytesRead;
  final int? copyTotalBytes;

  /// Recent sanitized diagnostics, bounded by [ImportController.maxRetainedDiagnostics].
  final List<PgnImportDiagnostic> diagnostics;

  final PgnImportResult? result;
  final String? errorMessage;
  final AppFailure? failure;
  final bool cancellationRequested;

  int? get bytesRead => copyBytesRead ?? progress?.bytesRead;
  int? get totalBytes => copyTotalBytes ?? progress?.totalBytes;
  int get indexedBlockCount =>
      progress?.indexedBlockCount ?? result?.indexedBlockCount ?? 0;
  int get diagnosticCount =>
      progress?.diagnosticCount ??
      result?.diagnosticCount ??
      diagnostics.length;
  bool get isBusy => switch (status) {
    ImportStatus.selecting ||
    ImportStatus.copying ||
    ImportStatus.indexing => true,
    _ => false,
  };
  bool get canCancel =>
      (status == ImportStatus.copying || status == ImportStatus.indexing) &&
      !cancellationRequested &&
      !(progress?.cancellationRequested ?? false);
}

/// Coordinates source selection, managed copying, registration, and indexing.
///
/// Dependencies are injected so this workflow can be tested without platform
/// UI or a real filesystem. The canonical PGN bytes are copied unchanged.
final class ImportController extends ChangeNotifier {
  ImportController({
    required this.fileSourcePicker,
    required this.fileSource,
    required this.targetFactory,
    required this.sourceRepository,
    required this.importService,
    required this.clock,
    required this.idGenerator,
  });

  static const int maxRetainedDiagnostics = 100;
  static const int scannerVersion = DriftPgnImportService.scannerVersion;

  final FileSourcePicker fileSourcePicker;
  final FileSource fileSource;
  final Future<ManagedCopyTarget> Function() targetFactory;
  final PgnSourceRepository sourceRepository;
  final PgnImportService importService;
  final AppClock clock;
  final IdGenerator idGenerator;

  ImportState _state = ImportState();
  ImportState get state => _state;

  bool _disposed = false;
  int _runNumber = 0;
  bool _cancelRequested = false;
  CopyCancellation? _copyCancellation;
  PgnImportOperation? _operation;
  String? _sourceId;
  String? _jobId;
  StreamSubscription<PgnImportProgress>? _progressSubscription;
  StreamSubscription<PgnImportDiagnostic>? _diagnosticSubscription;
  final List<PgnImportDiagnostic> _diagnostics = [];

  /// Selects a PGN, copies it into app storage, then indexes the managed copy.
  Future<void> selectAndImport() async {
    if (_disposed || _state.isBusy) return;
    _resetOperationContext();
    final run = ++_runNumber;
    SelectedFileSource? selected;
    _publish(ImportState(status: ImportStatus.selecting));
    try {
      selected = await fileSourcePicker.pickPgnSource();
      if (!_isCurrent(run)) return;
      if (selected == null) {
        _publish(ImportState());
        return;
      }
      _publish(
        ImportState(
          status: ImportStatus.copying,
          selectedSource: selected,
          copyTotalBytes: selected.lengthBytes,
        ),
      );
      await _copyRegisterAndIndex(selected, run);
    } catch (error) {
      if (_isCurrent(run)) {
        if (selected == null) {
          _fail(_asFailure(error));
        } else {
          _handleFailure(error, selected);
        }
      }
    }
  }

  /// Copies a selected replacement and reconnects it to the existing source
  /// identity. Existing byte locators are restored only when the stored
  /// fingerprint matches the selected copy using the old managed mtime.
  Future<SourceRelinkOutcome?> relinkSource(String sourceId) async {
    if (_disposed || _state.isBusy) return null;
    _resetOperationContext();
    final run = ++_runNumber;
    SelectedFileSource? selected;
    _publish(ImportState(status: ImportStatus.selecting));
    try {
      final source = await sourceRepository.getById(sourceId);
      if (!_isCurrent(run)) return null;
      if (source == null || source.importState != 'sourceMissing') {
        throw const ValidationFailure(
          code: 'source_relink_unavailable',
          message: 'This source is no longer waiting for repair.',
        );
      }
      selected = await fileSourcePicker.pickPgnSource();
      if (!_isCurrent(run)) return null;
      if (selected == null) {
        _publish(ImportState());
        return null;
      }

      _publish(
        ImportState(
          status: ImportStatus.copying,
          selectedSource: selected,
          copyTotalBytes: selected.lengthBytes,
        ),
      );
      _copyCancellation = CopyCancellation();
      final target = await targetFactory();
      var bytesWritten = 0;
      final progressTarget = _ProgressCopyTarget(
        target,
        onWrite: (length) {
          bytesWritten += length;
          if (_isCurrent(run)) {
            _publish(
              _stateWith(
                status: ImportStatus.copying,
                selectedSource: selected,
                copyBytesRead: bytesWritten,
                copyTotalBytes: selected!.lengthBytes,
              ),
            );
          }
        },
      );
      final copied = await fileSource.copyToManagedStorage(
        selected.reference,
        target: progressTarget,
        cancellation: _copyCancellation!,
        expectedLength: selected.lengthBytes,
      );
      if (!_isCurrent(run)) return null;

      final reference = ManagedSourceReference(copied.reference);
      final comparisonInput = await fileSource.fingerprintInput(
        reference,
        modifiedAt: source.modifiedAt,
      );
      if (!_isCurrent(run)) return null;
      final sameRevision =
          source.modifiedAt != null &&
          source.fingerprint != null &&
          SourceFingerprint.compute(comparisonInput) == source.fingerprint;
      final liveInput = await fileSource.fingerprintInput(reference);
      if (!_isCurrent(run)) return null;
      final now = clock.utcNow;
      final updated = PgnSource(
        id: source.id,
        displayName: selected.displayName,
        accessMode: PgnSourceAccessMode.managedCopy,
        managedPath: copied.reference,
        sizeBytes: copied.length,
        modifiedAt: liveInput.modifiedAt,
        fingerprint: SourceFingerprint.compute(liveInput),
        scannerVersion: source.scannerVersion,
        importState: sameRevision ? 'indexed' : 'sourceChanged',
        safeCheckpoint: sameRevision ? source.safeCheckpoint : 0,
        createdAt: source.createdAt,
        updatedAt: now,
      );
      if (sameRevision) {
        await sourceRepository.updateAfterVerifiedRelink(
          source: updated,
          expectedFingerprint: source.fingerprint!,
        );
      } else {
        await sourceRepository.update(updated);
      }
      if (!_isCurrent(run)) return null;
      _publish(
        ImportState(status: ImportStatus.completed, selectedSource: selected),
      );
      return sameRevision
          ? SourceRelinkOutcome.sameRevision
          : SourceRelinkOutcome.changedRevision;
    } catch (error) {
      if (_isCurrent(run)) {
        if (selected == null) {
          _fail(_asFailure(error));
        } else {
          _handleFailure(error, selected);
        }
      }
      return null;
    }
  }

  /// Resumes indexing from a safe checkpoint, or repeats a cancelled copy.
  Future<void> resume() async {
    final resumableFailure =
        _state.status == ImportStatus.failed &&
        _state.result?.resumeDisposition == PgnImportResumeDisposition.resume;
    if (_disposed ||
        _state.isBusy ||
        (_state.status != ImportStatus.cancelled && !resumableFailure)) {
      return;
    }
    final run = ++_runNumber;
    _cancelRequested = false;
    _diagnostics
      ..clear()
      ..addAll(_state.diagnostics);
    final selected = _state.selectedSource;
    if (_jobId != null) {
      await _runIndexing(run, resumeJobId: _jobId);
    } else if (selected != null) {
      _publish(
        ImportState(
          status: ImportStatus.copying,
          selectedSource: selected,
          copyTotalBytes: selected.lengthBytes,
          diagnostics: _diagnostics,
        ),
      );
      try {
        await _copyRegisterAndIndex(selected, run);
      } catch (error) {
        if (_isCurrent(run)) _handleFailure(error, selected);
      }
    } else {
      await selectAndImport();
    }
  }

  /// Rebuilds locators for a changed source while preserving reconciled IDs.
  Future<bool> reindexSource(String sourceId) async {
    if (_disposed || _state.isBusy || sourceId.isEmpty) return false;
    _resetOperationContext();
    _sourceId = sourceId;
    final run = ++_runNumber;
    _cancelRequested = false;
    await _runIndexing(run, reindex: true);
    return _isCurrent(run) && _state.status == ImportStatus.completed;
  }

  /// Requests safe cancellation. Indexed blocks already committed are kept.
  Future<void> cancel() async {
    if (_disposed || !_state.canCancel || _cancelRequested) return;
    _cancelRequested = true;
    _publish(_stateWith(cancellationRequested: true));
    _copyCancellation?.cancel();
    final operation = _operation;
    if (operation != null) {
      try {
        await operation.cancel();
      } catch (_) {
        // The operation's result reports the safe terminal outcome.
      }
    }
  }

  /// Clears a terminal result and returns to the initial state.
  void reset() {
    if (_disposed || _state.isBusy) return;
    ++_runNumber;
    _cancelRequested = false;
    _sourceId = null;
    _jobId = null;
    _diagnostics.clear();
    _publish(ImportState());
  }

  /// Restores a durable nonterminal indexing job discovered on app startup.
  /// The job is left paused until the user deliberately chooses Resume.
  void restoreResumableImport({
    required PgnSource source,
    required String jobId,
    required int indexedBlockCount,
    required int diagnosticCount,
    required int bytesRead,
    required int safeCheckpoint,
  }) {
    if (_disposed || _state.isBusy || _state.status != ImportStatus.idle) {
      return;
    }
    if (source.accessMode != PgnSourceAccessMode.managedCopy ||
        source.managedPath == null ||
        jobId.isEmpty) {
      return;
    }
    _sourceId = source.id;
    _jobId = jobId;
    final reference = ManagedSourceReference(source.managedPath!);
    final selected = SelectedFileSource(
      reference: reference,
      displayName: source.displayName,
      lengthBytes: source.sizeBytes,
      modifiedAt: source.modifiedAt,
      mimeType: 'application/x-chess-pgn',
    );
    final progress = PgnImportProgress(
      jobId: jobId,
      phase: PgnImportPhase.cancelled,
      bytesRead: bytesRead,
      totalBytes: source.sizeBytes,
      indexedBlockCount: indexedBlockCount,
      diagnosticCount: diagnosticCount,
      cancellationRequested: false,
      safeCheckpoint: safeCheckpoint,
    );
    _publish(
      ImportState(
        status: ImportStatus.cancelled,
        selectedSource: selected,
        progress: progress,
        result: PgnImportResult(
          jobId: jobId,
          phase: PgnImportPhase.cancelled,
          indexedBlockCount: indexedBlockCount,
          diagnosticCount: diagnosticCount,
          resumeDisposition: PgnImportResumeDisposition.resume,
        ),
      ),
    );
  }

  Future<void> _copyRegisterAndIndex(
    SelectedFileSource selected,
    int run,
  ) async {
    _copyCancellation = CopyCancellation();
    final target = await targetFactory();
    if (!_isCurrent(run) || _cancelRequested) {
      await target.discard();
      if (_isCurrent(run)) _publishCancelled(selected);
      return;
    }

    var bytesWritten = 0;
    final progressTarget = _ProgressCopyTarget(
      target,
      onWrite: (length) {
        bytesWritten += length;
        if (_isCurrent(run)) {
          _publish(
            _stateWith(
              status: ImportStatus.copying,
              selectedSource: selected,
              copyBytesRead: bytesWritten,
              copyTotalBytes: selected.lengthBytes,
            ),
          );
        }
      },
    );
    final copied = await fileSource.copyToManagedStorage(
      selected.reference,
      target: progressTarget,
      cancellation: _copyCancellation!,
      expectedLength: selected.lengthBytes,
    );
    if (!_isCurrent(run)) return;

    final managedReference = ManagedSourceReference(copied.reference);
    final fingerprintInput = await fileSource.fingerprintInput(
      managedReference,
    );
    if (!_isCurrent(run)) return;
    final fingerprint = SourceFingerprint.compute(fingerprintInput);
    final now = clock.utcNow;
    final sourceId = idGenerator.generateId();
    _sourceId = sourceId;
    final source = PgnSource(
      id: sourceId,
      displayName: selected.displayName,
      accessMode: PgnSourceAccessMode.managedCopy,
      managedPath: copied.reference,
      sizeBytes: copied.length,
      modifiedAt: fingerprintInput.modifiedAt,
      fingerprint: fingerprint,
      scannerVersion: scannerVersion,
      importState: 'pending',
      safeCheckpoint: 0,
      createdAt: now,
      updatedAt: now,
    );
    await sourceRepository.create(source);
    if (!_isCurrent(run)) return;
    await _runIndexing(run);
  }

  Future<void> _runIndexing(
    int run, {
    String? resumeJobId,
    bool reindex = false,
  }) async {
    final sourceId = _sourceId;
    if (sourceId == null && resumeJobId == null) {
      _fail(
        const ValidationFailure(
          code: 'resume_unavailable',
          message: 'This import cannot be resumed. Select the PGN again.',
        ),
      );
      return;
    }
    _publish(
      _stateWith(
        status: ImportStatus.indexing,
        clearProgress: true,
        clearCopyProgress: true,
        clearResult: true,
        clearError: true,
        clearFailure: true,
        cancellationRequested: false,
      ),
    );
    late final PgnImportOperation operation;
    try {
      operation = resumeJobId == null
          ? reindex
                ? importService.reindex(sourceId!)
                : importService.start(PgnImportRequest(sourceId: sourceId!))
          : importService.resume(resumeJobId);
    } catch (error) {
      if (_isCurrent(run)) _fail(_asFailure(error));
      return;
    }
    _operation = operation;
    if (_cancelRequested) unawaited(operation.cancel());
    final progressSubscription = operation.progress.listen((progress) {
      if (!_isCurrent(run)) return;
      _jobId = progress.jobId;
      final mappedStatus = switch (progress.phase) {
        PgnImportPhase.selecting ||
        PgnImportPhase.preparing => ImportStatus.indexing,
        PgnImportPhase.indexing => ImportStatus.indexing,
        PgnImportPhase.cancelled => ImportStatus.cancelled,
        PgnImportPhase.failed => ImportStatus.failed,
        PgnImportPhase.completed => ImportStatus.completed,
      };
      // Keep the operation busy until its result and stream cleanup complete;
      // publishing terminal stream events here would permit unsafe re-entry.
      if (mappedStatus == ImportStatus.failed ||
          mappedStatus == ImportStatus.cancelled ||
          mappedStatus == ImportStatus.completed) {
        _publish(_stateWith(progress: progress));
      } else {
        _publish(_stateWith(status: mappedStatus, progress: progress));
      }
    });
    final diagnosticSubscription = operation.diagnostics.listen((diagnostic) {
      if (!_isCurrent(run)) return;
      _appendDiagnostic(diagnostic);
      _publish(_stateWith(diagnostics: _diagnostics));
    });
    _progressSubscription = progressSubscription;
    _diagnosticSubscription = diagnosticSubscription;

    PgnImportResult? finalResult;
    AppFailure? finalFailure;
    try {
      finalResult = await operation.result;
      if (_isCurrent(run)) {
        _jobId = finalResult.jobId;
        if (finalResult.phase == PgnImportPhase.failed) {
          finalFailure = _failureFromDiagnostics();
        }
      }
    } catch (error) {
      finalFailure = _asFailure(error);
    } finally {
      await progressSubscription.cancel();
      await diagnosticSubscription.cancel();
      if (identical(_operation, operation)) {
        _progressSubscription = null;
        _diagnosticSubscription = null;
        _operation = null;
      }
    }
    if (!_isCurrent(run)) return;
    final result = finalResult;
    if (result != null) {
      final status = switch (result.phase) {
        PgnImportPhase.completed => ImportStatus.completed,
        PgnImportPhase.cancelled => ImportStatus.cancelled,
        PgnImportPhase.failed => ImportStatus.failed,
        _ => ImportStatus.failed,
      };
      _publish(
        _stateWith(
          status: status,
          result: result,
          errorMessage: finalFailure?.message,
          failure: finalFailure,
        ),
      );
    } else if (finalFailure != null) {
      _fail(finalFailure);
    }
  }

  void _publishCancelled(SelectedFileSource selected) {
    _publish(
      ImportState(
        status: ImportStatus.cancelled,
        selectedSource: selected,
        copyBytesRead: _state.copyBytesRead,
        copyTotalBytes: selected.lengthBytes,
        diagnostics: _diagnostics,
      ),
    );
  }

  void _appendDiagnostic(PgnImportDiagnostic diagnostic) {
    _diagnostics.add(diagnostic);
    if (_diagnostics.length > maxRetainedDiagnostics) {
      _diagnostics.removeAt(0);
    }
  }

  AppFailure _failureFromDiagnostics() {
    final last = _diagnostics.lastOrNull;
    final message =
        last?.message ?? 'The PGN could not be indexed. Retry the import.';
    return switch (last?.category) {
      PgnImportDiagnosticCategory.storageFailure => DatabaseFailure(
        code: 'import_storage_failed',
        message: message,
      ),
      PgnImportDiagnosticCategory.sourceUnavailable ||
      PgnImportDiagnosticCategory.sourceChanged => FileFailure(
        code: 'import_source_unavailable',
        message: message,
      ),
      _ => PgnFailure(code: 'pgn_import_failed', message: message),
    };
  }

  AppFailure _asFailure(Object error) {
    if (error is AppFailure) return error;
    return const FileFailure(
      code: 'import_failed',
      message: 'The PGN could not be imported. Check storage and try again.',
    );
  }

  void _handleFailure(Object error, SelectedFileSource selected) {
    if (error is FileFailure && error.code == 'copy_cancelled') {
      _publishCancelled(selected);
      return;
    }
    _fail(_asFailure(error));
  }

  void _fail(AppFailure failure) {
    _publish(
      _stateWith(
        status: ImportStatus.failed,
        errorMessage: failure.message,
        failure: failure,
        diagnostics: _diagnostics,
      ),
    );
  }

  ImportState _stateWith({
    ImportStatus? status,
    SelectedFileSource? selectedSource,
    bool clearSelectedSource = false,
    PgnImportProgress? progress,
    bool clearProgress = false,
    int? copyBytesRead,
    int? copyTotalBytes,
    bool clearCopyProgress = false,
    List<PgnImportDiagnostic>? diagnostics,
    PgnImportResult? result,
    bool clearResult = false,
    String? errorMessage,
    bool clearError = false,
    AppFailure? failure,
    bool clearFailure = false,
    bool? cancellationRequested,
  }) => ImportState(
    status: status ?? _state.status,
    selectedSource: clearSelectedSource
        ? null
        : selectedSource ?? _state.selectedSource,
    progress: clearProgress ? null : progress ?? _state.progress,
    copyBytesRead: clearCopyProgress
        ? null
        : copyBytesRead ?? _state.copyBytesRead,
    copyTotalBytes: clearCopyProgress
        ? null
        : copyTotalBytes ?? _state.copyTotalBytes,
    diagnostics: diagnostics ?? _diagnostics,
    result: clearResult ? null : result ?? _state.result,
    errorMessage: clearError ? null : errorMessage ?? _state.errorMessage,
    failure: clearFailure ? null : failure ?? _state.failure,
    cancellationRequested:
        cancellationRequested ?? _state.cancellationRequested,
  );

  void _resetOperationContext() {
    _cancelRequested = false;
    _copyCancellation = null;
    _operation = null;
    _sourceId = null;
    _jobId = null;
    _diagnostics.clear();
  }

  bool _isCurrent(int run) => !_disposed && run == _runNumber;

  void _publish(ImportState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  /// Lets state-focused widget tests render a snapshot without platform I/O.
  @visibleForTesting
  void publishForTesting(ImportState state) => _publish(state);

  @override
  void dispose() {
    _disposed = true;
    ++_runNumber;
    _cancelRequested = true;
    _copyCancellation?.cancel();
    unawaited(_operation?.cancel() ?? Future<void>.value());
    unawaited(_progressSubscription?.cancel() ?? Future<void>.value());
    unawaited(_diagnosticSubscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}

final class _ProgressCopyTarget implements ManagedCopyTarget {
  _ProgressCopyTarget(this._delegate, {required this.onWrite});

  final ManagedCopyTarget _delegate;
  final void Function(int length) onWrite;

  @override
  Future<void> write(List<int> bytes) async {
    await _delegate.write(bytes);
    onWrite(bytes.length);
  }

  @override
  Future<String> promote({required int bytesWritten}) =>
      _delegate.promote(bytesWritten: bytesWritten);

  @override
  Future<void> discard() => _delegate.discard();
}
