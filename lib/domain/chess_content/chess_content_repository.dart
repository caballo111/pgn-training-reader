import '../../core/errors/app_failure.dart';
import 'chess_content.dart';

/// Loads complete, parsed chess content for one indexed PGN block.
///
/// Implementations read only the block identified by [id], using its indexed
/// source locator, and return the faithful domain representation without
/// loading the rest of the source file. The imported PGN remains canonical;
/// parsing must not rewrite or normalize the source content.
abstract interface class ChessContentRepository {
  /// Returns the parsed content for [id], or `null` when no indexed block has
  /// that ID.
  ///
  /// Throws a typed [AppFailure] when the block cannot be loaded. Expected
  /// failure categories include [FileFailure] when the source is unavailable
  /// or has changed, [DatabaseFailure] when its index or locator cannot be
  /// read, [PgnFailure] when the block is malformed, and
  /// [UnsupportedContentFailure] when it cannot safely be interpreted as
  /// standard chess. Unsupported content must never be returned as if it were
  /// supported [ChessContent].
  Future<ChessContent?> getById(String id);
}
