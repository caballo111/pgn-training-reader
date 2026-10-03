import 'dart:convert';

import 'package:drift/drift.dart' show Variable;

import '../data/database/app_database.dart';

/// Local reading cursor and answer exposure, independent of scored attempts.
final class StudyPresentationStore {
  StudyPresentationStore(this.database, this.blockId);

  final AppDatabase database;
  final String blockId;

  String get _key => 'study.presentation.$blockId';

  Future<Map<String, dynamic>> load() async {
    final rows = await database
        .customSelect(
          'SELECT value FROM app_settings WHERE key = ?',
          variables: [Variable<String>(_key)],
        )
        .get();
    if (rows.isEmpty) return {'version': 1};
    final data = Map<String, dynamic>.from(
      jsonDecode(rows.single.data['value'] as String) as Map,
    );
    if (data['version'] != 1) {
      throw const FormatException('Unsupported study presentation version.');
    }
    return data;
  }

  Future<void> save(Map<String, dynamic> value) => database.customStatement(
    'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)',
    [
      _key,
      jsonEncode({...value, 'version': 1}),
    ],
  );
}
