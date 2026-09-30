import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/app/app.dart';
import 'package:pgntrainingreader/app/dependencies.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';

void main() {
  testWidgets('shows the searchable library and empty state', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(
      PgnTrainingReaderApp(
        dependencies: AppDependencies(databaseFactory: () => database),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Search library'), findsOneWidget);
    expect(find.text('No matching PGN content.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
  });
}
