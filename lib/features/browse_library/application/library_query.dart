import '../../../domain/chess_content/content_type.dart';
import '../../../domain/library/pgn_index_repository.dart';

/// Ordering supported by the index repository: source, then source ordinal.
enum LibrarySort { sourceOrder }

/// User-facing paging and filter state for a library search.
final class LibraryQuery {
  const LibraryQuery({
    this.pageSize = 50,
    this.searchText = '',
    this.sort = LibrarySort.sourceOrder,
    this.player,
    this.event,
    this.contentType,
    this.section,
    this.theme,
    this.difficulty,
    this.result,
    this.sourceId,
  }) : assert(pageSize > 0 && pageSize <= 1000);

  final int pageSize;
  final String searchText;
  final LibrarySort sort;
  final String? player;
  final String? event;
  final ContentType? contentType;
  final String? section;
  final String? theme;
  final String? difficulty;
  final String? result;
  final String? sourceId;

  PgnIndexFilter toIndexFilter() => PgnIndexFilter(
    query: _clean(searchText),
    player: _clean(player),
    event: _clean(event),
    contentType: contentType,
    section: _clean(section),
    theme: _clean(theme),
    difficulty: _clean(difficulty),
    result: _clean(result),
    sourceId: sourceId,
  );

  PgnIndexSort get repositorySort => switch (sort) {
    LibrarySort.sourceOrder => PgnIndexSort.sourceOrder,
  };

  LibraryQuery copyWith({
    int? pageSize,
    String? searchText,
    LibrarySort? sort,
    String? player,
    String? event,
    ContentType? contentType,
    String? section,
    String? theme,
    String? difficulty,
    String? result,
    String? sourceId,
    bool clearPlayer = false,
    bool clearEvent = false,
    bool clearContentType = false,
    bool clearSection = false,
    bool clearTheme = false,
    bool clearDifficulty = false,
    bool clearResult = false,
    bool clearSourceId = false,
  }) => LibraryQuery(
    pageSize: pageSize ?? this.pageSize,
    searchText: searchText ?? this.searchText,
    sort: sort ?? this.sort,
    player: clearPlayer ? null : player ?? this.player,
    event: clearEvent ? null : event ?? this.event,
    contentType: clearContentType ? null : contentType ?? this.contentType,
    section: clearSection ? null : section ?? this.section,
    theme: clearTheme ? null : theme ?? this.theme,
    difficulty: clearDifficulty ? null : difficulty ?? this.difficulty,
    result: clearResult ? null : result ?? this.result,
    sourceId: clearSourceId ? null : sourceId ?? this.sourceId,
  );

  static String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}
