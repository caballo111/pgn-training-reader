import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/app/study_presentation_store.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';

void main() {
  test(
    'reading cursor and exposure persist without creating training records',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = StudyPresentationStore(db, 'block');
      expect(await store.load(), {'version': 1});
      await store.save({
        'reader': {
          'path': [0, 1],
          'orientation': 'black',
          'scroll': 90.0,
        },
        'exposed': true,
        'sourceRevision': 'revision',
      });
      final saved = await StudyPresentationStore(db, 'block').load();
      expect(saved['reader'], {
        'path': [0, 1],
        'orientation': 'black',
        'scroll': 90.0,
      });
      expect(saved['exposed'], true);
      expect(await StudyPresentationStore(db, 'other').load(), {'version': 1});
      expect(await db.select(db.puzzleAttempts).get(), isEmpty);
      expect(await db.select(db.cycles).get(), isEmpty);
    },
  );

  test(
    'future presentation versions cannot be interpreted as empty history',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        'INSERT INTO app_settings (key, value) VALUES (?, ?)',
        ['study.presentation.block', '{"version":2,"future":"preserve"}'],
      );
      await expectLater(
        StudyPresentationStore(db, 'block').load(),
        throwsFormatException,
      );
      expect(
        (await db
                .customSelect(
                  "SELECT value FROM app_settings WHERE key = 'study.presentation.block'",
                )
                .getSingle())
            .data['value'],
        '{"version":2,"future":"preserve"}',
      );
    },
  );
}
