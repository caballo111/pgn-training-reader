import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';

void main() {
  test('version 1 rows survive additive version 4 migrations', () async {
    final directory = await Directory.systemTemp.createTemp('pgn-migration-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/library.sqlite');
    final original = AppDatabase(NativeDatabase(file));
    await original.customStatement(
      "INSERT INTO pgn_sources (id, display_name, access_mode, scanner_version, "
      "import_state, created_at_micros, updated_at_micros) "
      "VALUES ('source', 'Library', 'ManagedCopy', 1, 'cancelled', 1, 1)",
    );
    await original.customStatement(
      "INSERT INTO pgn_blocks (id, source_id, start_offset, end_offset, ordinal, "
      "content_type, parse_status) "
      "VALUES ('block', 'source', 0, 20, 0, 'Puzzle', 'NotParsed')",
    );
    await original.customStatement(
      "INSERT INTO import_jobs (id, source_id, status, started_at_micros) "
      "VALUES ('job', 'source', 'cancelled', 1)",
    );
    // Remove only the five additive columns to reconstruct the shipped v1
    // schema, including its unchanged relationships and indexes.
    for (final column in ['inferred_classification', 'authored_content_type']) {
      await original.customStatement(
        'ALTER TABLE pgn_blocks DROP COLUMN $column',
      );
    }
    for (final column in [
      'source_fingerprint',
      'scanner_version',
      'source_size_bytes',
    ]) {
      await original.customStatement(
        'ALTER TABLE import_jobs DROP COLUMN $column',
      );
    }
    await original.customStatement(
      'ALTER TABLE timing_segments DROP COLUMN session_id',
    );
    await original.customStatement('DROP TABLE cycle_item_completions');
    await original.customStatement('PRAGMA user_version = 1');
    await original.close();

    final migrated = AppDatabase(NativeDatabase(file));
    addTearDown(migrated.close);
    final block = await migrated.select(migrated.pgnBlocks).getSingle();
    expect(block.id, 'block');
    expect(block.startOffset, 0);
    expect(block.endOffset, 20);
    expect(block.contentType, 'Puzzle');
    expect(block.inferredClassification, isFalse);
    expect(block.authoredContentType, isNull);
    final job = await migrated.select(migrated.importJobs).getSingle();
    expect(job.id, 'job');
    expect(job.sourceFingerprint, isNull);
    expect(job.scannerVersion, isNull);
    expect(job.sourceSizeBytes, isNull);
    final version = await migrated
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 4);
    final completionTable = await migrated
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'cycle_item_completions'",
        )
        .getSingle();
    expect(completionTable.read<String>('name'), 'cycle_item_completions');
    final timingColumns = await migrated
        .customSelect('PRAGMA table_info(timing_segments)')
        .get();
    expect(
      timingColumns.map((row) => row.read<String>('name')),
      contains('session_id'),
    );
  });

  test(
    'version 2 history survives completion and session attribution migrations',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pgn-v2-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/history.sqlite');
      final original = AppDatabase(NativeDatabase(file));
      await original.customStatement(
        "INSERT INTO pgn_sources (id, display_name, access_mode, scanner_version, import_state, created_at_micros, updated_at_micros) VALUES ('source', 'Library', 'ManagedCopy', 1, 'ready', 1, 1)",
      );
      await original.customStatement(
        "INSERT INTO pgn_blocks (id, source_id, start_offset, end_offset, ordinal, content_type, parse_status) VALUES ('block', 'source', 0, 20, 0, 'Puzzle', 'NotParsed')",
      );
      await original.customStatement(
        "INSERT INTO training_sets (id, name, created_at_micros, updated_at_micros) VALUES ('set', 'Set', 1, 1)",
      );
      await original.customStatement(
        "INSERT INTO cycles (id, training_set_id, status, started_at_micros, created_at_micros) VALUES ('cycle', 'set', 'active', 1, 1)",
      );
      await original.customStatement(
        "INSERT INTO training_sessions (id, cycle_id, status, started_at_micros, study_day_micros) VALUES ('session', 'cycle', 'active', 1, 1)",
      );
      await original.customStatement(
        "INSERT INTO puzzle_attempts (id, block_id, cycle_id, session_id, status, started_at_micros) VALUES ('attempt', 'block', 'cycle', 'session', 'active', 1)",
      );
      await original.customStatement(
        "INSERT INTO timing_segments (id, attempt_id, started_at_micros) VALUES ('segment', 'attempt', 1)",
      );
      await original.customStatement('DROP TABLE cycle_item_completions');
      await original.customStatement(
        'ALTER TABLE timing_segments DROP COLUMN session_id',
      );
      await original.customStatement('PRAGMA user_version = 2');
      await original.close();

      final migrated = AppDatabase(NativeDatabase(file));
      addTearDown(migrated.close);
      expect(
        (await migrated.select(migrated.puzzleAttempts).getSingle()).id,
        'attempt',
      );
      final segment = await migrated
          .select(migrated.timingSegments)
          .getSingle();
      expect(segment.id, 'segment');
      expect(segment.sessionId, isNull);
      final version = await migrated
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 4);
    },
  );
}
