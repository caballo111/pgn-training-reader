import 'package:drift/drift.dart';

/// Creates a database migration strategy without depending on generated app
/// database classes.
///
/// The database's [GeneratedDatabase.schemaVersion] must equal [schemaVersion].
/// Fresh databases are created through Drift's [Migrator.createAll]. Existing
/// databases are upgraded one version at a time using [steps].
class DatabaseMigrator {
  DatabaseMigrator({
    required this.schemaVersion,
    Map<int, DatabaseMigrationStep> steps = const {},
    this.afterCreate,
    this.backupBeforeDestructiveMigration,
    this.beforeOpen,
  }) : steps = Map.unmodifiable(steps) {
    if (schemaVersion < 1) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'Must be positive',
      );
    }
    for (final entry in this.steps.entries) {
      if (entry.key < 1 || entry.key >= schemaVersion) {
        throw ArgumentError.value(
          entry.key,
          'steps',
          'Migration starting version must be between 1 and schemaVersion - 1',
        );
      }
    }
  }

  /// Latest schema version that this strategy can open.
  final int schemaVersion;

  /// Upgrade steps keyed by their starting schema version.
  ///
  /// A step at key `n` must migrate schema `n` to `n + 1`. Missing steps are
  /// rejected, so a version bump cannot silently skip migration work.
  final Map<int, DatabaseMigrationStep> steps;

  /// Optional additive SQL needed after Drift creates modeled tables.
  final Future<void> Function(GeneratedDatabase database)? afterCreate;

  /// Called before the first destructive step in an upgrade.
  ///
  /// Applications can use this callback to make a recoverable database copy.
  /// It runs inside Drift's migration transaction, before the step is applied.
  /// A backup failure aborts the migration.
  final Future<void> Function(
    GeneratedDatabase database,
    int fromVersion,
    int toVersion,
  )?
  backupBeforeDestructiveMigration;

  /// Runs after creation or migration and before the database accepts queries.
  /// Use this for connection-level setup such as SQLite PRAGMAs.
  final Future<void> Function(OpeningDetails details)? beforeOpen;

  MigrationStrategy get strategy => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await afterCreate?.call(migrator.database);
    },
    onUpgrade: _upgradeTransactionally,
    beforeOpen: beforeOpen,
  );

  Future<void> _upgrade(Migrator migrator, int from, int to) async {
    if (to != schemaVersion) {
      throw StateError(
        'Migration strategy targets schema $schemaVersion, but Drift requested $to.',
      );
    }
    if (from < 1) {
      // A database with user_version 0 is an empty/unversioned database. It
      // needs the same complete schema creation as a newly created database.
      if (from == 0 && to == 1) {
        await migrator.createAll();
        return;
      }
      throw StateError('Unsupported database schema version: $from.');
    }
    if (from > to) {
      throw StateError(
        'Downgrading database schema from $from to $to is not supported.',
      );
    }

    var currentVersion = from;
    var backupCreated = false;
    while (currentVersion < to) {
      final step = steps[currentVersion];
      if (step == null) {
        throw StateError(
          'No migration is registered from schema $currentVersion to ${currentVersion + 1}.',
        );
      }

      if (step.destructive && !backupCreated) {
        final backup = backupBeforeDestructiveMigration;
        if (backup == null) {
          throw StateError(
            'Migration from schema $currentVersion is destructive, but no '
            'backup hook was provided.',
          );
        }
        await backup(migrator.database, from, to);
        backupCreated = true;
      }

      await step.migrate(migrator);
      currentVersion++;
    }
  }

  Future<void> _upgradeTransactionally(
    Migrator migrator,
    int from,
    int to,
  ) async {
    try {
      await migrator.database.transaction(() => _upgrade(migrator, from, to));
    } catch (_) {
      // Some SQLite opening delegates update user_version before invoking
      // onUpgrade. Restore the prior version after rolling back schema work so
      // a later process can safely retry the same migration.
      try {
        await migrator.database.customStatement('PRAGMA user_version = $from');
      } catch (_) {
        // Keep the original migration error; the database may be unavailable.
      }
      rethrow;
    }
  }
}

/// A single migration from schema version `n` to `n + 1`.
class DatabaseMigrationStep {
  const DatabaseMigrationStep({
    required this.migrate,
    this.destructive = false,
  });

  final Future<void> Function(Migrator migrator) migrate;
  final bool destructive;
}
