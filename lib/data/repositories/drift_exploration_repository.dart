import 'dart:convert';

import 'package:drift/drift.dart' show Variable;

import '../../domain/analysis/exploration_repository.dart';
import '../../domain/analysis/exploration_session.dart';
import '../database/app_database.dart';

/// Persists one versioned exploration draft per source revision and authored
/// occurrence, using the existing app settings table.
final class DriftExplorationRepository implements ExplorationRepository {
  DriftExplorationRepository(this._database);

  static const int _storageVersion = 1;
  static const String _keyPrefix = 'analysis.exploration.v1.';

  final AppDatabase _database;
  Future<void> _queue = Future<void>.value();

  @override
  Future<ExplorationSession?> load(ExplorationOrigin origin) {
    _validateOrigin(origin);
    return _enqueue(() => _load(origin));
  }

  @override
  Future<void> save(ExplorationSession session) {
    final origin = session.origin;
    _validateOrigin(origin);
    return _enqueue(() => _save(session));
  }

  Future<ExplorationSession?> _load(ExplorationOrigin origin) async {
    final rows = await _database
        .customSelect(
          'SELECT value FROM app_settings WHERE key = ?',
          variables: <Variable<String>>[Variable<String>(_keyFor(origin))],
        )
        .get();
    if (rows.isEmpty) return null;
    return _decode(rows.single.data['value'] as String, expectedOrigin: origin);
  }

  Future<void> _save(ExplorationSession session) async {
    final origin = session.origin;
    final key = _keyFor(origin);
    final value = jsonEncode(<String, Object?>{
      'version': _storageVersion,
      'origin': origin.toJson(),
      'session': session.toJson(),
    });

    // Inspect the current row and replace it in one transaction. In
    // particular, an older app must not erase a row written by a newer one.
    await _database.transaction(() async {
      final rows = await _database
          .customSelect(
            'SELECT value FROM app_settings WHERE key = ?',
            variables: <Variable<String>>[Variable<String>(key)],
          )
          .get();
      if (rows.isNotEmpty) {
        final existing = _decode(rows.single.data['value'] as String);
        if (existing.origin.identityKey != origin.identityKey ||
            existing.origin != origin) {
          throw const FormatException(
            'Stored exploration draft belongs to a different origin.',
          );
        }
      }
      await _database.customStatement(
        'INSERT INTO app_settings (key, value) VALUES (?, ?) '
        'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        <Object?>[key, value],
      );
    });
  }

  ExplorationSession _decode(
    String encoded, {
    ExplorationOrigin? expectedOrigin,
  }) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('Malformed exploration draft.');
    }
    final envelope = Map<String, Object?>.from(decoded);
    if (envelope['version'] != _storageVersion) {
      throw const FormatException('Unsupported exploration draft version.');
    }
    final originJson = envelope['origin'];
    final sessionJson = envelope['session'];
    if (originJson is! Map || sessionJson is! Map) {
      throw const FormatException('Malformed exploration draft.');
    }

    final storedOrigin = ExplorationOrigin.fromJson(
      Map<String, Object?>.from(originJson),
    );
    final session = ExplorationSession.fromJson(
      Map<String, Object?>.from(sessionJson),
    );
    if (storedOrigin.identityKey != session.origin.identityKey ||
        storedOrigin != session.origin) {
      throw const FormatException(
        'Exploration draft origin does not match its session.',
      );
    }
    if (expectedOrigin != null &&
        (expectedOrigin.identityKey != session.origin.identityKey ||
            expectedOrigin != session.origin)) {
      throw const FormatException(
        'Exploration draft does not match the requested origin.',
      );
    }
    return session;
  }

  String _keyFor(ExplorationOrigin origin) {
    // Encode source scope and authored occurrence directly. This stays
    // reversible and collision-free without a short hash, while keeping the
    // key limited to the scope plus path/try discriminator.
    final identity = jsonEncode(<Object?>[
      origin.scopeId,
      origin.authoredPath,
      origin.discriminator,
    ]);
    return '$_keyPrefix${base64Url.encode(utf8.encode(identity)).replaceAll('=', '')}';
  }

  void _validateOrigin(ExplorationOrigin origin) {
    if (origin.scopeId.isEmpty) {
      throw ArgumentError.value(
        origin.scopeId,
        'origin.scopeId',
        'A stable source and revision scope is required.',
      );
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _queue.then<T>((_) => operation());
    // Keep later operations moving after a failed load or write while still
    // returning the original error to the caller that initiated it.
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
