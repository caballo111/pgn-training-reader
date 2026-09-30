import 'package:flutter/material.dart';

import '../application/import_controller.dart';
import '../application/import_recovery.dart';
import 'import_progress.dart';

/// Screen for choosing a PGN file and following its import.
///
/// The controller is supplied by the application so this view can be tested
/// without opening a platform file picker or touching the real filesystem.
final class ImportPage extends StatelessWidget {
  const ImportPage({super.key, required this.controller});

  final ImportController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import PGN')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => _ImportContent(
          state: controller.state,
          onSelect: controller.selectAndImport,
          onCancel: controller.cancel,
          onResume: controller.resume,
          onReset: controller.reset,
        ),
      ),
    );
  }
}

final class _ImportContent extends StatelessWidget {
  const _ImportContent({
    required this.state,
    required this.onSelect,
    required this.onCancel,
    required this.onResume,
    required this.onReset,
  });

  final ImportState state;
  final VoidCallback onSelect;
  final VoidCallback onCancel;
  final VoidCallback onResume;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = state.isBusy;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.file_open_outlined,
                  size: 56,
                  color: theme.colorScheme.primary,
                  semanticLabel: 'Choose a PGN file',
                ),
                const SizedBox(height: 16),
                Text(
                  'Add a PGN file to your library',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose a .pgn file. It will be copied into this app and '
                  'indexed on your device so you can browse it offline.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                _StateMessage(state: state),
                if (state.status == ImportStatus.failed ||
                    state.status == ImportStatus.cancelled) ...[
                  const SizedBox(height: 16),
                  _RecoveryPanel(
                    state: state,
                    onResume: onResume,
                    onSelect: onSelect,
                    onReset: onReset,
                  ),
                ],
                if (state.status == ImportStatus.completed) ...[
                  const SizedBox(height: 16),
                  _CompletedSummary(state: state),
                ],
                if (state.selectedSource case final source?) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    label: 'Selected file: ${source.displayName}',
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.description_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                source.displayName,
                                style: theme.textTheme.titleMedium,
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (state.status == ImportStatus.copying ||
                    state.status == ImportStatus.indexing) ...[
                  const SizedBox(height: 20),
                  ImportProgress(state: state, onCancel: onCancel),
                ],
                const SizedBox(height: 24),
                if (state.status == ImportStatus.completed) ...[
                  FilledButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.add),
                    label: const Text('Import another PGN'),
                  ),
                ] else if (state.status == ImportStatus.failed ||
                    state.status == ImportStatus.cancelled) ...[
                  const SizedBox.shrink(),
                ] else ...[
                  FilledButton.icon(
                    onPressed: isBusy ? null : onSelect,
                    icon: const Icon(Icons.folder_open),
                    label: Text(isBusy ? 'Please wait…' : 'Choose PGN file'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.state});

  final ImportState state;

  @override
  Widget build(BuildContext context) {
    final (icon, message) = switch (state.status) {
      ImportStatus.idle => (
        Icons.info_outline,
        'Your file stays on this device.',
      ),
      ImportStatus.selecting => (Icons.hourglass_top, 'Opening file picker…'),
      ImportStatus.copying => (Icons.copy_outlined, 'Copying your PGN file'),
      ImportStatus.indexing => (Icons.search, 'Indexing games in your file'),
      ImportStatus.cancelled => (
        Icons.pause_circle_outline,
        'The import has stopped.',
      ),
      ImportStatus.failed => (
        Icons.error_outline,
        'The import needs attention.',
      ),
      ImportStatus.completed => (
        Icons.check_circle_outline,
        'PGN indexing is complete.',
      ),
    };

    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

final class _RecoveryPanel extends StatelessWidget {
  const _RecoveryPanel({
    required this.state,
    required this.onResume,
    required this.onSelect,
    required this.onReset,
  });

  final ImportState state;
  final VoidCallback onResume;
  final VoidCallback onSelect;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final recovery = importRecoveryFor(state);
    final VoidCallback? onAction = switch (recovery.action) {
      ImportRecoveryAction.resume => onResume,
      ImportRecoveryAction.restart => () {
        onReset();
        onSelect();
      },
      ImportRecoveryAction.selectSource ||
      ImportRecoveryAction.repairSource => onSelect,
      ImportRecoveryAction.none => null,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recovery.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(recovery.explanation),
            const SizedBox(height: 8),
            Text(recovery.preserved),
            if (onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(switch (recovery.action) {
                  ImportRecoveryAction.resume => Icons.play_arrow,
                  ImportRecoveryAction.restart => Icons.refresh,
                  ImportRecoveryAction.selectSource ||
                  ImportRecoveryAction.repairSource => Icons.folder_open,
                  ImportRecoveryAction.none => Icons.check,
                }),
                label: Text(recovery.actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _CompletedSummary extends StatelessWidget {
  const _CompletedSummary({required this.state});

  final ImportState state;

  @override
  Widget build(BuildContext context) {
    final diagnostics = state.diagnostics;
    final count = state.diagnosticCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${state.indexedBlockCount} PGN blocks indexed',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (count > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$count item${count == 1 ? '' : 's'} need attention. '
                'Recognized blocks were kept in the index.',
              ),
              for (final diagnostic in diagnostics.take(5))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    label: 'Import diagnostic',
                    child: Text('• ${diagnostic.message}'),
                  ),
                ),
              if (count > diagnostics.length)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Showing ${diagnostics.length} recent messages. '
                    'There are $count diagnostics in total.',
                  ),
                ),
            ] else ...[
              const SizedBox(height: 8),
              const Text('No import diagnostics were reported.'),
            ],
          ],
        ),
      ),
    );
  }
}
