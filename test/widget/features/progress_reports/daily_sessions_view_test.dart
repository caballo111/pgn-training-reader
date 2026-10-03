import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/training/lifecycle_status.dart';
import 'package:pgntrainingreader/domain/training/progress_aggregate.dart';
import 'package:pgntrainingreader/domain/training/progress_report_data.dart';
import 'package:pgntrainingreader/domain/training/training_repository.dart';
import 'package:pgntrainingreader/domain/training/training_session.dart';
import 'package:pgntrainingreader/features/progress_reports/presentation/daily_sessions_view.dart';

void main() {
  testWidgets(
    '20 days stay collapsed; expanding shows sorted day totals and every session',
    (tester) async {
      final sessions = <SessionProgressAggregate>[];
      for (var index = 1; index <= 20; index++) {
        final day = DateTime.utc(2026, 1, index);
        sessions.add(
          _session(
            'late-$index',
            day,
            DateTime(2026, 1, index, 16),
            passed: 1,
            seconds: 10,
            nonPuzzleSeconds: 5,
          ),
        );
        sessions.add(
          _session(
            'early-$index',
            day,
            DateTime(2026, 1, index, 9),
            skipped: 1,
            seconds: 20,
          ),
        );
      }
      final repository = _Repository({'cycle': Future.value(sessions)});
      await tester.pumpWidget(_app(repository, 'cycle'));
      await tester.pumpAndSettle();

      expect(find.text('20 days · 40 sessions'), findsOneWidget);
      expect(find.text('2026-01-20'), findsNothing);
      await tester.tap(find.text('Daily sessions'));
      await tester.pumpAndSettle();
      expect(find.text('2026-01-20'), findsOneWidget);
      expect(find.text('2026-01-01'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('2026-01-20')).dy,
        lessThan(tester.getTopLeft(find.text('2026-01-01')).dy),
      );
      expect(
        find.text('2 sessions · 2 attempted · 1 passed · 35s'),
        findsNWidgets(20),
      );

      await tester.tap(find.text('2026-01-20'));
      await tester.pumpAndSettle();
      expect(find.text('4:00 PM'), findsOneWidget);
      expect(find.text('9:00 AM'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('4:00 PM')).dy,
        lessThan(tester.getTopLeft(find.text('9:00 AM')).dy),
      );
      expect(find.text('Passed'), findsNWidgets(2));
      expect(find.text('Skipped'), findsNWidgets(2));
      expect(find.text('Active duration'), findsNWidgets(2));

      await tester.tap(find.text('2026-01-20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-01-20'));
      await tester.pumpAndSettle();
      expect(find.text('4:00 PM'), findsOneWidget);
      expect(find.text('9:00 AM'), findsOneWidget);
    },
  );

  testWidgets('summaries wrap at phone width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository({
      'cycle': Future.value([
        _session(
          'one',
          DateTime.utc(2026, 2, 1),
          DateTime(2026, 2, 1, 9),
          passed: 1,
          seconds: 35,
        ),
        _session(
          'two',
          DateTime.utc(2026, 2, 1),
          DateTime(2026, 2, 1, 8),
          skipped: 1,
          seconds: 35,
        ),
      ]),
    });
    await tester.pumpWidget(_app(repository, 'cycle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daily sessions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-02-01'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cycle change resets disclosures and hides prior results while loading',
    (tester) async {
      final pending = Completer<List<SessionProgressAggregate>>();
      final repository = _Repository({
        'first': Future.value([
          _session(
            'first',
            DateTime.utc(2026, 3, 1),
            DateTime(2026, 3, 1, 9),
            passed: 1,
            seconds: 10,
          ),
        ]),
        'second': pending.future,
      });
      await tester.pumpWidget(_app(repository, 'first'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daily sessions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-03-01'));
      await tester.pumpAndSettle();
      expect(find.text('9:00 AM'), findsOneWidget);

      await tester.pumpWidget(_app(repository, 'second'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('9:00 AM'), findsNothing);
      pending.complete([
        _session(
          'second',
          DateTime.utc(2026, 3, 2),
          DateTime(2026, 3, 2, 10),
          skipped: 1,
          seconds: 12,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('2026-03-02'), findsNothing);
      await tester.tap(find.text('Daily sessions'));
      await tester.pumpAndSettle();
      expect(find.text('2026-03-02'), findsOneWidget);
    },
  );

  testWidgets('session load error offers retry', (tester) async {
    var calls = 0;
    final repository = _Repository(
      {},
      onSessions: (cycle) {
        calls++;
        return calls == 1
            ? Future<List<SessionProgressAggregate>>.error(StateError('failed'))
            : Future.value([
                _session(
                  'retry',
                  DateTime.utc(2026, 4, 1),
                  DateTime(2026, 4, 1, 8),
                  passed: 1,
                  seconds: 1,
                ),
              ]);
      },
    );
    await tester.pumpWidget(_app(repository, 'cycle'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load daily sessions.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('1 day · 1 session'), findsOneWidget);
  });
}

Widget _app(TrainingRepository repository, String cycle) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: DailySessionsView(repository: repository, cycleId: cycle),
    ),
  ),
);

SessionProgressAggregate _session(
  String id,
  DateTime day,
  DateTime startedAt, {
  int passed = 0,
  int skipped = 0,
  required int seconds,
  int nonPuzzleSeconds = 0,
}) => SessionProgressAggregate(
  session: TrainingSession(
    id: id,
    cycleId: 'cycle',
    status: TrainingSessionStatus.closed,
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(minutes: 1)),
    studyDay: day,
  ),
  progress: ProgressAggregate(
    passedCount: passed,
    wrongMoveOutcomeCount: 0,
    revealedCount: 0,
    skippedCount: skipped,
    timedOutCount: 0,
    abandonedCount: 0,
    wrongMoveCount: 0,
    hintCount: 0,
    attemptActiveDurations: List.filled(
      passed + skipped,
      Duration(seconds: seconds),
    ),
    nonPuzzleActiveDuration: Duration(seconds: nonPuzzleSeconds),
  ),
);

final class _Repository implements TrainingRepository {
  _Repository(this.results, {this.onSessions});

  final Map<String, Future<List<SessionProgressAggregate>>> results;
  final Future<List<SessionProgressAggregate>> Function(String cycle)?
  onSessions;

  @override
  Future<List<SessionProgressAggregate>> sessionAggregatesForCycle(
    String cycleId,
  ) => onSessions?.call(cycleId) ?? results[cycleId]!;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
