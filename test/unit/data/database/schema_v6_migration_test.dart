import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';

void main() {
  test(
    'legacy categories become Text without losing metadata or completion',
    () async {
      final directory = await Directory.systemTemp.createTemp('pgn-v6-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/library.sqlite');
      final original = AppDatabase(NativeDatabase(file));
      await original.customStatement(
        "INSERT INTO pgn_sources (id, display_name, access_mode, scanner_version, import_state, created_at_micros, updated_at_micros) VALUES ('source', 'Library', 'ManagedCopy', 1, 'ready', 1, 1)",
      );
      await original.customStatement(
        "INSERT INTO training_sets (id, name, created_at_micros, updated_at_micros) VALUES ('set', 'Lessons', 1, 1)",
      );
      await original.customStatement(
        "INSERT INTO cycles (id, training_set_id, status, created_at_micros) VALUES ('cycle', 'set', 'active', 1)",
      );
      for (final (index, type) in [
        'Instruction',
        'Demonstration',
        'Puzzle',
      ].indexed) {
        await original.customStatement(
          'INSERT INTO pgn_blocks (id, source_id, start_offset, end_offset, ordinal, content_type, authored_content_type, parse_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [
            'block-$index',
            'source',
            index * 20,
            index * 20 + 20,
            index,
            type,
            type,
            'NotParsed',
          ],
        );
        await original.customStatement(
          'INSERT INTO training_set_items (id, training_set_id, block_id, position, content_type, added_at_micros) VALUES (?, ?, ?, ?, ?, ?)',
          ['item-$index', 'set', 'block-$index', index, type, 1],
        );
      }
      await original.customStatement(
        "INSERT INTO cycle_item_completions (cycle_id, training_set_item_id, completed_at_micros) VALUES ('cycle', 'item-0', 42)",
      );
      await original.customStatement('PRAGMA user_version = 5');
      await original.close();

      final migrated = AppDatabase(NativeDatabase(file));
      addTearDown(migrated.close);
      final blocks = await migrated.select(migrated.pgnBlocks).get();
      expect(
        {for (final block in blocks) block.id: block.contentType},
        {'block-0': 'Text', 'block-1': 'Text', 'block-2': 'Puzzle'},
      );
      expect(
        {for (final block in blocks) block.id: block.authoredContentType},
        {
          'block-0': 'Instruction',
          'block-1': 'Demonstration',
          'block-2': 'Puzzle',
        },
      );
      final items = await migrated.select(migrated.trainingSetItems).get();
      expect(
        {for (final item in items) item.id: item.contentType},
        {'item-0': 'Text', 'item-1': 'Text', 'item-2': 'Puzzle'},
      );
      final completion = await migrated
          .select(migrated.cycleItemCompletions)
          .getSingle();
      expect(completion.trainingSetItemId, 'item-0');
      expect(completion.completedAtMicros, 42);
    },
  );
}
