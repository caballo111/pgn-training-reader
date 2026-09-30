import 'package:flutter/material.dart';

import '../application/import_controller.dart';

/// Progress summary for a PGN import operation.
///
/// The widget accepts the controller's immutable state so the phase, counters,
/// and cancellation affordance always describe the same update.
class ImportProgress extends StatelessWidget {
  const ImportProgress({
    required this.state,
    required this.onCancel,
    super.key,
  });

  final ImportState state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final bytesRead = state.bytesRead;
    final totalBytes = state.totalBytes;
    final hasKnownTotal = totalBytes != null && totalBytes > 0;
    final fraction = hasKnownTotal
        ? ((bytesRead ?? 0) / totalBytes).clamp(0.0, 1.0)
        : null;
    final phase = _phaseLabel(state.status);
    final processedBytes = bytesRead ?? 0;
    final byteDescription = hasKnownTotal
        ? '${_formatBytes(processedBytes)} of ${_formatBytes(totalBytes)}'
        : processedBytes > 0
        ? '${_formatBytes(processedBytes)} processed; total size unknown'
        : 'Total size unknown';
    final progressLabel = '$phase. $byteDescription.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(phase, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Semantics(
              label: 'Import progress',
              value: progressLabel,
              child: ExcludeSemantics(
                child: LinearProgressIndicator(value: fraction),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _ProgressMetric(label: 'Bytes', value: byteDescription),
                _ProgressMetric(
                  label: 'Blocks indexed',
                  value: '${state.indexedBlockCount}',
                ),
                _ProgressMetric(
                  label: 'Diagnostics',
                  value: '${state.diagnosticCount}',
                ),
              ],
            ),
            if (state.canCancel) ...[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel import'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _phaseLabel(ImportStatus status) => switch (status) {
    ImportStatus.idle => 'Ready to import',
    ImportStatus.selecting => 'Selecting a file',
    ImportStatus.copying => 'Copying source file',
    ImportStatus.indexing => 'Indexing PGN blocks',
    ImportStatus.cancelled => 'Import cancelled',
    ImportStatus.failed => 'Import failed',
    ImportStatus.completed => 'Import complete',
  };

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = -1;
    do {
      value /= 1024;
      unit++;
    } while (value >= 1024 && unit < units.length - 1);
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: value,
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    ),
  );
}
