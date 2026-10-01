// Reproducible, sanitized performance benchmark for the real Drift PGN
// importer and repositories. Run with:
// flutter test test/performance/pgn_performance_benchmark_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:pgntrainingreader/core/time/app_clock.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';
import 'package:pgntrainingreader/data/file_access/file_source.dart';
import 'package:pgntrainingreader/data/file_access/file_source_picker.dart';
import 'package:pgntrainingreader/data/pgn/pgn_indexer.dart';
import 'package:pgntrainingreader/data/repositories/drift_pgn_index_repository.dart';
import 'package:pgntrainingreader/data/repositories/drift_chess_content_repository.dart';
import 'package:pgntrainingreader/data/repositories/drift_pgn_source_repository.dart';
import 'package:pgntrainingreader/domain/library/pgn_import_service.dart';
import 'package:pgntrainingreader/domain/library/pgn_index_repository.dart';

const _managedDirectoryName = 'managed_pgn_sources';
const _sourceToken = '0123456789abcdef0123456789abcdef';
const _sampleCount = 100;

Future<Map<String, Object>> runPgnPerformanceBenchmark(int count) async {
  if (count <= 0) {
    throw ArgumentError.value(count, 'count', 'Must be positive.');
  }
  final result = await _run(count);
  stdout.writeln(jsonEncode(result));
  return result;
}

Future<Map<String, Object>> _run(int count) async {
  final temp = await Directory.systemTemp.createTemp('pgn-performance-');
  final managedDir = Directory('${temp.path}/$_managedDirectoryName')
    ..createSync();
  final sourceFile = File('${managedDir.path}/$_sourceToken.pgn');
  await _writeGeneratedPgn(sourceFile, count);
  final db = AppDatabase(NativeDatabase(File('${temp.path}/benchmark.sqlite')));
  final clock = _BenchmarkClock();
  final sampler = _RssSampler()..start();
  try {
    await db
        .into(db.pgnSources)
        .insert(
          PgnSourcesCompanion.insert(
            id: 'benchmark-source',
            displayName: 'sanitized-benchmark.pgn',
            accessMode: 'ManagedCopy',
            managedPath: const Value(_sourceToken),
            scannerVersion: DriftPgnImportService.scannerVersion,
            importState: 'ready',
            createdAtMicros: clock.utcNow.microsecondsSinceEpoch,
            updatedAtMicros: clock.utcNow.microsecondsSinceEpoch,
          ),
        );
    final fileSource = _BenchmarkFileSource(sourceFile);
    final import = DriftPgnImportService(
      database: db,
      fileSource: fileSource,
      idGenerator: _BenchmarkIds(),
      clock: clock,
    );
    final importWatch = Stopwatch()..start();
    final outcome = await import
        .start(PgnImportRequest(sourceId: 'benchmark-source'))
        .result;
    importWatch.stop();
    if (outcome.phase != PgnImportPhase.completed ||
        outcome.indexedBlockCount != count) {
      throw StateError(
        'Import failed: ${outcome.phase}, ${outcome.indexedBlockCount}/$count blocks.',
      );
    }

    final repository = DriftPgnIndexRepository(db);
    final queryMicros = <int>[];
    for (var i = 0; i < _sampleCount; i++) {
      final watch = Stopwatch()..start();
      final page = await repository.search(
        filter: const PgnIndexFilter(sourceId: 'benchmark-source'),
        offset: (i * (count ~/ _sampleCount)).clamp(0, count - 1),
        limit: 20,
      );
      watch.stop();
      if (page.items.isEmpty) {
        throw StateError('Benchmark query unexpectedly returned no rows.');
      }
      queryMicros.add(watch.elapsedMicroseconds);
    }

    final lastPage = await repository.search(
      filter: const PgnIndexFilter(sourceId: 'benchmark-source'),
      offset: count - 1,
      limit: 1,
    );
    if (lastPage.items.isEmpty) {
      throw StateError('Final block was not indexed.');
    }
    final selected = lastPage.items.single;
    final contentRepository = DriftChessContentRepository(
      indexRepository: repository,
      sourceRepository: DriftPgnSourceRepository(db),
      fileSource: fileSource,
    );
    final selectedLoadMicros = <int>[];
    for (var i = 0; i < _sampleCount; i++) {
      final watch = Stopwatch()..start();
      final content = await contentRepository.getById(selected.id);
      watch.stop();
      if (content == null) {
        throw StateError('Selected block content was not loaded.');
      }
      selectedLoadMicros.add(watch.elapsedMicroseconds);
    }
    sampler.stop();
    return <String, Object>{
      'blocks': count,
      'sourceBytes': await sourceFile.length(),
      'importMilliseconds': importWatch.elapsedMilliseconds,
      'importBlocksPerSecond':
          (count * 1000000 / importWatch.elapsedMicroseconds).round(),
      'searchQueryP50Micros': _percentile(queryMicros, .50),
      'searchQueryP95Micros': _percentile(queryMicros, .95),
      'selectedBlockLoadP50Micros': _percentile(selectedLoadMicros, .50),
      'selectedBlockLoadP95Micros': _percentile(selectedLoadMicros, .95),
      'selectedBlockBytes': selected.endOffset - selected.startOffset,
      'baselineRssBytes': sampler.baseline,
      'peakRssBytes': sampler.peak,
      'rssGrowthBytes': sampler.peak - sampler.baseline,
      'rssSamplingIntervalMillis': 10,
      'diagnostics': outcome.diagnosticCount,
      'note':
          'Synthetic sanitized host benchmark; not reference Android result.',
    };
  } finally {
    sampler.stop();
    await db.close();
    await temp.delete(recursive: true);
  }
}

Future<void> _writeGeneratedPgn(File file, int count) async {
  final sink = file.openWrite();
  for (var i = 0; i < count; i++) {
    sink.write(
      '[Event "Benchmark"]\n[White "Player A"]\n[Black "Player B"]\n[Result "*"]\n\n1. e4 e5 *\n\n',
    );
  }
  await sink.flush();
  await sink.close();
}

int _percentile(List<int> values, double percentile) {
  values.sort();
  return values[((values.length - 1) * percentile).round()];
}

int _rss() {
  final status = File('/proc/self/status');
  if (status.existsSync()) {
    for (final line in status.readAsLinesSync()) {
      if (line.startsWith('VmRSS:')) {
        return int.parse(line.split(RegExp(r'\s+'))[1]) * 1024;
      }
    }
  }
  return ProcessInfo.currentRss;
}

final class _RssSampler {
  late int baseline;
  late int peak;
  Timer? _timer;
  void start() {
    baseline = peak = _rss();
    _timer = Timer.periodic(
      const Duration(milliseconds: 10),
      (_) => peak = math.max(peak, _rss()),
    );
  }

  void stop() {
    _timer?.cancel();
    peak = math.max(peak, _rss());
  }
}

final class _BenchmarkFileSource implements FileSource {
  _BenchmarkFileSource(this.file);
  final File file;

  @override
  Stream<List<int>> openReadStream(OpaqueSourceReference reference) =>
      file.openRead();

  @override
  Future<int?> length(OpaqueSourceReference reference) => file.length();

  @override
  Future<Uint8List> readRange(
    OpaqueSourceReference reference, {
    required int start,
    required int endExclusive,
  }) async {
    final handle = await file.open();
    try {
      await handle.setPosition(start);
      return Uint8List.fromList(await handle.read(endExclusive - start));
    } finally {
      await handle.close();
    }
  }

  @override
  Future<FileFingerprintInput> fingerprintInput(
    OpaqueSourceReference reference, {
    DateTime? modifiedAt,
    int sampleSize = 4096,
  }) async {
    final size = await file.length();
    final offsets = <int>{
      0,
      math.max(0, size ~/ 2 - sampleSize ~/ 2),
      math.max(0, size - sampleSize),
    };
    final samples = <FingerprintSample>[];
    for (final offset in offsets) {
      samples.add(
        FingerprintSample(
          offset: offset,
          bytes: await readRange(
            reference,
            start: offset,
            endExclusive: math.min(size, offset + sampleSize),
          ),
        ),
      );
    }
    return FileFingerprintInput(
      length: size,
      modifiedAt: await file.lastModified(),
      samples: samples,
    );
  }

  @override
  Future<ManagedCopyResult> copyToManagedStorage(
    OpaqueSourceReference reference, {
    required ManagedCopyTarget target,
    required CopyCancellation cancellation,
    int? expectedLength,
  }) => throw UnsupportedError('Copy is outside benchmark scope.');
}

final class _BenchmarkIds implements IdGenerator {
  var _next = 0;
  @override
  String generateId() => 'benchmark-${_next++}';
}

final class _BenchmarkClock implements AppClock {
  @override
  final DateTime utcNow = DateTime.utc(2026, 10, 1);
  @override
  Duration get monotonicElapsed => Duration.zero;
}
