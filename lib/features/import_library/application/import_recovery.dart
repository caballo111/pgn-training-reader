import '../../../core/errors/app_failure.dart';
import '../../../domain/library/pgn_import_service.dart';
import 'import_controller.dart';

/// The next safe action available after an import stops.
enum ImportRecoveryAction { resume, restart, selectSource, repairSource, none }

/// Sanitized recovery guidance for an import outcome.
final class ImportRecoveryInfo {
  const ImportRecoveryInfo({
    required this.title,
    required this.explanation,
    required this.preserved,
    required this.action,
    required this.actionLabel,
  });

  final String title;
  final String explanation;
  final String preserved;
  final ImportRecoveryAction action;
  final String actionLabel;
}

/// Resolves an import outcome to safe user-facing recovery guidance.
///
/// Stable failure codes and typed failures select the explanation; arbitrary
/// exception text is never shown. Resume disposition controls which actions
/// are offered for stopped indexing jobs.
ImportRecoveryInfo importRecoveryFor(ImportState state) {
  final disposition = state.result?.resumeDisposition;
  final committed = state.indexedBlockCount;
  final preserved = committed > 0
      ? '$committed indexed block${committed == 1 ? '' : 's'} and your '
            'previous library data are preserved.'
      : 'Your existing library data is preserved.';

  if (state.status == ImportStatus.cancelled) {
    if (state.progress == null && state.result == null) {
      return ImportRecoveryInfo(
        title: 'Copy cancelled',
        explanation:
            'The unfinished local copy was discarded. Choose the PGN again '
            'when you are ready to start over.',
        preserved: 'Your existing library data is preserved.',
        action: ImportRecoveryAction.selectSource,
        actionLabel: 'Choose PGN file',
      );
    }
    final action = _actionForDisposition(disposition);
    return ImportRecoveryInfo(
      title: 'Import cancelled',
      explanation:
          'Indexing stopped at a safe point. The managed copy and '
          'committed blocks are preserved.',
      preserved: preserved,
      action: action,
      actionLabel: _labelFor(action),
    );
  }

  final failure = state.failure;
  final code = failure?.code;
  if (disposition == PgnImportResumeDisposition.repairSource) {
    return ImportRecoveryInfo(
      title: 'The saved source is unavailable',
      explanation:
          'Select the PGN again to create a fresh local copy and start a new '
          'import. The interrupted job cannot be repaired in place.',
      preserved: preserved,
      action: ImportRecoveryAction.selectSource,
      actionLabel: 'Select PGN again',
    );
  }
  if (code == 'insufficient_storage') {
    return ImportRecoveryInfo(
      title: 'Not enough device storage',
      explanation:
          'Free up space on this device, then select the PGN again to retry.',
      preserved: preserved,
      action: ImportRecoveryAction.selectSource,
      actionLabel: 'Choose PGN file',
    );
  }

  if (failure is DatabaseFailure ||
      code == 'source_persistence_failed' ||
      code == 'pgn_index_write_failed' ||
      code == 'pgn_index_read_failed') {
    final action = _actionForDisposition(disposition);
    return ImportRecoveryInfo(
      title: 'The library could not save the import',
      explanation:
          'Check that device storage is available, then continue from the '
          'last saved point when possible.',
      preserved: preserved,
      action: action,
      actionLabel: _labelFor(action),
    );
  }

  if (failure is UnsupportedContentFailure ||
      code == 'unsupported_file_access' ||
      code == 'invalid_source_reference' ||
      code == 'managed_source_missing' ||
      code == 'source_read_failed' ||
      code == 'file_selection_failed') {
    return ImportRecoveryInfo(
      title: 'This file could not be accessed',
      explanation:
          'Choose a readable PGN file from a location the app can access.',
      preserved: preserved,
      action: ImportRecoveryAction.selectSource,
      actionLabel: 'Choose another PGN',
    );
  }

  if (failure is PgnFailure || code == 'malformed_content') {
    final action = _actionForDisposition(disposition);
    return ImportRecoveryInfo(
      title: 'The PGN could not be fully read',
      explanation:
          'Some content may be malformed. Review the reported items and '
          'select a corrected file if needed.',
      preserved: preserved,
      action: action,
      actionLabel: _labelFor(action),
    );
  }

  final action = _actionForDisposition(disposition);
  return ImportRecoveryInfo(
    title: 'The import could not be completed',
    explanation:
        failure?.message ??
        'Try again with a readable PGN file. If this keeps happening, '
            'restart the import.',
    preserved: preserved,
    action: action,
    actionLabel: _labelFor(action),
  );
}

ImportRecoveryAction _actionForDisposition(
  PgnImportResumeDisposition? disposition,
) => switch (disposition) {
  PgnImportResumeDisposition.resume => ImportRecoveryAction.resume,
  PgnImportResumeDisposition.restart => ImportRecoveryAction.restart,
  PgnImportResumeDisposition.repairSource => ImportRecoveryAction.repairSource,
  PgnImportResumeDisposition.none || null => ImportRecoveryAction.selectSource,
};

String _labelFor(ImportRecoveryAction action) => switch (action) {
  ImportRecoveryAction.resume => 'Resume import',
  ImportRecoveryAction.restart => 'Restart import',
  ImportRecoveryAction.selectSource => 'Choose PGN file',
  ImportRecoveryAction.repairSource => 'Select source again',
  ImportRecoveryAction.none => 'Done',
};
