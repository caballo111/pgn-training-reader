import 'dart:async';

import 'package:flutter/material.dart';

import 'dependencies.dart';
import '../core/errors/app_failure.dart';
import '../domain/chess_content/pgn_block_index.dart';
import '../features/browse_library/application/library_controller.dart';
import '../features/browse_library/presentation/library_page.dart';
import '../features/import_library/presentation/import_page.dart';
import '../features/game_reader/presentation/game_reader_page.dart';
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
  final libraryController = LibraryController(
    indexRepository: dependencies.pgnIndexRepository,
    sourceRepository: dependencies.pgnSourceRepository,
  );
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (context) => LibraryPage(
      controller: libraryController,
      onImport: () async {
        await Navigator.of(context).pushNamed(AppRoutes.import);
        if (context.mounted) await libraryController.load();
      },
      onTrainingSets: () =>
          Navigator.of(context).pushNamed(AppRoutes.trainingSets),
      onOpen: (block) => unawaited(_openBlock(context, dependencies, block)),
    ),
  );
}

Future<void> _openBlock(
  BuildContext context,
  AppDependencies dependencies,
  PgnBlockIndex block,
) async {
  try {
    final content = await dependencies.chessContentRepository.getById(block.id);
    if (!context.mounted) return;
    if (content == null) {
      _showOpenFailure(context, 'This library item is no longer available.');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => GameReaderPage(content: content)),
    );
  } on AppFailure catch (failure) {
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ContentFailurePage(
          title: failure is UnsupportedContentFailure
              ? 'Unsupported content'
              : 'Unable to open PGN',
          message: failure.message,
        ),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      _showOpenFailure(
        context,
        'The selected library item could not be opened.',
      );
    }
  }
}

void _showOpenFailure(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

final class _ContentFailurePage extends StatelessWidget {
  const _ContentFailurePage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}
