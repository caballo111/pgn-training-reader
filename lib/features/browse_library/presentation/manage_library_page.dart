import 'package:flutter/material.dart';

import '../../../domain/chess_content/pgn_source.dart';
import '../../../domain/library/library_lifecycle_service.dart';
import '../../../domain/library/pgn_source_repository.dart';

/// Lists the user's books and routes add/remove actions to their owners.
final class ManageLibraryPage extends StatefulWidget {
  const ManageLibraryPage({
    super.key,
    required this.sourceRepository,
    required this.onAddBook,
    required this.removeBook,
    required this.pendingCleanupSourceIds,
    required this.retryCleanup,
  });

  final PgnSourceRepository sourceRepository;
  final Future<void> Function() onAddBook;
  final Future<LibraryRemovalResult> Function(String sourceId) removeBook;
  final Future<List<String>> Function() pendingCleanupSourceIds;
  final Future<LibraryRemovalResult> Function(String sourceId) retryCleanup;

  @override
  State<ManageLibraryPage> createState() => _ManageLibraryPageState();
}

final class _ManageLibraryPageState extends State<ManageLibraryPage> {
  List<PgnSource> _sources = const [];
  List<PgnSource> _pendingCleanup = const [];
  bool _loading = true;
  bool _adding = false;
  String? _loadingError;
  final Set<String> _removing = {};
  final Set<String> _confirming = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadingError = null;
    });
    try {
      final sources = await widget.sourceRepository.list();
      final pendingIds = await widget.pendingCleanupSourceIds();
      final pending = await Future.wait(
        pendingIds.map(widget.sourceRepository.getById),
      );
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _pendingCleanup = pending.whereType<PgnSource>().toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingError = 'Could not load your books.';
      });
    }
  }

  Future<void> _addBook() async {
    setState(() => _adding = true);
    try {
      await widget.onAddBook();
      if (mounted) await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The add book flow could not be opened.')),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _confirmRemove(PgnSource source) async {
    if (_loading || _adding || _removing.isNotEmpty || _confirming.isNotEmpty) {
      return;
    }
    if (!_confirming.add(source.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove book from library?'),
        content: Text(
          '“${source.displayName}” will leave your active library. Its app copy '
          'will be deleted when available. Saved training history will be '
          'retained; the removed book content will no longer be available. '
          'External PGN files are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-remove-book'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove from library'),
          ),
        ],
      ),
    );
    _confirming.remove(source.id);
    if (!mounted) return;
    if (confirmed == true) await _remove(source);
  }

  Future<void> _remove(PgnSource source) async {
    if (_removing.isNotEmpty || _adding) return;
    setState(() => _removing.add(source.id));
    try {
      final result = await widget.removeBook(source.id);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      if (result.status == LibraryRemovalStatus.cleanupFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            action: SnackBarAction(
              label: 'Retry cleanup',
              onPressed: () => _retryCleanup(source.id),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book removed from your library.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not remove this book. Finish any active import, then retry.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _removing.remove(source.id));
    }
  }

  Future<void> _retryCleanup(String sourceId) async {
    if (_removing.isNotEmpty || _adding) return;
    setState(() => _removing.add(sourceId));
    try {
      final result = await widget.retryCleanup(sourceId);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cleanup could not be retried. Try again later.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _removing.remove(sourceId));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Manage library')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('add-book'),
              onPressed:
                  _loading ||
                      _adding ||
                      _removing.isNotEmpty ||
                      _confirming.isNotEmpty
                  ? null
                  : _addBook,
              icon: _adding
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Add book'),
            ),
          ),
        ),
        Expanded(child: _content()),
      ],
    ),
  );

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadingError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadingError!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_sources.isEmpty && _pendingCleanup.isEmpty) {
      return const Center(child: Text('No books in your library yet.'));
    }
    return ListView.builder(
      itemCount: _sources.length + _pendingCleanup.length,
      itemBuilder: (context, index) {
        if (index >= _sources.length) {
          final source = _pendingCleanup[index - _sources.length];
          final busy = _removing.contains(source.id);
          return ListTile(
            key: ValueKey('cleanup-book-${source.id}'),
            leading: const Icon(Icons.delete_outline),
            title: Text(source.displayName),
            subtitle: const Text('Removed · app copy cleanup pending'),
            trailing: busy
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: 'Retry cleanup',
                    onPressed: () => _retryCleanup(source.id),
                    icon: const Icon(Icons.refresh),
                  ),
          );
        }
        final source = _sources[index];
        final busy = _removing.contains(source.id);
        return ListTile(
          key: ValueKey('managed-book-${source.id}'),
          leading: const Icon(Icons.menu_book_outlined),
          title: Text(source.displayName),
          subtitle: Text(switch (source.importState) {
            'indexed' =>
              source.accessMode == PgnSourceAccessMode.managedCopy
                  ? 'Stored on this device'
                  : 'Original file remains in its location',
            'sourceMissing' => 'Source missing · indexed history preserved',
            'sourceChanged' => 'Source changed · re-index required',
            _ => 'Import status: ${source.importState}',
          }),
          trailing: busy
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : PopupMenuButton<String>(
                  tooltip: 'Book actions',
                  onSelected: (_) {
                    if (!_loading &&
                        !_adding &&
                        !_removing.contains(source.id) &&
                        _removing.isEmpty &&
                        _confirming.isEmpty) {
                      _confirmRemove(source);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove from library'),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
