import 'package:flutter/material.dart';

import '../../../domain/training/progress_calculator.dart';
import '../../../domain/training/progress_report_data.dart';
import '../../../domain/training/training_repository.dart';

/// Shows progress grouped by theme and difficulty when metadata is available.
final class MetadataProgressSummaryView extends StatefulWidget {
  const MetadataProgressSummaryView({
    super.key,
    required this.repository,
    required this.cycleId,
  });

  final TrainingRepository repository;
  final String cycleId;

  @override
  State<MetadataProgressSummaryView> createState() =>
      _MetadataProgressSummaryViewState();
}

typedef _MetadataSummaryData = ({
  List<MetadataProgressAggregate> themes,
  List<MetadataProgressAggregate> difficulties,
});

final class _MetadataProgressSummaryViewState
    extends State<MetadataProgressSummaryView> {
  late Future<_MetadataSummaryData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MetadataProgressSummaryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.cycleId != widget.cycleId) {
      _load();
    }
  }

  void _load() {
    _dataFuture = _loadData();
  }

  Future<_MetadataSummaryData> _loadData() async {
    final themesFuture = widget.repository.themeAggregatesForCycle(
      widget.cycleId,
    );
    final difficultiesFuture = widget.repository.difficultyAggregatesForCycle(
      widget.cycleId,
    );
    return (themes: await themesFuture, difficulties: await difficultiesFuture);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_MetadataSummaryData>(
    future: _dataFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _Notice(
          message: 'Could not load theme and difficulty summaries.',
          action: 'Retry',
          onPressed: () => setState(_load),
        );
      }
      final data = snapshot.data!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetadataSection(
            title: 'By theme',
            unavailableMessage: 'Theme metadata unavailable for this cycle.',
            summaries: data.themes,
          ),
          const SizedBox(height: 12),
          _MetadataSection(
            title: 'By difficulty',
            unavailableMessage:
                'Difficulty metadata unavailable for this cycle.',
            summaries: data.difficulties,
          ),
        ],
      );
    },
  );
}

final class _MetadataSection extends StatelessWidget {
  const _MetadataSection({
    required this.title,
    required this.unavailableMessage,
    required this.summaries,
  });

  final String title;
  final String unavailableMessage;
  final List<MetadataProgressAggregate> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(unavailableMessage),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final summary in summaries) ...[
          _MetadataCard(summary: summary),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

final class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.summary});

  final MetadataProgressAggregate summary;

  @override
  Widget build(BuildContext context) {
    final metrics = ProgressCalculator.calculate(summary.progress);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary.value, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _MetricRow('Attempted', '${metrics.attemptedCount}'),
            _MetricRow('Passed', '${metrics.passedCount}'),
            _MetricRow('Assisted', '${metrics.assistedCount}'),
            _MetricRow('Failed', '${metrics.nonPassingCount}'),
            _MetricRow(
              'Accuracy',
              metrics.accuracyPercent == null
                  ? 'Not available'
                  : '${metrics.accuracyPercent!.toStringAsFixed(1)}%',
            ),
            _MetricRow('Active time', _formatDuration(metrics.totalActiveTime)),
            _MetricRow(
              'Average per attempt',
              _format(metrics.averageAttemptActiveTime),
            ),
            _MetricRow(
              'Median per attempt',
              _format(metrics.medianAttemptActiveTime),
            ),
            const Divider(height: 20),
            _MetricRow('Passed', '${metrics.passedCount}'),
            _MetricRow('Assisted', '${metrics.assistedCount}'),
            _MetricRow('Wrong move', '${metrics.wrongMoveOutcomeCount}'),
            _MetricRow('Revealed', '${metrics.revealedCount}'),
            _MetricRow('Skipped', '${metrics.skippedCount}'),
            _MetricRow('Timed out', '${metrics.timedOutCount}'),
            _MetricRow('Abandoned', '${metrics.abandonedCount}'),
          ],
        ),
      ),
    );
  }
}

final class _MetricRow extends StatelessWidget {
  const _MetricRow(this.label, this.value);

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

final class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.action, this.onPressed});

  final String message;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (action != null && onPressed != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onPressed, child: Text(action!)),
          ],
        ],
      ),
    ),
  );
}

String _format(Duration? duration) =>
    duration == null ? 'Not available' : _formatDuration(duration);

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}
