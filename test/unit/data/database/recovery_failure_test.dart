import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';
import 'package:pgntrainingreader/data/database/database_migrator.dart';

void main() {
  test(
    'corrupt database bytes remain available for recovery or support',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pgn-corrupt-db-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/library.sqlite');
      final original = List<int>.generate(256, (i) => (i * 17) & 0xff);
      await file.writeAsBytes(original);

      final database = AppDatabase(NativeDatabase(file));
      await expectLater(
        database.customSelect('SELECT 1').get(),
        throwsA(anything),
      );
      await database.close();

      expect(await file.readAsBytes(), original);
    },
  );

  test('failed migration rolls back and can be retried after reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pgn-migration-stop-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/library.sqlite');
    final initial = AppDatabase(NativeDatabase(file));
    await initial.customStatement(
      "INSERT INTO pgn_sources (id, display_name, access_mode, scanner_version, import_state, created_at_micros, updated_at_micros) VALUES ('preserve', 'Library', 'managedCopy', 1, 'ready', 1, 1)",
    );
    await initial.customStatement('DROP TABLE app_settings');
    await initial.customStatement('PRAGMA user_version = 6');
    await initial.close();

    final interrupted = _InterruptedMigrationDatabase(NativeDatabase(file));
    await expectLater(
      interrupted.customSelect('SELECT 1').get(),
      throwsA(isA<StateError>()),
    );
    await interrupted.close();

    final versionProbe = _Version6ProbeDatabase(NativeDatabase(file));
    final version = await versionProbe
        .customSelect('PRAGMA user_version')
        .get();
    expect(version.single.read<int>('user_version'), 6);
    final settings = await versionProbe
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'migration_probe'",
        )
        .get();
    expect(settings, isEmpty);
    await versionProbe.close();

    // The normal migrator can reopen the unchanged v6 database and finish.
    final recovered = AppDatabase(NativeDatabase(file));
    final rows = await recovered
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'app_settings'",
        )
        .get();
    expect(rows, hasLength(1));
    final source = await recovered
        .customSelect(
          "SELECT display_name FROM pgn_sources WHERE id = 'preserve'",
        )
        .get();
    expect(source.single.read<String>('display_name'), 'Library');
    await recovered.close();
  });
}

final class _InterruptedMigrationDatabase extends AppDatabase {
  _InterruptedMigrationDatabase(super.executor);

  @override
  MigrationStrategy get migration => DatabaseMigrator(
    schemaVersion: schemaVersion,
    steps: {
      6: DatabaseMigrationStep(
        migrate: (migrator) async {
          await migrator.database.customStatement(
            'CREATE TABLE migration_probe (value TEXT)',
          );
          throw StateError('simulated interruption');
        },
      ),
    },
  ).strategy;
}

final class _Version6ProbeDatabase extends AppDatabase {
  _Version6ProbeDatabase(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onUpgrade: (_, _, _) async {});
}
