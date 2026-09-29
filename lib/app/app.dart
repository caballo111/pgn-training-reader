import 'package:flutter/material.dart';

import 'dependencies.dart';
import 'navigation.dart';

/// Root widget for PGN Training Reader.
final class PgnTrainingReaderApp extends StatelessWidget {
  const PgnTrainingReaderApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PGN Training Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      initialRoute: AppRoutes.library,
      onGenerateRoute: onGenerateAppRoute,
    );
  }
}

/// The initial library destination while import and browsing features are built.
final class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
                semanticLabel: 'Chess library',
              ),
              const SizedBox(height: 16),
              Text(
                'Your PGN library will appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
