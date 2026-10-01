import 'package:flutter_test/flutter_test.dart';

import '../../tool/pgn_performance_benchmark.dart';

void main() {
  const fullBenchmarks = bool.fromEnvironment('PGN_BENCHMARK_FULL');
  const requestedCount = int.fromEnvironment('PGN_BENCHMARK_BLOCKS');
  final counts = requestedCount > 0
      ? <int>[requestedCount]
      : fullBenchmarks
      ? <int>[10000, 100000]
      : <int>[100];
  for (final count in counts) {
    test(
      'benchmark real importer and repositories with $count blocks',
      () async {
        final result = await runPgnPerformanceBenchmark(count);
        expect(result['blocks'], count);
        expect(result['diagnostics'], 0);
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  }
}
