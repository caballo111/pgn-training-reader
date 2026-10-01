import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content_repository.dart';
import 'package:pgntrainingreader/domain/library/pgn_index_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/pgn_block_index.dart';
import 'package:pgntrainingreader/domain/training/authored_line_puzzle_evaluator.dart';
import 'package:pgntrainingreader/domain/training/training_repository.dart';
import 'package:pgntrainingreader/domain/training/training_session_service.dart';
import 'package:pgntrainingreader/domain/training/training_set.dart';
import 'package:pgntrainingreader/domain/training/training_set_repository.dart';
import 'package:pgntrainingreader/features/training_sets/presentation/training_sets_page.dart';

import '../../../support/fake_app_clock.dart';
import '../../../support/fake_id_generator.dart';

void main() {
  testWidgets('training set can be archived and remains visible as archived', (
    tester,
  ) async {
    final repository = _ArchiveRepository()..sets.add(_set());
    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();
    expect(repository.sets.single.status, TrainingSetStatus.archived);
    expect(find.text('Archived'), findsOneWidget);
  });
  for (final archived in [false, true]) {
    testWidgets(
      'removes ${archived ? 'archived' : 'active'} set after confirmation',
      (tester) async {
        final repository = _ArchiveRepository()..sets.add(_set());
        if (archived) {
          await repository.archiveSet(
            id: 'set-1',
            archivedAt: DateTime.utc(2026),
          );
        }
        await _pumpPage(tester, repository);
        await _openRemove(tester);
        expect(find.text('Remove training set?'), findsOneWidget);
        expect(repository.sets, hasLength(1));
        await tester.tap(find.text('Remove').last);
        await tester.pumpAndSettle();
        expect(repository.sets, isEmpty);
        expect(find.text('Opening work'), findsNothing);
        expect(
          find.text('Create a training set from your imported content.'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('canceling removal keeps the set', (tester) async {
    final repository = _ArchiveRepository()..sets.add(_set());
    await _pumpPage(tester, repository);
    await _openRemove(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.sets, hasLength(1));
    expect(find.text('Opening work'), findsOneWidget);
  });

  testWidgets('failed removal keeps the set and allows retry', (tester) async {
    final repository = _ArchiveRepository()
      ..sets.add(_set())
      ..failRemoval = true;
    await _pumpPage(tester, repository);
    await _openRemove(tester);
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Could not remove the training set. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Opening work'), findsOneWidget);
    repository.failRemoval = false;
    await _openRemove(tester);
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(repository.sets, isEmpty);
  });
}

Future<void> _openRemove(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Remove'));
  await tester.pumpAndSettle();
}

Future<void> _pumpPage(
  WidgetTester tester,
  _ArchiveRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TrainingSetsPage(
        repository: repository,
        indexRepository: _EmptyIndexRepository(),
        trainingRepository: _UnusedTrainingRepository(),
        sessionService: _UnusedSessionService(),
        contentRepository: _UnusedContentRepository(),
        evaluatorFactory: () => AuthoredLinePuzzleEvaluator(),
        clock: FakeAppClock(initialWallTime: DateTime.utc(2026)),
        idGenerator: FakeIdGenerator(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TrainingSet _set() => TrainingSet(
  id: 'set-1',
  name: 'Opening work',
  items: const [],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

final class _ArchiveRepository implements TrainingSetRepository {
  final List<TrainingSet> sets = [];
  bool failRemoval = false;
  @override
  Future<void> removeSet({
    required String id,
    required DateTime removedAt,
  }) async {
    if (failRemoval) throw StateError('save failed');
    sets.removeWhere((set) => set.id == id);
  }

  @override
  Future<List<TrainingSet>> listSets() async => List.of(sets);
  @override
  Future<void> archiveSet({
    required String id,
    required DateTime archivedAt,
  }) async {
    final index = sets.indexWhere((set) => set.id == id);
    final set = sets[index];
    sets[index] = TrainingSet(
      id: set.id,
      name: set.name,
      status: TrainingSetStatus.archived,
      items: set.items,
      createdAt: set.createdAt,
      updatedAt: archivedAt,
      archivedAt: archivedAt,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _EmptyIndexRepository implements PgnIndexRepository {
  @override
  Future<int> countForSource(String sourceId) async => 0;
  @override
  Future<PgnBlockIndex?> getById(String id) async => null;
  @override
  Future<PgnIndexPage> search({
    PgnIndexFilter filter = const PgnIndexFilter(),
    PgnIndexSort sort = PgnIndexSort.sourceOrder,
    int offset = 0,
    required int limit,
  }) async => PgnIndexPage(items: const [], nextOffset: null);
}

final class _UnusedTrainingRepository implements TrainingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnusedSessionService implements TrainingSessionService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnusedContentRepository implements ChessContentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
