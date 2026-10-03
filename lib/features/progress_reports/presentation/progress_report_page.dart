import 'package:flutter/material.dart';

import '../../../domain/training/cycle.dart';
import '../application/progress_report_controller.dart';
import 'cycle_comparison_view.dart';
import 'daily_sessions_view.dart';
import 'metadata_progress_summary_view.dart';

/// Presents the transparent calculated summary for one selected cycle.
final class ProgressReportPage extends StatefulWidget {
  const ProgressReportPage({
    super.key,
    required this.controller,
    required this.trainingSetName,
  });

  final ProgressReportController controller;
  final String trainingSetName;

  @override
  State<ProgressReportPage> createState() => _ProgressReportPageState();
}

final class _ProgressReportPageState extends State<ProgressReportPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Progress report')),
    body: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        if (state.status == ProgressReportStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == ProgressReportStatus.failed) {
          return _MessageView(
            message: state.errorMessage ?? 'Could not load training progress.',
            actionLabel: 'Retry',
            onAction: widget.controller.refresh,
          );
        }
        if (state.cycles.isEmpty) {
          return _MessageView(
            message: 'Complete a training cycle to see its progress report.',
          );
        }
        final summary = state.selectedSummary;
        final selectedCycle = state.selectedCycle;
        if (summary == null || selectedCycle == null) {
          return const _MessageView(message: 'No cycle is selected.');
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.trainingSetName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _CycleSelector(
              cycles: state.cycles,
              selectedCycleId: state.selectedCycleId!,
              onSelected: widget.controller.selectCycle,
            ),
            const SizedBox(height: 16),
            _MetricCard(
              title: 'Cycle results',
              rows: [
                _Metric('Attempted', '${summary.attemptedCount}'),
                _Metric('Passed', '${summary.passedCount}'),
                _Metric('Assisted', '${summary.assistedCount}'),
                _Metric('Failed', '${summary.nonPassingCount}'),
                _Metric(
                  'Accuracy',
                  summary.accuracyPercent == null
                      ? 'Not available'
                      : '${summary.accuracyPercent!.toStringAsFixed(1)}%',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MetricCard(
              title: 'Active time',
              rows: [
                _Metric(
                  'Total cycle time',
                  _formatDuration(summary.totalActiveTime),
                ),
                _Metric(
                  'Average per attempt',
                  _formatOptionalDuration(summary.averageAttemptActiveTime),
                ),
                _Metric(
                  'Median per attempt',
                  _formatOptionalDuration(summary.medianAttemptActiveTime),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MetricCard(
              title: 'Outcome counts',
              rows: [
                _Metric('Passed', '${summary.passedCount}'),
                _Metric(
                  'Failed on a wrong move',
                  '${summary.wrongMoveOutcomeCount}',
                ),
                _Metric('Revealed', '${summary.revealedCount}'),
                _Metric('Skipped', '${summary.skippedCount}'),
                _Metric('Timed out', '${summary.timedOutCount}'),
                _Metric('Abandoned', '${summary.abandonedCount}'),
              ],
            ),
            if (state.cycles.length > 1) ...[
              const SizedBox(height: 12),
              CycleComparisonView(controller: widget.controller),
            ],
            const SizedBox(height: 12),
            DailySessionsView(
              repository: widget.controller.repository,
              cycleId: selectedCycle.id,
            ),
            MetadataProgressSummaryView(
              repository: widget.controller.repository,
              cycleId: selectedCycle.id,
            ),
          ],
        );
      },
    ),
  );
}

final class _CycleSelector extends StatelessWidget {
  const _CycleSelector({
    required this.cycles,
    required this.selectedCycleId,
    required this.onSelected,
  });

  final List<Cycle> cycles;
  final String selectedCycleId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: selectedCycleId,
    decoration: const InputDecoration(labelText: 'Cycle'),
    items: [
      for (var index = 0; index < cycles.length; index++)
        DropdownMenuItem(
          value: cycles[index].id,
          child: Text(_cycleLabel(cycles[index], index)),
        ),
    ],
    onChanged: (id) {
      if (id != null) onSelected(id);
    },
  );
}

String _cycleLabel(Cycle cycle, int index) {
  final date = cycle.startedAt ?? cycle.createdAt;
  final day = date.toLocal();
  final month = day.month.toString().padLeft(2, '0');
  final dateText = '${day.year}-$month-${day.day.toString().padLeft(2, '0')}';
  return 'Cycle ${index + 1} · $dateText';
}

final class _Metric {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
}

final class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.rows});

  final String title;
  final List<_Metric> rows;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(child: Text(row.label)),
                  Text(row.value, textAlign: TextAlign.end),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

final class _MessageView extends StatelessWidget {
  const _MessageView({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

String _formatOptionalDuration(Duration? duration) =>
    duration == null ? 'Not available' : _formatDuration(duration);

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}
