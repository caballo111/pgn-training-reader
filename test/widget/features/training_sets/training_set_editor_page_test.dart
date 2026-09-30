import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/pgn_block_index.dart';
import 'package:pgntrainingreader/domain/library/pgn_index_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content_repository.dart';
import 'package:pgntrainingreader/domain/training/training_set.dart';
import 'package:pgntrainingreader/domain/training/training_set_item.dart';
import 'package:pgntrainingreader/domain/training/training_set_repository.dart';
import 'package:pgntrainingreader/domain/training/training_repository.dart';
import 'package:pgntrainingreader/domain/training/training_session_service.dart';
import 'package:pgntrainingreader/domain/training/authored_line_puzzle_evaluator.dart';
import 'package:pgntrainingreader/features/training_sets/application/training_set_editor_controller.dart';
import 'package:pgntrainingreader/features/training_sets/presentation/training_set_editor_page.dart';
import 'package:pgntrainingreader/features/training_sets/presentation/training_sets_page.dart';

import '../../../support/fake_app_clock.dart';
import '../../../support/fake_id_generator.dart';

void main() {
  testWidgets('editor marks puzzle as scored and instruction as not scored', (
    tester,
  ) async {
    final repository = _SetRepository();
    final clock = FakeAppClock(initialWallTime: DateTime.utc(2026));
    final controller = TrainingSetEditorController(
      repository: repository,
      clock: clock,
      idGenerator: FakeIdGenerator(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingSetEditorPage(
          controller: controller,
          indexRepository: _IndexRepository([
            _block('p', ContentType.puzzle),
            _block('i', ContentType.instruction),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.add(_block('p', ContentType.puzzle));
    controller.add(_block('i', ContentType.instruction));
    await tester.pump();
    expect(find.text('Scored puzzle'), findsOneWidget);
    expect(find.text('Not scored'), findsOneWidget);
    expect(controller.state.items.map((item) => item.contentType), [
      ContentType.puzzle,
      ContentType.instruction,
    ]);
  });

  testWidgets('training set can be archived and remains visible as archived', (
    tester,
  ) async {
    final repository = _SetRepository()
      ..sets.add(_set('set-1', 'Opening work'));
    final clock = FakeAppClock(initialWallTime: DateTime.utc(2026));
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingSetsPage(
          repository: repository,
          indexRepository: _IndexRepository(const []),
          trainingRepository: _UnusedTrainingRepository(),
          sessionService: _UnusedSessionService(),
          contentRepository: _UnusedContentRepository(),
          evaluatorFactory: () => AuthoredLinePuzzleEvaluator(),
          clock: clock,
          idGenerator: FakeIdGenerator(),
        ),
      ),
    );
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

PgnBlockIndex _block(String id, ContentType type) => PgnBlockIndex(
  id: id,
  sourceId: 'source',
  startOffset: 0,
  endOffset: 1,
  ordinal: id == 'p' ? 0 : 1,
  contentType: type,
  parseStatus: PgnBlockParseStatus.valid,
);

TrainingSet _set(String id, String name) => TrainingSet(
  id: id,
  name: name,
  items: const [],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

final class _IndexRepository implements PgnIndexRepository {
  _IndexRepository(this.blocks);
  final List<PgnBlockIndex> blocks;
  @override
  Future<int> countForSource(String sourceId) async => blocks.length;
  @override
  Future<PgnBlockIndex?> getById(String id) async =>
      blocks.where((b) => b.id == id).firstOrNull;
  @override
  Future<PgnIndexPage> search({
    PgnIndexFilter filter = const PgnIndexFilter(),
    int offset = 0,
    required int limit,
  }) async {
    final filtered = blocks
        .where(
          (block) =>
              filter.contentType == null ||
              block.contentType == filter.contentType,
        )
        .toList();
    final page = filtered.skip(offset).take(limit).toList();
    return PgnIndexPage(
      items: page,
      nextOffset: offset + page.length < filtered.length
          ? offset + page.length
          : null,
    );
  }
}

final class _SetRepository implements TrainingSetRepository {
  final List<TrainingSet> sets = [];
  @override
  Future<void> addItem(TrainingSetItem item) async {}
  @override
  Future<void> archiveSet({
    required String id,
    required DateTime archivedAt,
  }) async {
    final i = sets.indexWhere((set) => set.id == id);
    final set = sets[i];
    sets[i] = TrainingSet(
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
  Future<void> createSet(TrainingSet set) async => sets.add(set);
  @override
  Future<TrainingSet?> getSet(String id) async =>
      sets.where((set) => set.id == id).firstOrNull;
  @override
  Future<List<TrainingSet>> listSets() async => List.of(sets);
  @override
  Future<void> removeItem({
    required String trainingSetId,
    required String itemId,
  }) async {}
  @override
  Future<void> renameSet({
    required String id,
    required String name,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> reorderItems({
    required String trainingSetId,
    required List<String> orderedItemIds,
  }) async {}
}
