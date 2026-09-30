import 'package:flutter/material.dart';

import '../../../domain/training/progress_calculator.dart';
import '../../../domain/training/progress_report_data.dart';
import '../../../domain/training/training_repository.dart';

/// Loads and displays the daily session summaries for one training cycle.
final class DailySessionsView extends StatefulWidget {
  const DailySessionsView({
    super.key,
    required this.repository,
    required this.cycleId,
  });

  final TrainingRepository repository;
  final String cycleId;

  @override
  State<DailySessionsView> createState() => _DailySessionsViewState();
}

final class _DailySessionsViewState extends State<DailySessionsView> {
  late Future<List<SessionProgressAggregate>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DailySessionsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.cycleId != widget.cycleId) {
      _load();
    }
  }

  void _load() {
    _sessionsFuture = widget.repository.sessionAggregatesForCycle(
      widget.cycleId,
    );
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<SessionProgressAggregate>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Notice(
              message: 'Could not load daily sessions.',
              action: 'Retry',
              onPressed: () => setState(_load),
            );
          }
          final sessions = snapshot.data ?? const <SessionProgressAggregate>[];
          if (sessions.isEmpty) {
            return const _Notice(
              message: 'No daily sessions have been recorded.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily sessions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final session in sessions) ...[
                _SessionCard(session: session),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      );
}

final class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final SessionProgressAggregate session;

  @override
  Widget build(BuildContext context) {
    final summary = ProgressCalculator.calculate(session.progress);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _dateLabel(session.session.studyDay),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _MetricRow(
              'Active duration',
              _formatDuration(summary.totalActiveTime),
            ),
            _MetricRow('Attempted', '${summary.attemptedCount}'),
            if (summary.attemptedCount == 0)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('No attempts in this session.'),
              )
            else ...[
              const Divider(height: 20),
              _MetricRow('Passed', '${summary.passedCount}'),
              _MetricRow('Wrong move', '${summary.wrongMoveOutcomeCount}'),
              _MetricRow('Revealed', '${summary.revealedCount}'),
              _MetricRow('Skipped', '${summary.skippedCount}'),
              _MetricRow('Timed out', '${summary.timedOutCount}'),
              _MetricRow('Abandoned', '${summary.abandonedCount}'),
            ],
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

String _dateLabel(DateTime value) {
  final date = value.toLocal();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}
