import 'package:flutter/material.dart';

import '../../../domain/chess_content/content_type.dart';
import '../../../domain/chess_content/pgn_block_index.dart';
import '../../../domain/library/pgn_index_repository.dart';
import '../../../domain/library/pgn_source_repository.dart';
import '../application/training_set_editor_controller.dart';

String? _meaningfulMetadata(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty || cleaned == '?' ? null : cleaned;
}

final RegExp _exerciseHeaderPattern = RegExp(
  r'^\s*(?:Exercise|Puzzle|Problem)\s+(\d+)\b',
  caseSensitive: false,
);

/// Exercise number shown/used by the builder, recovered from generic PGN metadata.
int? trainingBlockNumber(PgnBlockIndex block) {
  if (block.sequence != null) return block.sequence;
  final id = _meaningfulMetadata(block.exerciseId);
  if (id != null && !id.toLowerCase().startsWith('generated-')) {
    final authoredNumber = int.tryParse(id);
    if (authoredNumber != null) return authoredNumber;
  }
  for (final header in [block.black, block.white]) {
    final match = _exerciseHeaderPattern.firstMatch(header ?? '');
    final number = int.tryParse(match?.group(1) ?? '');
    if (number != null) return number;
  }
  return null;
}

/// Section metadata, including the common export convention of a heading in
/// White and an exercise label in Black.
String? trainingBlockSection(PgnBlockIndex block) {
  final explicit = _meaningfulMetadata(block.section);
  if (explicit != null) return explicit;
  if (_exerciseHeaderPattern.hasMatch(block.black ?? '')) {
    return _meaningfulMetadata(block.white);
  }
  return null;
}

String trainingBlockTitle(PgnBlockIndex block) {
  final number = trainingBlockNumber(block);
  final section = trainingBlockSection(block);
  final identityTitle = [
    if (number != null) 'Exercise $number',
    ?section,
  ].join(' · ');
  if (identityTitle.isNotEmpty) return identityTitle;
  final event = _meaningfulMetadata(block.event);
  if (event != null) return event;
  final players = [
    _meaningfulMetadata(block.white),
    _meaningfulMetadata(block.black),
  ].whereType<String>().toList();
  if (players.isNotEmpty) return players.join(' — ');
  return 'Game ${block.ordinal + 1}';
}

/// Editor for an ordered set of indexed Puzzle and Text blocks.
final class TrainingSetEditorPage extends StatefulWidget {
  const TrainingSetEditorPage({
    super.key,
    required this.controller,
    required this.indexRepository,
    this.sourceRepository,
  });
  final TrainingSetEditorController controller;
  final PgnIndexRepository indexRepository;
  final PgnSourceRepository? sourceRepository;
  @override
  State<TrainingSetEditorPage> createState() => _TrainingSetEditorPageState();
}

final class _TrainingSetEditorPageState extends State<TrainingSetEditorPage> {
  late Future<List<PgnBlockIndex>> _candidates = _loadCandidates();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.controller.state.name,
  );
  late final TextEditingController _rangeStart = TextEditingController();
  late final TextEditingController _rangeEnd = TextEditingController();
  late final TextEditingController _searchController = TextEditingController();
  String? _book, _section, _difficulty;
  Map<String, String> _sourceNames = const {};
  Map<String, String> _sourceStates = const {};
  bool _sourceMetadataLoaded = false;
  bool _includeText = false;
  @override
  void initState() {
    super.initState();
    _loadSourceNames();
  }

  Future<void> _loadSourceNames() async {
    final repository = widget.sourceRepository;
    if (repository == null) return;
    try {
      final sources = await repository.list();
      if (mounted) {
        setState(() {
          _sourceNames = {
            for (final source in sources) source.id: source.displayName,
          };
          _sourceStates = {
            for (final source in sources) source.id: source.importState,
          };
          _sourceMetadataLoaded = true;
        });
      }
    } catch (_) {
      // Keep source IDs as labels when source metadata cannot be loaded.
    }
  }

  String _bookLabel(String id) => _sourceNames[id] ?? id;

  bool _sourceUnavailable(PgnBlockIndex block) {
    if (widget.sourceRepository == null || !_sourceMetadataLoaded) return false;
    return _sourceStates[block.sourceId] != 'indexed';
  }

  bool _blockUnavailable(PgnBlockIndex block) =>
      block.contentType == ContentType.unsupported ||
      block.parseStatus == PgnBlockParseStatus.malformed ||
      block.parseStatus == PgnBlockParseStatus.unsupported ||
      block.diagnosticSummary == 'duplicateExerciseId' ||
      _sourceUnavailable(block);
  @override
  void dispose() {
    _nameController.dispose();
    _rangeStart.dispose();
    _rangeEnd.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<PgnBlockIndex>> _loadCandidates() async {
    final found = <String, PgnBlockIndex>{};
    // Page all indexed matches so builders never depend on the library viewport.
    var offset = 0;
    while (true) {
      final page = await widget.indexRepository.search(
        filter: const PgnIndexFilter(),
        offset: offset,
        limit: 1000,
      );
      if (!mounted) return const [];
      for (final block in page.items) {
        found[block.id] = block;
      }
      if (page.nextOffset == null) break;
      offset = page.nextOffset!;
    }
    _cachedBlocks.addAll(found);
    return found.values.toList()..sort((a, b) {
      final s = a.sourceId.compareTo(b.sourceId);
      return s == 0 ? a.ordinal.compareTo(b.ordinal) : s;
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
    bottomNavigationBar: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              key: const Key('training-set-save'),
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
              label: Text(state.isSaving ? 'Saving…' : 'Save set'),
            ),
          ),
        );
      },
    ),
    body: FutureBuilder<List<PgnBlockIndex>>(
      future: _candidates,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <PgnBlockIndex>[];
        final books = all.map((b) => b.sourceId).toSet().toList()..sort();
        final sections =
            all
                .where((b) => _book == null || b.sourceId == _book)
                .map(trainingBlockSection)
                .whereType<String>()
                .toSet()
                .toList()
              ..sort();
        final difficulties =
            all
                .where((b) => _book == null || b.sourceId == _book)
                .map((b) => _meaningfulMetadata(b.difficulty))
                .whereType<String>()
                .toSet()
                .toList()
              ..sort();
        final filtered = all
            .where(
              (b) =>
                  (_book == null || b.sourceId == _book) &&
                  (_section == null || trainingBlockSection(b) == _section) &&
                  (_difficulty == null ||
                      _meaningfulMetadata(b.difficulty) == _difficulty) &&
                  (b.contentType == ContentType.puzzle ||
                      b.contentType == ContentType.unsupported ||
                      _includeText) &&
                  (_searchController.text.trim().isEmpty ||
                      trainingBlockTitle(b).toLowerCase().contains(
                        _searchController.text.trim().toLowerCase(),
                      ) ||
                      _bookLabel(b.sourceId).toLowerCase().contains(
                        _searchController.text.trim().toLowerCase(),
                      )),
            )
            .toList();
        final numbers =
            filtered.map(trainingBlockNumber).whereType<int>().toSet().toList()
              ..sort();
        final gaps = <String>[];
        for (var i = 1; i < numbers.length; i++) {
          if (numbers[i] > numbers[i - 1] + 1) {
            gaps.add('${numbers[i - 1] + 1}–${numbers[i] - 1}');
          }
        }
        final missing = filtered.any((b) => trainingBlockNumber(b) == null);
        final numberingSummary =
            'Source order${missing ? ' · some exercise numbers are missing' : ''}${gaps.isEmpty ? '' : ' · gaps: ${gaps.join(', ')}'}';
        Widget choice(
          String label,
          String? value,
          List<String> values,
          ValueChanged<String?> set, {
          String Function(String)? labelForValue,
        }) => DropdownButtonFormField<String?>(
          key: ValueKey<String>('training-set-filter-$label-${value ?? 'all'}'),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: <DropdownMenuItem<String?>>[
            DropdownMenuItem<String?>(
              value: null,
              child: Text('All $label'.toLowerCase()),
            ),
            for (final v in values)
              DropdownMenuItem<String?>(
                value: v,
                child: Text(
                  labelForValue?.call(v) ?? v,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: set,
        );
        void bulk(Iterable<PgnBlockIndex> blocks) {
          final batch = blocks.toList();
          final unavailableBlockIds = batch
              .where(_sourceUnavailable)
              .map((block) => block.id)
              .toSet();
          final report = widget.controller.addMany(
            batch,
            unavailableBlockIds: unavailableBlockIds,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added ${report['added']}; ${report['duplicates']} already selected; ${report['malformed']} malformed; ${report['unsupported']} unsupported; ${report['unavailable']} unavailable',
              ),
            ),
          );
        }

        // Filtering changes only with library metadata and filter input, not
        // each name edit or selection change. Rows are built by the viewport.
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final state = widget.controller.state;
            final selectedIds = state.items.map((item) => item.blockId).toSet();
            return CustomScrollView(
              key: const Key('training-set-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.list(
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
                            key: const Key('builder-report'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (state.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(state.errorMessage!),
                        ),
                      const Divider(height: 32),
                      Text(
                        'Build selection',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (snapshot.hasError)
                        Column(
                          children: [
                            const Text('Could not load library content.'),
                            TextButton(
                              onPressed: () => setState(
                                () => _candidates = _loadCandidates(),
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        )
                      else if (!snapshot.hasData)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        choice(
                          'Book',
                          _book,
                          books,
                          (v) => setState(() {
                            _book = v;
                            _section = null;
                            _difficulty = null;
                          }),
                          labelForValue: _bookLabel,
                        ),
                        choice(
                          'Section',
                          _section,
                          sections,
                          (v) => setState(() => _section = v),
                        ),
                        choice(
                          'Difficulty',
                          _difficulty,
                          difficulties,
                          (v) => setState(() => _difficulty = v),
                        ),
                        SwitchListTile(
                          title: const Text('Include text blocks'),
                          value: _includeText,
                          onChanged: (v) => setState(() => _includeText = v),
                        ),
                        TextField(
                          key: const Key('training-set-search'),
                          controller: _searchController,
                          decoration: const InputDecoration(
                            labelText: 'Search matching results',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${filtered.length} matching results · current filters: ${_book == null ? 'all books' : _bookLabel(_book!)}; ${_section ?? 'all sections'}; ${_difficulty ?? 'all difficulties'}; ${_includeText ? 'puzzles and text' : 'puzzles'}${_searchController.text.trim().isEmpty ? '' : '; search “${_searchController.text.trim()}”'}',
                          key: const Key('training-set-result-summary'),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => bulk(filtered),
                              key: const Key('training-set-select-all'),
                              child: Text(
                                'Select all ${filtered.length} matching results',
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                final puzzles = filtered
                                    .where(
                                      (b) =>
                                          b.contentType == ContentType.puzzle,
                                    )
                                    .toList();
                                bulk(puzzles.take((puzzles.length + 1) ~/ 2));
                              },
                              child: const Text('First half'),
                            ),
                            TextButton(
                              onPressed: () {
                                final puzzles = filtered
                                    .where(
                                      (b) =>
                                          b.contentType == ContentType.puzzle,
                                    )
                                    .toList();
                                bulk(puzzles.skip((puzzles.length + 1) ~/ 2));
                              },
                              child: const Text('Second half'),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _rangeStart,
                                key: const Key('training-set-range-start'),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Exercise from',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _rangeEnd,
                                key: const Key('training-set-range-end'),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'to',
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Add exercise range',
                              icon: const Icon(Icons.playlist_add),
                              onPressed: () {
                                final a = int.tryParse(_rangeStart.text),
                                    z = int.tryParse(_rangeEnd.text);
                                if (a == null || z == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Enter a valid exercise range',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final range = filtered.where((b) {
                                  final n = trainingBlockNumber(b);
                                  return n != null && n >= a && n <= z;
                                }).toList();
                                bulk(range);
                              },
                            ),
                          ],
                        ),
                        Text(numberingSummary),
                        if (filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('No matching entries.'),
                          ),
                      ],
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _candidateTile(filtered[index], selectedIds),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.list(
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        'Preview · ${state.items.where((i) => i.contentType == ContentType.puzzle).length} puzzles · ${state.items.where((i) => i.contentType == ContentType.text).length} text',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (state.items.isEmpty)
                        const Text('No items added yet.'),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverReorderableList(
                    itemCount: state.items.length,
                    onReorderItem: widget.controller.reorder,
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      final block = _cachedBlocks[item.blockId];
                      return Material(
                        key: ValueKey(item.id),
                        child: ListTile(
                          title: Text(
                            block == null
                                ? 'Selected item'
                                : trainingBlockTitle(block),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.contentType == ContentType.puzzle
                                    ? 'Scored puzzle'
                                    : 'Not scored',
                              ),
                              if (block != null)
                                Text(_bookLabel(block.sourceId)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Remove item',
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () =>
                                    widget.controller.remove(item.id),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
  );

  final Map<String, PgnBlockIndex> _cachedBlocks = {};
  Widget _candidateTile(PgnBlockIndex block, Set<String> selectedIds) {
    final added = selectedIds.contains(block.id);
    final duplicate = block.diagnosticSummary == 'duplicateExerciseId';
    final unavailable = _blockUnavailable(block);
    final label = switch (block.parseStatus) {
      PgnBlockParseStatus.malformed => 'Malformed · Unavailable',
      PgnBlockParseStatus.unsupported => 'Unsupported · Unavailable',
      PgnBlockParseStatus.notParsed || PgnBlockParseStatus.valid
          when _sourceUnavailable(block) =>
        'Source unavailable',
      PgnBlockParseStatus.notParsed ||
      PgnBlockParseStatus.valid => switch (block.contentType) {
        ContentType.puzzle => 'Puzzle · Scored',
        ContentType.text => 'Text · Not scored',
        ContentType.unsupported => 'Unsupported · Unavailable',
      },
    };
    final unavailableReason = duplicate
        ? 'Duplicate exercise ID; blocked until corrected'
        : block.parseStatus == PgnBlockParseStatus.malformed
        ? 'Malformed content'
        : block.parseStatus == PgnBlockParseStatus.unsupported ||
              block.contentType == ContentType.unsupported
        ? 'Unsupported content'
        : _sourceUnavailable(block)
        ? 'Source unavailable'
        : '';
    return ListTile(
      key: ValueKey('candidate-${block.id}'),
      title: Text(trainingBlockTitle(block)),
      subtitle: Text(
        '$label · ${_bookLabel(block.sourceId)}${unavailableReason.isEmpty ? '' : ' · $unavailableReason'}',
      ),
      trailing: unavailable
          ? const Icon(
              Icons.warning_amber,
              semanticLabel: 'Unavailable; cannot add to training',
            )
          : IconButton(
              tooltip: added ? 'Already added' : 'Add item',
              icon: Icon(added ? Icons.check : Icons.add),
              onPressed: added ? null : () => widget.controller.add(block),
            ),
    );
  }
}
