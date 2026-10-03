import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/errors/app_failure.dart';
import '../../core/time/app_clock.dart';
import '../../core/utilities/id_generator.dart';
import '../../domain/chess_content/content_type.dart';
import '../../domain/chess_content/pgn_block_index.dart';
import '../../domain/library/pgn_import_service.dart';
import '../database/app_database.dart';
import '../file_access/file_source.dart';
import '../file_access/file_source_picker.dart';
import '../file_access/managed_file_source.dart';
import '../file_access/source_fingerprint.dart';
import 'content_classifier.dart';
import 'exercise_identity.dart';
import 'pgn_source_operation_registry.dart';
import 'pgn_header_reader.dart';
import 'scanner/pgn_boundary_scanner.dart';

/// Drift implementation of the baseline PGN import operation.
///
/// Each stored range is read independently and capped at 8 MiB. Scanner input
/// and file reads are subdivided into 64 KiB pieces to keep long imports
/// cooperative with the UI isolate.
final class DriftPgnImportService implements PgnImportService {
  DriftPgnImportService({
    required this.database,
    required this.fileSource,
    required this.idGenerator,
    required this.clock,
  });

  static const int scannerVersion = 1;
  static const int _chunkSize = 64 * 1024;
  static const int _maximumBlockBytes = 8 * 1024 * 1024;
  static const int _maximumDiagnostics = 1000;
  static const int _batchSize = 50;

  final AppDatabase database;
  final FileSource fileSource;
  final IdGenerator idGenerator;
  final AppClock clock;
  @override
  PgnImportOperation start(PgnImportRequest request) {
    final operation = _ImportOperation();
    unawaited(_start(request.sourceId, operation));
    return operation;
  }

  @override
  PgnImportOperation reindex(String sourceId) {
    final operation = _ImportOperation();
    unawaited(_start(sourceId, operation, reindex: true));
    return operation;
  }

  @override
  PgnImportOperation resume(String jobId) {
    final operation = _ImportOperation();
    unawaited(_resume(jobId, operation));
    return operation;
  }

  Future<void> _resume(String jobId, _ImportOperation operation) async {
    ImportJob? job;
    try {
      job = await (database.select(
        database.importJobs,
      )..where((row) => row.id.equals(jobId))).getSingleOrNull();
    } catch (_) {
      await operation.fail(
        jobId.isEmpty ? idGenerator.generateId() : jobId,
        PgnImportResumeDisposition.resume,
        'The import job could not be read. Retry resume after checking storage.',
      );
      return;
    }
    if (jobId.isEmpty) {
      await operation.fail(
        idGenerator.generateId(),
        PgnImportResumeDisposition.restart,
        'An import job ID is required to resume.',
      );
      return;
    }
    if (job == null ||
        !const {'cancelled', 'failed', 'indexing'}.contains(job.status)) {
      await operation.fail(
        jobId,
        PgnImportResumeDisposition.restart,
        'This import job is unknown or cannot be resumed.',
      );
      return;
    }
    await _start(job.sourceId, operation, resumeJob: job);
  }

  Future<void> _start(
    String sourceId,
    _ImportOperation operation, {
    ImportJob? resumeJob,
    bool reindex = false,
  }) async {
    final jobId = resumeJob?.id ?? idGenerator.generateId();
    var indexed = 0;
    var diagnostics = 0;
    var skipped = 0;
    var bytesRead = 0;
    var safeCheckpoint = resumeJob?.safeCheckpoint ?? 0;
    var lastAcceptedEnd = safeCheckpoint;
    var lastAcceptedOrdinal = resumeJob?.blocksScanned ?? 0;
    indexed = resumeJob?.blocksIndexed ?? 0;
    diagnostics = resumeJob?.diagnosticCount ?? 0;
    skipped = resumeJob?.blocksSkipped ?? 0;
    int? totalBytes;
    var reindexing = reindex;
    if (!PgnSourceOperationRegistry.tryBeginImport(database, sourceId)) {
      await operation.fail(
        jobId,
        PgnImportResumeDisposition.restart,
        'Another import is already active for this source.',
      );
      return;
    }
    try {
      operation.emit(
        PgnImportProgress(
          jobId: jobId,
          phase: PgnImportPhase.preparing,
          indexedBlockCount: 0,
          diagnosticCount: 0,
          cancellationRequested: false,
        ),
      );
      final source = await (database.select(
        database.pgnSources,
      )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
      if (source == null) {
        await operation.fail(
          jobId,
          PgnImportResumeDisposition.restart,
          'The source is not registered. Add it to the library and retry.',
        );
        return;
      }
      if (source.importState == 'deleted') {
        await operation.fail(
          jobId,
          PgnImportResumeDisposition.restart,
          'This book was removed from the library and cannot be indexed.',
          emitDiagnostic: false,
        );
        return;
      }
      // A new re-index request after an interrupted re-index starts a clean
      // scan from the original baseline. Resume, in contrast, keeps the
      // existing staged candidate rows and job ID.
      if (reindex && resumeJob == null && source.importState == 'reindexing') {
        final started = await database.transaction(() async {
          final currentSource = await (database.select(
            database.pgnSources,
          )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
          if (currentSource == null || currentSource.importState == 'deleted') {
            return false;
          }
          await database.customStatement(
            "DELETE FROM pgn_blocks WHERE source_id = ? AND reindex_job_id IS NOT NULL "
            "AND reindex_job_id NOT LIKE 'baseline:%'",
            [sourceId],
          );
          await database.customStatement(
            "UPDATE pgn_blocks SET is_current = 1, reindex_job_id = NULL "
            "WHERE source_id = ? AND reindex_job_id LIKE 'baseline:%'",
            [sourceId],
          );
          await (database.update(database.pgnSources)..where(
                (row) =>
                    row.id.equals(sourceId) &
                    row.importState.isNotValue('deleted'),
              ))
              .write(
                PgnSourcesCompanion(
                  importState: const Value('indexed'),
                  updatedAtMicros: Value(_nowMicros()),
                ),
              );
          return true;
        });
        if (!started) {
          await operation.fail(
            jobId,
            PgnImportResumeDisposition.restart,
            'This book was removed from the library and cannot be indexed.',
            emitDiagnostic: false,
          );
          return;
        }
      } else {
        reindexing = reindexing || source.importState == 'reindexing';
      }
      if (resumeJob != null) {
        final hasBaseline = await database
            .customSelect(
              'SELECT 1 FROM pgn_blocks WHERE source_id = ? AND reindex_job_id = ? LIMIT 1',
              variables: [
                Variable.withString(sourceId),
                Variable.withString('baseline:${resumeJob.id}'),
              ],
            )
            .get();
        reindexing = reindexing || hasBaseline.isNotEmpty;
        if (reindexing && source.importState != 'reindexing') {
          await (database.update(database.pgnSources)..where(
                (row) =>
                    row.id.equals(sourceId) &
                    row.importState.isNotValue('deleted'),
              ))
              .write(
                PgnSourcesCompanion(
                  importState: const Value('reindexing'),
                  updatedAtMicros: Value(_nowMicros()),
                ),
              );
        }
      }
      if (resumeJob == null && !reindexing) {
        final active =
            await (database.select(database.importJobs)
                  ..where(
                    (row) =>
                        row.sourceId.equals(sourceId) &
                        row.status.equals('indexing'),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (active != null) {
          await operation.fail(
            active.id,
            PgnImportResumeDisposition.resume,
            'An import for this source is already active or needs explicit resume.',
          );
          return;
        }
      } else if (resumeJob == null && reindexing) {
        final activeJobs =
            await (database.select(database.importJobs)..where(
                  (row) =>
                      row.sourceId.equals(sourceId) &
                      row.status.equals('indexing'),
                ))
                .get();
        for (final activeJob in activeJobs) {
          await (database.update(
            database.importJobs,
          )..where((row) => row.id.equals(activeJob.id))).write(
            ImportJobsCompanion(
              status: const Value('failed'),
              finishedAtMicros: Value(_nowMicros()),
            ),
          );
        }
      }
      final OpaqueSourceReference reference;
      if (source.accessMode == 'ExternalReference' &&
          source.externalReference != null) {
        try {
          reference = ExternalSourceReference(source.externalReference!);
        } on ArgumentError {
          await operation.fail(
            jobId,
            PgnImportResumeDisposition.repairSource,
            'The source reference cannot be opened. Repair the source and retry.',
          );
          return;
        }
      } else if (source.managedPath != null && source.managedPath!.isNotEmpty) {
        try {
          reference = ManagedSourceReference(source.managedPath!);
        } on ArgumentError {
          await operation.fail(
            jobId,
            PgnImportResumeDisposition.repairSource,
            'The source reference cannot be opened. Repair the source and retry.',
          );
          return;
        }
      } else {
        await operation.fail(
          jobId,
          PgnImportResumeDisposition.repairSource,
          'The source reference cannot be opened. Repair the source and retry.',
        );
        return;
      }
      totalBytes = await fileSource.length(reference);
      final fingerprintInput = await fileSource.fingerprintInput(reference);
      final fingerprint = SourceFingerprint.compute(fingerprintInput);
      if (resumeJob != null &&
          (resumeJob.scannerVersion == null ||
              resumeJob.sourceFingerprint == null ||
              resumeJob.sourceSizeBytes == null)) {
        await operation.fail(
          jobId,
          PgnImportResumeDisposition.restart,
          'This job predates resumable source snapshots. Restart indexing from the beginning.',
          indexedBlockCount: indexed,
          diagnosticCount: diagnostics,
          safeCheckpoint: safeCheckpoint,
        );
        return;
      }
      if (resumeJob != null &&
          (resumeJob.scannerVersion != scannerVersion ||
              resumeJob.sourceFingerprint == null ||
              resumeJob.sourceFingerprint != fingerprint ||
              resumeJob.sourceSizeBytes != totalBytes ||
              source.scannerVersion != scannerVersion ||
              source.sizeBytes != totalBytes ||
              source.fingerprint != fingerprint)) {
        throw const FileFailure(
          code: 'source_revision_changed',
          message: 'The source revision or scanner version changed.',
        );
      }
      if (!reindexing &&
          source.fingerprint != null &&
          source.fingerprint != fingerprint) {
        await operation.fail(
          jobId,
          PgnImportResumeDisposition.repairSource,
          'The saved source has changed. Repair or re-import it before indexing.',
        );
        return;
      }
      if (reindexing && resumeJob == null) {
        if (totalBytes == null) {
          throw const FileFailure(
            code: 'reindex_length_unknown',
            message:
                'The source length cannot be verified for safe re-indexing.',
          );
        }
        final maxOrdinalRows = await database
            .customSelect(
              'SELECT COALESCE(MAX(ordinal), -1) AS max_ordinal FROM pgn_blocks '
              "WHERE source_id = ? AND (is_current = 1 OR reindex_job_id LIKE 'baseline:%')",
              variables: [Variable.withString(sourceId)],
            )
            .getSingle();
        final oldMaxOrdinal = maxOrdinalRows.read<int>('max_ordinal');
        final ordinalOffset = oldMaxOrdinal + totalBytes + 1;
        final started = await database.transaction(() async {
          final currentSource = await (database.select(
            database.pgnSources,
          )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
          if (currentSource == null || currentSource.importState == 'deleted') {
            return false;
          }
          await database.customStatement(
            "DELETE FROM pgn_blocks WHERE source_id = ? AND reindex_job_id IS NOT NULL "
            "AND reindex_job_id NOT LIKE 'baseline:%'",
            [sourceId],
          );
          await database.customStatement(
            'UPDATE pgn_blocks SET ordinal = ordinal + ?, is_current = 0, '
            'reindex_job_id = ? WHERE source_id = ? AND is_current = 1',
            [ordinalOffset, 'baseline:$jobId', sourceId],
          );
          await (database.update(
            database.pgnSources,
          )..where((row) => row.id.equals(sourceId))).write(
            PgnSourcesCompanion(
              fingerprint: Value(fingerprint),
              sizeBytes: Value(totalBytes),
              modifiedAtMicros: Value(
                fingerprintInput.modifiedAt?.toUtc().microsecondsSinceEpoch,
              ),
              scannerVersion: const Value(scannerVersion),
              importState: const Value('reindexing'),
              safeCheckpoint: const Value(0),
              updatedAtMicros: Value(_nowMicros()),
            ),
          );
          await database
              .into(database.importJobs)
              .insert(
                ImportJobsCompanion.insert(
                  id: jobId,
                  sourceId: sourceId,
                  status: 'indexing',
                  startedAtMicros: _nowMicros(),
                  sourceFingerprint: Value(fingerprint),
                  scannerVersion: const Value(scannerVersion),
                  sourceSizeBytes: Value(totalBytes),
                ),
              );
          return true;
        });
        if (!started) {
          await operation.fail(
            jobId,
            PgnImportResumeDisposition.restart,
            'This book was removed from the library and cannot be indexed.',
            emitDiagnostic: false,
          );
          return;
        }
      }
      if (resumeJob == null && !reindexing) {
        final existingCount =
            await (database.selectOnly(database.pgnBlocks)
                  ..addColumns([database.pgnBlocks.id.count()])
                  ..where(database.pgnBlocks.sourceId.equals(sourceId)))
                .map((row) => row.read(database.pgnBlocks.id.count()) ?? 0)
                .getSingle();
        if (existingCount > 0 || source.importState == 'indexed') {
          await operation.fail(
            jobId,
            PgnImportResumeDisposition.restart,
            'This source is already indexed. Start from a repaired or new source.',
          );
          return;
        }
        final started = await database.transaction(() async {
          final currentSource = await (database.select(
            database.pgnSources,
          )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
          if (currentSource == null || currentSource.importState == 'deleted') {
            return false;
          }
          if (currentSource.fingerprint == null) {
            await (database.update(
              database.pgnSources,
            )..where((row) => row.id.equals(sourceId))).write(
              PgnSourcesCompanion(
                fingerprint: Value(fingerprint),
                sizeBytes: Value(totalBytes),
                scannerVersion: const Value(scannerVersion),
              ),
            );
          }
          await database
              .into(database.importJobs)
              .insert(
                ImportJobsCompanion.insert(
                  id: jobId,
                  sourceId: sourceId,
                  status: 'indexing',
                  startedAtMicros: _nowMicros(),
                  sourceFingerprint: Value(fingerprint),
                  scannerVersion: const Value(scannerVersion),
                  sourceSizeBytes: Value(totalBytes),
                ),
              );
          return true;
        });
        if (!started) {
          await operation.fail(
            jobId,
            PgnImportResumeDisposition.restart,
            'This book was removed from the library and cannot be indexed.',
            emitDiagnostic: false,
          );
          return;
        }
      } else if (resumeJob != null) {
        final resumed = await database.transaction(() async {
          final currentSource = await (database.select(
            database.pgnSources,
          )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
          if (currentSource == null || currentSource.importState == 'deleted') {
            return false;
          }
          await (database.update(
            database.importJobs,
          )..where((row) => row.id.equals(jobId))).write(
            const ImportJobsCompanion(
              status: Value('indexing'),
              cancellationRequested: Value(false),
              finishedAtMicros: Value(null),
            ),
          );
          return true;
        });
        if (!resumed) {
          await operation.fail(
            jobId,
            PgnImportResumeDisposition.restart,
            'This book was removed from the library and cannot be indexed.',
            emitDiagnostic: false,
          );
          return;
        }
      }

      if (operation.isCancelled) {
        await _terminal(
          sourceId,
          resumeJob,
          jobId,
          'cancelled',
          safeCheckpoint,
          resumeJob?.blocksScanned ?? 0,
          indexed,
          diagnostics,
          skipped: skipped,
          isReindexing: reindexing,
        );
        operation.cancelled(
          jobId,
          indexed,
          diagnostics,
          safeCheckpoint,
          totalBytes: totalBytes,
        );
        return;
      }

      final batchBlocks = <_PendingBlock>[];
      final batchDiagnostics = <PgnImportDiagnostic>[];
      final batchDuplicateMarks = <PgnBlock>[];
      late Future<void> Function(int) commit;
      final scanner = PgnBoundaryScanner(startOffset: safeCheckpoint);
      var ordinal = resumeJob?.blocksScanned ?? 0;

      Future<void> accept(PgnBlockRange range) async {
        final currentOrdinal = ordinal++;
        lastAcceptedEnd = range.endOffset;
        lastAcceptedOrdinal = ordinal;
        if (range.isMalformed) {
          skipped++;
          batchDiagnostics.add(
            PgnImportDiagnostic(
              severity: PgnImportDiagnosticSeverity.warning,
              category: PgnImportDiagnosticCategory.malformedBlock,
              sourceId: sourceId,
              sourceOffset: range.startOffset,
              blockOrdinal: currentOrdinal,
              message:
                  'A malformed PGN block was skipped. Check the source file.',
            ),
          );
          if (batchBlocks.length + batchDiagnostics.length >= _batchSize) {
            await commit(range.endOffset);
          }
          return;
        }
        final length = range.endOffset - range.startOffset;
        if (length > _maximumBlockBytes) {
          skipped++;
          batchDiagnostics.add(
            PgnImportDiagnostic(
              severity: PgnImportDiagnosticSeverity.warning,
              category: PgnImportDiagnosticCategory.malformedBlock,
              sourceId: sourceId,
              sourceOffset: range.startOffset,
              blockOrdinal: currentOrdinal,
              message: 'A PGN block exceeds the supported metadata size and was skipped.',
            ),
          );
          await commit(range.endOffset);
          return;
        }
        final bytes = await fileSource.readRange(
          reference,
          start: range.startOffset,
          endExclusive: range.endOffset,
        );
        String text;
        try {
          text = utf8.decode(bytes, allowMalformed: false);
        } on FormatException {
          skipped++;
          batchDiagnostics.add(
            PgnImportDiagnostic(
              severity: PgnImportDiagnosticSeverity.warning,
              category: PgnImportDiagnosticCategory.invalidEncoding,
              sourceId: sourceId,
              sourceOffset: range.startOffset,
              blockOrdinal: currentOrdinal,
              message: 'A PGN block has invalid text encoding and was skipped.',
            ),
          );
          if (batchBlocks.length + batchDiagnostics.length >= _batchSize) {
            await commit(range.endOffset);
          }
          return;
        }
        final read = const PgnHeaderReader().read(text);
        if (read.isMalformed) {
          skipped++;
          batchDiagnostics.add(
            PgnImportDiagnostic(
              severity: PgnImportDiagnosticSeverity.warning,
              category: PgnImportDiagnosticCategory.malformedBlock,
              sourceId: sourceId,
              sourceOffset: range.startOffset,
              blockOrdinal: currentOrdinal,
              message:
                  'A malformed PGN header was skipped. Check the source file.',
            ),
          );
          if (batchBlocks.length + batchDiagnostics.length >= _batchSize) {
            await commit(range.endOffset);
          }
          return;
        }
        final headers = read.headers;
        final authoredId = headers['X-ExerciseId'];
        final authoredIdentity =
            ExerciseIdentityResolver.isValidAuthoredId(authoredId)
            ? authoredId
            : null;
        var duplicate = false;
        PgnBlock? persistedDuplicate;
        _PendingBlock? batchDuplicate;
        if (authoredIdentity != null) {
          batchDuplicate = batchBlocks.cast<_PendingBlock?>().firstWhere(
            (item) => item?.authoredExerciseId == authoredIdentity,
            orElse: () => null,
          );
          persistedDuplicate = await _findAuthoredDuplicate(
            sourceId: sourceId,
            authoredId: authoredIdentity,
            reindexing: reindexing,
            jobId: jobId,
          );
          duplicate = batchDuplicate != null || persistedDuplicate != null;
        }
        final classification = const ContentClassifier().classify(headers);
        final movetext = text.substring(read.movetextOffset).trim();
        final identity = const ExerciseIdentityResolver().resolve(
          sourceId: sourceId,
          startOffset: range.startOffset,
          headers: headers,
          authoredLine: movetext,
          duplicateAuthoredId: duplicate,
        );
        if (duplicate) {
          if (batchDuplicate != null &&
              batchDuplicate.index.diagnosticSummary == null) {
            final marked = _withDuplicateSummary(batchDuplicate.index);
            final index = batchBlocks.indexOf(batchDuplicate);
            batchBlocks[index] = _PendingBlock(
              marked,
              batchDuplicate.exerciseId,
              batchDuplicate.authoredExerciseId,
              batchDuplicate.fallbackIdentityKey,
            );
            batchDiagnostics.add(
              _duplicateDiagnostic(
                sourceId,
                marked.startOffset,
                marked.ordinal,
              ),
            );
          } else if (persistedDuplicate != null &&
              persistedDuplicate.diagnosticSummary == null) {
            batchDuplicateMarks.add(persistedDuplicate);
            batchDiagnostics.add(
              _duplicateDiagnostic(
                sourceId,
                persistedDuplicate.startOffset,
                persistedDuplicate.ordinal,
              ),
            );
          }
          batchDiagnostics.add(
            _duplicateDiagnostic(sourceId, range.startOffset, currentOrdinal),
          );
        }
        final fields = <String, String>{};
        for (final key in const [
          'Section',
          'Sequence',
          'Theme',
          'Difficulty',
        ]) {
          final value = headers['X-$key'];
          if (value != null) fields[key] = value;
        }
        final sequence = int.tryParse(fields['Sequence'] ?? '');
        batchBlocks.add(
          _PendingBlock(
            PgnBlockIndex(
              id: idGenerator.generateId(),
              sourceId: sourceId,
              startOffset: range.startOffset,
              endOffset: range.endOffset,
              ordinal: currentOrdinal,
              event: headers['Event'],
              site: headers['Site'],
              date: headers['Date'],
              round: headers['Round'],
              white: headers['White'],
              black: headers['Black'],
              result: headers['Result'],
              contentType: classification.contentType,
              exerciseId: identity.exerciseId,
              section: fields['Section'],
              sequence: sequence,
              theme: fields['Theme'],
              difficulty: fields['Difficulty'],
              parseStatus: classification.contentType == ContentType.unsupported
                  ? PgnBlockParseStatus.unsupported
                  : PgnBlockParseStatus.notParsed,
              diagnosticSummary: duplicate ? 'duplicateExerciseId' : null,
              inferredClassification: classification.inferred,
              authoredContentType: classification.authoredValue,
            ),
            identity.exerciseId,
            identity.authoredExerciseId,
            identity.fallbackIdentityKey,
          ),
        );
        if (classification.contentType == ContentType.unsupported) {
          batchDiagnostics.add(
            PgnImportDiagnostic(
              severity: PgnImportDiagnosticSeverity.warning,
              category: PgnImportDiagnosticCategory.unsupportedContent,
              sourceId: sourceId,
              sourceOffset: range.startOffset,
              blockOrdinal: currentOrdinal,
              message: 'This block uses an unsupported content type and was preserved without chess interpretation.',
            ),
          );
        }
        if (batchBlocks.length + batchDiagnostics.length >= _batchSize) {
          await commit(range.endOffset);
        }
      }

      commit = (int checkpoint) async {
        if (batchBlocks.isEmpty &&
            batchDiagnostics.isEmpty &&
            checkpoint == safeCheckpoint) {
          return;
        }
        final diagnosticRoom = max(0, _maximumDiagnostics - diagnostics);
        final committedDiagnostics = batchDiagnostics
            .take(diagnosticRoom)
            .toList(growable: false);
        await database.transaction(() async {
          final currentSource = await (database.select(
            database.pgnSources,
          )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
          if (currentSource == null || currentSource.importState == 'deleted') {
            throw const _SourceRemovedDuringImport();
          }
          for (final item in batchBlocks) {
            final b = item.index;
            await database
                .into(database.pgnBlocks)
                .insert(
                  PgnBlocksCompanion.insert(
                    id: b.id,
                    sourceId: b.sourceId,
                    startOffset: b.startOffset,
                    endOffset: b.endOffset,
                    ordinal: b.ordinal,
                    contentType: b.contentType.toDatabaseValue(),
                    parseStatus: b.parseStatus.toDatabaseValue(),
                    event: Value(b.event),
                    site: Value(b.site),
                    date: Value(b.date),
                    round: Value(b.round),
                    white: Value(b.white),
                    black: Value(b.black),
                    result: Value(b.result),
                    exerciseId: Value(b.exerciseId),
                    section: Value(b.section),
                    sequence: Value(b.sequence),
                    theme: Value(b.theme),
                    difficulty: Value(b.difficulty),
                    diagnosticSummary: Value(b.diagnosticSummary),
                    inferredClassification: Value(b.inferredClassification),
                    authoredContentType: Value(b.authoredContentType),
                  ),
                );
            await database.customStatement(
              'UPDATE pgn_blocks SET authored_exercise_id = ?, '
              'fallback_identity_key = ?, is_current = ?, reindex_job_id = ? '
              'WHERE id = ?',
              [
                item.authoredExerciseId,
                item.fallbackIdentityKey,
                reindexing ? 0 : 1,
                reindexing ? jobId : null,
                b.id,
              ],
            );
          }
          for (final priorBlock in batchDuplicateMarks) {
            await (database.update(
              database.pgnBlocks,
            )..where((row) => row.id.equals(priorBlock.id))).write(
              PgnBlocksCompanion(
                diagnosticSummary: const Value('duplicateExerciseId'),
              ),
            );
          }
          for (final diagnostic in committedDiagnostics) {
            await database
                .into(database.importDiagnostics)
                .insert(
                  ImportDiagnosticsCompanion.insert(
                    id: idGenerator.generateId(),
                    importJobId: jobId,
                    severity: diagnostic.severity.name,
                    blockOrdinal: Value(diagnostic.blockOrdinal),
                    startOffset: Value(diagnostic.sourceOffset),
                    endOffset: const Value.absent(),
                    diagnosticCode: diagnostic.category.name,
                    sanitizedMessage: diagnostic.message,
                    createdAtMicros: _nowMicros(),
                  ),
                );
          }
          await (database.update(
            database.importJobs,
          )..where((r) => r.id.equals(jobId))).write(
            ImportJobsCompanion(
              status: const Value('indexing'),
              bytesProcessed: Value(checkpoint),
              blocksScanned: Value(ordinal),
              blocksIndexed: Value(indexed + batchBlocks.length),
              blocksSkipped: Value(skipped),
              diagnosticCount: Value(diagnostics + committedDiagnostics.length),
              safeCheckpoint: Value(checkpoint),
            ),
          );
          await (database.update(
            database.pgnSources,
          )..where((r) => r.id.equals(sourceId))).write(
            PgnSourcesCompanion(
              safeCheckpoint: Value(checkpoint),
              importState: const Value('indexing'),
              updatedAtMicros: Value(_nowMicros()),
            ),
          );
        });
        indexed += batchBlocks.length;
        for (final diagnostic in committedDiagnostics) {
          operation.emitDiagnostic(diagnostic);
        }
        diagnostics += committedDiagnostics.length;
        batchBlocks.clear();
        batchDiagnostics.clear();
        batchDuplicateMarks.clear();
        safeCheckpoint = checkpoint;
        operation.emit(
          PgnImportProgress(
            jobId: jobId,
            phase: PgnImportPhase.indexing,
            bytesRead: bytesRead,
            totalBytes: totalBytes,
            indexedBlockCount: indexed,
            diagnosticCount: diagnostics,
            cancellationRequested: false,
            safeCheckpoint: safeCheckpoint,
          ),
        );
      };

      operation.emit(
        PgnImportProgress(
          jobId: jobId,
          phase: PgnImportPhase.indexing,
          bytesRead: 0,
          totalBytes: totalBytes,
          indexedBlockCount: 0,
          diagnosticCount: 0,
          cancellationRequested: false,
        ),
      );
      if (operation.isCancelled) {
        await _terminal(
          sourceId,
          resumeJob,
          jobId,
          'cancelled',
          safeCheckpoint,
          ordinal,
          indexed,
          diagnostics,
          skipped: skipped,
          isReindexing: reindexing,
        );
        operation.cancelled(
          jobId,
          indexed,
          diagnostics,
          safeCheckpoint,
          totalBytes: totalBytes,
        );
        return;
      }
      var skipBytes = safeCheckpoint;
      await for (final incoming in fileSource.openReadStream(reference)) {
        for (var offset = 0; offset < incoming.length; offset += _chunkSize) {
          final end = min(offset + _chunkSize, incoming.length);
          final piece = incoming.sublist(offset, end);
          if (skipBytes >= piece.length) {
            skipBytes -= piece.length;
            bytesRead += piece.length;
            continue;
          }
          final usable = skipBytes == 0 ? piece : piece.sublist(skipBytes);
          bytesRead += piece.length;
          skipBytes = 0;
          final ranges = scanner.consume(usable);
          for (final range in ranges) {
            await accept(range);
            if (operation.isCancelled) break;
          }
          if (operation.isCancelled) break;
          await Future<void>.delayed(Duration.zero);
        }
        if (operation.isCancelled) break;
      }
      if (operation.isCancelled) {
        // Pending complete ranges can be safely committed. The checkpoint
        // remains at the last completed range; unresolved scanner bytes stay uncommitted.
        final checkpoint = lastAcceptedEnd;
        await commit(checkpoint);
        await _terminal(
          sourceId,
          resumeJob,
          jobId,
          'cancelled',
          checkpoint,
          lastAcceptedOrdinal,
          indexed,
          diagnostics,
          skipped: skipped,
          isReindexing: reindexing,
        );
        operation.cancelled(
          jobId,
          indexed,
          diagnostics,
          safeCheckpoint,
          totalBytes: totalBytes,
        );
        return;
      }
      for (final range in scanner.finish()) {
        await accept(range);
      }
      if (ordinal == 0 && batchBlocks.isEmpty && batchDiagnostics.isEmpty) {
        batchDiagnostics.add(
          PgnImportDiagnostic(
            severity: PgnImportDiagnosticSeverity.info,
            category: PgnImportDiagnosticCategory.other,
            sourceId: sourceId,
            message: 'The source contains no PGN blocks. Choose a file with games or training content.',
          ),
        );
      }
      await commit(bytesRead);
      if (reindexing) {
        final unresolved = await _finishReindex(
          sourceId,
          jobId,
          allowDiagnostic: diagnostics < _maximumDiagnostics,
        );
        if (unresolved != null && diagnostics < _maximumDiagnostics) {
          diagnostics++;
          operation.emitDiagnostic(unresolved);
        }
      }
      final finalized = await database.transaction(() async {
        final currentSource = await (database.select(
          database.pgnSources,
        )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
        if (currentSource == null || currentSource.importState == 'deleted') {
          return false;
        }
        await (database.update(
          database.importJobs,
        )..where((r) => r.id.equals(jobId))).write(
          ImportJobsCompanion(
            status: const Value('completed'),
            finishedAtMicros: Value(_nowMicros()),
            bytesProcessed: Value(bytesRead),
            safeCheckpoint: Value(bytesRead),
          ),
        );
        await (database.update(
          database.pgnSources,
        )..where((r) => r.id.equals(sourceId))).write(
          PgnSourcesCompanion(
            importState: const Value('indexed'),
            safeCheckpoint: Value(bytesRead),
            updatedAtMicros: Value(_nowMicros()),
          ),
        );
        return true;
      });
      if (!finalized) throw const _SourceRemovedDuringImport();
      operation.complete(
        PgnImportResult(
          jobId: jobId,
          phase: PgnImportPhase.completed,
          indexedBlockCount: indexed,
          diagnosticCount: diagnostics,
          resumeDisposition: PgnImportResumeDisposition.none,
        ),
        bytesRead: bytesRead,
        totalBytes: totalBytes,
        safeCheckpoint: bytesRead,
      );
    } on _SourceRemovedDuringImport {
      operation.complete(
        PgnImportResult(
          jobId: jobId,
          phase: PgnImportPhase.failed,
          indexedBlockCount: indexed,
          diagnosticCount: diagnostics,
          resumeDisposition: PgnImportResumeDisposition.restart,
        ),
        safeCheckpoint: safeCheckpoint,
      );
    } catch (error) {
      final isFileFailure = error is FileFailure;
      final category = isFileFailure
          ? ((error.code.toLowerCase().contains('changed') ||
                    error.code.toLowerCase().contains('revision'))
                ? PgnImportDiagnosticCategory.sourceChanged
                : PgnImportDiagnosticCategory.sourceUnavailable)
          : PgnImportDiagnosticCategory.storageFailure;
      var disposition = isFileFailure
          ? PgnImportResumeDisposition.repairSource
          : PgnImportResumeDisposition.resume;
      final message = isFileFailure
          ? 'The source could not be read. Repair or relink it, then retry.'
          : 'Indexing stopped after a storage error. Previously committed blocks are preserved; resume to continue.';
      var failureDiagnosticCount = min(_maximumDiagnostics, diagnostics + 1);
      var emitFailureDiagnostic = diagnostics < _maximumDiagnostics;
      var committedCheckpoint = safeCheckpoint;
      var committedIndexed = indexed;
      try {
        final savedJob = await (database.select(
          database.importJobs,
        )..where((r) => r.id.equals(jobId))).getSingleOrNull();
        if (savedJob == null && !isFileFailure) {
          disposition = PgnImportResumeDisposition.restart;
        }
        if (savedJob != null) {
          // The persisted job is the authority after rollback. Local counters
          // may include ranges from the failed, uncommitted batch.
          committedCheckpoint = savedJob.safeCheckpoint;
          committedIndexed = savedJob.blocksIndexed;
          emitFailureDiagnostic =
              savedJob.diagnosticCount < _maximumDiagnostics;
          failureDiagnosticCount = min(
            _maximumDiagnostics,
            savedJob.diagnosticCount + 1,
          );
          final d = PgnImportDiagnostic(
            severity: PgnImportDiagnosticSeverity.error,
            category: category,
            sourceId: sourceId,
            message: message,
          );
          await database.transaction(() async {
            final currentSource = await (database.select(
              database.pgnSources,
            )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
            if (currentSource == null ||
                currentSource.importState == 'deleted') {
              return;
            }
            if (savedJob.diagnosticCount < _maximumDiagnostics) {
              await database
                  .into(database.importDiagnostics)
                  .insert(
                    ImportDiagnosticsCompanion.insert(
                      id: idGenerator.generateId(),
                      importJobId: jobId,
                      severity: d.severity.name,
                      blockOrdinal: const Value.absent(),
                      startOffset: const Value.absent(),
                      endOffset: const Value.absent(),
                      diagnosticCode: d.category.name,
                      sanitizedMessage: d.message,
                      createdAtMicros: _nowMicros(),
                    ),
                  );
            }
            await (database.update(
              database.importJobs,
            )..where((r) => r.id.equals(jobId))).write(
              ImportJobsCompanion(
                status: const Value('failed'),
                finishedAtMicros: Value(_nowMicros()),
                diagnosticCount: Value(failureDiagnosticCount),
              ),
            );
            await (database.update(
              database.pgnSources,
            )..where((r) => r.id.equals(sourceId))).write(
              PgnSourcesCompanion(
                importState: Value(reindexing ? 'reindexing' : 'failed'),
                safeCheckpoint: Value(committedCheckpoint),
                updatedAtMicros: Value(_nowMicros()),
              ),
            );
          });
        }
      } catch (_) {
        // A failed database cannot reliably persist another diagnostic. The
        // committed checkpoint and prior rows remain authoritative.
      }
      await operation.fail(
        jobId,
        disposition,
        message,
        category: category,
        sourceId: sourceId,
        indexedBlockCount: committedIndexed,
        diagnosticCount: failureDiagnosticCount,
        safeCheckpoint: committedCheckpoint,
        emitDiagnostic: emitFailureDiagnostic,
      );
    } finally {
      PgnSourceOperationRegistry.endImport(database, sourceId);
    }
  }

  int _nowMicros() => clock.utcNow.toUtc().microsecondsSinceEpoch;

  Future<PgnImportDiagnostic?> _finishReindex(
    String sourceId,
    String jobId, {
    required bool allowDiagnostic,
  }) async {
    final baseline = await database
        .customSelect(
          "SELECT id, ordinal, authored_exercise_id, fallback_identity_key, exercise_id, "
          "diagnostic_summary FROM pgn_blocks WHERE source_id = ? AND reindex_job_id = ?",
          variables: [
            Variable.withString(sourceId),
            Variable.withString('baseline:$jobId'),
          ],
        )
        .get();
    final candidates = await database
        .customSelect(
          'SELECT id, ordinal, authored_exercise_id, fallback_identity_key, exercise_id, '
          'diagnostic_summary FROM pgn_blocks WHERE source_id = ? AND reindex_job_id = ?',
          variables: [
            Variable.withString(sourceId),
            Variable.withString(jobId),
          ],
        )
        .get();
    final matched = <(String, String)>[];
    final usedCandidates = <String>{};
    final usedBaseline = <String>{};

    Map<String, List<QueryRow>> groups(
      List<QueryRow> rows,
      String column, {
      bool excludeDuplicates = false,
    }) {
      final result = <String, List<QueryRow>>{};
      for (final row in rows) {
        if (excludeDuplicates &&
            row.read<String?>('diagnostic_summary') == 'duplicateExerciseId') {
          continue;
        }
        // An authored identity is authoritative. Content fallback keys can
        // pair generated identities only when both records lack authored IDs.
        if (column == 'fallback_identity_key' &&
            row.read<String?>('authored_exercise_id') != null) {
          continue;
        }
        final value = row.read<String?>(column);
        if (value != null && value.isNotEmpty) (result[value] ??= []).add(row);
      }
      return result;
    }

    void pairUnique(String column, {required bool excludeDuplicates}) {
      final oldGroups = groups(
        baseline,
        column,
        excludeDuplicates: excludeDuplicates,
      );
      final newGroups = groups(
        candidates,
        column,
        excludeDuplicates: excludeDuplicates,
      );
      for (final entry in oldGroups.entries) {
        final oldRows = entry.value;
        final newRows = newGroups[entry.key];
        if (oldRows.length != 1 || newRows == null || newRows.length != 1) {
          continue;
        }
        final oldId = oldRows.single.read<String>('id');
        final newId = newRows.single.read<String>('id');
        if (usedBaseline.add(oldId) && usedCandidates.add(newId)) {
          matched.add((oldId, newId));
        }
      }
    }

    // Authored IDs are authoritative only when unique on both sides. Fallback
    // keys are content-derived and likewise require an unambiguous match.
    pairUnique('authored_exercise_id', excludeDuplicates: true);
    pairUnique('fallback_identity_key', excludeDuplicates: true);

    // Any unmatched legacy row without explicit authored provenance has no
    // safe identity match. This includes a known fallback whose content key
    // changed, not only older rows with no stored fallback key.
    final unresolvedLegacyFallback = baseline.any(
      (row) =>
          !usedBaseline.contains(row.read<String>('id')) &&
          row.read<String?>('authored_exercise_id') == null,
    );

    await database.transaction(() async {
      for (final pair in matched) {
        final candidateOrdinal = candidates
            .firstWhere((row) => row.read<String>('id') == pair.$2)
            .read<int>('ordinal');
        await database.customStatement(
          'UPDATE pgn_blocks SET start_offset = (SELECT start_offset FROM pgn_blocks WHERE id = ?), '
          'end_offset = (SELECT end_offset FROM pgn_blocks WHERE id = ?), '
          'event = (SELECT event FROM pgn_blocks WHERE id = ?), site = (SELECT site FROM pgn_blocks WHERE id = ?), '
          'date = (SELECT date FROM pgn_blocks WHERE id = ?), round = (SELECT round FROM pgn_blocks WHERE id = ?), '
          'white = (SELECT white FROM pgn_blocks WHERE id = ?), black = (SELECT black FROM pgn_blocks WHERE id = ?), '
          'result = (SELECT result FROM pgn_blocks WHERE id = ?), content_type = (SELECT content_type FROM pgn_blocks WHERE id = ?), '
          'exercise_id = (SELECT exercise_id FROM pgn_blocks WHERE id = ?), section = (SELECT section FROM pgn_blocks WHERE id = ?), '
          'sequence = (SELECT sequence FROM pgn_blocks WHERE id = ?), theme = (SELECT theme FROM pgn_blocks WHERE id = ?), '
          'difficulty = (SELECT difficulty FROM pgn_blocks WHERE id = ?), parse_status = (SELECT parse_status FROM pgn_blocks WHERE id = ?), '
          'diagnostic_summary = (SELECT diagnostic_summary FROM pgn_blocks WHERE id = ?), '
          'inferred_classification = (SELECT inferred_classification FROM pgn_blocks WHERE id = ?), '
          'authored_content_type = (SELECT authored_content_type FROM pgn_blocks WHERE id = ?), '
          'authored_exercise_id = (SELECT authored_exercise_id FROM pgn_blocks WHERE id = ?), '
          'fallback_identity_key = (SELECT fallback_identity_key FROM pgn_blocks WHERE id = ?), '
          'is_current = 1, reindex_job_id = NULL WHERE id = ?',
          [...List<String>.filled(21, pair.$2), pair.$1],
        );
        await database.customStatement('DELETE FROM pgn_blocks WHERE id = ?', [
          pair.$2,
        ]);
        await database.customStatement(
          'UPDATE pgn_blocks SET ordinal = ? WHERE id = ?',
          [candidateOrdinal, pair.$1],
        );
      }
      await database.customStatement(
        'UPDATE pgn_blocks SET is_current = 1, reindex_job_id = NULL WHERE source_id = ? AND reindex_job_id = ?',
        [sourceId, jobId],
      );
      await database.customStatement(
        "UPDATE pgn_blocks SET reindex_job_id = NULL WHERE source_id = ? AND reindex_job_id = ?",
        [sourceId, 'baseline:$jobId'],
      );
      if (unresolvedLegacyFallback && allowDiagnostic) {
        await database
            .into(database.importDiagnostics)
            .insert(
              ImportDiagnosticsCompanion.insert(
                id: idGenerator.generateId(),
                importJobId: jobId,
                severity: 'warning',
                diagnosticCode: 'unresolvedFallbackIdentity',
                sanitizedMessage: 'Some legacy fallback identities could not be matched safely.',
                createdAtMicros: _nowMicros(),
              ),
            );
      }
    });
    if (!unresolvedLegacyFallback || !allowDiagnostic) return null;
    return PgnImportDiagnostic(
      severity: PgnImportDiagnosticSeverity.warning,
      category: PgnImportDiagnosticCategory.unresolvedFallbackIdentity,
      sourceId: sourceId,
      message: 'Some legacy fallback identities could not be matched safely; prior training history remains attached to stale items.',
    );
  }

  Future<PgnBlock?> _findAuthoredDuplicate({
    required String sourceId,
    required String authoredId,
    required bool reindexing,
    required String jobId,
  }) async {
    final currentClause = reindexing
        ? 'reindex_job_id = ?'
        : 'is_current = 1 AND reindex_job_id IS NULL';
    final variables = <Variable<Object>>[
      Variable.withString(sourceId),
      Variable.withString(authoredId),
      if (reindexing) Variable.withString(jobId),
    ];
    final matches = await database
        .customSelect(
          'SELECT id FROM pgn_blocks WHERE source_id = ? '
          'AND authored_exercise_id = ? AND $currentClause LIMIT 1',
          variables: variables,
        )
        .get();
    if (matches.isEmpty) return null;
    final id = matches.first.read<String>('id');
    return (database.select(
      database.pgnBlocks,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<void> _terminal(
    String sourceId,
    ImportJob? prior,
    String jobId,
    String status,
    int checkpoint,
    int scanned,
    int indexed,
    int diagnostics, {
    int skipped = 0,
    bool isReindexing = false,
  }) async {
    await database.transaction(() async {
      final currentSource = await (database.select(
        database.pgnSources,
      )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
      if (currentSource == null || currentSource.importState == 'deleted') {
        return;
      }
      await (database.update(
        database.importJobs,
      )..where((r) => r.id.equals(jobId))).write(
        ImportJobsCompanion(
          status: Value(status),
          bytesProcessed: Value(checkpoint),
          blocksScanned: Value(scanned),
          blocksIndexed: Value(indexed),
          blocksSkipped: Value(skipped),
          diagnosticCount: Value(diagnostics),
          safeCheckpoint: Value(checkpoint),
          cancellationRequested: Value(status == 'cancelled'),
          finishedAtMicros: Value(_nowMicros()),
        ),
      );
      await (database.update(
        database.pgnSources,
      )..where((r) => r.id.equals(sourceId))).write(
        PgnSourcesCompanion(
          importState: Value(
            status == 'cancelled' && isReindexing ? 'reindexing' : status,
          ),
          safeCheckpoint: Value(checkpoint),
          updatedAtMicros: Value(_nowMicros()),
        ),
      );
    });
  }
}

final class _PendingBlock {
  const _PendingBlock(
    this.index,
    this.exerciseId,
    this.authoredExerciseId,
    this.fallbackIdentityKey,
  );
  final PgnBlockIndex index;
  final String exerciseId;
  final String? authoredExerciseId;
  final String? fallbackIdentityKey;
}

final class _SourceRemovedDuringImport implements Exception {
  const _SourceRemovedDuringImport();
}

PgnBlockIndex _withDuplicateSummary(PgnBlockIndex b) => PgnBlockIndex(
  id: b.id,
  sourceId: b.sourceId,
  startOffset: b.startOffset,
  endOffset: b.endOffset,
  ordinal: b.ordinal,
  event: b.event,
  site: b.site,
  date: b.date,
  round: b.round,
  white: b.white,
  black: b.black,
  result: b.result,
  contentType: b.contentType,
  exerciseId: b.exerciseId,
  section: b.section,
  sequence: b.sequence,
  theme: b.theme,
  difficulty: b.difficulty,
  parseStatus: b.parseStatus,
  diagnosticSummary: 'duplicateExerciseId',
  inferredClassification: b.inferredClassification,
  authoredContentType: b.authoredContentType,
);

PgnImportDiagnostic _duplicateDiagnostic(
  String sourceId,
  int offset,
  int ordinal,
) => PgnImportDiagnostic(
  severity: PgnImportDiagnosticSeverity.warning,
  category: PgnImportDiagnosticCategory.duplicateExerciseId,
  sourceId: sourceId,
  sourceOffset: offset,
  blockOrdinal: ordinal,
  message: 'A repeated exercise ID was found. Review this block identity.',
);

final class _ImportOperation implements PgnImportOperation {
  final _progress = StreamController<PgnImportProgress>.broadcast();
  final _diagnostics = StreamController<PgnImportDiagnostic>.broadcast();
  final Completer<PgnImportResult> _result = Completer<PgnImportResult>();
  bool _cancelRequested = false;
  bool get isCancelled => _cancelRequested;
  @override
  Stream<PgnImportProgress> get progress => _progress.stream;
  @override
  Stream<PgnImportDiagnostic> get diagnostics => _diagnostics.stream;
  @override
  Future<PgnImportResult> get result => _result.future;
  void emit(PgnImportProgress value) {
    if (!_progress.isClosed) _progress.add(value);
  }

  void emitDiagnostic(PgnImportDiagnostic value) {
    if (!_diagnostics.isClosed) _diagnostics.add(value);
  }

  void complete(
    PgnImportResult value, {
    int? bytesRead,
    int? totalBytes,
    required int safeCheckpoint,
    bool cancellationRequested = false,
  }) {
    emit(
      PgnImportProgress(
        jobId: value.jobId,
        phase: value.phase,
        bytesRead: bytesRead,
        totalBytes: totalBytes,
        indexedBlockCount: value.indexedBlockCount,
        diagnosticCount: value.diagnosticCount,
        cancellationRequested: cancellationRequested,
        safeCheckpoint: safeCheckpoint,
      ),
    );
    _result.complete(value);
    unawaited(_progress.close());
    unawaited(_diagnostics.close());
  }

  Future<void> fail(
    String jobId,
    PgnImportResumeDisposition disposition,
    String message, {
    int indexedBlockCount = 0,
    int diagnosticCount = 1,
    int safeCheckpoint = 0,
    PgnImportDiagnosticCategory category = PgnImportDiagnosticCategory.other,
    String? sourceId,
    bool emitDiagnostic = true,
  }) async {
    final result = PgnImportResult(
      jobId: jobId,
      phase: PgnImportPhase.failed,
      indexedBlockCount: indexedBlockCount,
      diagnosticCount: diagnosticCount,
      resumeDisposition: disposition,
    );
    final d = PgnImportDiagnostic(
      severity: PgnImportDiagnosticSeverity.error,
      category: category,
      sourceId: sourceId,
      message: message,
    );
    if (emitDiagnostic && !_diagnostics.isClosed) _diagnostics.add(d);
    complete(result, safeCheckpoint: safeCheckpoint);
  }

  @override
  Future<void> cancel() async {
    _cancelRequested = true;
  }

  void cancelled(
    String jobId,
    int indexed,
    int diagnostics,
    int checkpoint, {
    int? totalBytes,
  }) {
    complete(
      PgnImportResult(
        jobId: jobId,
        phase: PgnImportPhase.cancelled,
        indexedBlockCount: indexed,
        diagnosticCount: diagnostics,
        resumeDisposition: PgnImportResumeDisposition.resume,
      ),
      bytesRead: checkpoint,
      totalBytes: totalBytes,
      safeCheckpoint: checkpoint,
      cancellationRequested: true,
    );
  }
}
