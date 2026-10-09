/// Creates one local analysis engine instance.
typedef AnalysisEngineFactory = AnalysisEngine Function();

/// A cancellable source of structured chess analysis.
///
/// Implementations must honor [budget], emit updates while searching, emit a
/// final result when a search completes, and make [stop] safe during startup.
abstract interface class AnalysisEngine {
  /// Analyzes [startingFen] followed by UCI [moves] from that position.
  Stream<AnalysisResult> analyze({
    required String startingFen,
    required List<String> moves,
    required Duration budget,
  });

  /// Stops the active search and completes after it is safe to send a new one.
  Future<void> stop();

  /// Stops active work and releases engine resources.
  Future<void> dispose();
}

/// A score from White's perspective.
///
/// Exactly one of [centipawns] or [mate] is normally present. A null score is
/// allowed for terminal `bestmove` lines that arrive without an `info score`.
final class AnalysisResult {
  const AnalysisResult({
    required this.depth,
    required this.principalVariation,
    required this.isComplete,
    this.centipawns,
    this.mate,
  });

  /// White-relative evaluation in centipawns, when supplied by the engine.
  final int? centipawns;

  /// White-relative mate distance in moves, when supplied by the engine.
  final int? mate;

  /// Search depth associated with this result.
  final int depth;

  /// Principal variation in UCI move notation.
  final List<String> principalVariation;

  /// True when the engine ended this search with `bestmove`.
  final bool isComplete;

  /// Short alias useful to presenters and test fakes.
  List<String> get pv => principalVariation;
}
