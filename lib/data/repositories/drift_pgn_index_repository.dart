import 'package:drift/drift.dart';

import '../../core/errors/app_failure.dart';
import '../../domain/chess_content/content_type.dart';
import '../../domain/chess_content/pgn_block_index.dart';
import '../../domain/library/pgn_index_repository.dart';
import '../database/app_database.dart';
import '../database/app_database.dart' as db show PgnBlock;

/// Drift-backed searchable PGN index.
final class DriftPgnIndexRepository implements PgnIndexRepository {
  DriftPgnIndexRepository(this._database);

  static const int maxPageSize = 1000;
  final AppDatabase _database;

  @override
  Future<PgnBlockIndex?> getById(String id) => _guard(() async {
    final row = await (_database.select(
      _database.pgnBlocks,
    )..where((block) => block.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  });

  @override
  Future<int> countForSource(String sourceId) => _guard(
    () async =>
        await (_database.selectOnly(_database.pgnBlocks)
              ..addColumns(<Expression<Object>>[_database.pgnBlocks.id.count()])
              ..where(_database.pgnBlocks.sourceId.equals(sourceId)))
            .map((row) => row.read(_database.pgnBlocks.id.count())!)
            .getSingle(),
  );

  @override
  Future<PgnIndexPage> search({
    PgnIndexFilter filter = const PgnIndexFilter(),
    PgnIndexSort sort = PgnIndexSort.sourceOrder,
    int offset = 0,
    required int limit,
  }) => _guard(() async {
    if (limit < 1 || limit > maxPageSize) {
      throw const ValidationFailure(
        code: 'invalid_page_limit',
        message: 'Page size must be between 1 and 1000.',
      );
    }
    if (offset < 0) {
      throw const ValidationFailure(
        code: 'invalid_page_offset',
        message: 'Page offset must not be negative.',
      );
    }

    final query = _database.select(_database.pgnBlocks);
    final clauses = <Expression<bool>>[];
    void substring(TextColumn column, String? value) {
      final needle = value?.trim();
      if (needle == null || needle.isEmpty) return;
      clauses.add(column.like('%${_escapeLike(needle)}%', escapeChar: r'\'));
    }

    if (filter.sourceId != null) {
      clauses.add(_database.pgnBlocks.sourceId.equals(filter.sourceId!));
    }
    substring(_database.pgnBlocks.event, filter.event);
    substring(_database.pgnBlocks.result, filter.result);
    substring(_database.pgnBlocks.section, filter.section);
    substring(_database.pgnBlocks.theme, filter.theme);
    substring(_database.pgnBlocks.difficulty, filter.difficulty);
    if (filter.player?.trim().isNotEmpty ?? false) {
      final pattern = '%${_escapeLike(filter.player!.trim())}%';
      clauses.add(
        _database.pgnBlocks.white.like(pattern, escapeChar: r'\') |
            _database.pgnBlocks.black.like(pattern, escapeChar: r'\'),
      );
    }
    if (filter.query?.trim().isNotEmpty ?? false) {
      final pattern = '%${_escapeLike(filter.query!.trim())}%';
      clauses.add(
        _database.pgnBlocks.white.like(pattern, escapeChar: r'\') |
            _database.pgnBlocks.black.like(pattern, escapeChar: r'\') |
            _database.pgnBlocks.event.like(pattern, escapeChar: r'\') |
            _database.pgnBlocks.date.like(pattern, escapeChar: r'\'),
      );
    }
    if (filter.contentType != null) {
      clauses.add(
        _database.pgnBlocks.contentType.equals(
          filter.contentType!.toDatabaseValue(),
        ),
      );
    }
    if (clauses.isNotEmpty) {
      query.where((_) => clauses.reduce((left, right) => left & right));
    }
    switch (sort) {
      case PgnIndexSort.sourceOrder:
        query.orderBy([
          (block) => OrderingTerm.asc(block.sourceId),
          (block) => OrderingTerm.asc(block.ordinal),
        ]);
    }
    query.limit(limit + 1, offset: offset);
    final rows = await query.get();
    final hasMore = rows.length > limit;
    final visible = hasMore ? rows.take(limit) : rows;
    return PgnIndexPage(
      items: visible.map(_fromRow).toList(growable: false),
      nextOffset: hasMore ? offset + limit : null,
    );
  });

  static String _escapeLike(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  static PgnBlockIndex _fromRow(db.PgnBlock row) => PgnBlockIndex(
    id: row.id,
    sourceId: row.sourceId,
    startOffset: row.startOffset,
    endOffset: row.endOffset,
    ordinal: row.ordinal,
    event: row.event,
    site: row.site,
    date: row.date,
    round: row.round,
    white: row.white,
    black: row.black,
    result: row.result,
    contentType: ContentType.fromDatabaseValue(row.contentType),
    exerciseId: row.exerciseId,
    section: row.section,
    sequence: row.sequence,
    theme: row.theme,
    difficulty: row.difficulty,
    parseStatus: PgnBlockParseStatus.fromDatabaseValue(row.parseStatus),
    diagnosticSummary: row.diagnosticSummary,
    inferredClassification: row.inferredClassification,
    authoredContentType: row.authoredContentType,
  );

  static Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const DatabaseFailure(
        code: 'pgn_index_read_failed',
        message:
            'Indexed PGN metadata could not be loaded. Retry the operation.',
      );
    }
  }
}
