import 'package:flutter/material.dart';

import '../../../app/theme_controller.dart';
import '../../../domain/chess_content/pgn_block_index.dart';
import '../../../domain/chess_content/pgn_source.dart';
import '../application/library_controller.dart';
import '../application/library_query.dart';
import 'library_filter_controls.dart';

/// Searchable, bounded view of indexed PGN blocks.
final class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.controller,
    this.themeController,
    this.onImport,
    this.onManageLibrary,
    this.onRepairSource,
    this.onReindexSource,
    this.onTrainingSets,
    this.onOpen,
  });
  final LibraryController controller;
  final ThemeController? themeController;
  final VoidCallback? onImport;
  final VoidCallback? onManageLibrary;
  final ValueChanged<PgnSource>? onRepairSource;
  final ValueChanged<PgnSource>? onReindexSource;
  final VoidCallback? onTrainingSets;
  final ValueChanged<PgnBlockIndex>? onOpen;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

final class _LibraryPageState extends State<LibraryPage> {
  final _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.load();
    _scrollController.addListener(_scroll);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _scroll() {
    if (_scrollController.position.extentAfter < 400 &&
        widget.controller.state.hasMore) {
      widget.controller.loadNextPage();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          if (widget.themeController case final themeController?)
            ListenableBuilder(
              listenable: themeController,
              builder: (context, child) => PopupMenuButton<ThemeMode>(
                key: const Key('library-appearance'),
                tooltip: 'Appearance',
                icon: Icon(switch (themeController.mode) {
                  ThemeMode.dark => Icons.dark_mode_outlined,
                  ThemeMode.light => Icons.light_mode_outlined,
                  ThemeMode.system => Icons.brightness_auto_outlined,
                }),
                onSelected: (mode) async {
                  try {
                    await themeController.setMode(mode);
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not save appearance preference.'),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  for (final (mode, label) in const [
                    (ThemeMode.dark, 'Dark'),
                    (ThemeMode.light, 'Light'),
                    (ThemeMode.system, 'Follow system'),
                  ])
                    CheckedPopupMenuItem(
                      value: mode,
                      checked: themeController.mode == mode,
                      child: Text(label),
                    ),
                ],
              ),
            ),
          if (widget.onManageLibrary != null)
            IconButton(
              tooltip: 'Manage library',
              onPressed: widget.onManageLibrary,
              icon: const Icon(Icons.library_books_outlined),
            ),
          if (widget.onTrainingSets != null)
            IconButton(
              tooltip: 'Training sets',
              onPressed: widget.onTrainingSets,
              icon: const Icon(Icons.view_list_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('library-search'),
                    decoration: InputDecoration(
                      hintText: 'Search library',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: widget.controller.setSearchText,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const Key('library-filters'),
                  tooltip: _filterCount(state.query) == 0
                      ? 'Filters'
                      : 'Filters (${_filterCount(state.query)} active)',
                  onPressed: _showFilters,
                  icon: Badge(
                    isLabelVisible: _filterCount(state.query) > 0,
                    label: Text('${_filterCount(state.query)}'),
                    child: const Icon(Icons.tune),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _body(state)),
        ],
      ),
    );
  }

  int _filterCount(LibraryQuery query) =>
      [
            query.contentType,
            query.section,
            query.theme,
            query.difficulty,
            query.result,
            query.sourceId,
          ]
          .where((value) => value != null && value.toString().trim().isNotEmpty)
          .length;

  Future<void> _showFilters() async {
    FocusScope.of(context).unfocus();
    var draft = widget.controller.state.query;
    final sources = widget.controller.state.sources;
    final result = await showModalBottomSheet<LibraryQuery>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filter library',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setSheetState(() {
                        draft = draft.copyWith(
                          clearContentType: true,
                          clearSection: true,
                          clearTheme: true,
                          clearDifficulty: true,
                          clearResult: true,
                          clearSourceId: true,
                        );
                      }),
                      child: const Text('Clear filters'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                LibraryFilterControls(
                  query: draft,
                  sources: sources,
                  onChanged: (query) => setSheetState(() => draft = query),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, draft),
                    child: const Text('Apply filters'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    // Keep search text current if it changed while the sheet was open.
    widget.controller.updateQuery(
      result.copyWith(searchText: widget.controller.state.query.searchText),
    );
  }

  Widget _body(LibraryState state) => switch (state.status) {
    LibraryLoadStatus.loading when state.items.isEmpty => const Center(
      child: CircularProgressIndicator(semanticsLabel: 'Loading library'),
    ),
    LibraryLoadStatus.failed => _failure(state),
    LibraryLoadStatus.ready when state.items.isEmpty => _empty(),
    _ => ListView.builder(
      controller: _scrollController,
      itemCount: state.items.length + (state.loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading more results',
              ),
            ),
          );
        }
        final item = state.items[index];
        final source = state.sources
            .where((source) => source.id == item.sourceId)
            .firstOrNull;
        final sourceMissing = source?.importState == 'sourceMissing';
        final sourceChanged = source?.importState == 'sourceChanged';
        final duplicateExerciseId =
            item.diagnosticSummary == 'duplicateExerciseId';
        final sourceUnavailable = sourceMissing || sourceChanged;
        final players = [
          item.white,
          item.black,
        ].whereType<String>().where((v) => v.isNotEmpty).join(' — ');
        return ListTile(
          key: ValueKey('library-item-${item.id}'),
          title: Text(
            players.isEmpty ? item.event ?? 'Untitled PGN block' : players,
          ),
          subtitle: Text(
            [
              if (sourceMissing) 'Source missing · indexed history preserved',
              if (sourceChanged) 'Source changed · re-index required',
              if (duplicateExerciseId)
                'Duplicate exercise ID · preserved but blocked',
              item.event,
              item.date,
              item.result,
              item.section,
              item.theme,
              item.difficulty,
            ].whereType<String>().where((v) => v.isNotEmpty).join(' · '),
          ),
          leading: Icon(
            _icon(item.contentType.name),
            semanticLabel: item.contentType.name,
          ),
          trailing: duplicateExerciseId
              ? widget.onImport == null
                    ? const Icon(
                        Icons.warning_amber,
                        semanticLabel: 'Duplicate exercise ID; item blocked',
                      )
                    : TextButton(
                        onPressed: widget.onImport,
                        child: const Text('Import corrected PGN'),
                      )
              : sourceMissing
              ? widget.onRepairSource == null
                    ? const Icon(
                        Icons.warning_amber,
                        semanticLabel: 'Source missing',
                      )
                    : TextButton(
                        onPressed: () => widget.onRepairSource!(source!),
                        child: const Text('Relink'),
                      )
              : sourceChanged
              ? widget.onReindexSource == null
                    ? const Icon(
                        Icons.warning_amber,
                        semanticLabel: 'Source changed; re-index required',
                      )
                    : TextButton(
                        onPressed: () => widget.onReindexSource!(source!),
                        child: const Text('Re-index'),
                      )
              : const Icon(Icons.chevron_right),
          onTap:
              sourceUnavailable || duplicateExerciseId || widget.onOpen == null
              ? null
              : () => widget.onOpen!(item),
        );
      },
    ),
  };

  Widget _failure(LibraryState state) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(state.errorMessage ?? 'Could not load the library.'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: widget.controller.refresh,
          child: const Text('Retry'),
        ),
      ],
    ),
  );

  Widget _empty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.menu_book_outlined, size: 48),
        const SizedBox(height: 12),
        const Text('No matching PGN content.'),
        if (widget.onManageLibrary != null) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.onManageLibrary,
            icon: const Icon(Icons.library_books_outlined),
            label: const Text('Manage library'),
          ),
        ],
      ],
    ),
  );

  IconData _icon(String type) => switch (type) {
    'puzzle' => Icons.extension_outlined,
    'text' => Icons.menu_book_outlined,
    _ => Icons.help_outline,
  };
}
