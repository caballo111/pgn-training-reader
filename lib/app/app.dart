import 'package:flutter/material.dart';

import 'dependencies.dart';
import 'navigation.dart';

/// Root widget for PGN Training Reader.
final class PgnTrainingReaderApp extends StatelessWidget {
  const PgnTrainingReaderApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dependencies.themeController,
      builder: (context, child) => MaterialApp(
        title: 'PGN Training Reader',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: dependencies.themeController.mode,
        initialRoute: AppRoutes.library,
        onGenerateRoute: (settings) =>
            onGenerateAppRoute(settings, dependencies: dependencies),
      ),
    );
  }
}
