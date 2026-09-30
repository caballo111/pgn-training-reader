import 'package:flutter/material.dart';

import 'app.dart';
import 'dependencies.dart';
import '../features/import_library/presentation/import_page.dart';
import '../features/training_sets/presentation/training_sets_page.dart';
import '../domain/training/authored_line_puzzle_evaluator.dart';

/// Route names used by the application shell.
abstract final class AppRoutes {
  static const library = '/';
  static const import = '/import';
  static const trainingSets = '/training-sets';
}

/// Builds the initial route and provides a safe fallback for unknown routes.
Route<dynamic> onGenerateAppRoute(
  RouteSettings settings, {
  required AppDependencies dependencies,
}) {
  if (settings.name == AppRoutes.import) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => ImportPage(controller: dependencies.importController),
    );
  }
  if (settings.name == AppRoutes.trainingSets) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => TrainingSetsPage(
        repository: dependencies.trainingSetRepository,
        indexRepository: dependencies.pgnIndexRepository,
        trainingRepository: dependencies.trainingRepository,
        sessionService: dependencies.trainingSessionService,
        contentRepository: dependencies.chessContentRepository,
        evaluatorFactory: () => AuthoredLinePuzzleEvaluator(
          clock: dependencies.clock,
          idGenerator: dependencies.idGenerator,
        ),
        clock: dependencies.clock,
        idGenerator: dependencies.idGenerator,
      ),
    );
  }
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => LibraryPage(dependencies: dependencies),
  );
}
