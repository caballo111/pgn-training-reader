import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/time/app_clock.dart';
import '../../../core/utilities/id_generator.dart';
import '../../../domain/library/pgn_index_repository.dart';
import '../../../domain/library/pgn_source_repository.dart';
import '../../../domain/training/puzzle_completion_policy.dart';
import '../../../domain/training/training_set.dart';
import '../../../domain/training/lifecycle_status.dart';
import '../../../domain/training/training_set_repository.dart';
import '../../../domain/chess_content/chess_content_repository.dart';
import '../../../domain/analysis/analysis_engine.dart';
import '../../../domain/analysis/exploration_repository.dart';
import '../../../domain/training/training_repository.dart';
import '../../../domain/training/training_session_service.dart';
import '../../../domain/training/training_set_item.dart';
import '../application/training_set_editor_controller.dart';
import 'training_set_editor_page.dart';
import '../../training_session/application/active_session_controller.dart';
import '../../training_session/presentation/active_session_page.dart';
import '../../puzzle_solver/application/puzzle_solver_controller.dart';
import '../../progress_reports/application/progress_report_controller.dart';
import '../../progress_reports/presentation/progress_report_page.dart';

final class TrainingSetsPage extends StatefulWidget {
  const TrainingSetsPage({
    super.key,
    required this.repository,
    required this.indexRepository,
    this.sourceRepository,
    required this.trainingRepository,
    required this.sessionService,
    required this.contentRepository,
    required this.evaluatorFactory,
    required this.clock,
    required this.idGenerator,
    this.explorationRepository,
    this.analysisEngineFactory,
  });
  final TrainingSetRepository repository;
  final PgnIndexRepository indexRepository;
  final PgnSourceRepository? sourceRepository;
  final TrainingRepository trainingRepository;
  final TrainingSessionService sessionService;
  final ChessContentRepository contentRepository;
  final PuzzleEvaluatorFactory evaluatorFactory;
  final AppClock clock;
  final IdGenerator idGenerator;
  final ExplorationRepository? explorationRepository;
  final AnalysisEngineFactory? analysisEngineFactory;

  @override
  State<TrainingSetsPage> createState() => _TrainingSetsPageState();
}

final class _TrainingSetsPageState extends State<TrainingSetsPage> {
  late Future<List<TrainingSet>> _sets = widget.repository.listSets();
  final Set<String> _removing = {};
  void _reload() => setState(() {
    _sets = widget.repository.listSets();
  });

  Future<void> _edit([TrainingSet? set]) async {
    final controller = TrainingSetEditorController(
      repository: widget.repository,
      clock: widget.clock,
      idGenerator: widget.idGenerator,
      set: set,
    );
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TrainingSetEditorPage(
          controller: controller,
          indexRepository: widget.indexRepository,
          sourceRepository: widget.sourceRepository,
        ),
      ),
    );
    controller.dispose();
    if (saved == true && mounted) _reload();
  }

  Future<void> _archive(TrainingSet set) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive training set?'),
        content: Text(
          '“${set.name}” will be kept with its history and removed from active editing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository.archiveSet(
      id: set.id,
      archivedAt: widget.clock.utcNow,
    );
    if (mounted) _reload();
  }

  Future<void> _remove(TrainingSet set) async {
    if (_removing.contains(set.id)) return;
    setState(() => _removing.add(set.id));
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove training set?'),
          content: Text(
            '“${set.name}” will be removed from this list and can no longer be trained. '
            'Your imported content and saved training history will be kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await widget.repository.removeSet(
        id: set.id,
        removedAt: widget.clock.utcNow,
      );
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not remove the training set. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _removing.remove(set.id));
    }
  }

  Future<void> _train(TrainingSet set) async {
    final cycles = await widget.trainingRepository.listCycles(set.id);
    final hasActiveCycle = cycles.any(
      (cycle) => cycle.status == CycleStatus.active,
    );
    final policy = hasActiveCycle
        ? PuzzleCompletionPolicy.allMoves
        : await _chooseCompletionPolicy();
    if (policy == null || !mounted) return;
    final controller = ActiveSessionController(
      trainingSet: set,
      sessionService: widget.sessionService,
      repository: widget.trainingRepository,
      contentRepository: widget.contentRepository,
      clock: widget.clock,
      evaluatorFactory: widget.evaluatorFactory,
      completionPolicy: policy,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ActiveSessionPage(
          controller: controller,
          explorationRepository: widget.explorationRepository,
          analysisEngineFactory: widget.analysisEngineFactory,
          explorationScopeIdResolver: _explorationScopeIdFor,
        ),
      ),
    );
    controller.dispose();
    if (mounted) _reload();
  }

  Future<String?> _explorationScopeIdFor(TrainingSetItem item) async {
    final sources = widget.sourceRepository;
    if (sources == null) return null;
    try {
      final block = await widget.indexRepository.getById(item.blockId);
      if (block == null) return null;
      final source = await sources.getById(block.sourceId);
      final fingerprint = source?.fingerprint;
      if (source == null ||
          source.importState != 'indexed' ||
          fingerprint == null ||
          fingerprint.isEmpty) {
        return null;
      }
      return jsonEncode([block.id, block.sourceId, fingerprint]);
    } catch (_) {
      return null;
    }
  }

  Future<PuzzleCompletionPolicy?> _chooseCompletionPolicy() =>
      showDialog<PuzzleCompletionPolicy>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Choose completion policy'),
          children: [
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, PuzzleCompletionPolicy.keyMoves),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Key Moves'),
                subtitle: Text(
                  'Complete at an authored ✔ marker; use the full line when none exists.',
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, PuzzleCompletionPolicy.allMoves),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('All Moves'),
                subtitle: Text('Complete the full authored continuation.'),
              ),
            ),
          ],
        ),
      );

  Future<void> _report(TrainingSet set) async {
    final controller = ProgressReportController(
      trainingSetId: set.id,
      repository: widget.trainingRepository,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProgressReportPage(
          controller: controller,
          trainingSetName: set.name,
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Training sets')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('New set'),
    ),
    body: FutureBuilder<List<TrainingSet>>(
      future: _sets,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load training sets: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final sets = snapshot.data!;
        if (sets.isEmpty) {
          return const Center(
            child: Text('Create a training set from your imported content.'),
          );
        }
        return ListView(
          children: [
            for (final set in sets)
              ListTile(
                title: Text(set.name),
                subtitle: Text(
                  '${set.items.length} items · ${set.items.where((item) => item.contentType.name == 'puzzle').length} scored',
                ),
                leading: Icon(
                  set.status == TrainingSetStatus.archived
                      ? Icons.archive_outlined
                      : Icons.view_list_outlined,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'View progress report',
                      onPressed: () => _report(set),
                      icon: const Icon(Icons.assessment_outlined),
                    ),
                    if (set.status == TrainingSetStatus.active)
                      IconButton(
                        tooltip: 'Start or resume cycle',
                        onPressed: _removing.contains(set.id)
                            ? null
                            : () => _train(set),
                        icon: const Icon(Icons.play_arrow),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text('Archived'),
                      ),
                    PopupMenuButton<String>(
                      enabled: !_removing.contains(set.id),
                      onSelected: (action) {
                        if (action == 'edit') _edit(set);
                        if (action == 'archive') _archive(set);
                        if (action == 'remove') _remove(set);
                      },
                      itemBuilder: (_) => [
                        if (set.status == TrainingSetStatus.active) ...[
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'archive',
                            child: Text('Archive'),
                          ),
                        ],
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}
