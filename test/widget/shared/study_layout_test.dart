import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/shared/presentation/study_layout.dart';

void main() {
  testWidgets('keeps actions reachable outside long details at phone sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudyLayout(
            header: const Text('Casual practice · Solving'),
            board: const SizedBox.square(
              dimension: 300,
              child: ColoredBox(color: Colors.blue),
            ),
            details: ListView.builder(
              itemCount: 80,
              itemBuilder: (context, index) => Text('Detail $index'),
            ),
            actions: FilledButton(
              onPressed: () {},
              child: const Text('Show solution'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Show solution'), findsOneWidget);
    expect(
      tester.getRect(find.text('Show solution')).bottom,
      lessThanOrEqualTo(640),
    );
    expect(find.text('Detail 79'), findsNothing);
  });

  testWidgets('fits reserved actions in landscape and at large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: StudyLayout(
              header: const Text('Book · Section · Block 8'),
              board: const AspectRatio(
                aspectRatio: 1,
                child: ColoredBox(color: Colors.blue),
              ),
              details: const SingleChildScrollView(child: Text('Notes')),
              actions: FilledButton(
                onPressed: () {},
                child: const Text('Show solution'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Show solution'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
