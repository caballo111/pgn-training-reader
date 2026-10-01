import 'dart:async';

import 'package:flutter/material.dart';

import 'dependencies.dart';
import 'library_puzzle_practice.dart';
import '../core/errors/app_failure.dart';
import '../domain/chess_content/pgn_block_index.dart';
import '../features/browse_library/application/library_controller.dart';
import '../features/browse_library/presentation/library_page.dart';
import '../features/import_library/presentation/import_page.dart';
import '../features/import_library/application/import_controller.dart';
import '../features/game_reader/presentation/game_reader_page.dart';
import '../features/training_sets/presentation/training_sets_page.dart';
import '../domain/training/authored_line_puzzle_evaluator.dart';
import '../domain/training/puzzle_completion_policy.dart';

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
      onRepairSource: (source) => _relinkSource(
        context,
        dependencies,
        libraryController,
        sourceId: source.id,
        sourceName: source.displayName,
      ),
      onReindexSource: (source) => _reindexSource(
        context,
        dependencies,
        libraryController,
        sourceId: source.id,
        sourceName: source.displayName,
      ),
      onTrainingSets: () =>
          Navigator.of(context).pushNamed(AppRoutes.trainingSets),
      onOpen: (block) => unawaited(
        _openBlock(context, dependencies, libraryController, block),
      ),
    ),
  );
}

Future<void> _reindexSource(
  BuildContext context,
  AppDependencies dependencies,
  LibraryController libraryController, {
  required String sourceId,
  required String sourceName,
}) async {
  final completed = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => ImportPage(
        controller: dependencies.importController,
        reindexSourceId: sourceId,
        reindexSourceName: sourceName,
      ),
    ),
  );
  if (!context.mounted) return;
  await libraryController.load();
  if (!context.mounted || completed != true) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Source re-indexed. Existing history is preserved.'),
    ),
  );
}

Future<void> _openBlock(
  BuildContext context,
  AppDependencies dependencies,
  LibraryController libraryController,
  PgnBlockIndex block,
) async {
  try {
    var content = await dependencies.chessContentRepository.getById(block.id);
    if (!context.mounted) return;
    if (content == null) {
      _showOpenFailure(context, 'This library item is no longer available.');
      return;
    }
    var nextBlock = await dependencies.pgnIndexRepository.getNextInSource(
      block,
    );
    var previousBlock = await dependencies.pgnIndexRepository
        .getPreviousInSource(block);
    if (!context.mounted) return;
    var loading = false;
    var startNextPuzzle = false;
    PuzzleCompletionPolicy? nextPuzzlePolicy;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StatefulBuilder(
          builder: (readerContext, setReaderState) {
            Future<void> navigate(
              PgnBlockIndex target, {
              bool startSolving = false,
              PuzzleCompletionPolicy? completionPolicy,
            }) async {
              if (loading) return;
              setReaderState(() => loading = true);
              try {
                final loaded = await dependencies.chessContentRepository
                    .getById(target.id);
                if (loaded == null) {
                  throw const ValidationFailure(
                    code: 'library_item_missing',
                    message: 'This library item is no longer available.',
                  );
                }
                final next = await dependencies.pgnIndexRepository
                    .getNextInSource(target);
                final previous = await dependencies.pgnIndexRepository
                    .getPreviousInSource(target);
                if (!readerContext.mounted) return;
                setReaderState(() {
                  block = target;
                  content = loaded;
                  nextBlock = next;
                  previousBlock = previous;
                  startNextPuzzle = startSolving;
                  nextPuzzlePolicy = completionPolicy;
                });
              } catch (error) {
                if (!readerContext.mounted) return;
                _showOpenFailure(
                  readerContext,
                  error is AppFailure
                      ? error.message
                      : 'The selected library item could not be opened.',
                );
              } finally {
                if (readerContext.mounted) {
                  setReaderState(() => loading = false);
                }
              }
            }

            final currentBlock = block;
            return GameReaderPage(
              key: ValueKey(currentBlock.id),
              content: content!,
              showBlockNavigation: true,
              onPreviousBlock: loading || previousBlock == null
                  ? null
                  : () => unawaited(navigate(previousBlock!)),
              onNextBlock: loading || nextBlock == null
                  ? null
                  : () => unawaited(navigate(nextBlock!)),
              puzzleViewBuilder: (_, puzzle) => LibraryPuzzlePractice(
                dependencies: dependencies,
                blockId: currentBlock.id,
                bookId: currentBlock.sourceId,
                puzzle: puzzle,
                startAutomatically: startNextPuzzle,
                initialCompletionPolicy: nextPuzzlePolicy,
                onNextPuzzle: nextBlock == null
                    ? null
                    : (policy) => navigate(
                        nextBlock!,
                        startSolving: true,
                        completionPolicy: policy,
                      ),
              ),
              onClassificationOverride: currentBlock.authoredContentType == null
                  ? (type) => dependencies.pgnIndexRepository
                        .overrideClassification(currentBlock.id, type)
                  : null,
            );
          },
        ),
      ),
    );
    await libraryController.load();
  } on AppFailure catch (failure) {
    if (!context.mounted) return;
    if (_isMissingSource(failure)) {
      try {
        await libraryController.markSourceMissing(block.sourceId);
      } catch (_) {
        // Keep the repair path available even if status persistence fails.
      }
      if (!context.mounted) return;
      final sourceName = libraryController.state.sources
          .where((source) => source.id == block.sourceId)
          .firstOrNull
          ?.displayName;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (repairContext) => _SourceRepairPage(
            sourceName: sourceName ?? 'This PGN source',
            onRelink: () async {
              final outcome = await _relinkSource(
                repairContext,
                dependencies,
                libraryController,
                sourceId: block.sourceId,
                sourceName: sourceName ?? 'This PGN source',
                showOutcomeMessage: false,
              );
              if (outcome != null && repairContext.mounted) {
                Navigator.of(repairContext).pop();
                if (context.mounted) _showRelinkOutcome(context, outcome);
              }
            },
          ),
        ),
      );
      return;
    }
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

Future<SourceRelinkOutcome?> _relinkSource(
  BuildContext context,
  AppDependencies dependencies,
  LibraryController libraryController, {
  required String sourceId,
  required String sourceName,
  bool showOutcomeMessage = true,
}) async {
  final outcome = await Navigator.of(context).push<SourceRelinkOutcome>(
    MaterialPageRoute<SourceRelinkOutcome>(
      builder: (_) => ImportPage(
        controller: dependencies.importController,
        relinkSourceId: sourceId,
        relinkSourceName: sourceName,
      ),
    ),
  );
  if (!context.mounted) return outcome;
  await libraryController.load();
  if (!context.mounted || outcome == null) return outcome;
  if (showOutcomeMessage) _showRelinkOutcome(context, outcome);
  return outcome;
}

void _showRelinkOutcome(BuildContext context, SourceRelinkOutcome outcome) {
  final message = switch (outcome) {
    SourceRelinkOutcome.sameRevision => 'Source relinked. Existing indexed content and training history are available again.',
    SourceRelinkOutcome.changedRevision => 'The source content differs. Existing blocks remain unavailable until re-indexing completes.',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

bool _isMissingSource(AppFailure failure) =>
    failure is FileFailure &&
    const {
      'managed_source_missing',
      'source_missing',
      'source_relink_required',
    }.contains(failure.code);

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

final class _SourceRepairPage extends StatelessWidget {
  const _SourceRepairPage({required this.sourceName, required this.onRelink});

  final String sourceName;
  final VoidCallback onRelink;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Source unavailable')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$sourceName is missing or no longer accessible.'),
            const SizedBox(height: 8),
            const Text(
              'The index and training history are preserved. Relink the original PGN to restore access, or re-index if its content changed.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRelink,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Relink source'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to library'),
            ),
          ],
        ),
      ),
    ),
  );
}
