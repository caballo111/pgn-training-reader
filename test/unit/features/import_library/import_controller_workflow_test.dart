import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/errors/app_failure.dart';
import 'package:pgntrainingreader/core/time/app_clock.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/data/file_access/file_source.dart';
import 'package:pgntrainingreader/data/file_access/file_source_picker.dart';
import 'package:pgntrainingreader/data/file_access/managed_file_source.dart';
import 'package:pgntrainingreader/data/file_access/source_fingerprint.dart';
import 'package:pgntrainingreader/domain/chess_content/pgn_source.dart';
import 'package:pgntrainingreader/domain/library/pgn_import_service.dart';
import 'package:pgntrainingreader/domain/library/pgn_source_repository.dart';
import 'package:pgntrainingreader/features/import_library/application/import_controller.dart';

void main() {
  group('ImportController workflow', () {
    test(
      'copies source, registers it, then publishes index progress',
      () async {
        final harness = _Harness();
        final seen = <ImportState>[];
        harness.controller.addListener(
          () => seen.add(harness.controller.state),
        );

        await harness.controller.selectAndImport();

        expect(harness.controller.state.status, ImportStatus.completed);
        expect(harness.controller.state.indexedBlockCount, 3);
        expect(harness.repository.sources, hasLength(1));
        expect(
          harness.repository.sources.single.accessMode,
          PgnSourceAccessMode.managedCopy,
        );
        expect(harness.repository.sources.single.fingerprint, isNotEmpty);
        expect(harness.fileSource.managedBytes.values.single, _pgnBytes);
        expect(
          seen.any(
            (state) =>
                state.status == ImportStatus.copying &&
                state.bytesRead == _pgnBytes.length,
          ),
          isTrue,
        );
        final indexing = seen.firstWhere(
          (state) =>
              state.status == ImportStatus.indexing && state.progress != null,
        );
        expect(indexing.copyBytesRead, isNull);
        expect(indexing.bytesRead, 10);
      },
    );

    test(
      'cancel while target creation is pending leaves a resumable copy',
      () async {
        final targetCompleter = Completer<ManagedCopyTarget>();
        final harness = _Harness(targetFactory: () => targetCompleter.future);

        final importing = harness.controller.selectAndImport();
        await _until(
          () => harness.controller.state.status == ImportStatus.copying,
        );
        await harness.controller.cancel();
        targetCompleter.complete(harness.fileSource.newTarget());
        await importing;

        expect(harness.controller.state.status, ImportStatus.cancelled);
        expect(harness.controller.state.canCancel, isFalse);
        expect(harness.importService.startCalls, 0);
        expect(harness.fileSource.managedBytes, isEmpty);
      },
    );

    test('resumes a failed job whose result permits resume', () async {
      final service = _ScriptedImportService(<PgnImportResult Function()>[
        () => _result(PgnImportPhase.failed, PgnImportResumeDisposition.resume),
        () =>
            _result(PgnImportPhase.completed, PgnImportResumeDisposition.none),
      ]);
      final harness = _Harness(importService: service);

      await harness.controller.selectAndImport();
      expect(harness.controller.state.status, ImportStatus.failed);
      expect(harness.controller.state.failure, isA<PgnFailure>());
      await harness.controller.resume();

      expect(service.resumeCalls, 1);
      expect(harness.controller.state.status, ImportStatus.completed);
    });

    test(
      'forwards cancellation while indexing and retains completed counts',
      () async {
        final service = _ScriptedImportService([
          () => _result(
            PgnImportPhase.completed,
            PgnImportResumeDisposition.none,
          ),
        ], holdFirstStart: true);
        final harness = _Harness(importService: service);

        final importing = harness.controller.selectAndImport();
        await _until(
          () => harness.controller.state.status == ImportStatus.indexing,
        );
        await harness.controller.cancel();
        await importing;

        expect(service.lastOperation!.cancelCalls, 1);
        expect(harness.controller.state.status, ImportStatus.cancelled);
        expect(harness.controller.state.indexedBlockCount, 2);
      },
    );

    test('dispose during selection ignores the late picker result', () async {
      final pickerCompleter = Completer<SelectedFileSource?>();
      final picker = _Picker(() => pickerCompleter.future);
      final harness = _Harness(picker: picker);

      final selecting = harness.controller.selectAndImport();
      await _until(() => picker.calls == 1);
      harness.controller.dispose();
      pickerCompleter.complete(harness.selected);
      await selecting;

      expect(harness.fileSource.copyCalls, 0);
      expect(harness.repository.sources, isEmpty);
    });

    test('ignores duplicate selection calls while picker is open', () async {
      final pickerCompleter = Completer<SelectedFileSource?>();
      final picker = _Picker(() => pickerCompleter.future);
      final harness = _Harness(picker: picker);

      final first = harness.controller.selectAndImport();
      await _until(() => picker.calls == 1);
      await harness.controller.selectAndImport();
      expect(picker.calls, 1);
      pickerCompleter.complete(null);
      await first;
    });

    test('source registration failure preserves existing sources', () async {
      final oldSource = _source('old-id', 'prior.pgn');
      final repository = _MemorySourceRepository(
        existing: [oldSource],
        createFailure: const DatabaseFailure(
          code: 'write_failed',
          message: 'Source metadata could not be saved.',
        ),
      );
      final harness = _Harness(repository: repository);

      await harness.controller.selectAndImport();

      expect(harness.controller.state.status, ImportStatus.failed);
      expect(harness.controller.state.failure, isA<DatabaseFailure>());
      expect(await repository.list(), [oldSource]);
      expect(harness.fileSource.managedBytes, hasLength(1));
    });

    test('restores a persisted job as paused and resumable', () {
      final harness = _Harness();
      final source = _source('restored-source', 'library.pgn');

      harness.controller.restoreResumableImport(
        source: source,
        jobId: 'restored-job',
        indexedBlockCount: 8,
        diagnosticCount: 2,
        bytesRead: 1234,
        safeCheckpoint: 900,
      );

      expect(harness.controller.state.status, ImportStatus.cancelled);
      expect(
        harness.controller.state.result?.resumeDisposition,
        PgnImportResumeDisposition.resume,
      );
      expect(harness.controller.state.indexedBlockCount, 8);
      expect(harness.controller.state.bytesRead, 1234);
      expect(
        harness.controller.state.selectedSource?.displayName,
        'library.pgn',
      );
    });

    test('relinks a matching source under the existing identity', () async {
      final oldModifiedAt = DateTime.utc(2026, 1, 2);
      final missing = _source(
        'old-source',
        'old.pgn',
        importState: 'sourceMissing',
        modifiedAt: oldModifiedAt,
        fingerprint: _fingerprint(oldModifiedAt, _pgnBytes),
        safeCheckpoint: _pgnBytes.length,
      );
      final repository = _MemorySourceRepository(existing: [missing]);
      final harness = _Harness(repository: repository);

      final outcome = await harness.controller.relinkSource(missing.id);

      expect(outcome, SourceRelinkOutcome.sameRevision);
      final linked = (await repository.getById(missing.id))!;
      expect(linked.id, missing.id);
      expect(linked.managedPath, isNot(missing.managedPath));
      expect(linked.importState, 'indexed');
      expect(linked.safeCheckpoint, missing.safeCheckpoint);
      expect(repository.sources, hasLength(1));
    });

    test('relink with changed samples blocks existing locators', () async {
      final oldModifiedAt = DateTime.utc(2026, 1, 2);
      final missing = _source(
        'old-source',
        'old.pgn',
        importState: 'sourceMissing',
        modifiedAt: oldModifiedAt,
        fingerprint: _fingerprint(oldModifiedAt, _pgnBytes),
        safeCheckpoint: _pgnBytes.length,
      );
      final repository = _MemorySourceRepository(existing: [missing]);
      final harness = _Harness(repository: repository);
      harness.fileSource.selectedBytes = Uint8List.fromList(_pgnBytes)
        ..[0] = _pgnBytes.first ^ 1;

      final outcome = await harness.controller.relinkSource(missing.id);

      expect(outcome, SourceRelinkOutcome.changedRevision);
      final linked = (await repository.getById(missing.id))!;
      expect(linked.id, missing.id);
      expect(linked.importState, 'sourceChanged');
      expect(linked.safeCheckpoint, 0);
      expect(linked.managedPath, isNot(missing.managedPath));
    });
  });
}

const _pgnText = '[Event "Controller Test"]\n[Result "*"]\n\n1. e4 *\n';
final Uint8List _pgnBytes = Uint8List.fromList(_pgnText.codeUnits);

Future<void> _until(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Condition did not become true.');
}

PgnImportResult _result(
  PgnImportPhase phase,
  PgnImportResumeDisposition disposition,
) => PgnImportResult(
  jobId: 'job-1',
  phase: phase,
  indexedBlockCount: phase == PgnImportPhase.completed ? 3 : 2,
  diagnosticCount: 0,
  resumeDisposition: disposition,
);

String _fingerprint(DateTime? modifiedAt, Uint8List bytes) =>
    SourceFingerprint.compute(
      FileFingerprintInput(
        length: bytes.length,
        modifiedAt: modifiedAt,
        samples: [FingerprintSample(offset: 0, bytes: bytes)],
      ),
    );

PgnSource _source(
  String id,
  String name, {
  String importState = 'indexing',
  DateTime? modifiedAt,
  String? fingerprint,
  int safeCheckpoint = 0,
}) => PgnSource(
  id: id,
  displayName: name,
  accessMode: PgnSourceAccessMode.managedCopy,
  managedPath: 'a' * 32,
  sizeBytes: _pgnBytes.length,
  modifiedAt: modifiedAt,
  fingerprint: fingerprint,
  scannerVersion: ImportController.scannerVersion,
  importState: importState,
  safeCheckpoint: safeCheckpoint,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

final class _Harness {
  _Harness({
    _Picker? picker,
    _MemorySourceRepository? repository,
    _ScriptedImportService? importService,
    Future<ManagedCopyTarget> Function()? targetFactory,
  }) : picker = picker ?? _Picker(() async => _selectedSource),
       repository = repository ?? _MemorySourceRepository(),
       importService =
           importService ??
           _ScriptedImportService([
             () => _result(
               PgnImportPhase.completed,
               PgnImportResumeDisposition.none,
             ),
           ]) {
    controller = ImportController(
      fileSourcePicker: this.picker,
      fileSource: fileSource,
      targetFactory: targetFactory ?? () async => fileSource.newTarget(),
      sourceRepository: this.repository,
      importService: this.importService,
      clock: _FixedClock(),
      idGenerator: _Ids(),
    );
  }

  final _Picker picker;
  final _MemorySourceRepository repository;
  final _ScriptedImportService importService;
  final _MemoryFileSource fileSource = _MemoryFileSource();
  late final ImportController controller;
  final SelectedFileSource selected = SelectedFileSource(
    reference: _PickerReference(),
    displayName: 'study.pgn',
    lengthBytes: _pgnBytes.length,
    modifiedAt: DateTime.utc(2026),
  );
}

final SelectedFileSource _selectedSource = SelectedFileSource(
  reference: _PickerReference(),
  displayName: 'study.pgn',
  lengthBytes: _pgnBytes.length,
  modifiedAt: DateTime.utc(2026),
);

final class _Picker implements FileSourcePicker {
  _Picker(this.pick);
  final Future<SelectedFileSource?> Function() pick;
  int calls = 0;
  @override
  Future<SelectedFileSource?> pickPgnSource() {
    calls++;
    return pick();
  }
}

final class _PickerReference implements OpaqueSourceReference {}

final class _FixedClock implements AppClock {
  @override
  DateTime get utcNow => DateTime.utc(2026);
  @override
  Duration get monotonicElapsed => Duration.zero;
}

final class _Ids implements IdGenerator {
  int _next = 0;
  @override
  String generateId() => 'source-${_next++}';
}

final class _MemoryFileSource implements FileSource {
  final Map<String, Uint8List> managedBytes = {};
  Uint8List selectedBytes = _pgnBytes;
  int copyCalls = 0;
  int _targetNumber = 0;

  _Target newTarget() => _Target(this, 'a' * 31 + '${_targetNumber++}');

  @override
  Stream<List<int>> openReadStream(OpaqueSourceReference reference) async* {
    if (reference is ManagedSourceReference) {
      yield managedBytes[reference.token]!;
    } else {
      yield selectedBytes;
    }
  }

  @override
  Future<int?> length(OpaqueSourceReference reference) async =>
      reference is ManagedSourceReference
      ? managedBytes[reference.token]!.length
      : selectedBytes.length;

  @override
  Future<Uint8List> readRange(
    OpaqueSourceReference reference, {
    required int start,
    required int endExclusive,
  }) async {
    final bytes = reference is ManagedSourceReference
        ? managedBytes[reference.token]!
        : selectedBytes;
    return Uint8List.fromList(bytes.sublist(start, endExclusive));
  }

  @override
  Future<FileFingerprintInput> fingerprintInput(
    OpaqueSourceReference reference, {
    DateTime? modifiedAt,
    int sampleSize = 4096,
  }) async {
    final bytes = reference is ManagedSourceReference
        ? managedBytes[reference.token]!
        : selectedBytes;
    return FileFingerprintInput(
      length: bytes.length,
      modifiedAt: modifiedAt,
      samples: [FingerprintSample(offset: 0, bytes: bytes)],
    );
  }

  @override
  Future<ManagedCopyResult> copyToManagedStorage(
    OpaqueSourceReference reference, {
    required ManagedCopyTarget target,
    required CopyCancellation cancellation,
    int? expectedLength,
  }) async {
    copyCalls++;
    if (cancellation.isCancelled) {
      throw const FileFailure(code: 'copy_cancelled', message: 'Cancelled.');
    }
    var written = 0;
    await for (final chunk in openReadStream(reference)) {
      await target.write(chunk);
      written += chunk.length;
    }
    final token = await target.promote(bytesWritten: written);
    return ManagedCopyResult(reference: token, length: written);
  }
}

final class _Target implements ManagedCopyTarget {
  _Target(this.fileSource, this.token);
  final _MemoryFileSource fileSource;
  final String token;
  final BytesBuilder bytes = BytesBuilder(copy: false);
  bool discarded = false;
  @override
  Future<void> write(List<int> chunk) async => bytes.add(chunk);
  @override
  Future<String> promote({required int bytesWritten}) async {
    final value = bytes.takeBytes();
    fileSource.managedBytes[token] = value;
    return token;
  }

  @override
  Future<void> discard() async {
    discarded = true;
    fileSource.managedBytes.remove(token);
  }
}

final class _MemorySourceRepository implements PgnSourceRepository {
  _MemorySourceRepository({
    List<PgnSource> existing = const [],
    this.createFailure,
  }) : existing = List.of(existing);
  final List<PgnSource> existing;
  final AppFailure? createFailure;
  final List<PgnSource> sources = [];
  @override
  Future<void> create(PgnSource source) async {
    final failure = createFailure;
    if (failure != null) throw failure;
    sources.add(source);
  }

  @override
  Future<PgnSource?> getById(String id) async =>
      [...sources, ...existing].where((source) => source.id == id).firstOrNull;
  @override
  Future<List<PgnSource>> list() async => [...existing, ...sources];
  @override
  Future<void> remove({required String id, required DateTime removedAt}) async {
    throw UnsupportedError('Removal is outside this import test fake.');
  }

  @override
  Future<void> update(PgnSource source) async {
    sources.removeWhere((current) => current.id == source.id);
    sources.add(source);
  }

  @override
  Future<void> updateAfterVerifiedRelink({
    required PgnSource source,
    required String expectedFingerprint,
  }) async {
    final old = await getById(source.id);
    if (old?.fingerprint != expectedFingerprint ||
        old?.importState != 'sourceMissing') {
      throw const DatabaseFailure(
        code: 'source_relink_stale',
        message: 'Source changed during relink.',
      );
    }
    await update(source);
  }
}

final class _ScriptedImportService implements PgnImportService {
  _ScriptedImportService(this.outcomes, {this.holdFirstStart = false});
  final List<PgnImportResult Function()> outcomes;
  final bool holdFirstStart;
  int startCalls = 0;
  int resumeCalls = 0;
  _Operation? lastOperation;
  int _outcomeIndex = 0;

  _Operation _newOperation() {
    final result = outcomes[_outcomeIndex++]();
    final operation = _Operation(
      result,
      hold: holdFirstStart && startCalls == 1,
    );
    lastOperation = operation;
    return operation;
  }

  @override
  PgnImportOperation start(PgnImportRequest request) {
    startCalls++;
    return _newOperation();
  }

  @override
  PgnImportOperation resume(String jobId) {
    resumeCalls++;
    return _newOperation();
  }

  @override
  PgnImportOperation reindex(String sourceId) => _newOperation();
}

final class _Operation implements PgnImportOperation {
  _Operation(this.terminalResult, {required this.hold}) {
    scheduleMicrotask(() {
      _progress.add(
        PgnImportProgress(
          jobId: terminalResult.jobId,
          phase: PgnImportPhase.indexing,
          bytesRead: 10,
          totalBytes: _pgnBytes.length,
          indexedBlockCount: 2,
          diagnosticCount: 0,
          cancellationRequested: false,
          safeCheckpoint: 5,
        ),
      );
      if (!hold) finish(terminalResult);
    });
  }
  final PgnImportResult terminalResult;
  final bool hold;
  final StreamController<PgnImportProgress> _progress =
      StreamController<PgnImportProgress>.broadcast(sync: true);
  final StreamController<PgnImportDiagnostic> _diagnostics =
      StreamController<PgnImportDiagnostic>.broadcast(sync: true);
  final Completer<PgnImportResult> _result = Completer<PgnImportResult>();
  int cancelCalls = 0;
  @override
  Stream<PgnImportProgress> get progress => _progress.stream;
  @override
  Stream<PgnImportDiagnostic> get diagnostics => _diagnostics.stream;
  @override
  Future<PgnImportResult> get result => _result.future;

  void finish(PgnImportResult result) {
    if (_result.isCompleted) return;
    _progress.add(
      PgnImportProgress(
        jobId: result.jobId,
        phase: result.phase,
        bytesRead: 20,
        totalBytes: _pgnBytes.length,
        indexedBlockCount: result.indexedBlockCount,
        diagnosticCount: result.diagnosticCount,
        cancellationRequested: result.phase == PgnImportPhase.cancelled,
        safeCheckpoint: 20,
      ),
    );
    _result.complete(result);
    unawaited(_progress.close());
    unawaited(_diagnostics.close());
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    finish(
      PgnImportResult(
        jobId: terminalResult.jobId,
        phase: PgnImportPhase.cancelled,
        indexedBlockCount: 2,
        diagnosticCount: 0,
        resumeDisposition: PgnImportResumeDisposition.resume,
      ),
    );
  }
}
