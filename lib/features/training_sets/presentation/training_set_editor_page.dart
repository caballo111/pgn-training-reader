import 'package:flutter/material.dart';

import '../../../domain/chess_content/content_type.dart';
import '../../../domain/chess_content/pgn_block_index.dart';
import '../../../domain/library/pgn_index_repository.dart';
import '../../../domain/training/training_set_item.dart';
import '../application/training_set_editor_controller.dart';

/// Editor for an ordered set of indexed Puzzle and Text blocks.
final class TrainingSetEditorPage extends StatefulWidget {
  const TrainingSetEditorPage({
    super.key,
    required this.controller,
    required this.indexRepository,
  });
  final TrainingSetEditorController controller;
  final PgnIndexRepository indexRepository;

  @override
  State<TrainingSetEditorPage> createState() => _TrainingSetEditorPageState();
}

final class _TrainingSetEditorPageState extends State<TrainingSetEditorPage> {
  late final Future<List<PgnBlockIndex>> _candidates = _loadCandidates();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.controller.state.name,
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<List<PgnBlockIndex>> _loadCandidates() async {
    final found = <String, PgnBlockIndex>{};
    for (final type in [ContentType.puzzle, ContentType.text]) {
      var offset = 0;
      while (true) {
        final page = await widget.indexRepository.search(
          filter: PgnIndexFilter(contentType: type),
          offset: offset,
          limit: 100,
        );
        for (final block in page.items) {
          found[block.id] = block;
        }
        if (page.nextOffset == null) break;
        offset = page.nextOffset!;
      }
    }
    return found.values.toList()..sort((a, b) {
      final bySource = a.sourceId.compareTo(b.sourceId);
      return bySource == 0 ? a.ordinal.compareTo(b.ordinal) : bySource;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.controller.state.name.isEmpty
            ? 'New training set'
            : 'Edit training set',
      ),
    ),
    body: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const Key('training-set-name'),
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Set name',
                border: OutlineInputBorder(),
              ),
              onChanged: widget.controller.setName,
            ),
            if (state.validationMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  state.validationMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(state.errorMessage!),
              ),
            const SizedBox(height: 20),
            Text(
              'Ordered items',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (state.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No items added yet.'),
              ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.items.length,
              onReorderItem: widget.controller.reorder,
              itemBuilder: (context, index) {
                final item = state.items[index];
                final scored = item.contentType == ContentType.puzzle;
                return ListTile(
                  key: ValueKey(item.id),
                  title: Text(
                    '${item.contentType.name[0].toUpperCase()}${item.contentType.name.substring(1)}',
                  ),
                  subtitle: Text(scored ? 'Scored puzzle' : 'Not scored'),
                  trailing: IconButton(
                    tooltip: 'Remove item',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => widget.controller.remove(item.id),
                  ),
                );
              },
            ),
            const Divider(height: 32),
            Text(
              'Available library content',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            FutureBuilder<List<PgnBlockIndex>>(
              future: _candidates,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Import PGN files to add content.'),
                  );
                }
                return Column(
                  children: [
                    for (final block in snapshot.data!)
                      _candidateTile(block, state.items),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: state.isSaving
                  ? null
                  : () async {
                      if (await widget.controller.save() && context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    },
              icon: state.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save set'),
            ),
          ],
        );
      },
    ),
  );

  Widget _candidateTile(PgnBlockIndex block, List<TrainingSetItem> items) {
    final alreadyAdded = items.any((item) => item.blockId == block.id);
    final duplicateExerciseId =
        block.diagnosticSummary == 'duplicateExerciseId';
    final label = switch (block.contentType) {
      ContentType.puzzle => 'Puzzle · Scored',
      ContentType.text => 'Text · Not scored',
      ContentType.unsupported => 'Unsupported',
    };
    final event = block.event?.trim();
    final title = (event == null || event.isEmpty)
        ? 'Game ${block.ordinal + 1}'
        : event;
    return ListTile(
      key: ValueKey('candidate-${block.id}'),
      title: Text(title),
      subtitle: Text(
        duplicateExerciseId
            ? '$label · Duplicate exercise ID; blocked until corrected'
            : label,
      ),
      trailing: duplicateExerciseId
          ? const Icon(
              Icons.warning_amber,
              semanticLabel: 'Duplicate exercise ID; cannot add to training',
            )
          : IconButton(
              tooltip: alreadyAdded ? 'Already added' : 'Add item',
              icon: Icon(alreadyAdded ? Icons.check : Icons.add),
              onPressed: alreadyAdded
                  ? null
                  : () => widget.controller.add(block),
            ),
    );
  }
}
