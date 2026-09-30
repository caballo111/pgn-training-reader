import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/chess_content/pgn_block_index.dart';
import '../../../domain/library/pgn_index_repository.dart';
import '../../../domain/library/pgn_source_repository.dart';
import '../../../domain/chess_content/pgn_source.dart';
import 'library_query.dart';

enum LibraryLoadStatus { loading, ready, failed }

@immutable
final class LibraryState {
  const LibraryState({
    this.items = const [],
    this.sources = const [],
    this.query = const LibraryQuery(),
    this.status = LibraryLoadStatus.loading,
    this.hasMore = false,
    this.loadingMore = false,
    this.errorMessage,
  });
  final List<PgnBlockIndex> items;
  final List<PgnSource> sources;
  final LibraryQuery query;
  final LibraryLoadStatus status;
  final bool hasMore;
  final bool loadingMore;
  final String? errorMessage;
}

/// Loads bounded index pages and discards responses from superseded searches.
final class LibraryController extends ChangeNotifier {
  LibraryController({
    required this.indexRepository,
    required this.sourceRepository,
    this.debounceDuration = const Duration(milliseconds: 250),
    LibraryQuery initialQuery = const LibraryQuery(),
  }) : _state = LibraryState(query: initialQuery);

  final PgnIndexRepository indexRepository;
  final PgnSourceRepository sourceRepository;
  final Duration debounceDuration;
  LibraryState _state;
  Timer? _debounce;
  int _generation = 0;
  int? _nextOffset;
  bool _disposed = false;
  LibraryState get state => _state;

  Future<void> load() async {
    final generation = ++_generation;
    _set(
      _state.copyWith(status: LibraryLoadStatus.loading, errorMessage: null),
    );
    try {
      final sources = await sourceRepository.list();
      if (!_current(generation)) return;
      _state = LibraryState(
        sources: sources,
        query: _state.query,
        status: LibraryLoadStatus.loading,
      );
      notifyListeners();
      await _fetchFirst(generation);
    } catch (error) {
      if (_current(generation)) _fail(error);
    }
  }

  void setSearchText(String value) {
    _replaceQuery(_state.query.copyWith(searchText: value), debounce: true);
  }

  void updateQuery(LibraryQuery query) => _replaceQuery(query);

  Future<void> refresh() async {
    _debounce?.cancel();
    final generation = ++_generation;
    _set(
      _state.copyWith(status: LibraryLoadStatus.loading, errorMessage: null),
    );
    await _fetchFirst(generation);
  }

  Future<void> loadNextPage() async {
    final offset = _nextOffset;
    if (offset == null ||
        _state.loadingMore ||
        _state.status != LibraryLoadStatus.ready) {
      return;
    }
    final generation = _generation;
    _set(_state.copyWith(loadingMore: true));
    try {
      final page = await indexRepository.search(
        filter: _state.query.toIndexFilter(),
        sort: _state.query.repositorySort,
        offset: offset,
        limit: _state.query.pageSize,
      );
      if (!_current(generation)) return;
      _nextOffset = page.nextOffset;
      _set(
        _state.copyWith(
          items: [..._state.items, ...page.items],
          hasMore: page.nextOffset != null,
          loadingMore: false,
        ),
      );
    } catch (error) {
      if (_current(generation)) _fail(error);
    }
  }

  void _replaceQuery(LibraryQuery query, {bool debounce = false}) {
    _debounce?.cancel();
    final generation = ++_generation;
    _nextOffset = null;
    _set(
      LibraryState(
        items: const [],
        sources: _state.sources,
        query: query,
        status: LibraryLoadStatus.loading,
      ),
    );
    if (debounce) {
      _debounce = Timer(debounceDuration, () => _fetchFirst(generation));
    } else {
      unawaited(_fetchFirst(generation));
    }
  }

  Future<void> _fetchFirst(int generation) async {
    try {
      final page = await indexRepository.search(
        filter: _state.query.toIndexFilter(),
        sort: _state.query.repositorySort,
        limit: _state.query.pageSize,
      );
      if (!_current(generation)) return;
      _nextOffset = page.nextOffset;
      _set(
        _state.copyWith(
          items: page.items,
          hasMore: page.nextOffset != null,
          status: LibraryLoadStatus.ready,
          loadingMore: false,
          errorMessage: null,
        ),
      );
    } catch (error) {
      if (_current(generation)) _fail(error);
    }
  }

  void _fail(Object error) => _set(
    _state.copyWith(
      status: LibraryLoadStatus.failed,
      loadingMore: false,
      errorMessage: 'Could not load indexed PGN content. Retry the search.',
    ),
  );

  bool _current(int generation) => !_disposed && generation == _generation;
  void _set(LibraryState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _debounce?.cancel();
    super.dispose();
  }
}

extension on LibraryState {
  LibraryState copyWith({
    List<PgnBlockIndex>? items,
    List<PgnSource>? sources,
    LibraryQuery? query,
    LibraryLoadStatus? status,
    bool? hasMore,
    bool? loadingMore,
    String? errorMessage,
  }) => LibraryState(
    items: items ?? this.items,
    sources: sources ?? this.sources,
    query: query ?? this.query,
    status: status ?? this.status,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    errorMessage: errorMessage,
  );
}
