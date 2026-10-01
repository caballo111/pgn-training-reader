import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('creates every version 7 table', () async {
    final rows = await database
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
        )
        .get();

    expect(
      rows.map((row) => row.read<String>('name')).toSet(),
      equals(<String>{
        'pgn_sources',
        'pgn_blocks',
        'import_jobs',
        'import_diagnostics',
        'training_sets',
        'training_set_items',
        'cycles',
        'training_sessions',
        'puzzle_attempts',
        'attempt_moves',
        'timing_segments',
        'cycle_item_completions',
        'app_settings',
      }),
    );
    final schemaVersion = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(schemaVersion.read<int>('user_version'), 7);
  });

  test('creates every declared query index', () async {
    final rows = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();

    expect(
      rows.map((row) => row.read<String>('name')).toSet(),
      containsAll(<String>{
        'pgn_blocks_source_order',
        'pgn_blocks_exercise_id',
        'pgn_blocks_content_type',
        'pgn_blocks_white',
        'pgn_blocks_black',
        'pgn_blocks_event',
        'pgn_blocks_result',
        'pgn_blocks_current_order',
        'pgn_blocks_authored_identity',
        'pgn_blocks_fallback_identity',
        'pgn_blocks_section',
        'pgn_blocks_theme',
        'pgn_blocks_difficulty',
        'import_jobs_source',
        'import_jobs_status',
        'import_diagnostics_job',
        'training_sets_status',
        'training_set_items_block',
        'training_set_items_order',
        'cycles_one_active_per_set',
        'training_sessions_one_active_per_cycle',
        'puzzle_attempts_one_unfinished_per_item',
        'timing_segments_one_open_per_attempt',
        'cycles_set_status',
        'training_sessions_cycle',
        'puzzle_attempts_cycle',
        'puzzle_attempts_block',
        'puzzle_attempts_session',
        'puzzle_attempts_outcome',
        'attempt_moves_attempt_order',
        'timing_segments_attempt',
      }),
    );

    final expectedColumns = <String, List<String>>{
      'pgn_blocks_source_order': <String>['source_id', 'ordinal'],
      'pgn_blocks_exercise_id': <String>['source_id', 'exercise_id'],
      'pgn_blocks_content_type': <String>['content_type'],
      'pgn_blocks_white': <String>['white'],
      'pgn_blocks_black': <String>['black'],
      'pgn_blocks_event': <String>['event'],
      'pgn_blocks_result': <String>['result'],
      'pgn_blocks_current_order': <String>[
        'source_id',
        'is_current',
        'ordinal',
      ],
      'pgn_blocks_authored_identity': <String>[
        'source_id',
        'authored_exercise_id',
        'is_current',
      ],
      'pgn_blocks_fallback_identity': <String>[
        'source_id',
        'fallback_identity_key',
        'is_current',
      ],
      'pgn_blocks_section': <String>['section'],
      'pgn_blocks_theme': <String>['theme'],
      'pgn_blocks_difficulty': <String>['difficulty'],
      'import_jobs_source': <String>['source_id'],
      'import_jobs_status': <String>['status'],
      'import_diagnostics_job': <String>['import_job_id'],
      'training_sets_status': <String>['status'],
      'training_set_items_block': <String>['block_id'],
      'training_set_items_order': <String>['training_set_id', 'position'],
      'cycles_set_status': <String>['training_set_id', 'status'],
      'training_sessions_one_active_per_cycle': <String>['cycle_id'],
      'puzzle_attempts_one_unfinished_per_item': <String>[
        'cycle_id',
        'block_id',
      ],
      'timing_segments_one_open_per_attempt': <String>['attempt_id'],
      'training_sessions_cycle': <String>['cycle_id', 'started_at_micros'],
      'puzzle_attempts_cycle': <String>['cycle_id', 'started_at_micros'],
      'puzzle_attempts_block': <String>['block_id', 'started_at_micros'],
      'puzzle_attempts_session': <String>['session_id'],
      'puzzle_attempts_outcome': <String>['outcome'],
      'attempt_moves_attempt_order': <String>['attempt_id', 'ordinal'],
      'timing_segments_attempt': <String>['attempt_id', 'started_at_micros'],
    };

    for (final entry in expectedColumns.entries) {
      final indexRows = await database
          .customSelect('PRAGMA index_info("${entry.key}")')
          .get();
      expect(
        indexRows.map((row) => row.read<String>('name')).toList(),
        entry.value,
        reason: '${entry.key} must index the declared columns in order',
      );
    }

    final activeIndex = await database
        .customSelect(
          "SELECT sql FROM sqlite_master "
          "WHERE type = 'index' AND name = 'cycles_one_active_per_set'",
        )
        .getSingle();
    expect(
      activeIndex.read<String>('sql'),
      contains("WHERE status = 'active'"),
    );
  });

  test('enforces source ordinal, set position, and move ordinal uniqueness', () async {
    await database.customStatement(
      "INSERT INTO pgn_sources "
      '(id, display_name, access_mode, scanner_version, import_state, '
      'created_at_micros, updated_at_micros) '
      "VALUES ('source', 'Source', 'managed', 1, 'ready', 1, 1)",
    );
    await database.customStatement(
      "INSERT INTO pgn_blocks "
      '(id, source_id, start_offset, end_offset, ordinal, content_type, '
      'parse_status) VALUES (\'block-1\', \'source\', 0, 10, 0, \'Puzzle\', \'ok\')',
    );
    await expectLater(
      database.customStatement(
        "INSERT INTO pgn_blocks "
        '(id, source_id, start_offset, end_offset, ordinal, content_type, '
        'parse_status) VALUES (\'block-2\', \'source\', 10, 20, 0, \'Puzzle\', \'ok\')',
      ),
      throwsA(isA<Exception>()),
    );

    await database.customStatement(
      "INSERT INTO training_sets "
      '(id, name, created_at_micros, updated_at_micros) '
      "VALUES ('set', 'Set', 1, 1)",
    );
    await database.customStatement(
      "INSERT INTO training_set_items "
      '(id, training_set_id, block_id, position, content_type, added_at_micros) '
      "VALUES ('item-1', 'set', 'block-1', 0, 'Puzzle', 1)",
    );
    await expectLater(
      database.customStatement(
        "INSERT INTO training_set_items "
        '(id, training_set_id, block_id, position, content_type, added_at_micros) '
        "VALUES ('item-2', 'set', 'block-1', 0, 'Puzzle', 1)",
      ),
      throwsA(isA<Exception>()),
    );

    await database.customStatement(
      "INSERT INTO cycles (id, training_set_id, status, created_at_micros) "
      "VALUES ('cycle-1', 'set', 'active', 1)",
    );
    await expectLater(
      database.customStatement(
        "INSERT INTO cycles (id, training_set_id, status, created_at_micros) "
        "VALUES ('cycle-2', 'set', 'active', 2)",
      ),
      throwsA(isA<Exception>()),
    );
    await database.customStatement(
      "INSERT INTO cycles (id, training_set_id, status, created_at_micros) "
      "VALUES ('cycle-2', 'set', 'completed', 2)",
    );

    await database.customStatement(
      "INSERT INTO training_sessions "
      '(id, cycle_id, status, started_at_micros, study_day_micros) '
      "VALUES ('session', 'cycle-1', 'active', 1, 1)",
    );
    await database.customStatement(
      "INSERT INTO puzzle_attempts "
      '(id, block_id, cycle_id, session_id, status, started_at_micros) '
      "VALUES ('attempt', 'block-1', 'cycle-1', 'session', 'active', 1)",
    );
    await database.customStatement(
      "INSERT INTO attempt_moves "
      '(id, attempt_id, ordinal, move, legal, accepted, submitted_at_micros) '
      "VALUES ('move-1', 'attempt', 0, 'e2e4', 1, 1, 1)",
    );
    await expectLater(
      database.customStatement(
        "INSERT INTO attempt_moves "
        '(id, attempt_id, ordinal, move, legal, accepted, submitted_at_micros) '
        "VALUES ('move-2', 'attempt', 0, 'd2d4', 1, 1, 2)",
      ),
      throwsA(isA<Exception>()),
    );
  });
}
