import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pgntrainingreader/data/pgn/scanner/pgn_boundary_scanner.dart';

const _chunkSize = 64 * 1024;
const _game = '[Event "benchmark"]\n[Result "*"]\n\n1. e4 *\n';
const _memoryLimitBytes = 64 * 1024 * 1024;
const _growthAllowanceBytes = 24 * 1024 * 1024;

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == '--child') {
    final count = int.parse(args[1]);
    final result = await _runChild(count);
    stdout.writeln(jsonEncode(result));
    return;
  }

  final counts = args.isEmpty
      ? <int>[10000, 100000]
      : args.map(int.parse).toList();
  final results = <_Result>[];
  for (final count in counts) {
    final result = await _runIsolated(count);
    if (result.blocks != count) {
      throw StateError('Expected $count blocks, scanned ${result.blocks}.');
    }
    results.add(result);
    stdout.writeln(
      '${result.blocks} blocks: ${_formatBytes(result.inputBytes)} scanned, '
      '${result.blocksPerSecond.toStringAsFixed(0)} blocks/s, '
      'RSS baseline ${_formatBytes(result.baselineRss)}, '
      'peak ${_formatBytes(result.peakRss)}, '
      'growth ${_formatBytes(result.growthBytes)}',
    );
    stdout.writeln(
      '  huge-comment stress: ${_formatBytes(result.commentBytes)} scanned, '
      'peak RSS ${_formatBytes(result.commentPeakRss)}, '
      'growth ${_formatBytes(result.commentPeakRss - result.commentBaselineRss)}',
    );
  }

  if (results.length >= 2) {
    final smallest = results.first;
    final largest = results.last;
    final allowedGrowth = math.max(
      _growthAllowanceBytes,
      smallest.growthBytes + _growthAllowanceBytes,
    );
    if (largest.growthBytes > _memoryLimitBytes ||
        largest.growthBytes > allowedGrowth) {
      stderr.writeln(
        'Memory bound failed: largest run grew by '
        '${_formatBytes(largest.growthBytes)} (limit '
        '${_formatBytes(math.min(_memoryLimitBytes, allowedGrowth))}).',
      );
      exitCode = 1;
    } else {
      stdout.writeln(
        'Memory bound passed: largest-run RSS growth stayed below '
        '${_formatBytes(math.min(_memoryLimitBytes, allowedGrowth))}.',
      );
    }
  }
}

Future<_Result> _runIsolated(int count) async {
  final process = await Process.start(Platform.resolvedExecutable, <String>[
    Platform.script.toFilePath(),
    '--child',
    '$count',
  ]);
  final outputFuture = process.stdout.transform(utf8.decoder).join();
  final errorFuture = process.stderr.transform(utf8.decoder).join();
  final status = await process.exitCode;
  final output = await outputFuture;
  final error = await errorFuture;
  if (status != 0) {
    throw ProcessException(
      Platform.resolvedExecutable,
      <String>[],
      error,
      status,
    );
  }
  return _Result.fromJson(jsonDecode(output.trim()) as Map<String, dynamic>);
}

Future<Map<String, Object>> _runChild(int count) async {
  final baselineRss = _currentRss();
  final scanner = PgnBoundaryScanner();
  final pattern = ascii.encode(_game);
  final buffer = Uint8List(_chunkSize);
  var buffered = 0;
  var blocks = 0;
  var inputBytes = 0;
  var peakRss = _currentRss();
  final stopwatch = Stopwatch()..start();

  void send(int length) {
    final ranges = scanner.consume(Uint8List.sublistView(buffer, 0, length));
    blocks += ranges.length;
    inputBytes += length;
    peakRss = math.max(peakRss, _peakRss());
  }

  for (var index = 0; index < count; index++) {
    var offset = 0;
    while (offset < pattern.length) {
      final copied = math.min(_chunkSize - buffered, pattern.length - offset);
      buffer.setRange(buffered, buffered + copied, pattern, offset);
      buffered += copied;
      offset += copied;
      if (buffered == _chunkSize) {
        send(buffered);
        buffered = 0;
      }
    }
  }
  if (buffered > 0) send(buffered);
  blocks += scanner.finish().length;
  stopwatch.stop();
  peakRss = math.max(peakRss, _peakRss());
  final comment = await _runHugeCommentStress();
  if (comment.$3 - comment.$2 > _memoryLimitBytes) {
    throw StateError('Huge-comment scan exceeded the 64 MiB RSS growth bound.');
  }
  return <String, Object>{
    'blocks': blocks,
    'inputBytes': inputBytes,
    'elapsedMicros': stopwatch.elapsedMicroseconds,
    'baselineRss': baselineRss,
    'peakRss': peakRss,
    'commentBytes': comment.$1,
    'commentBaselineRss': comment.$2,
    'commentPeakRss': comment.$3,
  };
}

Future<(int, int, int)> _runHugeCommentStress() async {
  // Stream a 256 MiB comment without constructing or retaining its contents.
  const commentTargetBytes = 256 * 1024 * 1024;
  final scanner = PgnBoundaryScanner();
  final buffer = Uint8List(_chunkSize);
  buffer.fillRange(0, buffer.length, 120); // 'x'
  final open = ascii.encode('[Event "large comment"]\n\n{');
  final close = ascii.encode('} *\n');
  var bytes = 0;
  final baselineRss = _currentRss();
  var peakRss = _peakRss();

  scanner.consume(open);
  bytes += open.length;
  var remaining = commentTargetBytes - open.length - close.length;
  while (remaining > 0) {
    final length = math.min(buffer.length, remaining);
    scanner.consume(Uint8List.sublistView(buffer, 0, length));
    remaining -= length;
    bytes += length;
    peakRss = math.max(peakRss, _peakRss());
  }
  final ranges = scanner.consume(close);
  bytes += close.length;
  final finalRanges = scanner.finish();
  if (ranges.length + finalRanges.length != 1) {
    throw StateError('Huge-comment stress did not find exactly one block.');
  }
  return (bytes, baselineRss, math.max(peakRss, _peakRss()));
}

int _currentRss() => _readProcStatus('VmRSS') ?? ProcessInfo.currentRss;
int _peakRss() => _readProcStatus('VmHWM') ?? ProcessInfo.maxRss;
int? _readProcStatus(String name) {
  final file = File('/proc/self/status');
  if (!file.existsSync()) return null;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('$name:')) {
      final fields = line.split(RegExp(r'\s+'));
      return int.parse(fields[1]) * 1024;
    }
  }
  return null;
}

String _formatBytes(int bytes) {
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
}

class _Result {
  const _Result({
    required this.blocks,
    required this.inputBytes,
    required this.elapsedMicros,
    required this.baselineRss,
    required this.peakRss,
    required this.commentBytes,
    required this.commentBaselineRss,
    required this.commentPeakRss,
  });

  factory _Result.fromJson(Map<String, dynamic> json) => _Result(
    blocks: json['blocks'] as int,
    inputBytes: json['inputBytes'] as int,
    elapsedMicros: json['elapsedMicros'] as int,
    baselineRss: json['baselineRss'] as int,
    peakRss: json['peakRss'] as int,
    commentBytes: json['commentBytes'] as int,
    commentBaselineRss: json['commentBaselineRss'] as int,
    commentPeakRss: json['commentPeakRss'] as int,
  );

  final int blocks;
  final int inputBytes;
  final int elapsedMicros;
  final int baselineRss;
  final int peakRss;
  final int commentBytes;
  final int commentBaselineRss;
  final int commentPeakRss;

  int get growthBytes => math.max(0, peakRss - baselineRss);
  double get blocksPerSecond => blocks / (elapsedMicros / 1000000);
}
