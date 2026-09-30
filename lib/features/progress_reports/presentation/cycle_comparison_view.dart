import 'package:flutter/material.dart';

import '../../../domain/training/cycle.dart';
import '../application/progress_report_controller.dart';

/// Shows the raw accuracy and active-time changes between two selected cycles.
final class CycleComparisonView extends StatelessWidget {
  const CycleComparisonView({super.key, required this.controller});

  final ProgressReportController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final state = controller.state;
      final candidates = state.cycles
          .where((cycle) => cycle.id != state.selectedCycleId)
          .toList(growable: false);
      if (state.status != ProgressReportStatus.ready ||
          state.selectedCycleId == null ||
          candidates.isEmpty) {
        return const SizedBox.shrink();
      }

      final comparison = state.comparison;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cycle comparison',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: state.comparisonCycleId ?? '',
                decoration: const InputDecoration(
                  labelText: 'Compare selected cycle with',
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('No comparison'),
                  ),
                  for (var index = 0; index < state.cycles.length; index++)
                    if (state.cycles[index].id != state.selectedCycleId)
                      DropdownMenuItem(
                        value: state.cycles[index].id,
                        child: Text(_cycleLabel(state.cycles[index], index)),
                      ),
                ],
                onChanged: (id) => controller.selectComparisonCycle(
                  id == null || id.isEmpty ? null : id,
                ),
              ),
              const SizedBox(height: 12),
              if (comparison == null)
                const Text('Choose another cycle to compare these results.')
              else ...[
                Text(
                  'Change = selected cycle − comparison cycle',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                _ComparisonMetric(
                  label: 'Accuracy',
                  earlier: _formatAccuracy(comparison.earlier.accuracyPercent),
                  later: _formatAccuracy(comparison.later.accuracyPercent),
                  change: _formatPercentagePointChange(
                    comparison.accuracyPercentagePointChange,
                  ),
                ),
                const Divider(),
                _ComparisonMetric(
                  label: 'Total active time',
                  earlier: _formatDuration(comparison.earlier.totalActiveTime),
                  later: _formatDuration(comparison.later.totalActiveTime),
                  change: _formatDurationChange(
                    comparison.totalActiveTimeChange,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

final class _ComparisonMetric extends StatelessWidget {
  const _ComparisonMetric({
    required this.label,
    required this.earlier,
    required this.later,
    required this.change,
  });

  final String label;
  final String earlier;
  final String later;
  final String change;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4),
      _ValueRow(label: 'Comparison cycle', value: earlier),
      _ValueRow(label: 'Selected cycle', value: later),
      _ValueRow(label: 'Change', value: change),
    ],
  );
}

final class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, textAlign: TextAlign.end),
      ],
    ),
  );
}

String _cycleLabel(Cycle cycle, int index) {
  final date = (cycle.startedAt ?? cycle.createdAt).toLocal();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return 'Cycle ${index + 1} · ${date.year}-$month-$day';
}

String _formatAccuracy(double? value) =>
    value == null ? 'Not available' : '${value.toStringAsFixed(1)}%';

String _formatPercentagePointChange(double? value) {
  if (value == null) return 'Not available';
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)} percentage points';
}

String _formatDuration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}

String _formatDurationChange(Duration value) {
  final sign = value.isNegative ? '−' : '+';
  final absolute = Duration(microseconds: value.inMicroseconds.abs());
  return '$sign${_formatDuration(absolute)}';
}
