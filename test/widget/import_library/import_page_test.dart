import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/errors/app_failure.dart';
import 'package:pgntrainingreader/core/time/app_clock.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/data/file_access/file_source.dart';
import 'package:pgntrainingreader/data/file_access/file_source_picker.dart';
import 'package:pgntrainingreader/domain/library/pgn_import_service.dart';
import 'package:pgntrainingreader/domain/library/pgn_source_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/pgn_source.dart';
import 'package:pgntrainingreader/features/import_library/application/import_controller.dart';
import 'package:pgntrainingreader/features/import_library/presentation/import_page.dart';

void main() {
  group('ImportPage', () {
    late _Harness harness;

    setUp(() => harness = _Harness());
    tearDown(() => harness.controller.dispose());

    testWidgets('renders idle state and allows file selection', (tester) async {
      await _pumpPage(tester, harness);

      expect(find.text('Your file stays on this device.'), findsOneWidget);
      expect(find.text('Choose PGN file'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Choose PGN file'));
      await tester.pumpAndSettle();
      expect(harness.picker.pickCount, 1);
      expect(harness.controller.state.status, ImportStatus.idle);
    });

    testWidgets('renders selecting state with selection action unavailable', (
      tester,
    ) async {
      harness.publish(ImportState(status: ImportStatus.selecting));
      await _pumpPage(tester, harness);

      expect(find.text('Opening file picker…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('renders copying state and supports cancel affordance', (
      tester,
    ) async {
      harness.publish(
        _busyState(ImportStatus.copying, bytesRead: 512, totalBytes: 1024),
      );
      await _pumpPage(tester, harness);

      expect(find.text('Copying your PGN file'), findsOneWidget);
      expect(find.text('Copying source file'), findsOneWidget);
      expect(find.text('512 B of 1.0 KB'), findsOneWidget);
      expect(find.text('Blocks indexed'), findsOneWidget);
      expect(find.text('Diagnostics'), findsOneWidget);
      await tester.tap(find.text('Cancel import'));
      await tester.pump();
      expect(harness.controller.state.status, ImportStatus.copying);
    });

    testWidgets('renders indexing with accessible indeterminate progress', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      harness.publish(
        _busyState(
          ImportStatus.indexing,
          bytesRead: 2048,
          totalBytes: null,
          indexedBlocks: 7,
          diagnostics: 2,
        ),
      );
      await _pumpPage(tester, harness);

      expect(find.text('Indexing games in your file'), findsOneWidget);
      expect(find.text('Indexing PGN blocks'), findsOneWidget);
      expect(find.text('2.0 KB processed; total size unknown'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, isNull);
      expect(find.bySemanticsLabel('Import progress'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Import progress')).value,
        contains('total size unknown'),
      );
      expect(find.text('Cancel import'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('renders cancelled state with resume and choose actions', (
      tester,
    ) async {
      harness.publish(
        ImportState(
          status: ImportStatus.cancelled,
          result: _result(PgnImportResumeDisposition.resume),
        ),
      );
      await _pumpPage(tester, harness);

      expect(find.text('The import has stopped.'), findsOneWidget);
      expect(find.text('Resume import'), findsOneWidget);
      await tester.tap(find.text('Resume import'));
      await tester.pumpAndSettle();
      expect(harness.controller.state.status, ImportStatus.idle);
      expect(harness.picker.pickCount, 1);
    });

    testWidgets(
      'renders failed state and offers retry with recovery guidance',
      (tester) async {
        harness.publish(
          ImportState(
            status: ImportStatus.failed,
            failure: const FileFailure(
              code: 'unsupported_file_access',
              message: 'The file cannot be accessed.',
            ),
          ),
        );
        await _pumpPage(tester, harness);

        expect(find.text('This file could not be accessed'), findsOneWidget);
        expect(
          find.textContaining('Choose a readable PGN file'),
          findsOneWidget,
        );
        expect(find.textContaining('preserved'), findsOneWidget);
        expect(find.text('Choose another PGN'), findsOneWidget);
        final failures = <(AppFailure, String, String)>[
          (
            const FileFailure(
              code: 'unsupported_file_access',
              message: 'Cannot access source.',
            ),
            'This file could not be accessed',
            'Choose another PGN',
          ),
          (
            const FileFailure(
              code: 'insufficient_storage',
              message: 'Insufficient storage.',
            ),
            'Not enough device storage',
            'Choose PGN file',
          ),
          (
            const PgnFailure(
              code: 'malformed_content',
              message: 'Malformed PGN.',
            ),
            'The PGN could not be fully read',
            'Restart import',
          ),
          (
            const DatabaseFailure(
              code: 'pgn_index_write_failed',
              message: 'Could not write index.',
            ),
            'The library could not save the import',
            'Restart import',
          ),
        ];
        for (final (failure, title, actionLabel) in failures) {
          harness.publish(
            ImportState(
              status: ImportStatus.failed,
              failure: failure,
              result: _result(PgnImportResumeDisposition.restart),
              progress: _progress(
                phase: PgnImportPhase.failed,
                indexedBlocks: 3,
              ),
            ),
          );
          await tester.pump();
          expect(find.text(title), findsOneWidget);
          expect(find.textContaining('3 indexed blocks'), findsOneWidget);
          expect(find.text(actionLabel), findsOneWidget);
          await tester.tap(find.text(actionLabel));
          await tester.pumpAndSettle();
          expect(harness.picker.pickCount, greaterThan(0));
          expect(harness.controller.state.status, ImportStatus.idle);
        }
      },
    );

    testWidgets('renders completed state and offers another import', (
      tester,
    ) async {
      harness.publish(
        ImportState(
          status: ImportStatus.completed,
          result: _result(
            PgnImportResumeDisposition.none,
            phase: PgnImportPhase.completed,
          ),
        ),
      );
      await _pumpPage(tester, harness);

      expect(find.text('3 PGN blocks indexed'), findsOneWidget);
      expect(find.text('Import another PGN'), findsOneWidget);
      await tester.tap(find.text('Import another PGN'));
      await tester.pump();
      expect(harness.controller.state.status, ImportStatus.idle);
    });

    testWidgets('keeps controls usable at narrow width and large text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      harness.publish(
        _busyState(
          ImportStatus.indexing,
          bytesRead: null,
          totalBytes: null,
          indexedBlocks: 123456,
          diagnostics: 1234,
        ),
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(home: ImportPage(controller: harness.controller)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Cancel import'), findsOneWidget);
      expect(find.text('Blocks indexed'), findsOneWidget);
      expect(find.text('Diagnostics'), findsOneWidget);
    });
  });
}

Future<void> _pumpPage(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(
    MaterialApp(home: ImportPage(controller: harness.controller)),
  );
}

ImportState _busyState(
  ImportStatus status, {
  required int? bytesRead,
  required int? totalBytes,
  int indexedBlocks = 0,
  int diagnostics = 0,
}) => ImportState(
  status: status,
  progress: PgnImportProgress(
    jobId: 'job-1',
    phase: status == ImportStatus.copying
        ? PgnImportPhase.preparing
        : PgnImportPhase.indexing,
    bytesRead: bytesRead,
    totalBytes: totalBytes,
    indexedBlockCount: indexedBlocks,
    diagnosticCount: diagnostics,
    cancellationRequested: false,
  ),
);

final class _Harness {
  final picker = _Picker();
  final service = _ImportService();
  late final ImportController controller = ImportController(
    fileSourcePicker: picker,
    fileSource: _FileSource(),
    targetFactory: () async => _Target(),
    sourceRepository: _SourceRepository(),
    importService: service,
    clock: _Clock(),
    idGenerator: _Ids(),
  );

  void publish(ImportState state) => controller.publishForTesting(state);
}

final class _Picker implements FileSourcePicker {
  int pickCount = 0;

  @override
  Future<SelectedFileSource?> pickPgnSource() async {
    pickCount++;
    return null;
  }
}

final class _FileSource implements FileSource {
  @override
  Stream<List<int>> openReadStream(OpaqueSourceReference reference) =>
      const Stream.empty();

  @override
  Future<int?> length(OpaqueSourceReference reference) async => null;

  @override
  Future<Uint8List> readRange(
    OpaqueSourceReference reference, {
    required int start,
    required int endExclusive,
  }) async => Uint8List(0);

  @override
  Future<FileFingerprintInput> fingerprintInput(
    OpaqueSourceReference reference, {
    DateTime? modifiedAt,
    int sampleSize = 4096,
  }) async =>
      FileFingerprintInput(length: null, modifiedAt: null, samples: const []);

  @override
  Future<ManagedCopyResult> copyToManagedStorage(
    OpaqueSourceReference reference, {
    required ManagedCopyTarget target,
    required CopyCancellation cancellation,
    int? expectedLength,
  }) async =>
      const ManagedCopyResult(reference: 'fake-managed-source', length: 0);
}

final class _Target implements ManagedCopyTarget {
  @override
  Future<void> write(List<int> bytes) async {}

  @override
  Future<String> promote({required int bytesWritten}) async => 'fake-source';

  @override
  Future<void> discard() async {}
}

final class _SourceRepository implements PgnSourceRepository {
  @override
  Future<void> remove({required String id, required DateTime removedAt}) async {
    throw UnsupportedError('Removal is outside this import test fake.');
  }

  @override
  Future<PgnSource?> getById(String id) async => null;

  @override
  Future<List<PgnSource>> list() async => const [];

  @override
  Future<void> create(PgnSource source) async {}

  @override
  Future<void> update(PgnSource source) async {}

  @override
  Future<void> updateAfterVerifiedRelink({
    required PgnSource source,
    required String expectedFingerprint,
  }) async {}
}

final class _ImportService implements PgnImportService {
  int startCount = 0;
  int resumeCount = 0;

  @override
  PgnImportOperation start(PgnImportRequest request) {
    startCount++;
    return _Operation();
  }

  @override
  PgnImportOperation resume(String jobId) {
    resumeCount++;
    return _Operation();
  }

  @override
  PgnImportOperation reindex(String sourceId) => _Operation();
}

final class _Operation implements PgnImportOperation {
  @override
  Stream<PgnImportProgress> get progress => const Stream.empty();

  @override
  Stream<PgnImportDiagnostic> get diagnostics => const Stream.empty();

  @override
  Future<PgnImportResult> get result async =>
      _result(PgnImportResumeDisposition.none, phase: PgnImportPhase.completed);

  @override
  Future<void> cancel() async {}
}

final class _Clock implements AppClock {
  @override
  DateTime get utcNow => DateTime.utc(2026);

  @override
  Duration get monotonicElapsed => Duration.zero;
}

final class _Ids implements IdGenerator {
  @override
  String generateId() => 'test-id';
}

PgnImportProgress _progress({
  required PgnImportPhase phase,
  int indexedBlocks = 0,
  int diagnosticCount = 0,
}) => PgnImportProgress(
  jobId: 'job-1',
  phase: phase,
  indexedBlockCount: indexedBlocks,
  diagnosticCount: diagnosticCount,
  cancellationRequested: false,
);

PgnImportResult _result(
  PgnImportResumeDisposition disposition, {
  PgnImportPhase phase = PgnImportPhase.failed,
}) => PgnImportResult(
  jobId: 'job-1',
  phase: phase,
  indexedBlockCount: 3,
  diagnosticCount: 0,
  resumeDisposition: disposition,
);
