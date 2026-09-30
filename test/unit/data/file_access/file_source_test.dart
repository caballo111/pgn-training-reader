import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/errors/app_failure.dart';
import 'package:pgntrainingreader/data/file_access/file_source.dart';
import 'package:pgntrainingreader/data/file_access/file_source_picker.dart';
import 'package:pgntrainingreader/data/file_access/flutter_file_source_picker.dart';
import 'package:pgntrainingreader/data/file_access/managed_file_source.dart';
import 'package:pgntrainingreader/data/file_access/source_fingerprint.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDirectory;
  late _MemoryPickedAccess picked;
  late ManagedFileSource source;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pgn-source-test-');
    picked = _MemoryPickedAccess();
    source = ManagedFileSource(
      pickedSources: picked,
      directoryProvider: () async => tempDirectory,
    );
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test(
    'copies bytes unchanged, reopens by opaque token, and reads ranges',
    () async {
      final original = Uint8List.fromList(List.generate(257, (i) => i));
      picked.bytes = original;
      final managed = await _copy(source, expectedLength: original.length);

      expect(managed.length, original.length);
      expect(managed.reference, isNot(contains('/')));
      final reopened = ManagedFileSource(
        pickedSources: picked,
        directoryProvider: () async => tempDirectory,
      );
      final reference = ManagedSourceReference(managed.reference);
      expect(
        await reopened
            .openReadStream(reference)
            .expand((chunk) => chunk)
            .toList(),
        original,
      );
      expect(await reopened.readRange(reference, start: 0, endExclusive: 4), [
        0,
        1,
        2,
        3,
      ]);
      expect(
        await reopened.readRange(reference, start: 111, endExclusive: 117),
        [111, 112, 113, 114, 115, 116],
      );
      expect(
        await reopened.readRange(reference, start: 253, endExclusive: 257),
        [253, 254, 255, 0],
      );
      expect(
        await reopened.readRange(reference, start: 257, endExclusive: 257),
        isEmpty,
      );
      await expectLater(
        reopened.readRange(reference, start: 258, endExclusive: 258),
        throwsA(isA<FileFailure>()),
      );
      await expectLater(
        reopened.readRange(reference, start: 256, endExclusive: 258),
        throwsA(isA<FileFailure>()),
      );
    },
  );

  test('copies when picked length is unknown', () async {
    picked.unknownLength = true;
    picked.bytes = Uint8List.fromList([80, 71, 78]);
    final result = await _copy(source);
    expect(result.length, 3);
    expect(await source.length(ManagedSourceReference(result.reference)), 3);
  });

  test(
    'reopens a persisted content URI for sampled fingerprints and ranges',
    () async {
      const channel = MethodChannel(
        'lberrios.pgntrainingreader/external_source',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'length':
                return 10;
              case 'modifiedAtMicros':
                return 1_000_000;
              case 'readRange':
                final arguments = call.arguments! as Map<Object?, Object?>;
                final start = arguments['start']! as int;
                final end = arguments['endExclusive']! as int;
                return Uint8List.fromList(
                  List<int>.generate(end - start, (index) => start + index),
                );
              default:
                throw PlatformException(code: 'not_implemented');
            }
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final external = ExternalSourceReference(
        'content://com.example.documents/document/42',
      );
      final adapter = const FlutterFileSource();
      final externalSource = ManagedFileSource(pickedSources: adapter);
      final fingerprintInput = await externalSource.fingerprintInput(
        external,
        sampleSize: 4,
      );

      expect(fingerprintInput.length, 10);
      expect(
        fingerprintInput.modifiedAt,
        DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      );
      expect(fingerprintInput.samples.map((sample) => sample.offset), [
        0,
        3,
        6,
      ]);
      expect(
        await externalSource.readRange(external, start: 3, endExclusive: 6),
        [3, 4, 5],
      );
      expect(
        () => ExternalSourceReference('file:///tmp/study.pgn'),
        throwsArgumentError,
      );
    },
  );

  test(
    'cancellation during stream removes temporary and reserved final files',
    () async {
      final access = _GatedPickedAccess();
      final cancellableSource = ManagedFileSource(
        pickedSources: access,
        directoryProvider: () async => tempDirectory,
      );
      final target = await cancellableSource.createTarget();
      final cancellation = CopyCancellation();
      final copying = cancellableSource.copyToManagedStorage(
        const _Reference(),
        target: _SignalingTarget(target, access.firstChunkWritten),
        cancellation: cancellation,
      );
      access.controller.add([1, 2, 3]);
      await access.firstChunkWritten.future;
      cancellation.cancel();
      access.controller.add([4, 5, 6]);
      await expectLater(copying, throwsA(isA<FileFailure>()));
      await access.cancelled.future;
      expect(await _managedFiles(tempDirectory), isEmpty);
    },
  );

  test(
    'pre-cancelled copy removes target files without reading the source',
    () async {
      final target = await source.createTarget();
      final cancellation = CopyCancellation()..cancel();
      await expectLater(
        source.copyToManagedStorage(
          const _Reference(),
          target: target,
          cancellation: cancellation,
        ),
        throwsA(isA<FileFailure>()),
      );
      expect(picked.openCount, 0);
      expect(await _managedFiles(tempDirectory), isEmpty);
    },
  );

  test(
    'length mismatch and source stream failure discard the incomplete copy',
    () async {
      picked.bytes = Uint8List.fromList([1, 2, 3]);
      await expectLater(
        _copy(source, expectedLength: 4),
        throwsA(isA<FileFailure>()),
      );
      expect(await _managedFiles(tempDirectory), isEmpty);

      picked.streamError = const FileFailure(
        code: 'read_failed',
        message: 'read failed',
      );
      await expectLater(_copy(source), throwsA(isA<FileFailure>()));
      expect(await _managedFiles(tempDirectory), isEmpty);
    },
  );

  test(
    'ENOSPC maps to insufficient_storage and preserves completed copies',
    () async {
      picked.bytes = Uint8List.fromList([9, 8, 7]);
      final existing = await _copy(source);
      final cancellation = CopyCancellation();
      final failingTarget = _FailingTarget(
        const FileSystemException(
          'disk full',
          '',
          OSError('No space left', 28),
        ),
      );
      await expectLater(
        source.copyToManagedStorage(
          const _Reference(),
          target: failingTarget,
          cancellation: cancellation,
        ),
        throwsA(
          isA<FileFailure>().having(
            (failure) => failure.code,
            'code',
            'insufficient_storage',
          ),
        ),
      );
      expect(failingTarget.discarded, isTrue);
      expect(
        await source
            .openReadStream(ManagedSourceReference(existing.reference))
            .expand((chunk) => chunk)
            .toList(),
        [9, 8, 7],
      );
    },
  );

  test(
    'fingerprints respond to sampled bytes, size, and modification time',
    () async {
      picked.bytes = Uint8List.fromList(List.generate(100, (i) => i));
      final atTime = DateTime.utc(2026, 1, 2);
      final original = await source.fingerprintInput(
        const _Reference(),
        sampleSize: 4,
        modifiedAt: atTime,
      );
      final same = await source.fingerprintInput(
        const _Reference(),
        sampleSize: 4,
        modifiedAt: atTime,
      );
      expect(
        SourceFingerprint.compute(original),
        SourceFingerprint.compute(same),
      );

      picked.bytes = Uint8List.fromList(
        List.generate(100, (i) => i == 0 ? 200 : i),
      );
      final sampledEdit = await source.fingerprintInput(
        const _Reference(),
        sampleSize: 4,
        modifiedAt: atTime,
      );
      expect(
        SourceFingerprint.compute(sampledEdit),
        isNot(SourceFingerprint.compute(original)),
      );

      picked.bytes = Uint8List.fromList([...List.generate(100, (i) => i), 100]);
      final resized = await source.fingerprintInput(
        const _Reference(),
        sampleSize: 4,
        modifiedAt: atTime,
      );
      expect(
        SourceFingerprint.compute(resized),
        isNot(SourceFingerprint.compute(original)),
      );
      final retimed = await source.fingerprintInput(
        const _Reference(),
        sampleSize: 4,
        modifiedAt: atTime.add(const Duration(seconds: 1)),
      );
      expect(
        SourceFingerprint.compute(retimed),
        isNot(SourceFingerprint.compute(original)),
      );

      // Changes outside the chosen samples can be missed when metadata is held
      // constant; fingerprints are change detectors, not byte identity proofs.
      picked.bytes = Uint8List.fromList(
        List.generate(100, (i) => i == 20 ? 201 : i),
      );
      final unsampledEdit = await source.fingerprintInput(
        const _Reference(),
        sampleSize: 4,
        modifiedAt: atTime,
      );
      expect(
        SourceFingerprint.compute(unsampledEdit),
        SourceFingerprint.compute(original),
      );
    },
  );

  test('picker cancellation, metadata, and selected stream/range use opaque handle', () async {
    final cancelled = FlutterFileSourcePicker(pickFile: () async => null);
    expect(await cancelled.pickPgnSource(), isNull);

    final fakeFile = _TestPlatformFile(
      name: 'study.pgn',
      bytes: Uint8List.fromList([10, 20, 30, 40]),
      lengthValue: 4,
    );
    final picker = FlutterFileSourcePicker(pickFile: () async => fakeFile);
    final selected = await picker.pickPgnSource();
    expect(selected, isNotNull);
    expect(selected!.displayName, 'study.pgn');
    expect(selected.lengthBytes, 4);
    expect(selected.mimeType, 'application/x-chess-pgn');
    expect(selected.reference, isA<OpaqueSourceReference>());

    const adapter = FlutterFileSource();
    expect(await adapter.length(selected.reference), 4);
    expect(
      await adapter.readRange(selected.reference, start: 1, endExclusive: 3),
      [20, 30],
    );
    expect(
      await adapter
          .openReadStream(selected.reference)
          .expand((chunk) => chunk)
          .toList(),
      [10, 20, 30, 40],
    );
  });
}

Future<ManagedCopyResult> _copy(
  ManagedFileSource source, {
  int? expectedLength,
}) async {
  final target = await source.createTarget();
  return source.copyToManagedStorage(
    const _Reference(),
    target: target,
    cancellation: CopyCancellation(),
    expectedLength: expectedLength,
  );
}

Future<List<File>> _managedFiles(Directory root) async => (await Directory(
  '${root.path}/managed_pgn_sources',
).list().toList()).whereType<File>().toList();

final class _Reference implements OpaqueSourceReference {
  const _Reference();
}

final class _MemoryPickedAccess implements PickedSourceAccess {
  Uint8List bytes = Uint8List(0);
  int? reportedLength;
  bool unknownLength = false;
  Object? streamError;
  int openCount = 0;

  @override
  Stream<List<int>> openReadStream(OpaqueSourceReference reference) async* {
    openCount++;
    if (streamError case final error?) throw error;
    yield bytes;
  }

  @override
  Future<int?> length(OpaqueSourceReference reference) async =>
      unknownLength ? null : (reportedLength ?? bytes.length);

  @override
  Future<DateTime?> modifiedAt(OpaqueSourceReference reference) async => null;

  @override
  Future<Uint8List> readRange(
    OpaqueSourceReference reference, {
    required int start,
    required int endExclusive,
  }) async => Uint8List.fromList(bytes.sublist(start, endExclusive));
}

final class _SignalingTarget implements ManagedCopyTarget {
  _SignalingTarget(this.delegate, this.firstWritten);

  final ManagedCopyTarget delegate;
  final Completer<void> firstWritten;

  @override
  Future<void> write(List<int> bytes) async {
    await delegate.write(bytes);
    if (!firstWritten.isCompleted) firstWritten.complete();
  }

  @override
  Future<String> promote({required int bytesWritten}) =>
      delegate.promote(bytesWritten: bytesWritten);

  @override
  Future<void> discard() => delegate.discard();
}

final class _GatedPickedAccess implements PickedSourceAccess {
  final firstChunkWritten = Completer<void>();
  final cancelled = Completer<void>();
  late final StreamController<List<int>> controller =
      StreamController<List<int>>(
        onCancel: () {
          if (!cancelled.isCompleted) cancelled.complete();
        },
      );

  @override
  Stream<List<int>> openReadStream(OpaqueSourceReference reference) =>
      controller.stream;

  @override
  Future<int?> length(OpaqueSourceReference reference) async => null;

  @override
  Future<DateTime?> modifiedAt(OpaqueSourceReference reference) async => null;

  @override
  Future<Uint8List> readRange(
    OpaqueSourceReference reference, {
    required int start,
    required int endExclusive,
  }) async => throw UnimplementedError();
}

final class _FailingTarget implements ManagedCopyTarget {
  _FailingTarget(this.error);

  final FileSystemException error;
  bool discarded = false;

  @override
  Future<void> write(List<int> bytes) async => throw error;
  @override
  Future<String> promote({required int bytesWritten}) async =>
      throw StateError('unexpected');
  @override
  Future<void> discard() async => discarded = true;
}

final class _TestPlatformFile extends PlatformFile {
  _TestPlatformFile({
    required this.name,
    required this.bytes,
    required this.lengthValue,
  });

  @override
  final String name;
  final Uint8List bytes;
  final int? lengthValue;

  @override
  Uri get uri => Uri.parse('memory://selected/$name');
  @override
  int? lengthSync() => null;
  @override
  Future<int?> length() async => lengthValue;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
