import 'dart:async';

import 'package:flutter/material.dart';

import 'dependencies.dart';
import 'library_puzzle_practice.dart';
import 'study_presentation_store.dart';
import '../core/errors/app_failure.dart';
import '../domain/chess_content/pgn_block_index.dart';
import '../domain/chess_content/content_type.dart';
import '../features/browse_library/application/library_controller.dart';
import '../features/browse_library/presentation/library_page.dart';
import '../features/browse_library/presentation/manage_library_page.dart';
import '../features/import_library/presentation/import_page.dart';
import '../features/import_library/application/import_controller.dart';
import '../features/game_reader/presentation/game_reader_page.dart';
import '../features/training_sets/presentation/training_sets_page.dart';
import '../domain/training/authored_line_puzzle_evaluator.dart';

/// Route names used by the application shell.
abstract final class AppRoutes {
  static const library = '/';
  static const import = '/import';
  static const manageLibrary = '/manage-library';
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
  if (settings.name == AppRoutes.manageLibrary) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (routeContext) => ManageLibraryPage(
        sourceRepository: dependencies.pgnSourceRepository,
        onAddBook: () async {
          await Navigator.of(routeContext).pushNamed(AppRoutes.import);
        },
        removeBook: dependencies.libraryLifecycleService.removeBook,
        pendingCleanupSourceIds:
            dependencies.libraryLifecycleService.pendingCleanupSourceIds,
        retryCleanup: dependencies.libraryLifecycleService.retryCleanup,
      ),
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
      themeController: dependencies.themeController,
      onImport: () => Navigator.of(context).pushNamed(AppRoutes.import),
      onManageLibrary: () async {
        await Navigator.of(context).pushNamed(AppRoutes.manageLibrary);
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
    String? revisionFor(String sourceId) => libraryController.state.sources
        .where((source) => source.id == sourceId)
        .firstOrNull
        ?.fingerprint;
    var readingPresentation = await StudyPresentationStore(
      dependencies.database,
      block.id,
    ).load();
    if (readingPresentation['sourceRevision'] != revisionFor(block.sourceId)) {
      readingPresentation = {
        'version': 1,
        'sourceRevision': revisionFor(block.sourceId),
      };
    }
    if (!context.mounted) return;
    var loading = false;
    String? openingFailure;
    var practiceKey = GlobalKey<LibraryPuzzlePracticeState>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StatefulBuilder(
          builder: (readerContext, setReaderState) {
            Future<void> navigate(PgnBlockIndex target) async {
              if (loading) return;
              setReaderState(() => loading = true);
              try {
                await practiceKey.currentState?.prepareToLeave();
                var loaded = content;
                String? failure;
                try {
                  loaded = await dependencies.chessContentRepository.getById(
                    target.id,
                  );
                  if (loaded == null) {
                    failure = 'This library item is no longer available.';
                  }
                } on AppFailure catch (error) {
                  failure = error.message;
                }
                if (failure != null) loaded = content;
                final next = await dependencies.pgnIndexRepository
                    .getNextInSource(target);
                final previous = await dependencies.pgnIndexRepository
                    .getPreviousInSource(target);
                var readerSettings = await StudyPresentationStore(
                  dependencies.database,
                  target.id,
                ).load();
                if (readerSettings['sourceRevision'] !=
                    revisionFor(target.sourceId)) {
                  readerSettings = {
                    'version': 1,
                    'sourceRevision': revisionFor(target.sourceId),
                  };
                }
                if (!readerContext.mounted) return;
                setReaderState(() {
                  block = target;
                  readingPresentation = readerSettings;
                  content = loaded;
                  openingFailure = failure;
                  nextBlock = next;
                  previousBlock = previous;
                  practiceKey = GlobalKey<LibraryPuzzlePracticeState>();
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
              unavailableMessage: openingFailure,
              initialReaderState: readingPresentation['reader'] is Map
                  ? Map<String, dynamic>.from(
                      readingPresentation['reader'] as Map,
                    )
                  : null,
              onSaveReaderState: (value) async {
                final snapshot = {...readingPresentation, 'reader': value};
                await StudyPresentationStore(
                  dependencies.database,
                  currentBlock.id,
                ).save(snapshot);
                readingPresentation = snapshot;
              },
              onRetryContent: openingFailure == null
                  ? null
                  : () => unawaited(navigate(currentBlock)),
              bookName:
                  libraryController.state.sources
                      .where((source) => source.id == currentBlock.sourceId)
                      .firstOrNull
                      ?.displayName ??
                  'Book',
              section: currentBlock.section,
              blockNumber: currentBlock.ordinal + 1,
              showBlockNavigation: true,
              onBookSettings: openingFailure == null
                  ? () => unawaited(
                      practiceKey.currentState?.openBookSettings() ??
                          Future<void>.value(),
                    )
                  : null,
              onPreviousBlock: loading || previousBlock == null
                  ? null
                  : () => unawaited(navigate(previousBlock!)),
              onNextBlock: loading || nextBlock == null
                  ? null
                  : () => unawaited(navigate(nextBlock!)),
              puzzleViewBuilder: (_, puzzle, onModeChanged) =>
                  LibraryPuzzlePractice(
                    key: practiceKey,
                    dependencies: dependencies,
                    blockId: currentBlock.id,
                    bookId: currentBlock.sourceId,
                    sourceRevision: libraryController.state.sources
                        .where((source) => source.id == currentBlock.sourceId)
                        .firstOrNull
                        ?.fingerprint,
                    showSettingsButton: false,
                    showModeInBody: false,
                    onModeChanged: onModeChanged,
                    puzzle: puzzle,
                    onPreviousBlock: previousBlock == null
                        ? null
                        : () => navigate(previousBlock!),
                    onNextPuzzle: nextBlock == null
                        ? null
                        : (_) => navigate(nextBlock!),
                  ),
              onClassificationOverride:
                  openingFailure == null &&
                      currentBlock.authoredContentType == null
                  ? (type) async {
                      if (type == ContentType.text) {
                        await practiceKey.currentState?.prepareForReading();
                      } else {
                        await practiceKey.currentState?.prepareToLeave();
                      }
                      final store = StudyPresentationStore(
                        dependencies.database,
                        currentBlock.id,
                      );
                      var presentation = await store.load();
                      if (type == ContentType.puzzle &&
                          practiceKey.currentState == null) {
                        presentation = {...presentation, 'exposed': true};
                        await store.save(presentation);
                      }
                      await dependencies.pgnIndexRepository
                          .overrideClassification(currentBlock.id, type);
                      if (readerContext.mounted) {
                        setReaderState(() {
                          readingPresentation = presentation;
                        });
                      }
                    }
                  : null,
            );
          },
        ),
      ),
    );
    if (!context.mounted) return;
    await libraryController.refresh(preserveLoadedPages: true);
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
