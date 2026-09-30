import 'package:flutter/material.dart';

import '../../../domain/chess_content/pgn_block_index.dart';
import '../application/library_controller.dart';
import 'library_filter_controls.dart';

/// Searchable, bounded view of indexed PGN blocks.
final class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.controller,
    this.onImport,
    this.onTrainingSets,
    this.onOpen,
  });
  final LibraryController controller;
  final VoidCallback? onImport;
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
          if (widget.onImport != null)
            IconButton(
              tooltip: 'Import PGN',
              onPressed: widget.onImport,
              icon: const Icon(Icons.file_open_outlined),
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
            child: Column(
              children: [
                TextField(
                  key: const Key('library-search'),
                  decoration: const InputDecoration(
                    labelText: 'Search library',
                    prefixIcon: Icon(Icons.search),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: widget.controller.setSearchText,
                ),
                const SizedBox(height: 12),
                LibraryFilterControls(
                  query: state.query,
                  sources: state.sources,
                  onChanged: widget.controller.updateQuery,
                ),
              ],
            ),
          ),
          Expanded(child: _body(state)),
        ],
      ),
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
          trailing: const Icon(Icons.chevron_right),
          onTap: widget.onOpen == null ? null : () => widget.onOpen!(item),
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
        if (widget.onImport != null) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.onImport,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Import PGN'),
          ),
        ],
      ],
    ),
  );

  IconData _icon(String type) => switch (type) {
    'puzzle' => Icons.extension_outlined,
    'instruction' => Icons.school_outlined,
    'demonstration' => Icons.play_lesson_outlined,
    _ => Icons.help_outline,
  };
}
