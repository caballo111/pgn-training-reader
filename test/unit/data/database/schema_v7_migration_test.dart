import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';

void main() {
  test(
    'v6 database without app_settings keeps history and installs settings',
    () async {
      final directory = await Directory.systemTemp.createTemp('pgn-v7-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/library.sqlite');

      final current = AppDatabase(NativeDatabase(file));
      await current.customStatement(
        "INSERT INTO pgn_sources (id, display_name, access_mode, scanner_version, import_state, created_at_micros, updated_at_micros) VALUES ('source', 'Library', 'managedCopy', 1, 'ready', 1, 1)",
      );
      await current.customStatement(
        "INSERT INTO pgn_blocks (id, source_id, start_offset, end_offset, ordinal, content_type, parse_status) VALUES ('block', 'source', 0, 10, 0, 'Puzzle', 'notParsed')",
      );
      await current.customStatement(
        "INSERT INTO training_sets (id, name, created_at_micros, updated_at_micros) VALUES ('set', 'Lessons', 1, 1)",
      );
      await current.customStatement(
        "INSERT INTO cycles (id, training_set_id, status, started_at_micros, created_at_micros) VALUES ('cycle', 'set', 'active', 1, 1)",
      );
      await current.customStatement(
        "INSERT INTO training_sessions (id, cycle_id, status, started_at_micros, study_day_micros) VALUES ('session', 'cycle', 'active', 1, 1)",
      );
      await current.customStatement(
        "INSERT INTO puzzle_attempts (id, block_id, cycle_id, session_id, status, outcome, started_at_micros, completed_at_micros, active_milliseconds) VALUES ('old-attempt', 'block', 'cycle', 'session', 'finalized', 'Passed', 1, 2, 1)",
      );
      await current.customStatement('DROP TABLE app_settings');
      await current.customStatement('PRAGMA user_version = 6');
      await current.close();

      final migrated = AppDatabase(NativeDatabase(file));
      addTearDown(migrated.close);
      final oldAttempt = await migrated
          .select(migrated.puzzleAttempts)
          .getSingle();
      expect(oldAttempt.id, 'old-attempt');
      expect(oldAttempt.outcome, 'Passed');
      expect(oldAttempt.completedAtMicros, 2);

      final settings = await migrated
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'app_settings'",
          )
          .get();
      expect(settings, hasLength(1));
      await migrated.customStatement(
        "INSERT INTO app_settings (key, value) VALUES ('migration-check', 'ready')",
      );
    },
  );
}
