import 'package:flutter/material.dart';

import '../../../domain/training/progress_calculator.dart';
import '../../../domain/training/progress_report_data.dart';
import '../../../domain/training/lifecycle_status.dart';
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
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<SessionProgressAggregate>>(
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
        return const _Notice(message: 'No daily sessions have been recorded.');
      }
      final days = _groupByStudyDay(sessions);
      return ExpansionTile(
        key: ValueKey<Object>((widget.cycleId, widget.repository)),
        initiallyExpanded: false,
        tilePadding: EdgeInsets.zero,
        title: Text(
          'Daily sessions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          '${days.length} ${days.length == 1 ? 'day' : 'days'} · '
          '${sessions.length} ${sessions.length == 1 ? 'session' : 'sessions'}',
        ),
        children: [
          for (final day in days)
            _DayTile(key: ValueKey('${widget.cycleId}:${day.key}'), day: day),
        ],
      );
    },
  );
}

final class _StudyDay {
  const _StudyDay({
    required this.key,
    required this.date,
    required this.sessions,
  });

  final String key;
  final DateTime date;
  final List<SessionProgressAggregate> sessions;
}

List<_StudyDay> _groupByStudyDay(List<SessionProgressAggregate> sessions) {
  final grouped = <String, List<SessionProgressAggregate>>{};
  final dates = <String, DateTime>{};
  for (final session in sessions) {
    final date = session.session.studyDay;
    final key =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    dates[key] = date;
    grouped.putIfAbsent(key, () => []).add(session);
  }
  final days = grouped.entries.map((entry) {
    final ordered = entry.value
      ..sort((a, b) {
        final byStart = b.session.startedAt.compareTo(a.session.startedAt);
        return byStart != 0 ? byStart : a.session.id.compareTo(b.session.id);
      });
    return _StudyDay(
      key: entry.key,
      date: dates[entry.key]!,
      sessions: ordered,
    );
  }).toList()..sort((a, b) => b.key.compareTo(a.key));
  return days;
}

final class _DayTile extends StatelessWidget {
  const _DayTile({super.key, required this.day});

  final _StudyDay day;

  @override
  Widget build(BuildContext context) {
    var attempted = 0;
    var passed = 0;
    var duration = Duration.zero;
    for (final session in day.sessions) {
      final summary = ProgressCalculator.calculate(session.progress);
      attempted += summary.attemptedCount;
      passed += summary.passedCount;
      duration += summary.totalActiveTime;
    }
    return ExpansionTile(
      initiallyExpanded: false,
      title: Text(_dateLabel(day.date)),
      subtitle: Text(
        '${day.sessions.length} ${day.sessions.length == 1 ? 'session' : 'sessions'} · '
        '$attempted attempted · $passed passed · ${_formatDuration(duration)}',
        softWrap: true,
      ),
      children: [
        for (final session in day.sessions) _SessionDetails(session: session),
      ],
    );
  }
}

final class _SessionDetails extends StatelessWidget {
  const _SessionDetails({required this.session});

  final SessionProgressAggregate session;

  @override
  Widget build(BuildContext context) {
    final summary = ProgressCalculator.calculate(session.progress);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  _timeLabel(session.session.startedAt),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(_statusLabel(session.session.status)),
              ],
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
              _MetricRow('Assisted', '${summary.assistedCount}'),
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

String _dateLabel(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final suffix = local.hour < 12 ? 'AM' : 'PM';
  return '$hour:${local.minute.toString().padLeft(2, '0')} $suffix';
}

String _statusLabel(TrainingSessionStatus status) => switch (status) {
  TrainingSessionStatus.active => 'Active',
  TrainingSessionStatus.paused => 'Paused',
  TrainingSessionStatus.closed => 'Closed',
  TrainingSessionStatus.recovered => 'Recovered',
};

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}
