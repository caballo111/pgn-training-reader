import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';
import 'package:pgntrainingreader/data/repositories/drift_exploration_repository.dart';
import 'package:pgntrainingreader/domain/analysis/exploration_session.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  late AppDatabase database;
  late DriftExplorationRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftExplorationRepository(database);
  });

  tearDown(() => database.close());

  test(
    'isolates source revisions and authored occurrences at the same FEN',
    () async {
      final first = _origin(scopeId: 'block:source-revision-1', path: [0, 1]);
      final otherRevision = _origin(
        scopeId: 'block:source-revision-2',
        path: [0, 1],
      );
      final otherOccurrence = _origin(
        scopeId: 'block:source-revision-1',
        path: [0, 2],
      );
      final recordedTry = _origin(
        scopeId: 'block:source-revision-1',
        path: [0, 1],
        discriminator: 'try:attempt-7',
      );

      for (final origin in [
        first,
        otherRevision,
        otherOccurrence,
        recordedTry,
      ]) {
        await repository.save(ExplorationSession.initial(origin: origin));
      }

      for (final origin in [
        first,
        otherRevision,
        otherOccurrence,
        recordedTry,
      ]) {
        expect(await repository.load(origin), isNotNull);
      }
      expect(
        await repository.load(
          _origin(scopeId: 'block:source-revision-1', path: [9, 9]),
        ),
        isNull,
        reason: 'matching FEN must never recover a draft from another path',
      );
      expect(
        await database.customSelect('SELECT key FROM app_settings').get(),
        hasLength(4),
      );
    },
  );

  test(
    'round-trips a durable branched draft after reopening the database',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'exploration-repository-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/reader.sqlite');
      final origin = _origin(scopeId: 'block:revision-a', path: [2, 0]);
      final session = ExplorationSession.initial(origin: origin)
          .playUci('e2e4')
          .playUci('e7e5')
          .previous()
          .playUci('c7c5');

      await database.close();
      database = AppDatabase(NativeDatabase(file));
      repository = DriftExplorationRepository(database);
      await repository.save(session);
      await database.close();

      database = AppDatabase(NativeDatabase(file));
      repository = DriftExplorationRepository(database);
      final restored = await repository.load(origin);
      expect(restored?.toJson(), session.toJson());
      expect(
        (restored!.toJson()['tree'] as List<Object?>),
        isNotEmpty,
        reason: 'both personal branches must survive a process restart',
      );
    },
  );

  test('load and save calls preserve invocation order', () async {
    final origin = _origin(scopeId: 'block:revision-a', path: [1]);
    final first = ExplorationSession.initial(origin: origin).playUci('e2e4');
    final second = first.playUci('e7e5');

    final firstSave = repository.save(first);
    final secondSave = repository.save(second);
    final read = repository.load(origin);
    await Future.wait([firstSave, secondSave]);

    expect((await read)?.toJson(), second.toJson());
  });

  test(
    'rejects unsupported and malformed rows without overwriting them',
    () async {
      final origin = _origin(scopeId: 'block:revision-a', path: [3]);
      final session = ExplorationSession.initial(origin: origin);
      await repository.save(session);
      final key =
          (await database
                      .customSelect('SELECT key FROM app_settings')
                      .getSingle())
                  .data['key']
              as String;

      for (final unsupported in [
        '{"version":2,"future":"keep me"}',
        '{not-json',
      ]) {
        await database.customStatement(
          'UPDATE app_settings SET value = ? WHERE key = ?',
          [unsupported, key],
        );
        await expectLater(repository.load(origin), throwsFormatException);
        await expectLater(repository.save(session), throwsFormatException);
        final preserved = await database
            .customSelect(
              'SELECT value FROM app_settings WHERE key = ?',
              variables: [Variable<String>(key)],
            )
            .getSingle();
        expect(preserved.data['value'], unsupported);
      }
    },
  );

  test('a failed operation does not block subsequent draft writes', () async {
    final unsupportedOrigin = _origin(scopeId: 'block:revision-a', path: [0]);
    final nextOrigin = _origin(scopeId: 'block:revision-a', path: [1]);
    final unsupportedSession = ExplorationSession.initial(
      origin: unsupportedOrigin,
    );
    await repository.save(unsupportedSession);
    final row = await database
        .customSelect('SELECT key FROM app_settings')
        .getSingle();
    await database.customStatement(
      'UPDATE app_settings SET value = ? WHERE key = ?',
      ['{"version":42,"preserve":true}', row.data['key']],
    );

    await expectLater(
      repository.save(unsupportedSession),
      throwsFormatException,
    );
    final nextSession = ExplorationSession.initial(origin: nextOrigin);
    await repository.save(nextSession);
    expect((await repository.load(nextOrigin))?.toJson(), nextSession.toJson());
  });
}

ExplorationOrigin _origin({
  required String scopeId,
  required List<int> path,
  String? discriminator,
}) => ExplorationOrigin(
  scopeId: scopeId,
  startingFen: _startFen,
  authoredPath: path,
  authoredMoves: const [],
  label: 'Study position',
  discriminator: discriminator,
);
