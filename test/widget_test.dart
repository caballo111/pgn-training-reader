import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/app/app.dart';
import 'package:pgntrainingreader/app/dependencies.dart';

void main() {
  testWidgets('shows the library placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(
      PgnTrainingReaderApp(dependencies: AppDependencies()),
    );

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Your PGN library will appear here.'), findsOneWidget);
  });
}
