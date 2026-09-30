import 'package:flutter/material.dart';

import '../../../core/time/app_clock.dart';
import '../../../core/utilities/id_generator.dart';
import '../../../domain/library/pgn_index_repository.dart';
import '../../../domain/training/training_set.dart';
import '../../../domain/training/training_set_repository.dart';
import '../../../domain/chess_content/chess_content_repository.dart';
import '../../../domain/training/training_repository.dart';
import '../../../domain/training/training_session_service.dart';
import '../application/training_set_editor_controller.dart';
import 'training_set_editor_page.dart';
import '../../training_session/application/active_session_controller.dart';
import '../../training_session/presentation/active_session_page.dart';
import '../../puzzle_solver/application/puzzle_solver_controller.dart';

final class TrainingSetsPage extends StatefulWidget {
  const TrainingSetsPage({
    super.key,
    required this.repository,
    required this.indexRepository,
    required this.trainingRepository,
    required this.sessionService,
    required this.contentRepository,
    required this.evaluatorFactory,
    required this.clock,
    required this.idGenerator,
  });
  final TrainingSetRepository repository;
  final PgnIndexRepository indexRepository;
  final TrainingRepository trainingRepository;
  final TrainingSessionService sessionService;
  final ChessContentRepository contentRepository;
  final PuzzleEvaluatorFactory evaluatorFactory;
  final AppClock clock;
  final IdGenerator idGenerator;

  @override
  State<TrainingSetsPage> createState() => _TrainingSetsPageState();
}

final class _TrainingSetsPageState extends State<TrainingSetsPage> {
  late Future<List<TrainingSet>> _sets = widget.repository.listSets();
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

  Future<void> _train(TrainingSet set) async {
    final controller = ActiveSessionController(
      trainingSet: set,
      sessionService: widget.sessionService,
      repository: widget.trainingRepository,
      contentRepository: widget.contentRepository,
      clock: widget.clock,
      evaluatorFactory: widget.evaluatorFactory,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ActiveSessionPage(controller: controller),
      ),
    );
    controller.dispose();
    if (mounted) _reload();
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
                trailing: set.status == TrainingSetStatus.active
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Start or resume cycle',
                            onPressed: () => _train(set),
                            icon: const Icon(Icons.play_arrow),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'edit') _edit(set);
                              if (action == 'archive') _archive(set);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'archive',
                                child: Text('Archive'),
                              ),
                            ],
                          ),
                        ],
                      )
                    : const Text('Archived'),
              ),
          ],
        );
      },
    ),
  );
}
