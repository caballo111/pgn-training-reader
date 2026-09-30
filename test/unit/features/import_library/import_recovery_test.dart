import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/errors/app_failure.dart';
import 'package:pgntrainingreader/domain/library/pgn_import_service.dart';
import 'package:pgntrainingreader/features/import_library/application/import_controller.dart';
import 'package:pgntrainingreader/features/import_library/application/import_recovery.dart';

void main() {
  group('importRecoveryFor', () {
    test('discards an unfinished copy and offers a fresh selection', () {
      final recovery = importRecoveryFor(
        ImportState(status: ImportStatus.cancelled),
      );

      expect(recovery.title, 'Copy cancelled');
      expect(recovery.explanation, contains('copy was discarded'));
      expect(recovery.action, ImportRecoveryAction.selectSource);
    });

    test('resumes cancelled indexing from its safe checkpoint', () {
      final recovery = importRecoveryFor(
        _state(
          status: ImportStatus.cancelled,
          disposition: PgnImportResumeDisposition.resume,
          indexed: 3,
        ),
      );

      expect(recovery.explanation, contains('managed copy'));
      expect(recovery.preserved, contains('3 indexed blocks'));
      expect(recovery.action, ImportRecoveryAction.resume);
    });

    test('explains insufficient storage and preserved library data', () {
      final recovery = importRecoveryFor(
        ImportState(
          status: ImportStatus.failed,
          failure: FileFailure(
            code: 'insufficient_storage',
            message: 'Not enough storage.',
          ),
        ),
      );

      expect(recovery.title, 'Not enough device storage');
      expect(recovery.preserved, contains('existing library data'));
      expect(recovery.action, ImportRecoveryAction.selectSource);
    });

    test('uses disposition to offer database resume', () {
      final recovery = importRecoveryFor(
        _state(
          status: ImportStatus.failed,
          failure: const DatabaseFailure(
            code: 'source_persistence_failed',
            message: 'Metadata could not be saved.',
          ),
          disposition: PgnImportResumeDisposition.resume,
        ),
      );

      expect(recovery.title, 'The library could not save the import');
      expect(recovery.action, ImportRecoveryAction.resume);
    });

    test('requires a fresh file when the saved source needs repair', () {
      final recovery = importRecoveryFor(
        _state(
          status: ImportStatus.failed,
          failure: const FileFailure(
            code: 'managed_source_missing',
            message: 'The saved copy is unavailable.',
          ),
          disposition: PgnImportResumeDisposition.repairSource,
        ),
      );

      expect(recovery.explanation, contains('new import'));
      expect(recovery.action, ImportRecoveryAction.selectSource);
    });

    test('maps malformed PGN failure to a restart action', () {
      final recovery = importRecoveryFor(
        _state(
          status: ImportStatus.failed,
          failure: const PgnFailure(
            code: 'malformed_content',
            message: 'Malformed PGN.',
          ),
          disposition: PgnImportResumeDisposition.restart,
        ),
      );

      expect(recovery.title, 'The PGN could not be fully read');
      expect(recovery.action, ImportRecoveryAction.restart);
    });
  });
}

ImportState _state({
  required ImportStatus status,
  AppFailure? failure,
  PgnImportResumeDisposition? disposition,
  int indexed = 0,
}) => ImportState(
  status: status,
  progress: status == ImportStatus.cancelled && disposition != null
      ? PgnImportProgress(
          jobId: 'job',
          phase: PgnImportPhase.cancelled,
          indexedBlockCount: indexed,
          diagnosticCount: 0,
          cancellationRequested: false,
        )
      : null,
  failure: failure,
  result: disposition == null
      ? null
      : PgnImportResult(
          jobId: 'job',
          phase: status == ImportStatus.cancelled
              ? PgnImportPhase.cancelled
              : PgnImportPhase.failed,
          indexedBlockCount: indexed,
          diagnosticCount: 0,
          resumeDisposition: disposition,
        ),
);
