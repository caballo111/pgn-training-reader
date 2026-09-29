// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PgnSourcesTable extends PgnSources
    with TableInfo<$PgnSourcesTable, PgnSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PgnSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accessModeMeta = const VerificationMeta(
    'accessMode',
  );
  @override
  late final GeneratedColumn<String> accessMode = GeneratedColumn<String>(
    'access_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _managedPathMeta = const VerificationMeta(
    'managedPath',
  );
  @override
  late final GeneratedColumn<String> managedPath = GeneratedColumn<String>(
    'managed_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _externalReferenceMeta = const VerificationMeta(
    'externalReference',
  );
  @override
  late final GeneratedColumn<String> externalReference =
      GeneratedColumn<String>(
        'external_reference',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modifiedAtMicrosMeta = const VerificationMeta(
    'modifiedAtMicros',
  );
  @override
  late final GeneratedColumn<int> modifiedAtMicros = GeneratedColumn<int>(
    'modified_at_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scannerVersionMeta = const VerificationMeta(
    'scannerVersion',
  );
  @override
  late final GeneratedColumn<int> scannerVersion = GeneratedColumn<int>(
    'scanner_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importStateMeta = const VerificationMeta(
    'importState',
  );
  @override
  late final GeneratedColumn<String> importState = GeneratedColumn<String>(
    'import_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _safeCheckpointMeta = const VerificationMeta(
    'safeCheckpoint',
  );
  @override
  late final GeneratedColumn<int> safeCheckpoint = GeneratedColumn<int>(
    'safe_checkpoint',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMicrosMeta = const VerificationMeta(
    'createdAtMicros',
  );
  @override
  late final GeneratedColumn<int> createdAtMicros = GeneratedColumn<int>(
    'created_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMicrosMeta = const VerificationMeta(
    'updatedAtMicros',
  );
  @override
  late final GeneratedColumn<int> updatedAtMicros = GeneratedColumn<int>(
    'updated_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    accessMode,
    managedPath,
    externalReference,
    sizeBytes,
    modifiedAtMicros,
    fingerprint,
    scannerVersion,
    importState,
    safeCheckpoint,
    createdAtMicros,
    updatedAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pgn_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<PgnSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('access_mode')) {
      context.handle(
        _accessModeMeta,
        accessMode.isAcceptableOrUnknown(data['access_mode']!, _accessModeMeta),
      );
    } else if (isInserting) {
      context.missing(_accessModeMeta);
    }
    if (data.containsKey('managed_path')) {
      context.handle(
        _managedPathMeta,
        managedPath.isAcceptableOrUnknown(
          data['managed_path']!,
          _managedPathMeta,
        ),
      );
    }
    if (data.containsKey('external_reference')) {
      context.handle(
        _externalReferenceMeta,
        externalReference.isAcceptableOrUnknown(
          data['external_reference']!,
          _externalReferenceMeta,
        ),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('modified_at_micros')) {
      context.handle(
        _modifiedAtMicrosMeta,
        modifiedAtMicros.isAcceptableOrUnknown(
          data['modified_at_micros']!,
          _modifiedAtMicrosMeta,
        ),
      );
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    }
    if (data.containsKey('scanner_version')) {
      context.handle(
        _scannerVersionMeta,
        scannerVersion.isAcceptableOrUnknown(
          data['scanner_version']!,
          _scannerVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scannerVersionMeta);
    }
    if (data.containsKey('import_state')) {
      context.handle(
        _importStateMeta,
        importState.isAcceptableOrUnknown(
          data['import_state']!,
          _importStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_importStateMeta);
    }
    if (data.containsKey('safe_checkpoint')) {
      context.handle(
        _safeCheckpointMeta,
        safeCheckpoint.isAcceptableOrUnknown(
          data['safe_checkpoint']!,
          _safeCheckpointMeta,
        ),
      );
    }
    if (data.containsKey('created_at_micros')) {
      context.handle(
        _createdAtMicrosMeta,
        createdAtMicros.isAcceptableOrUnknown(
          data['created_at_micros']!,
          _createdAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMicrosMeta);
    }
    if (data.containsKey('updated_at_micros')) {
      context.handle(
        _updatedAtMicrosMeta,
        updatedAtMicros.isAcceptableOrUnknown(
          data['updated_at_micros']!,
          _updatedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PgnSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PgnSource(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      accessMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}access_mode'],
      )!,
      managedPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}managed_path'],
      ),
      externalReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_reference'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      modifiedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified_at_micros'],
      ),
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      ),
      scannerVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scanner_version'],
      )!,
      importState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_state'],
      )!,
      safeCheckpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}safe_checkpoint'],
      )!,
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
      updatedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_micros'],
      )!,
    );
  }

  @override
  $PgnSourcesTable createAlias(String alias) {
    return $PgnSourcesTable(attachedDatabase, alias);
  }
}

class PgnSource extends DataClass implements Insertable<PgnSource> {
  final String id;
  final String displayName;
  final String accessMode;
  final String? managedPath;
  final String? externalReference;
  final int? sizeBytes;
  final int? modifiedAtMicros;
  final String? fingerprint;
  final int scannerVersion;
  final String importState;
  final int safeCheckpoint;
  final int createdAtMicros;
  final int updatedAtMicros;
  const PgnSource({
    required this.id,
    required this.displayName,
    required this.accessMode,
    this.managedPath,
    this.externalReference,
    this.sizeBytes,
    this.modifiedAtMicros,
    this.fingerprint,
    required this.scannerVersion,
    required this.importState,
    required this.safeCheckpoint,
    required this.createdAtMicros,
    required this.updatedAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['access_mode'] = Variable<String>(accessMode);
    if (!nullToAbsent || managedPath != null) {
      map['managed_path'] = Variable<String>(managedPath);
    }
    if (!nullToAbsent || externalReference != null) {
      map['external_reference'] = Variable<String>(externalReference);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || modifiedAtMicros != null) {
      map['modified_at_micros'] = Variable<int>(modifiedAtMicros);
    }
    if (!nullToAbsent || fingerprint != null) {
      map['fingerprint'] = Variable<String>(fingerprint);
    }
    map['scanner_version'] = Variable<int>(scannerVersion);
    map['import_state'] = Variable<String>(importState);
    map['safe_checkpoint'] = Variable<int>(safeCheckpoint);
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    map['updated_at_micros'] = Variable<int>(updatedAtMicros);
    return map;
  }

  PgnSourcesCompanion toCompanion(bool nullToAbsent) {
    return PgnSourcesCompanion(
      id: Value(id),
      displayName: Value(displayName),
      accessMode: Value(accessMode),
      managedPath: managedPath == null && nullToAbsent
          ? const Value.absent()
          : Value(managedPath),
      externalReference: externalReference == null && nullToAbsent
          ? const Value.absent()
          : Value(externalReference),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      modifiedAtMicros: modifiedAtMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(modifiedAtMicros),
      fingerprint: fingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(fingerprint),
      scannerVersion: Value(scannerVersion),
      importState: Value(importState),
      safeCheckpoint: Value(safeCheckpoint),
      createdAtMicros: Value(createdAtMicros),
      updatedAtMicros: Value(updatedAtMicros),
    );
  }

  factory PgnSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PgnSource(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      accessMode: serializer.fromJson<String>(json['accessMode']),
      managedPath: serializer.fromJson<String?>(json['managedPath']),
      externalReference: serializer.fromJson<String?>(
        json['externalReference'],
      ),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      modifiedAtMicros: serializer.fromJson<int?>(json['modifiedAtMicros']),
      fingerprint: serializer.fromJson<String?>(json['fingerprint']),
      scannerVersion: serializer.fromJson<int>(json['scannerVersion']),
      importState: serializer.fromJson<String>(json['importState']),
      safeCheckpoint: serializer.fromJson<int>(json['safeCheckpoint']),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
      updatedAtMicros: serializer.fromJson<int>(json['updatedAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'accessMode': serializer.toJson<String>(accessMode),
      'managedPath': serializer.toJson<String?>(managedPath),
      'externalReference': serializer.toJson<String?>(externalReference),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'modifiedAtMicros': serializer.toJson<int?>(modifiedAtMicros),
      'fingerprint': serializer.toJson<String?>(fingerprint),
      'scannerVersion': serializer.toJson<int>(scannerVersion),
      'importState': serializer.toJson<String>(importState),
      'safeCheckpoint': serializer.toJson<int>(safeCheckpoint),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
      'updatedAtMicros': serializer.toJson<int>(updatedAtMicros),
    };
  }

  PgnSource copyWith({
    String? id,
    String? displayName,
    String? accessMode,
    Value<String?> managedPath = const Value.absent(),
    Value<String?> externalReference = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    Value<int?> modifiedAtMicros = const Value.absent(),
    Value<String?> fingerprint = const Value.absent(),
    int? scannerVersion,
    String? importState,
    int? safeCheckpoint,
    int? createdAtMicros,
    int? updatedAtMicros,
  }) => PgnSource(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    accessMode: accessMode ?? this.accessMode,
    managedPath: managedPath.present ? managedPath.value : this.managedPath,
    externalReference: externalReference.present
        ? externalReference.value
        : this.externalReference,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    modifiedAtMicros: modifiedAtMicros.present
        ? modifiedAtMicros.value
        : this.modifiedAtMicros,
    fingerprint: fingerprint.present ? fingerprint.value : this.fingerprint,
    scannerVersion: scannerVersion ?? this.scannerVersion,
    importState: importState ?? this.importState,
    safeCheckpoint: safeCheckpoint ?? this.safeCheckpoint,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
    updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
  );
  PgnSource copyWithCompanion(PgnSourcesCompanion data) {
    return PgnSource(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      accessMode: data.accessMode.present
          ? data.accessMode.value
          : this.accessMode,
      managedPath: data.managedPath.present
          ? data.managedPath.value
          : this.managedPath,
      externalReference: data.externalReference.present
          ? data.externalReference.value
          : this.externalReference,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      modifiedAtMicros: data.modifiedAtMicros.present
          ? data.modifiedAtMicros.value
          : this.modifiedAtMicros,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      scannerVersion: data.scannerVersion.present
          ? data.scannerVersion.value
          : this.scannerVersion,
      importState: data.importState.present
          ? data.importState.value
          : this.importState,
      safeCheckpoint: data.safeCheckpoint.present
          ? data.safeCheckpoint.value
          : this.safeCheckpoint,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
      updatedAtMicros: data.updatedAtMicros.present
          ? data.updatedAtMicros.value
          : this.updatedAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PgnSource(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('accessMode: $accessMode, ')
          ..write('managedPath: $managedPath, ')
          ..write('externalReference: $externalReference, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('modifiedAtMicros: $modifiedAtMicros, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('scannerVersion: $scannerVersion, ')
          ..write('importState: $importState, ')
          ..write('safeCheckpoint: $safeCheckpoint, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    accessMode,
    managedPath,
    externalReference,
    sizeBytes,
    modifiedAtMicros,
    fingerprint,
    scannerVersion,
    importState,
    safeCheckpoint,
    createdAtMicros,
    updatedAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PgnSource &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.accessMode == this.accessMode &&
          other.managedPath == this.managedPath &&
          other.externalReference == this.externalReference &&
          other.sizeBytes == this.sizeBytes &&
          other.modifiedAtMicros == this.modifiedAtMicros &&
          other.fingerprint == this.fingerprint &&
          other.scannerVersion == this.scannerVersion &&
          other.importState == this.importState &&
          other.safeCheckpoint == this.safeCheckpoint &&
          other.createdAtMicros == this.createdAtMicros &&
          other.updatedAtMicros == this.updatedAtMicros);
}

class PgnSourcesCompanion extends UpdateCompanion<PgnSource> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String> accessMode;
  final Value<String?> managedPath;
  final Value<String?> externalReference;
  final Value<int?> sizeBytes;
  final Value<int?> modifiedAtMicros;
  final Value<String?> fingerprint;
  final Value<int> scannerVersion;
  final Value<String> importState;
  final Value<int> safeCheckpoint;
  final Value<int> createdAtMicros;
  final Value<int> updatedAtMicros;
  final Value<int> rowid;
  const PgnSourcesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.accessMode = const Value.absent(),
    this.managedPath = const Value.absent(),
    this.externalReference = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.modifiedAtMicros = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.scannerVersion = const Value.absent(),
    this.importState = const Value.absent(),
    this.safeCheckpoint = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.updatedAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PgnSourcesCompanion.insert({
    required String id,
    required String displayName,
    required String accessMode,
    this.managedPath = const Value.absent(),
    this.externalReference = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.modifiedAtMicros = const Value.absent(),
    this.fingerprint = const Value.absent(),
    required int scannerVersion,
    required String importState,
    this.safeCheckpoint = const Value.absent(),
    required int createdAtMicros,
    required int updatedAtMicros,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       accessMode = Value(accessMode),
       scannerVersion = Value(scannerVersion),
       importState = Value(importState),
       createdAtMicros = Value(createdAtMicros),
       updatedAtMicros = Value(updatedAtMicros);
  static Insertable<PgnSource> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? accessMode,
    Expression<String>? managedPath,
    Expression<String>? externalReference,
    Expression<int>? sizeBytes,
    Expression<int>? modifiedAtMicros,
    Expression<String>? fingerprint,
    Expression<int>? scannerVersion,
    Expression<String>? importState,
    Expression<int>? safeCheckpoint,
    Expression<int>? createdAtMicros,
    Expression<int>? updatedAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (accessMode != null) 'access_mode': accessMode,
      if (managedPath != null) 'managed_path': managedPath,
      if (externalReference != null) 'external_reference': externalReference,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (modifiedAtMicros != null) 'modified_at_micros': modifiedAtMicros,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (scannerVersion != null) 'scanner_version': scannerVersion,
      if (importState != null) 'import_state': importState,
      if (safeCheckpoint != null) 'safe_checkpoint': safeCheckpoint,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (updatedAtMicros != null) 'updated_at_micros': updatedAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PgnSourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<String>? accessMode,
    Value<String?>? managedPath,
    Value<String?>? externalReference,
    Value<int?>? sizeBytes,
    Value<int?>? modifiedAtMicros,
    Value<String?>? fingerprint,
    Value<int>? scannerVersion,
    Value<String>? importState,
    Value<int>? safeCheckpoint,
    Value<int>? createdAtMicros,
    Value<int>? updatedAtMicros,
    Value<int>? rowid,
  }) {
    return PgnSourcesCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      accessMode: accessMode ?? this.accessMode,
      managedPath: managedPath ?? this.managedPath,
      externalReference: externalReference ?? this.externalReference,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      modifiedAtMicros: modifiedAtMicros ?? this.modifiedAtMicros,
      fingerprint: fingerprint ?? this.fingerprint,
      scannerVersion: scannerVersion ?? this.scannerVersion,
      importState: importState ?? this.importState,
      safeCheckpoint: safeCheckpoint ?? this.safeCheckpoint,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (accessMode.present) {
      map['access_mode'] = Variable<String>(accessMode.value);
    }
    if (managedPath.present) {
      map['managed_path'] = Variable<String>(managedPath.value);
    }
    if (externalReference.present) {
      map['external_reference'] = Variable<String>(externalReference.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (modifiedAtMicros.present) {
      map['modified_at_micros'] = Variable<int>(modifiedAtMicros.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (scannerVersion.present) {
      map['scanner_version'] = Variable<int>(scannerVersion.value);
    }
    if (importState.present) {
      map['import_state'] = Variable<String>(importState.value);
    }
    if (safeCheckpoint.present) {
      map['safe_checkpoint'] = Variable<int>(safeCheckpoint.value);
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (updatedAtMicros.present) {
      map['updated_at_micros'] = Variable<int>(updatedAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PgnSourcesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('accessMode: $accessMode, ')
          ..write('managedPath: $managedPath, ')
          ..write('externalReference: $externalReference, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('modifiedAtMicros: $modifiedAtMicros, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('scannerVersion: $scannerVersion, ')
          ..write('importState: $importState, ')
          ..write('safeCheckpoint: $safeCheckpoint, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PgnBlocksTable extends PgnBlocks
    with TableInfo<$PgnBlocksTable, PgnBlock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PgnBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pgn_sources (id)',
    ),
  );
  static const VerificationMeta _startOffsetMeta = const VerificationMeta(
    'startOffset',
  );
  @override
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
    'start_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endOffsetMeta = const VerificationMeta(
    'endOffset',
  );
  @override
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
    'end_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventMeta = const VerificationMeta('event');
  @override
  late final GeneratedColumn<String> event = GeneratedColumn<String>(
    'event',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _siteMeta = const VerificationMeta('site');
  @override
  late final GeneratedColumn<String> site = GeneratedColumn<String>(
    'site',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roundMeta = const VerificationMeta('round');
  @override
  late final GeneratedColumn<String> round = GeneratedColumn<String>(
    'round',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _whiteMeta = const VerificationMeta('white');
  @override
  late final GeneratedColumn<String> white = GeneratedColumn<String>(
    'white',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blackMeta = const VerificationMeta('black');
  @override
  late final GeneratedColumn<String> black = GeneratedColumn<String>(
    'black',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentTypeMeta = const VerificationMeta(
    'contentType',
  );
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
    'content_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sectionMeta = const VerificationMeta(
    'section',
  );
  @override
  late final GeneratedColumn<String> section = GeneratedColumn<String>(
    'section',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _themeMeta = const VerificationMeta('theme');
  @override
  late final GeneratedColumn<String> theme = GeneratedColumn<String>(
    'theme',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<String> difficulty = GeneratedColumn<String>(
    'difficulty',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parseStatusMeta = const VerificationMeta(
    'parseStatus',
  );
  @override
  late final GeneratedColumn<String> parseStatus = GeneratedColumn<String>(
    'parse_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _diagnosticSummaryMeta = const VerificationMeta(
    'diagnosticSummary',
  );
  @override
  late final GeneratedColumn<String> diagnosticSummary =
      GeneratedColumn<String>(
        'diagnostic_summary',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    startOffset,
    endOffset,
    ordinal,
    event,
    site,
    date,
    round,
    white,
    black,
    result,
    contentType,
    exerciseId,
    section,
    sequence,
    theme,
    difficulty,
    parseStatus,
    diagnosticSummary,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pgn_blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<PgnBlock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
        _startOffsetMeta,
        startOffset.isAcceptableOrUnknown(
          data['start_offset']!,
          _startOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    if (data.containsKey('end_offset')) {
      context.handle(
        _endOffsetMeta,
        endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta),
      );
    } else if (isInserting) {
      context.missing(_endOffsetMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('event')) {
      context.handle(
        _eventMeta,
        event.isAcceptableOrUnknown(data['event']!, _eventMeta),
      );
    }
    if (data.containsKey('site')) {
      context.handle(
        _siteMeta,
        site.isAcceptableOrUnknown(data['site']!, _siteMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('round')) {
      context.handle(
        _roundMeta,
        round.isAcceptableOrUnknown(data['round']!, _roundMeta),
      );
    }
    if (data.containsKey('white')) {
      context.handle(
        _whiteMeta,
        white.isAcceptableOrUnknown(data['white']!, _whiteMeta),
      );
    }
    if (data.containsKey('black')) {
      context.handle(
        _blackMeta,
        black.isAcceptableOrUnknown(data['black']!, _blackMeta),
      );
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    }
    if (data.containsKey('content_type')) {
      context.handle(
        _contentTypeMeta,
        contentType.isAcceptableOrUnknown(
          data['content_type']!,
          _contentTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentTypeMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    }
    if (data.containsKey('section')) {
      context.handle(
        _sectionMeta,
        section.isAcceptableOrUnknown(data['section']!, _sectionMeta),
      );
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    }
    if (data.containsKey('theme')) {
      context.handle(
        _themeMeta,
        theme.isAcceptableOrUnknown(data['theme']!, _themeMeta),
      );
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    }
    if (data.containsKey('parse_status')) {
      context.handle(
        _parseStatusMeta,
        parseStatus.isAcceptableOrUnknown(
          data['parse_status']!,
          _parseStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parseStatusMeta);
    }
    if (data.containsKey('diagnostic_summary')) {
      context.handle(
        _diagnosticSummaryMeta,
        diagnosticSummary.isAcceptableOrUnknown(
          data['diagnostic_summary']!,
          _diagnosticSummaryMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceId, ordinal},
  ];
  @override
  PgnBlock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PgnBlock(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      startOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_offset'],
      )!,
      endOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_offset'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      event: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event'],
      ),
      site: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}site'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      ),
      round: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}round'],
      ),
      white: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}white'],
      ),
      black: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}black'],
      ),
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      ),
      contentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_type'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      ),
      section: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section'],
      ),
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      ),
      theme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme'],
      ),
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}difficulty'],
      ),
      parseStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parse_status'],
      )!,
      diagnosticSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diagnostic_summary'],
      ),
    );
  }

  @override
  $PgnBlocksTable createAlias(String alias) {
    return $PgnBlocksTable(attachedDatabase, alias);
  }
}

class PgnBlock extends DataClass implements Insertable<PgnBlock> {
  final String id;
  final String sourceId;
  final int startOffset;
  final int endOffset;
  final int ordinal;
  final String? event;
  final String? site;
  final String? date;
  final String? round;
  final String? white;
  final String? black;
  final String? result;
  final String contentType;
  final String? exerciseId;
  final String? section;
  final int? sequence;
  final String? theme;
  final String? difficulty;
  final String parseStatus;
  final String? diagnosticSummary;
  const PgnBlock({
    required this.id,
    required this.sourceId,
    required this.startOffset,
    required this.endOffset,
    required this.ordinal,
    this.event,
    this.site,
    this.date,
    this.round,
    this.white,
    this.black,
    this.result,
    required this.contentType,
    this.exerciseId,
    this.section,
    this.sequence,
    this.theme,
    this.difficulty,
    required this.parseStatus,
    this.diagnosticSummary,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['start_offset'] = Variable<int>(startOffset);
    map['end_offset'] = Variable<int>(endOffset);
    map['ordinal'] = Variable<int>(ordinal);
    if (!nullToAbsent || event != null) {
      map['event'] = Variable<String>(event);
    }
    if (!nullToAbsent || site != null) {
      map['site'] = Variable<String>(site);
    }
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<String>(date);
    }
    if (!nullToAbsent || round != null) {
      map['round'] = Variable<String>(round);
    }
    if (!nullToAbsent || white != null) {
      map['white'] = Variable<String>(white);
    }
    if (!nullToAbsent || black != null) {
      map['black'] = Variable<String>(black);
    }
    if (!nullToAbsent || result != null) {
      map['result'] = Variable<String>(result);
    }
    map['content_type'] = Variable<String>(contentType);
    if (!nullToAbsent || exerciseId != null) {
      map['exercise_id'] = Variable<String>(exerciseId);
    }
    if (!nullToAbsent || section != null) {
      map['section'] = Variable<String>(section);
    }
    if (!nullToAbsent || sequence != null) {
      map['sequence'] = Variable<int>(sequence);
    }
    if (!nullToAbsent || theme != null) {
      map['theme'] = Variable<String>(theme);
    }
    if (!nullToAbsent || difficulty != null) {
      map['difficulty'] = Variable<String>(difficulty);
    }
    map['parse_status'] = Variable<String>(parseStatus);
    if (!nullToAbsent || diagnosticSummary != null) {
      map['diagnostic_summary'] = Variable<String>(diagnosticSummary);
    }
    return map;
  }

  PgnBlocksCompanion toCompanion(bool nullToAbsent) {
    return PgnBlocksCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      startOffset: Value(startOffset),
      endOffset: Value(endOffset),
      ordinal: Value(ordinal),
      event: event == null && nullToAbsent
          ? const Value.absent()
          : Value(event),
      site: site == null && nullToAbsent ? const Value.absent() : Value(site),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      round: round == null && nullToAbsent
          ? const Value.absent()
          : Value(round),
      white: white == null && nullToAbsent
          ? const Value.absent()
          : Value(white),
      black: black == null && nullToAbsent
          ? const Value.absent()
          : Value(black),
      result: result == null && nullToAbsent
          ? const Value.absent()
          : Value(result),
      contentType: Value(contentType),
      exerciseId: exerciseId == null && nullToAbsent
          ? const Value.absent()
          : Value(exerciseId),
      section: section == null && nullToAbsent
          ? const Value.absent()
          : Value(section),
      sequence: sequence == null && nullToAbsent
          ? const Value.absent()
          : Value(sequence),
      theme: theme == null && nullToAbsent
          ? const Value.absent()
          : Value(theme),
      difficulty: difficulty == null && nullToAbsent
          ? const Value.absent()
          : Value(difficulty),
      parseStatus: Value(parseStatus),
      diagnosticSummary: diagnosticSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(diagnosticSummary),
    );
  }

  factory PgnBlock.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PgnBlock(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      startOffset: serializer.fromJson<int>(json['startOffset']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      event: serializer.fromJson<String?>(json['event']),
      site: serializer.fromJson<String?>(json['site']),
      date: serializer.fromJson<String?>(json['date']),
      round: serializer.fromJson<String?>(json['round']),
      white: serializer.fromJson<String?>(json['white']),
      black: serializer.fromJson<String?>(json['black']),
      result: serializer.fromJson<String?>(json['result']),
      contentType: serializer.fromJson<String>(json['contentType']),
      exerciseId: serializer.fromJson<String?>(json['exerciseId']),
      section: serializer.fromJson<String?>(json['section']),
      sequence: serializer.fromJson<int?>(json['sequence']),
      theme: serializer.fromJson<String?>(json['theme']),
      difficulty: serializer.fromJson<String?>(json['difficulty']),
      parseStatus: serializer.fromJson<String>(json['parseStatus']),
      diagnosticSummary: serializer.fromJson<String?>(
        json['diagnosticSummary'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'startOffset': serializer.toJson<int>(startOffset),
      'endOffset': serializer.toJson<int>(endOffset),
      'ordinal': serializer.toJson<int>(ordinal),
      'event': serializer.toJson<String?>(event),
      'site': serializer.toJson<String?>(site),
      'date': serializer.toJson<String?>(date),
      'round': serializer.toJson<String?>(round),
      'white': serializer.toJson<String?>(white),
      'black': serializer.toJson<String?>(black),
      'result': serializer.toJson<String?>(result),
      'contentType': serializer.toJson<String>(contentType),
      'exerciseId': serializer.toJson<String?>(exerciseId),
      'section': serializer.toJson<String?>(section),
      'sequence': serializer.toJson<int?>(sequence),
      'theme': serializer.toJson<String?>(theme),
      'difficulty': serializer.toJson<String?>(difficulty),
      'parseStatus': serializer.toJson<String>(parseStatus),
      'diagnosticSummary': serializer.toJson<String?>(diagnosticSummary),
    };
  }

  PgnBlock copyWith({
    String? id,
    String? sourceId,
    int? startOffset,
    int? endOffset,
    int? ordinal,
    Value<String?> event = const Value.absent(),
    Value<String?> site = const Value.absent(),
    Value<String?> date = const Value.absent(),
    Value<String?> round = const Value.absent(),
    Value<String?> white = const Value.absent(),
    Value<String?> black = const Value.absent(),
    Value<String?> result = const Value.absent(),
    String? contentType,
    Value<String?> exerciseId = const Value.absent(),
    Value<String?> section = const Value.absent(),
    Value<int?> sequence = const Value.absent(),
    Value<String?> theme = const Value.absent(),
    Value<String?> difficulty = const Value.absent(),
    String? parseStatus,
    Value<String?> diagnosticSummary = const Value.absent(),
  }) => PgnBlock(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    startOffset: startOffset ?? this.startOffset,
    endOffset: endOffset ?? this.endOffset,
    ordinal: ordinal ?? this.ordinal,
    event: event.present ? event.value : this.event,
    site: site.present ? site.value : this.site,
    date: date.present ? date.value : this.date,
    round: round.present ? round.value : this.round,
    white: white.present ? white.value : this.white,
    black: black.present ? black.value : this.black,
    result: result.present ? result.value : this.result,
    contentType: contentType ?? this.contentType,
    exerciseId: exerciseId.present ? exerciseId.value : this.exerciseId,
    section: section.present ? section.value : this.section,
    sequence: sequence.present ? sequence.value : this.sequence,
    theme: theme.present ? theme.value : this.theme,
    difficulty: difficulty.present ? difficulty.value : this.difficulty,
    parseStatus: parseStatus ?? this.parseStatus,
    diagnosticSummary: diagnosticSummary.present
        ? diagnosticSummary.value
        : this.diagnosticSummary,
  );
  PgnBlock copyWithCompanion(PgnBlocksCompanion data) {
    return PgnBlock(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      startOffset: data.startOffset.present
          ? data.startOffset.value
          : this.startOffset,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      event: data.event.present ? data.event.value : this.event,
      site: data.site.present ? data.site.value : this.site,
      date: data.date.present ? data.date.value : this.date,
      round: data.round.present ? data.round.value : this.round,
      white: data.white.present ? data.white.value : this.white,
      black: data.black.present ? data.black.value : this.black,
      result: data.result.present ? data.result.value : this.result,
      contentType: data.contentType.present
          ? data.contentType.value
          : this.contentType,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      section: data.section.present ? data.section.value : this.section,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      theme: data.theme.present ? data.theme.value : this.theme,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      parseStatus: data.parseStatus.present
          ? data.parseStatus.value
          : this.parseStatus,
      diagnosticSummary: data.diagnosticSummary.present
          ? data.diagnosticSummary.value
          : this.diagnosticSummary,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PgnBlock(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('ordinal: $ordinal, ')
          ..write('event: $event, ')
          ..write('site: $site, ')
          ..write('date: $date, ')
          ..write('round: $round, ')
          ..write('white: $white, ')
          ..write('black: $black, ')
          ..write('result: $result, ')
          ..write('contentType: $contentType, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('section: $section, ')
          ..write('sequence: $sequence, ')
          ..write('theme: $theme, ')
          ..write('difficulty: $difficulty, ')
          ..write('parseStatus: $parseStatus, ')
          ..write('diagnosticSummary: $diagnosticSummary')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    startOffset,
    endOffset,
    ordinal,
    event,
    site,
    date,
    round,
    white,
    black,
    result,
    contentType,
    exerciseId,
    section,
    sequence,
    theme,
    difficulty,
    parseStatus,
    diagnosticSummary,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PgnBlock &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.startOffset == this.startOffset &&
          other.endOffset == this.endOffset &&
          other.ordinal == this.ordinal &&
          other.event == this.event &&
          other.site == this.site &&
          other.date == this.date &&
          other.round == this.round &&
          other.white == this.white &&
          other.black == this.black &&
          other.result == this.result &&
          other.contentType == this.contentType &&
          other.exerciseId == this.exerciseId &&
          other.section == this.section &&
          other.sequence == this.sequence &&
          other.theme == this.theme &&
          other.difficulty == this.difficulty &&
          other.parseStatus == this.parseStatus &&
          other.diagnosticSummary == this.diagnosticSummary);
}

class PgnBlocksCompanion extends UpdateCompanion<PgnBlock> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<int> startOffset;
  final Value<int> endOffset;
  final Value<int> ordinal;
  final Value<String?> event;
  final Value<String?> site;
  final Value<String?> date;
  final Value<String?> round;
  final Value<String?> white;
  final Value<String?> black;
  final Value<String?> result;
  final Value<String> contentType;
  final Value<String?> exerciseId;
  final Value<String?> section;
  final Value<int?> sequence;
  final Value<String?> theme;
  final Value<String?> difficulty;
  final Value<String> parseStatus;
  final Value<String?> diagnosticSummary;
  final Value<int> rowid;
  const PgnBlocksCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.event = const Value.absent(),
    this.site = const Value.absent(),
    this.date = const Value.absent(),
    this.round = const Value.absent(),
    this.white = const Value.absent(),
    this.black = const Value.absent(),
    this.result = const Value.absent(),
    this.contentType = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.section = const Value.absent(),
    this.sequence = const Value.absent(),
    this.theme = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.parseStatus = const Value.absent(),
    this.diagnosticSummary = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PgnBlocksCompanion.insert({
    required String id,
    required String sourceId,
    required int startOffset,
    required int endOffset,
    required int ordinal,
    this.event = const Value.absent(),
    this.site = const Value.absent(),
    this.date = const Value.absent(),
    this.round = const Value.absent(),
    this.white = const Value.absent(),
    this.black = const Value.absent(),
    this.result = const Value.absent(),
    required String contentType,
    this.exerciseId = const Value.absent(),
    this.section = const Value.absent(),
    this.sequence = const Value.absent(),
    this.theme = const Value.absent(),
    this.difficulty = const Value.absent(),
    required String parseStatus,
    this.diagnosticSummary = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       startOffset = Value(startOffset),
       endOffset = Value(endOffset),
       ordinal = Value(ordinal),
       contentType = Value(contentType),
       parseStatus = Value(parseStatus);
  static Insertable<PgnBlock> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<int>? startOffset,
    Expression<int>? endOffset,
    Expression<int>? ordinal,
    Expression<String>? event,
    Expression<String>? site,
    Expression<String>? date,
    Expression<String>? round,
    Expression<String>? white,
    Expression<String>? black,
    Expression<String>? result,
    Expression<String>? contentType,
    Expression<String>? exerciseId,
    Expression<String>? section,
    Expression<int>? sequence,
    Expression<String>? theme,
    Expression<String>? difficulty,
    Expression<String>? parseStatus,
    Expression<String>? diagnosticSummary,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (startOffset != null) 'start_offset': startOffset,
      if (endOffset != null) 'end_offset': endOffset,
      if (ordinal != null) 'ordinal': ordinal,
      if (event != null) 'event': event,
      if (site != null) 'site': site,
      if (date != null) 'date': date,
      if (round != null) 'round': round,
      if (white != null) 'white': white,
      if (black != null) 'black': black,
      if (result != null) 'result': result,
      if (contentType != null) 'content_type': contentType,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (section != null) 'section': section,
      if (sequence != null) 'sequence': sequence,
      if (theme != null) 'theme': theme,
      if (difficulty != null) 'difficulty': difficulty,
      if (parseStatus != null) 'parse_status': parseStatus,
      if (diagnosticSummary != null) 'diagnostic_summary': diagnosticSummary,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PgnBlocksCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<int>? startOffset,
    Value<int>? endOffset,
    Value<int>? ordinal,
    Value<String?>? event,
    Value<String?>? site,
    Value<String?>? date,
    Value<String?>? round,
    Value<String?>? white,
    Value<String?>? black,
    Value<String?>? result,
    Value<String>? contentType,
    Value<String?>? exerciseId,
    Value<String?>? section,
    Value<int?>? sequence,
    Value<String?>? theme,
    Value<String?>? difficulty,
    Value<String>? parseStatus,
    Value<String?>? diagnosticSummary,
    Value<int>? rowid,
  }) {
    return PgnBlocksCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      ordinal: ordinal ?? this.ordinal,
      event: event ?? this.event,
      site: site ?? this.site,
      date: date ?? this.date,
      round: round ?? this.round,
      white: white ?? this.white,
      black: black ?? this.black,
      result: result ?? this.result,
      contentType: contentType ?? this.contentType,
      exerciseId: exerciseId ?? this.exerciseId,
      section: section ?? this.section,
      sequence: sequence ?? this.sequence,
      theme: theme ?? this.theme,
      difficulty: difficulty ?? this.difficulty,
      parseStatus: parseStatus ?? this.parseStatus,
      diagnosticSummary: diagnosticSummary ?? this.diagnosticSummary,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (event.present) {
      map['event'] = Variable<String>(event.value);
    }
    if (site.present) {
      map['site'] = Variable<String>(site.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (round.present) {
      map['round'] = Variable<String>(round.value);
    }
    if (white.present) {
      map['white'] = Variable<String>(white.value);
    }
    if (black.present) {
      map['black'] = Variable<String>(black.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (section.present) {
      map['section'] = Variable<String>(section.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (theme.present) {
      map['theme'] = Variable<String>(theme.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(difficulty.value);
    }
    if (parseStatus.present) {
      map['parse_status'] = Variable<String>(parseStatus.value);
    }
    if (diagnosticSummary.present) {
      map['diagnostic_summary'] = Variable<String>(diagnosticSummary.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PgnBlocksCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('ordinal: $ordinal, ')
          ..write('event: $event, ')
          ..write('site: $site, ')
          ..write('date: $date, ')
          ..write('round: $round, ')
          ..write('white: $white, ')
          ..write('black: $black, ')
          ..write('result: $result, ')
          ..write('contentType: $contentType, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('section: $section, ')
          ..write('sequence: $sequence, ')
          ..write('theme: $theme, ')
          ..write('difficulty: $difficulty, ')
          ..write('parseStatus: $parseStatus, ')
          ..write('diagnosticSummary: $diagnosticSummary, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportJobsTable extends ImportJobs
    with TableInfo<$ImportJobsTable, ImportJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pgn_sources (id)',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesProcessedMeta = const VerificationMeta(
    'bytesProcessed',
  );
  @override
  late final GeneratedColumn<int> bytesProcessed = GeneratedColumn<int>(
    'bytes_processed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _blocksScannedMeta = const VerificationMeta(
    'blocksScanned',
  );
  @override
  late final GeneratedColumn<int> blocksScanned = GeneratedColumn<int>(
    'blocks_scanned',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _blocksIndexedMeta = const VerificationMeta(
    'blocksIndexed',
  );
  @override
  late final GeneratedColumn<int> blocksIndexed = GeneratedColumn<int>(
    'blocks_indexed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _blocksSkippedMeta = const VerificationMeta(
    'blocksSkipped',
  );
  @override
  late final GeneratedColumn<int> blocksSkipped = GeneratedColumn<int>(
    'blocks_skipped',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _diagnosticCountMeta = const VerificationMeta(
    'diagnosticCount',
  );
  @override
  late final GeneratedColumn<int> diagnosticCount = GeneratedColumn<int>(
    'diagnostic_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _safeCheckpointMeta = const VerificationMeta(
    'safeCheckpoint',
  );
  @override
  late final GeneratedColumn<int> safeCheckpoint = GeneratedColumn<int>(
    'safe_checkpoint',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cancellationRequestedMeta =
      const VerificationMeta('cancellationRequested');
  @override
  late final GeneratedColumn<bool> cancellationRequested =
      GeneratedColumn<bool>(
        'cancellation_requested',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("cancellation_requested" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _startedAtMicrosMeta = const VerificationMeta(
    'startedAtMicros',
  );
  @override
  late final GeneratedColumn<int> startedAtMicros = GeneratedColumn<int>(
    'started_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtMicrosMeta = const VerificationMeta(
    'finishedAtMicros',
  );
  @override
  late final GeneratedColumn<int> finishedAtMicros = GeneratedColumn<int>(
    'finished_at_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    status,
    bytesProcessed,
    blocksScanned,
    blocksIndexed,
    blocksSkipped,
    diagnosticCount,
    safeCheckpoint,
    cancellationRequested,
    startedAtMicros,
    finishedAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('bytes_processed')) {
      context.handle(
        _bytesProcessedMeta,
        bytesProcessed.isAcceptableOrUnknown(
          data['bytes_processed']!,
          _bytesProcessedMeta,
        ),
      );
    }
    if (data.containsKey('blocks_scanned')) {
      context.handle(
        _blocksScannedMeta,
        blocksScanned.isAcceptableOrUnknown(
          data['blocks_scanned']!,
          _blocksScannedMeta,
        ),
      );
    }
    if (data.containsKey('blocks_indexed')) {
      context.handle(
        _blocksIndexedMeta,
        blocksIndexed.isAcceptableOrUnknown(
          data['blocks_indexed']!,
          _blocksIndexedMeta,
        ),
      );
    }
    if (data.containsKey('blocks_skipped')) {
      context.handle(
        _blocksSkippedMeta,
        blocksSkipped.isAcceptableOrUnknown(
          data['blocks_skipped']!,
          _blocksSkippedMeta,
        ),
      );
    }
    if (data.containsKey('diagnostic_count')) {
      context.handle(
        _diagnosticCountMeta,
        diagnosticCount.isAcceptableOrUnknown(
          data['diagnostic_count']!,
          _diagnosticCountMeta,
        ),
      );
    }
    if (data.containsKey('safe_checkpoint')) {
      context.handle(
        _safeCheckpointMeta,
        safeCheckpoint.isAcceptableOrUnknown(
          data['safe_checkpoint']!,
          _safeCheckpointMeta,
        ),
      );
    }
    if (data.containsKey('cancellation_requested')) {
      context.handle(
        _cancellationRequestedMeta,
        cancellationRequested.isAcceptableOrUnknown(
          data['cancellation_requested']!,
          _cancellationRequestedMeta,
        ),
      );
    }
    if (data.containsKey('started_at_micros')) {
      context.handle(
        _startedAtMicrosMeta,
        startedAtMicros.isAcceptableOrUnknown(
          data['started_at_micros']!,
          _startedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtMicrosMeta);
    }
    if (data.containsKey('finished_at_micros')) {
      context.handle(
        _finishedAtMicrosMeta,
        finishedAtMicros.isAcceptableOrUnknown(
          data['finished_at_micros']!,
          _finishedAtMicrosMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImportJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      bytesProcessed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_processed'],
      )!,
      blocksScanned: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}blocks_scanned'],
      )!,
      blocksIndexed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}blocks_indexed'],
      )!,
      blocksSkipped: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}blocks_skipped'],
      )!,
      diagnosticCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}diagnostic_count'],
      )!,
      safeCheckpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}safe_checkpoint'],
      )!,
      cancellationRequested: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cancellation_requested'],
      )!,
      startedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_micros'],
      )!,
      finishedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}finished_at_micros'],
      ),
    );
  }

  @override
  $ImportJobsTable createAlias(String alias) {
    return $ImportJobsTable(attachedDatabase, alias);
  }
}

class ImportJob extends DataClass implements Insertable<ImportJob> {
  final String id;
  final String sourceId;
  final String status;
  final int bytesProcessed;
  final int blocksScanned;
  final int blocksIndexed;
  final int blocksSkipped;
  final int diagnosticCount;
  final int safeCheckpoint;
  final bool cancellationRequested;
  final int startedAtMicros;
  final int? finishedAtMicros;
  const ImportJob({
    required this.id,
    required this.sourceId,
    required this.status,
    required this.bytesProcessed,
    required this.blocksScanned,
    required this.blocksIndexed,
    required this.blocksSkipped,
    required this.diagnosticCount,
    required this.safeCheckpoint,
    required this.cancellationRequested,
    required this.startedAtMicros,
    this.finishedAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['status'] = Variable<String>(status);
    map['bytes_processed'] = Variable<int>(bytesProcessed);
    map['blocks_scanned'] = Variable<int>(blocksScanned);
    map['blocks_indexed'] = Variable<int>(blocksIndexed);
    map['blocks_skipped'] = Variable<int>(blocksSkipped);
    map['diagnostic_count'] = Variable<int>(diagnosticCount);
    map['safe_checkpoint'] = Variable<int>(safeCheckpoint);
    map['cancellation_requested'] = Variable<bool>(cancellationRequested);
    map['started_at_micros'] = Variable<int>(startedAtMicros);
    if (!nullToAbsent || finishedAtMicros != null) {
      map['finished_at_micros'] = Variable<int>(finishedAtMicros);
    }
    return map;
  }

  ImportJobsCompanion toCompanion(bool nullToAbsent) {
    return ImportJobsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      status: Value(status),
      bytesProcessed: Value(bytesProcessed),
      blocksScanned: Value(blocksScanned),
      blocksIndexed: Value(blocksIndexed),
      blocksSkipped: Value(blocksSkipped),
      diagnosticCount: Value(diagnosticCount),
      safeCheckpoint: Value(safeCheckpoint),
      cancellationRequested: Value(cancellationRequested),
      startedAtMicros: Value(startedAtMicros),
      finishedAtMicros: finishedAtMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAtMicros),
    );
  }

  factory ImportJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportJob(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      status: serializer.fromJson<String>(json['status']),
      bytesProcessed: serializer.fromJson<int>(json['bytesProcessed']),
      blocksScanned: serializer.fromJson<int>(json['blocksScanned']),
      blocksIndexed: serializer.fromJson<int>(json['blocksIndexed']),
      blocksSkipped: serializer.fromJson<int>(json['blocksSkipped']),
      diagnosticCount: serializer.fromJson<int>(json['diagnosticCount']),
      safeCheckpoint: serializer.fromJson<int>(json['safeCheckpoint']),
      cancellationRequested: serializer.fromJson<bool>(
        json['cancellationRequested'],
      ),
      startedAtMicros: serializer.fromJson<int>(json['startedAtMicros']),
      finishedAtMicros: serializer.fromJson<int?>(json['finishedAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'status': serializer.toJson<String>(status),
      'bytesProcessed': serializer.toJson<int>(bytesProcessed),
      'blocksScanned': serializer.toJson<int>(blocksScanned),
      'blocksIndexed': serializer.toJson<int>(blocksIndexed),
      'blocksSkipped': serializer.toJson<int>(blocksSkipped),
      'diagnosticCount': serializer.toJson<int>(diagnosticCount),
      'safeCheckpoint': serializer.toJson<int>(safeCheckpoint),
      'cancellationRequested': serializer.toJson<bool>(cancellationRequested),
      'startedAtMicros': serializer.toJson<int>(startedAtMicros),
      'finishedAtMicros': serializer.toJson<int?>(finishedAtMicros),
    };
  }

  ImportJob copyWith({
    String? id,
    String? sourceId,
    String? status,
    int? bytesProcessed,
    int? blocksScanned,
    int? blocksIndexed,
    int? blocksSkipped,
    int? diagnosticCount,
    int? safeCheckpoint,
    bool? cancellationRequested,
    int? startedAtMicros,
    Value<int?> finishedAtMicros = const Value.absent(),
  }) => ImportJob(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    status: status ?? this.status,
    bytesProcessed: bytesProcessed ?? this.bytesProcessed,
    blocksScanned: blocksScanned ?? this.blocksScanned,
    blocksIndexed: blocksIndexed ?? this.blocksIndexed,
    blocksSkipped: blocksSkipped ?? this.blocksSkipped,
    diagnosticCount: diagnosticCount ?? this.diagnosticCount,
    safeCheckpoint: safeCheckpoint ?? this.safeCheckpoint,
    cancellationRequested: cancellationRequested ?? this.cancellationRequested,
    startedAtMicros: startedAtMicros ?? this.startedAtMicros,
    finishedAtMicros: finishedAtMicros.present
        ? finishedAtMicros.value
        : this.finishedAtMicros,
  );
  ImportJob copyWithCompanion(ImportJobsCompanion data) {
    return ImportJob(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      status: data.status.present ? data.status.value : this.status,
      bytesProcessed: data.bytesProcessed.present
          ? data.bytesProcessed.value
          : this.bytesProcessed,
      blocksScanned: data.blocksScanned.present
          ? data.blocksScanned.value
          : this.blocksScanned,
      blocksIndexed: data.blocksIndexed.present
          ? data.blocksIndexed.value
          : this.blocksIndexed,
      blocksSkipped: data.blocksSkipped.present
          ? data.blocksSkipped.value
          : this.blocksSkipped,
      diagnosticCount: data.diagnosticCount.present
          ? data.diagnosticCount.value
          : this.diagnosticCount,
      safeCheckpoint: data.safeCheckpoint.present
          ? data.safeCheckpoint.value
          : this.safeCheckpoint,
      cancellationRequested: data.cancellationRequested.present
          ? data.cancellationRequested.value
          : this.cancellationRequested,
      startedAtMicros: data.startedAtMicros.present
          ? data.startedAtMicros.value
          : this.startedAtMicros,
      finishedAtMicros: data.finishedAtMicros.present
          ? data.finishedAtMicros.value
          : this.finishedAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportJob(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('status: $status, ')
          ..write('bytesProcessed: $bytesProcessed, ')
          ..write('blocksScanned: $blocksScanned, ')
          ..write('blocksIndexed: $blocksIndexed, ')
          ..write('blocksSkipped: $blocksSkipped, ')
          ..write('diagnosticCount: $diagnosticCount, ')
          ..write('safeCheckpoint: $safeCheckpoint, ')
          ..write('cancellationRequested: $cancellationRequested, ')
          ..write('startedAtMicros: $startedAtMicros, ')
          ..write('finishedAtMicros: $finishedAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    status,
    bytesProcessed,
    blocksScanned,
    blocksIndexed,
    blocksSkipped,
    diagnosticCount,
    safeCheckpoint,
    cancellationRequested,
    startedAtMicros,
    finishedAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportJob &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.status == this.status &&
          other.bytesProcessed == this.bytesProcessed &&
          other.blocksScanned == this.blocksScanned &&
          other.blocksIndexed == this.blocksIndexed &&
          other.blocksSkipped == this.blocksSkipped &&
          other.diagnosticCount == this.diagnosticCount &&
          other.safeCheckpoint == this.safeCheckpoint &&
          other.cancellationRequested == this.cancellationRequested &&
          other.startedAtMicros == this.startedAtMicros &&
          other.finishedAtMicros == this.finishedAtMicros);
}

class ImportJobsCompanion extends UpdateCompanion<ImportJob> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String> status;
  final Value<int> bytesProcessed;
  final Value<int> blocksScanned;
  final Value<int> blocksIndexed;
  final Value<int> blocksSkipped;
  final Value<int> diagnosticCount;
  final Value<int> safeCheckpoint;
  final Value<bool> cancellationRequested;
  final Value<int> startedAtMicros;
  final Value<int?> finishedAtMicros;
  final Value<int> rowid;
  const ImportJobsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.status = const Value.absent(),
    this.bytesProcessed = const Value.absent(),
    this.blocksScanned = const Value.absent(),
    this.blocksIndexed = const Value.absent(),
    this.blocksSkipped = const Value.absent(),
    this.diagnosticCount = const Value.absent(),
    this.safeCheckpoint = const Value.absent(),
    this.cancellationRequested = const Value.absent(),
    this.startedAtMicros = const Value.absent(),
    this.finishedAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportJobsCompanion.insert({
    required String id,
    required String sourceId,
    required String status,
    this.bytesProcessed = const Value.absent(),
    this.blocksScanned = const Value.absent(),
    this.blocksIndexed = const Value.absent(),
    this.blocksSkipped = const Value.absent(),
    this.diagnosticCount = const Value.absent(),
    this.safeCheckpoint = const Value.absent(),
    this.cancellationRequested = const Value.absent(),
    required int startedAtMicros,
    this.finishedAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       status = Value(status),
       startedAtMicros = Value(startedAtMicros);
  static Insertable<ImportJob> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? status,
    Expression<int>? bytesProcessed,
    Expression<int>? blocksScanned,
    Expression<int>? blocksIndexed,
    Expression<int>? blocksSkipped,
    Expression<int>? diagnosticCount,
    Expression<int>? safeCheckpoint,
    Expression<bool>? cancellationRequested,
    Expression<int>? startedAtMicros,
    Expression<int>? finishedAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (status != null) 'status': status,
      if (bytesProcessed != null) 'bytes_processed': bytesProcessed,
      if (blocksScanned != null) 'blocks_scanned': blocksScanned,
      if (blocksIndexed != null) 'blocks_indexed': blocksIndexed,
      if (blocksSkipped != null) 'blocks_skipped': blocksSkipped,
      if (diagnosticCount != null) 'diagnostic_count': diagnosticCount,
      if (safeCheckpoint != null) 'safe_checkpoint': safeCheckpoint,
      if (cancellationRequested != null)
        'cancellation_requested': cancellationRequested,
      if (startedAtMicros != null) 'started_at_micros': startedAtMicros,
      if (finishedAtMicros != null) 'finished_at_micros': finishedAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<String>? status,
    Value<int>? bytesProcessed,
    Value<int>? blocksScanned,
    Value<int>? blocksIndexed,
    Value<int>? blocksSkipped,
    Value<int>? diagnosticCount,
    Value<int>? safeCheckpoint,
    Value<bool>? cancellationRequested,
    Value<int>? startedAtMicros,
    Value<int?>? finishedAtMicros,
    Value<int>? rowid,
  }) {
    return ImportJobsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      status: status ?? this.status,
      bytesProcessed: bytesProcessed ?? this.bytesProcessed,
      blocksScanned: blocksScanned ?? this.blocksScanned,
      blocksIndexed: blocksIndexed ?? this.blocksIndexed,
      blocksSkipped: blocksSkipped ?? this.blocksSkipped,
      diagnosticCount: diagnosticCount ?? this.diagnosticCount,
      safeCheckpoint: safeCheckpoint ?? this.safeCheckpoint,
      cancellationRequested:
          cancellationRequested ?? this.cancellationRequested,
      startedAtMicros: startedAtMicros ?? this.startedAtMicros,
      finishedAtMicros: finishedAtMicros ?? this.finishedAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (bytesProcessed.present) {
      map['bytes_processed'] = Variable<int>(bytesProcessed.value);
    }
    if (blocksScanned.present) {
      map['blocks_scanned'] = Variable<int>(blocksScanned.value);
    }
    if (blocksIndexed.present) {
      map['blocks_indexed'] = Variable<int>(blocksIndexed.value);
    }
    if (blocksSkipped.present) {
      map['blocks_skipped'] = Variable<int>(blocksSkipped.value);
    }
    if (diagnosticCount.present) {
      map['diagnostic_count'] = Variable<int>(diagnosticCount.value);
    }
    if (safeCheckpoint.present) {
      map['safe_checkpoint'] = Variable<int>(safeCheckpoint.value);
    }
    if (cancellationRequested.present) {
      map['cancellation_requested'] = Variable<bool>(
        cancellationRequested.value,
      );
    }
    if (startedAtMicros.present) {
      map['started_at_micros'] = Variable<int>(startedAtMicros.value);
    }
    if (finishedAtMicros.present) {
      map['finished_at_micros'] = Variable<int>(finishedAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportJobsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('status: $status, ')
          ..write('bytesProcessed: $bytesProcessed, ')
          ..write('blocksScanned: $blocksScanned, ')
          ..write('blocksIndexed: $blocksIndexed, ')
          ..write('blocksSkipped: $blocksSkipped, ')
          ..write('diagnosticCount: $diagnosticCount, ')
          ..write('safeCheckpoint: $safeCheckpoint, ')
          ..write('cancellationRequested: $cancellationRequested, ')
          ..write('startedAtMicros: $startedAtMicros, ')
          ..write('finishedAtMicros: $finishedAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportDiagnosticsTable extends ImportDiagnostics
    with TableInfo<$ImportDiagnosticsTable, ImportDiagnostic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportDiagnosticsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importJobIdMeta = const VerificationMeta(
    'importJobId',
  );
  @override
  late final GeneratedColumn<String> importJobId = GeneratedColumn<String>(
    'import_job_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES import_jobs (id)',
    ),
  );
  static const VerificationMeta _severityMeta = const VerificationMeta(
    'severity',
  );
  @override
  late final GeneratedColumn<String> severity = GeneratedColumn<String>(
    'severity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blockOrdinalMeta = const VerificationMeta(
    'blockOrdinal',
  );
  @override
  late final GeneratedColumn<int> blockOrdinal = GeneratedColumn<int>(
    'block_ordinal',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startOffsetMeta = const VerificationMeta(
    'startOffset',
  );
  @override
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
    'start_offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endOffsetMeta = const VerificationMeta(
    'endOffset',
  );
  @override
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
    'end_offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diagnosticCodeMeta = const VerificationMeta(
    'diagnosticCode',
  );
  @override
  late final GeneratedColumn<String> diagnosticCode = GeneratedColumn<String>(
    'diagnostic_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sanitizedMessageMeta = const VerificationMeta(
    'sanitizedMessage',
  );
  @override
  late final GeneratedColumn<String> sanitizedMessage = GeneratedColumn<String>(
    'sanitized_message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMicrosMeta = const VerificationMeta(
    'createdAtMicros',
  );
  @override
  late final GeneratedColumn<int> createdAtMicros = GeneratedColumn<int>(
    'created_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    importJobId,
    severity,
    blockOrdinal,
    startOffset,
    endOffset,
    diagnosticCode,
    sanitizedMessage,
    createdAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_diagnostics';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportDiagnostic> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('import_job_id')) {
      context.handle(
        _importJobIdMeta,
        importJobId.isAcceptableOrUnknown(
          data['import_job_id']!,
          _importJobIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_importJobIdMeta);
    }
    if (data.containsKey('severity')) {
      context.handle(
        _severityMeta,
        severity.isAcceptableOrUnknown(data['severity']!, _severityMeta),
      );
    } else if (isInserting) {
      context.missing(_severityMeta);
    }
    if (data.containsKey('block_ordinal')) {
      context.handle(
        _blockOrdinalMeta,
        blockOrdinal.isAcceptableOrUnknown(
          data['block_ordinal']!,
          _blockOrdinalMeta,
        ),
      );
    }
    if (data.containsKey('start_offset')) {
      context.handle(
        _startOffsetMeta,
        startOffset.isAcceptableOrUnknown(
          data['start_offset']!,
          _startOffsetMeta,
        ),
      );
    }
    if (data.containsKey('end_offset')) {
      context.handle(
        _endOffsetMeta,
        endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta),
      );
    }
    if (data.containsKey('diagnostic_code')) {
      context.handle(
        _diagnosticCodeMeta,
        diagnosticCode.isAcceptableOrUnknown(
          data['diagnostic_code']!,
          _diagnosticCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_diagnosticCodeMeta);
    }
    if (data.containsKey('sanitized_message')) {
      context.handle(
        _sanitizedMessageMeta,
        sanitizedMessage.isAcceptableOrUnknown(
          data['sanitized_message']!,
          _sanitizedMessageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sanitizedMessageMeta);
    }
    if (data.containsKey('created_at_micros')) {
      context.handle(
        _createdAtMicrosMeta,
        createdAtMicros.isAcceptableOrUnknown(
          data['created_at_micros']!,
          _createdAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImportDiagnostic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportDiagnostic(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      importJobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_job_id'],
      )!,
      severity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}severity'],
      )!,
      blockOrdinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}block_ordinal'],
      ),
      startOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_offset'],
      ),
      endOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_offset'],
      ),
      diagnosticCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diagnostic_code'],
      )!,
      sanitizedMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sanitized_message'],
      )!,
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
    );
  }

  @override
  $ImportDiagnosticsTable createAlias(String alias) {
    return $ImportDiagnosticsTable(attachedDatabase, alias);
  }
}

class ImportDiagnostic extends DataClass
    implements Insertable<ImportDiagnostic> {
  final String id;
  final String importJobId;
  final String severity;
  final int? blockOrdinal;
  final int? startOffset;
  final int? endOffset;
  final String diagnosticCode;
  final String sanitizedMessage;
  final int createdAtMicros;
  const ImportDiagnostic({
    required this.id,
    required this.importJobId,
    required this.severity,
    this.blockOrdinal,
    this.startOffset,
    this.endOffset,
    required this.diagnosticCode,
    required this.sanitizedMessage,
    required this.createdAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['import_job_id'] = Variable<String>(importJobId);
    map['severity'] = Variable<String>(severity);
    if (!nullToAbsent || blockOrdinal != null) {
      map['block_ordinal'] = Variable<int>(blockOrdinal);
    }
    if (!nullToAbsent || startOffset != null) {
      map['start_offset'] = Variable<int>(startOffset);
    }
    if (!nullToAbsent || endOffset != null) {
      map['end_offset'] = Variable<int>(endOffset);
    }
    map['diagnostic_code'] = Variable<String>(diagnosticCode);
    map['sanitized_message'] = Variable<String>(sanitizedMessage);
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    return map;
  }

  ImportDiagnosticsCompanion toCompanion(bool nullToAbsent) {
    return ImportDiagnosticsCompanion(
      id: Value(id),
      importJobId: Value(importJobId),
      severity: Value(severity),
      blockOrdinal: blockOrdinal == null && nullToAbsent
          ? const Value.absent()
          : Value(blockOrdinal),
      startOffset: startOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(startOffset),
      endOffset: endOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(endOffset),
      diagnosticCode: Value(diagnosticCode),
      sanitizedMessage: Value(sanitizedMessage),
      createdAtMicros: Value(createdAtMicros),
    );
  }

  factory ImportDiagnostic.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportDiagnostic(
      id: serializer.fromJson<String>(json['id']),
      importJobId: serializer.fromJson<String>(json['importJobId']),
      severity: serializer.fromJson<String>(json['severity']),
      blockOrdinal: serializer.fromJson<int?>(json['blockOrdinal']),
      startOffset: serializer.fromJson<int?>(json['startOffset']),
      endOffset: serializer.fromJson<int?>(json['endOffset']),
      diagnosticCode: serializer.fromJson<String>(json['diagnosticCode']),
      sanitizedMessage: serializer.fromJson<String>(json['sanitizedMessage']),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'importJobId': serializer.toJson<String>(importJobId),
      'severity': serializer.toJson<String>(severity),
      'blockOrdinal': serializer.toJson<int?>(blockOrdinal),
      'startOffset': serializer.toJson<int?>(startOffset),
      'endOffset': serializer.toJson<int?>(endOffset),
      'diagnosticCode': serializer.toJson<String>(diagnosticCode),
      'sanitizedMessage': serializer.toJson<String>(sanitizedMessage),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
    };
  }

  ImportDiagnostic copyWith({
    String? id,
    String? importJobId,
    String? severity,
    Value<int?> blockOrdinal = const Value.absent(),
    Value<int?> startOffset = const Value.absent(),
    Value<int?> endOffset = const Value.absent(),
    String? diagnosticCode,
    String? sanitizedMessage,
    int? createdAtMicros,
  }) => ImportDiagnostic(
    id: id ?? this.id,
    importJobId: importJobId ?? this.importJobId,
    severity: severity ?? this.severity,
    blockOrdinal: blockOrdinal.present ? blockOrdinal.value : this.blockOrdinal,
    startOffset: startOffset.present ? startOffset.value : this.startOffset,
    endOffset: endOffset.present ? endOffset.value : this.endOffset,
    diagnosticCode: diagnosticCode ?? this.diagnosticCode,
    sanitizedMessage: sanitizedMessage ?? this.sanitizedMessage,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
  );
  ImportDiagnostic copyWithCompanion(ImportDiagnosticsCompanion data) {
    return ImportDiagnostic(
      id: data.id.present ? data.id.value : this.id,
      importJobId: data.importJobId.present
          ? data.importJobId.value
          : this.importJobId,
      severity: data.severity.present ? data.severity.value : this.severity,
      blockOrdinal: data.blockOrdinal.present
          ? data.blockOrdinal.value
          : this.blockOrdinal,
      startOffset: data.startOffset.present
          ? data.startOffset.value
          : this.startOffset,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      diagnosticCode: data.diagnosticCode.present
          ? data.diagnosticCode.value
          : this.diagnosticCode,
      sanitizedMessage: data.sanitizedMessage.present
          ? data.sanitizedMessage.value
          : this.sanitizedMessage,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportDiagnostic(')
          ..write('id: $id, ')
          ..write('importJobId: $importJobId, ')
          ..write('severity: $severity, ')
          ..write('blockOrdinal: $blockOrdinal, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('diagnosticCode: $diagnosticCode, ')
          ..write('sanitizedMessage: $sanitizedMessage, ')
          ..write('createdAtMicros: $createdAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    importJobId,
    severity,
    blockOrdinal,
    startOffset,
    endOffset,
    diagnosticCode,
    sanitizedMessage,
    createdAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportDiagnostic &&
          other.id == this.id &&
          other.importJobId == this.importJobId &&
          other.severity == this.severity &&
          other.blockOrdinal == this.blockOrdinal &&
          other.startOffset == this.startOffset &&
          other.endOffset == this.endOffset &&
          other.diagnosticCode == this.diagnosticCode &&
          other.sanitizedMessage == this.sanitizedMessage &&
          other.createdAtMicros == this.createdAtMicros);
}

class ImportDiagnosticsCompanion extends UpdateCompanion<ImportDiagnostic> {
  final Value<String> id;
  final Value<String> importJobId;
  final Value<String> severity;
  final Value<int?> blockOrdinal;
  final Value<int?> startOffset;
  final Value<int?> endOffset;
  final Value<String> diagnosticCode;
  final Value<String> sanitizedMessage;
  final Value<int> createdAtMicros;
  final Value<int> rowid;
  const ImportDiagnosticsCompanion({
    this.id = const Value.absent(),
    this.importJobId = const Value.absent(),
    this.severity = const Value.absent(),
    this.blockOrdinal = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.diagnosticCode = const Value.absent(),
    this.sanitizedMessage = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportDiagnosticsCompanion.insert({
    required String id,
    required String importJobId,
    required String severity,
    this.blockOrdinal = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    required String diagnosticCode,
    required String sanitizedMessage,
    required int createdAtMicros,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       importJobId = Value(importJobId),
       severity = Value(severity),
       diagnosticCode = Value(diagnosticCode),
       sanitizedMessage = Value(sanitizedMessage),
       createdAtMicros = Value(createdAtMicros);
  static Insertable<ImportDiagnostic> custom({
    Expression<String>? id,
    Expression<String>? importJobId,
    Expression<String>? severity,
    Expression<int>? blockOrdinal,
    Expression<int>? startOffset,
    Expression<int>? endOffset,
    Expression<String>? diagnosticCode,
    Expression<String>? sanitizedMessage,
    Expression<int>? createdAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (importJobId != null) 'import_job_id': importJobId,
      if (severity != null) 'severity': severity,
      if (blockOrdinal != null) 'block_ordinal': blockOrdinal,
      if (startOffset != null) 'start_offset': startOffset,
      if (endOffset != null) 'end_offset': endOffset,
      if (diagnosticCode != null) 'diagnostic_code': diagnosticCode,
      if (sanitizedMessage != null) 'sanitized_message': sanitizedMessage,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportDiagnosticsCompanion copyWith({
    Value<String>? id,
    Value<String>? importJobId,
    Value<String>? severity,
    Value<int?>? blockOrdinal,
    Value<int?>? startOffset,
    Value<int?>? endOffset,
    Value<String>? diagnosticCode,
    Value<String>? sanitizedMessage,
    Value<int>? createdAtMicros,
    Value<int>? rowid,
  }) {
    return ImportDiagnosticsCompanion(
      id: id ?? this.id,
      importJobId: importJobId ?? this.importJobId,
      severity: severity ?? this.severity,
      blockOrdinal: blockOrdinal ?? this.blockOrdinal,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      diagnosticCode: diagnosticCode ?? this.diagnosticCode,
      sanitizedMessage: sanitizedMessage ?? this.sanitizedMessage,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (importJobId.present) {
      map['import_job_id'] = Variable<String>(importJobId.value);
    }
    if (severity.present) {
      map['severity'] = Variable<String>(severity.value);
    }
    if (blockOrdinal.present) {
      map['block_ordinal'] = Variable<int>(blockOrdinal.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
    }
    if (diagnosticCode.present) {
      map['diagnostic_code'] = Variable<String>(diagnosticCode.value);
    }
    if (sanitizedMessage.present) {
      map['sanitized_message'] = Variable<String>(sanitizedMessage.value);
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportDiagnosticsCompanion(')
          ..write('id: $id, ')
          ..write('importJobId: $importJobId, ')
          ..write('severity: $severity, ')
          ..write('blockOrdinal: $blockOrdinal, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('diagnosticCode: $diagnosticCode, ')
          ..write('sanitizedMessage: $sanitizedMessage, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrainingSetsTable extends TrainingSets
    with TableInfo<$TrainingSetsTable, TrainingSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrainingSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _createdAtMicrosMeta = const VerificationMeta(
    'createdAtMicros',
  );
  @override
  late final GeneratedColumn<int> createdAtMicros = GeneratedColumn<int>(
    'created_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMicrosMeta = const VerificationMeta(
    'updatedAtMicros',
  );
  @override
  late final GeneratedColumn<int> updatedAtMicros = GeneratedColumn<int>(
    'updated_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMicrosMeta = const VerificationMeta(
    'archivedAtMicros',
  );
  @override
  late final GeneratedColumn<int> archivedAtMicros = GeneratedColumn<int>(
    'archived_at_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    status,
    createdAtMicros,
    updatedAtMicros,
    archivedAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'training_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrainingSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at_micros')) {
      context.handle(
        _createdAtMicrosMeta,
        createdAtMicros.isAcceptableOrUnknown(
          data['created_at_micros']!,
          _createdAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMicrosMeta);
    }
    if (data.containsKey('updated_at_micros')) {
      context.handle(
        _updatedAtMicrosMeta,
        updatedAtMicros.isAcceptableOrUnknown(
          data['updated_at_micros']!,
          _updatedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMicrosMeta);
    }
    if (data.containsKey('archived_at_micros')) {
      context.handle(
        _archivedAtMicrosMeta,
        archivedAtMicros.isAcceptableOrUnknown(
          data['archived_at_micros']!,
          _archivedAtMicrosMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrainingSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrainingSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
      updatedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_micros'],
      )!,
      archivedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived_at_micros'],
      ),
    );
  }

  @override
  $TrainingSetsTable createAlias(String alias) {
    return $TrainingSetsTable(attachedDatabase, alias);
  }
}

class TrainingSet extends DataClass implements Insertable<TrainingSet> {
  final String id;
  final String name;
  final String status;
  final int createdAtMicros;
  final int updatedAtMicros;
  final int? archivedAtMicros;
  const TrainingSet({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAtMicros,
    required this.updatedAtMicros,
    this.archivedAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['status'] = Variable<String>(status);
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    map['updated_at_micros'] = Variable<int>(updatedAtMicros);
    if (!nullToAbsent || archivedAtMicros != null) {
      map['archived_at_micros'] = Variable<int>(archivedAtMicros);
    }
    return map;
  }

  TrainingSetsCompanion toCompanion(bool nullToAbsent) {
    return TrainingSetsCompanion(
      id: Value(id),
      name: Value(name),
      status: Value(status),
      createdAtMicros: Value(createdAtMicros),
      updatedAtMicros: Value(updatedAtMicros),
      archivedAtMicros: archivedAtMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAtMicros),
    );
  }

  factory TrainingSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrainingSet(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String>(json['status']),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
      updatedAtMicros: serializer.fromJson<int>(json['updatedAtMicros']),
      archivedAtMicros: serializer.fromJson<int?>(json['archivedAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String>(status),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
      'updatedAtMicros': serializer.toJson<int>(updatedAtMicros),
      'archivedAtMicros': serializer.toJson<int?>(archivedAtMicros),
    };
  }

  TrainingSet copyWith({
    String? id,
    String? name,
    String? status,
    int? createdAtMicros,
    int? updatedAtMicros,
    Value<int?> archivedAtMicros = const Value.absent(),
  }) => TrainingSet(
    id: id ?? this.id,
    name: name ?? this.name,
    status: status ?? this.status,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
    updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
    archivedAtMicros: archivedAtMicros.present
        ? archivedAtMicros.value
        : this.archivedAtMicros,
  );
  TrainingSet copyWithCompanion(TrainingSetsCompanion data) {
    return TrainingSet(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
      updatedAtMicros: data.updatedAtMicros.present
          ? data.updatedAtMicros.value
          : this.updatedAtMicros,
      archivedAtMicros: data.archivedAtMicros.present
          ? data.archivedAtMicros.value
          : this.archivedAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrainingSet(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('archivedAtMicros: $archivedAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    status,
    createdAtMicros,
    updatedAtMicros,
    archivedAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrainingSet &&
          other.id == this.id &&
          other.name == this.name &&
          other.status == this.status &&
          other.createdAtMicros == this.createdAtMicros &&
          other.updatedAtMicros == this.updatedAtMicros &&
          other.archivedAtMicros == this.archivedAtMicros);
}

class TrainingSetsCompanion extends UpdateCompanion<TrainingSet> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> status;
  final Value<int> createdAtMicros;
  final Value<int> updatedAtMicros;
  final Value<int?> archivedAtMicros;
  final Value<int> rowid;
  const TrainingSetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.updatedAtMicros = const Value.absent(),
    this.archivedAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrainingSetsCompanion.insert({
    required String id,
    required String name,
    this.status = const Value.absent(),
    required int createdAtMicros,
    required int updatedAtMicros,
    this.archivedAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAtMicros = Value(createdAtMicros),
       updatedAtMicros = Value(updatedAtMicros);
  static Insertable<TrainingSet> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? status,
    Expression<int>? createdAtMicros,
    Expression<int>? updatedAtMicros,
    Expression<int>? archivedAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (updatedAtMicros != null) 'updated_at_micros': updatedAtMicros,
      if (archivedAtMicros != null) 'archived_at_micros': archivedAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrainingSetsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? status,
    Value<int>? createdAtMicros,
    Value<int>? updatedAtMicros,
    Value<int?>? archivedAtMicros,
    Value<int>? rowid,
  }) {
    return TrainingSetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      archivedAtMicros: archivedAtMicros ?? this.archivedAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (updatedAtMicros.present) {
      map['updated_at_micros'] = Variable<int>(updatedAtMicros.value);
    }
    if (archivedAtMicros.present) {
      map['archived_at_micros'] = Variable<int>(archivedAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrainingSetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('archivedAtMicros: $archivedAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrainingSetItemsTable extends TrainingSetItems
    with TableInfo<$TrainingSetItemsTable, TrainingSetItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrainingSetItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trainingSetIdMeta = const VerificationMeta(
    'trainingSetId',
  );
  @override
  late final GeneratedColumn<String> trainingSetId = GeneratedColumn<String>(
    'training_set_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES training_sets (id)',
    ),
  );
  static const VerificationMeta _blockIdMeta = const VerificationMeta(
    'blockId',
  );
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
    'block_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pgn_blocks (id)',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentTypeMeta = const VerificationMeta(
    'contentType',
  );
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
    'content_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _addedAtMicrosMeta = const VerificationMeta(
    'addedAtMicros',
  );
  @override
  late final GeneratedColumn<int> addedAtMicros = GeneratedColumn<int>(
    'added_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trainingSetId,
    blockId,
    position,
    contentType,
    state,
    addedAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'training_set_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrainingSetItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('training_set_id')) {
      context.handle(
        _trainingSetIdMeta,
        trainingSetId.isAcceptableOrUnknown(
          data['training_set_id']!,
          _trainingSetIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_trainingSetIdMeta);
    }
    if (data.containsKey('block_id')) {
      context.handle(
        _blockIdMeta,
        blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blockIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('content_type')) {
      context.handle(
        _contentTypeMeta,
        contentType.isAcceptableOrUnknown(
          data['content_type']!,
          _contentTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentTypeMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('added_at_micros')) {
      context.handle(
        _addedAtMicrosMeta,
        addedAtMicros.isAcceptableOrUnknown(
          data['added_at_micros']!,
          _addedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_addedAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {trainingSetId, position},
  ];
  @override
  TrainingSetItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrainingSetItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      trainingSetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}training_set_id'],
      )!,
      blockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      contentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_type'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      addedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at_micros'],
      )!,
    );
  }

  @override
  $TrainingSetItemsTable createAlias(String alias) {
    return $TrainingSetItemsTable(attachedDatabase, alias);
  }
}

class TrainingSetItem extends DataClass implements Insertable<TrainingSetItem> {
  final String id;
  final String trainingSetId;
  final String blockId;
  final int position;
  final String contentType;
  final String state;
  final int addedAtMicros;
  const TrainingSetItem({
    required this.id,
    required this.trainingSetId,
    required this.blockId,
    required this.position,
    required this.contentType,
    required this.state,
    required this.addedAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['training_set_id'] = Variable<String>(trainingSetId);
    map['block_id'] = Variable<String>(blockId);
    map['position'] = Variable<int>(position);
    map['content_type'] = Variable<String>(contentType);
    map['state'] = Variable<String>(state);
    map['added_at_micros'] = Variable<int>(addedAtMicros);
    return map;
  }

  TrainingSetItemsCompanion toCompanion(bool nullToAbsent) {
    return TrainingSetItemsCompanion(
      id: Value(id),
      trainingSetId: Value(trainingSetId),
      blockId: Value(blockId),
      position: Value(position),
      contentType: Value(contentType),
      state: Value(state),
      addedAtMicros: Value(addedAtMicros),
    );
  }

  factory TrainingSetItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrainingSetItem(
      id: serializer.fromJson<String>(json['id']),
      trainingSetId: serializer.fromJson<String>(json['trainingSetId']),
      blockId: serializer.fromJson<String>(json['blockId']),
      position: serializer.fromJson<int>(json['position']),
      contentType: serializer.fromJson<String>(json['contentType']),
      state: serializer.fromJson<String>(json['state']),
      addedAtMicros: serializer.fromJson<int>(json['addedAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'trainingSetId': serializer.toJson<String>(trainingSetId),
      'blockId': serializer.toJson<String>(blockId),
      'position': serializer.toJson<int>(position),
      'contentType': serializer.toJson<String>(contentType),
      'state': serializer.toJson<String>(state),
      'addedAtMicros': serializer.toJson<int>(addedAtMicros),
    };
  }

  TrainingSetItem copyWith({
    String? id,
    String? trainingSetId,
    String? blockId,
    int? position,
    String? contentType,
    String? state,
    int? addedAtMicros,
  }) => TrainingSetItem(
    id: id ?? this.id,
    trainingSetId: trainingSetId ?? this.trainingSetId,
    blockId: blockId ?? this.blockId,
    position: position ?? this.position,
    contentType: contentType ?? this.contentType,
    state: state ?? this.state,
    addedAtMicros: addedAtMicros ?? this.addedAtMicros,
  );
  TrainingSetItem copyWithCompanion(TrainingSetItemsCompanion data) {
    return TrainingSetItem(
      id: data.id.present ? data.id.value : this.id,
      trainingSetId: data.trainingSetId.present
          ? data.trainingSetId.value
          : this.trainingSetId,
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      position: data.position.present ? data.position.value : this.position,
      contentType: data.contentType.present
          ? data.contentType.value
          : this.contentType,
      state: data.state.present ? data.state.value : this.state,
      addedAtMicros: data.addedAtMicros.present
          ? data.addedAtMicros.value
          : this.addedAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrainingSetItem(')
          ..write('id: $id, ')
          ..write('trainingSetId: $trainingSetId, ')
          ..write('blockId: $blockId, ')
          ..write('position: $position, ')
          ..write('contentType: $contentType, ')
          ..write('state: $state, ')
          ..write('addedAtMicros: $addedAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    trainingSetId,
    blockId,
    position,
    contentType,
    state,
    addedAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrainingSetItem &&
          other.id == this.id &&
          other.trainingSetId == this.trainingSetId &&
          other.blockId == this.blockId &&
          other.position == this.position &&
          other.contentType == this.contentType &&
          other.state == this.state &&
          other.addedAtMicros == this.addedAtMicros);
}

class TrainingSetItemsCompanion extends UpdateCompanion<TrainingSetItem> {
  final Value<String> id;
  final Value<String> trainingSetId;
  final Value<String> blockId;
  final Value<int> position;
  final Value<String> contentType;
  final Value<String> state;
  final Value<int> addedAtMicros;
  final Value<int> rowid;
  const TrainingSetItemsCompanion({
    this.id = const Value.absent(),
    this.trainingSetId = const Value.absent(),
    this.blockId = const Value.absent(),
    this.position = const Value.absent(),
    this.contentType = const Value.absent(),
    this.state = const Value.absent(),
    this.addedAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrainingSetItemsCompanion.insert({
    required String id,
    required String trainingSetId,
    required String blockId,
    required int position,
    required String contentType,
    this.state = const Value.absent(),
    required int addedAtMicros,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       trainingSetId = Value(trainingSetId),
       blockId = Value(blockId),
       position = Value(position),
       contentType = Value(contentType),
       addedAtMicros = Value(addedAtMicros);
  static Insertable<TrainingSetItem> custom({
    Expression<String>? id,
    Expression<String>? trainingSetId,
    Expression<String>? blockId,
    Expression<int>? position,
    Expression<String>? contentType,
    Expression<String>? state,
    Expression<int>? addedAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trainingSetId != null) 'training_set_id': trainingSetId,
      if (blockId != null) 'block_id': blockId,
      if (position != null) 'position': position,
      if (contentType != null) 'content_type': contentType,
      if (state != null) 'state': state,
      if (addedAtMicros != null) 'added_at_micros': addedAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrainingSetItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? trainingSetId,
    Value<String>? blockId,
    Value<int>? position,
    Value<String>? contentType,
    Value<String>? state,
    Value<int>? addedAtMicros,
    Value<int>? rowid,
  }) {
    return TrainingSetItemsCompanion(
      id: id ?? this.id,
      trainingSetId: trainingSetId ?? this.trainingSetId,
      blockId: blockId ?? this.blockId,
      position: position ?? this.position,
      contentType: contentType ?? this.contentType,
      state: state ?? this.state,
      addedAtMicros: addedAtMicros ?? this.addedAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (trainingSetId.present) {
      map['training_set_id'] = Variable<String>(trainingSetId.value);
    }
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (addedAtMicros.present) {
      map['added_at_micros'] = Variable<int>(addedAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrainingSetItemsCompanion(')
          ..write('id: $id, ')
          ..write('trainingSetId: $trainingSetId, ')
          ..write('blockId: $blockId, ')
          ..write('position: $position, ')
          ..write('contentType: $contentType, ')
          ..write('state: $state, ')
          ..write('addedAtMicros: $addedAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CyclesTable extends Cycles with TableInfo<$CyclesTable, Cycle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CyclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trainingSetIdMeta = const VerificationMeta(
    'trainingSetId',
  );
  @override
  late final GeneratedColumn<String> trainingSetId = GeneratedColumn<String>(
    'training_set_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES training_sets (id)',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMicrosMeta = const VerificationMeta(
    'startedAtMicros',
  );
  @override
  late final GeneratedColumn<int> startedAtMicros = GeneratedColumn<int>(
    'started_at_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMicrosMeta = const VerificationMeta(
    'completedAtMicros',
  );
  @override
  late final GeneratedColumn<int> completedAtMicros = GeneratedColumn<int>(
    'completed_at_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stoppedAtMicrosMeta = const VerificationMeta(
    'stoppedAtMicros',
  );
  @override
  late final GeneratedColumn<int> stoppedAtMicros = GeneratedColumn<int>(
    'stopped_at_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMicrosMeta = const VerificationMeta(
    'createdAtMicros',
  );
  @override
  late final GeneratedColumn<int> createdAtMicros = GeneratedColumn<int>(
    'created_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trainingSetId,
    status,
    startedAtMicros,
    completedAtMicros,
    stoppedAtMicros,
    createdAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cycles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Cycle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('training_set_id')) {
      context.handle(
        _trainingSetIdMeta,
        trainingSetId.isAcceptableOrUnknown(
          data['training_set_id']!,
          _trainingSetIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_trainingSetIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('started_at_micros')) {
      context.handle(
        _startedAtMicrosMeta,
        startedAtMicros.isAcceptableOrUnknown(
          data['started_at_micros']!,
          _startedAtMicrosMeta,
        ),
      );
    }
    if (data.containsKey('completed_at_micros')) {
      context.handle(
        _completedAtMicrosMeta,
        completedAtMicros.isAcceptableOrUnknown(
          data['completed_at_micros']!,
          _completedAtMicrosMeta,
        ),
      );
    }
    if (data.containsKey('stopped_at_micros')) {
      context.handle(
        _stoppedAtMicrosMeta,
        stoppedAtMicros.isAcceptableOrUnknown(
          data['stopped_at_micros']!,
          _stoppedAtMicrosMeta,
        ),
      );
    }
    if (data.containsKey('created_at_micros')) {
      context.handle(
        _createdAtMicrosMeta,
        createdAtMicros.isAcceptableOrUnknown(
          data['created_at_micros']!,
          _createdAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Cycle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cycle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      trainingSetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}training_set_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_micros'],
      ),
      completedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at_micros'],
      ),
      stoppedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stopped_at_micros'],
      ),
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
    );
  }

  @override
  $CyclesTable createAlias(String alias) {
    return $CyclesTable(attachedDatabase, alias);
  }
}

class Cycle extends DataClass implements Insertable<Cycle> {
  final String id;
  final String trainingSetId;
  final String status;
  final int? startedAtMicros;
  final int? completedAtMicros;
  final int? stoppedAtMicros;
  final int createdAtMicros;
  const Cycle({
    required this.id,
    required this.trainingSetId,
    required this.status,
    this.startedAtMicros,
    this.completedAtMicros,
    this.stoppedAtMicros,
    required this.createdAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['training_set_id'] = Variable<String>(trainingSetId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || startedAtMicros != null) {
      map['started_at_micros'] = Variable<int>(startedAtMicros);
    }
    if (!nullToAbsent || completedAtMicros != null) {
      map['completed_at_micros'] = Variable<int>(completedAtMicros);
    }
    if (!nullToAbsent || stoppedAtMicros != null) {
      map['stopped_at_micros'] = Variable<int>(stoppedAtMicros);
    }
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    return map;
  }

  CyclesCompanion toCompanion(bool nullToAbsent) {
    return CyclesCompanion(
      id: Value(id),
      trainingSetId: Value(trainingSetId),
      status: Value(status),
      startedAtMicros: startedAtMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAtMicros),
      completedAtMicros: completedAtMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAtMicros),
      stoppedAtMicros: stoppedAtMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(stoppedAtMicros),
      createdAtMicros: Value(createdAtMicros),
    );
  }

  factory Cycle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cycle(
      id: serializer.fromJson<String>(json['id']),
      trainingSetId: serializer.fromJson<String>(json['trainingSetId']),
      status: serializer.fromJson<String>(json['status']),
      startedAtMicros: serializer.fromJson<int?>(json['startedAtMicros']),
      completedAtMicros: serializer.fromJson<int?>(json['completedAtMicros']),
      stoppedAtMicros: serializer.fromJson<int?>(json['stoppedAtMicros']),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'trainingSetId': serializer.toJson<String>(trainingSetId),
      'status': serializer.toJson<String>(status),
      'startedAtMicros': serializer.toJson<int?>(startedAtMicros),
      'completedAtMicros': serializer.toJson<int?>(completedAtMicros),
      'stoppedAtMicros': serializer.toJson<int?>(stoppedAtMicros),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
    };
  }

  Cycle copyWith({
    String? id,
    String? trainingSetId,
    String? status,
    Value<int?> startedAtMicros = const Value.absent(),
    Value<int?> completedAtMicros = const Value.absent(),
    Value<int?> stoppedAtMicros = const Value.absent(),
    int? createdAtMicros,
  }) => Cycle(
    id: id ?? this.id,
    trainingSetId: trainingSetId ?? this.trainingSetId,
    status: status ?? this.status,
    startedAtMicros: startedAtMicros.present
        ? startedAtMicros.value
        : this.startedAtMicros,
    completedAtMicros: completedAtMicros.present
        ? completedAtMicros.value
        : this.completedAtMicros,
    stoppedAtMicros: stoppedAtMicros.present
        ? stoppedAtMicros.value
        : this.stoppedAtMicros,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
  );
  Cycle copyWithCompanion(CyclesCompanion data) {
    return Cycle(
      id: data.id.present ? data.id.value : this.id,
      trainingSetId: data.trainingSetId.present
          ? data.trainingSetId.value
          : this.trainingSetId,
      status: data.status.present ? data.status.value : this.status,
      startedAtMicros: data.startedAtMicros.present
          ? data.startedAtMicros.value
          : this.startedAtMicros,
      completedAtMicros: data.completedAtMicros.present
          ? data.completedAtMicros.value
          : this.completedAtMicros,
      stoppedAtMicros: data.stoppedAtMicros.present
          ? data.stoppedAtMicros.value
          : this.stoppedAtMicros,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cycle(')
          ..write('id: $id, ')
          ..write('trainingSetId: $trainingSetId, ')
          ..write('status: $status, ')
          ..write('startedAtMicros: $startedAtMicros, ')
          ..write('completedAtMicros: $completedAtMicros, ')
          ..write('stoppedAtMicros: $stoppedAtMicros, ')
          ..write('createdAtMicros: $createdAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    trainingSetId,
    status,
    startedAtMicros,
    completedAtMicros,
    stoppedAtMicros,
    createdAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cycle &&
          other.id == this.id &&
          other.trainingSetId == this.trainingSetId &&
          other.status == this.status &&
          other.startedAtMicros == this.startedAtMicros &&
          other.completedAtMicros == this.completedAtMicros &&
          other.stoppedAtMicros == this.stoppedAtMicros &&
          other.createdAtMicros == this.createdAtMicros);
}

class CyclesCompanion extends UpdateCompanion<Cycle> {
  final Value<String> id;
  final Value<String> trainingSetId;
  final Value<String> status;
  final Value<int?> startedAtMicros;
  final Value<int?> completedAtMicros;
  final Value<int?> stoppedAtMicros;
  final Value<int> createdAtMicros;
  final Value<int> rowid;
  const CyclesCompanion({
    this.id = const Value.absent(),
    this.trainingSetId = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAtMicros = const Value.absent(),
    this.completedAtMicros = const Value.absent(),
    this.stoppedAtMicros = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CyclesCompanion.insert({
    required String id,
    required String trainingSetId,
    required String status,
    this.startedAtMicros = const Value.absent(),
    this.completedAtMicros = const Value.absent(),
    this.stoppedAtMicros = const Value.absent(),
    required int createdAtMicros,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       trainingSetId = Value(trainingSetId),
       status = Value(status),
       createdAtMicros = Value(createdAtMicros);
  static Insertable<Cycle> custom({
    Expression<String>? id,
    Expression<String>? trainingSetId,
    Expression<String>? status,
    Expression<int>? startedAtMicros,
    Expression<int>? completedAtMicros,
    Expression<int>? stoppedAtMicros,
    Expression<int>? createdAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trainingSetId != null) 'training_set_id': trainingSetId,
      if (status != null) 'status': status,
      if (startedAtMicros != null) 'started_at_micros': startedAtMicros,
      if (completedAtMicros != null) 'completed_at_micros': completedAtMicros,
      if (stoppedAtMicros != null) 'stopped_at_micros': stoppedAtMicros,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CyclesCompanion copyWith({
    Value<String>? id,
    Value<String>? trainingSetId,
    Value<String>? status,
    Value<int?>? startedAtMicros,
    Value<int?>? completedAtMicros,
    Value<int?>? stoppedAtMicros,
    Value<int>? createdAtMicros,
    Value<int>? rowid,
  }) {
    return CyclesCompanion(
      id: id ?? this.id,
      trainingSetId: trainingSetId ?? this.trainingSetId,
      status: status ?? this.status,
      startedAtMicros: startedAtMicros ?? this.startedAtMicros,
      completedAtMicros: completedAtMicros ?? this.completedAtMicros,
      stoppedAtMicros: stoppedAtMicros ?? this.stoppedAtMicros,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (trainingSetId.present) {
      map['training_set_id'] = Variable<String>(trainingSetId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAtMicros.present) {
      map['started_at_micros'] = Variable<int>(startedAtMicros.value);
    }
    if (completedAtMicros.present) {
      map['completed_at_micros'] = Variable<int>(completedAtMicros.value);
    }
    if (stoppedAtMicros.present) {
      map['stopped_at_micros'] = Variable<int>(stoppedAtMicros.value);
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CyclesCompanion(')
          ..write('id: $id, ')
          ..write('trainingSetId: $trainingSetId, ')
          ..write('status: $status, ')
          ..write('startedAtMicros: $startedAtMicros, ')
          ..write('completedAtMicros: $completedAtMicros, ')
          ..write('stoppedAtMicros: $stoppedAtMicros, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrainingSessionsTable extends TrainingSessions
    with TableInfo<$TrainingSessionsTable, TrainingSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrainingSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cycleIdMeta = const VerificationMeta(
    'cycleId',
  );
  @override
  late final GeneratedColumn<String> cycleId = GeneratedColumn<String>(
    'cycle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cycles (id)',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMicrosMeta = const VerificationMeta(
    'startedAtMicros',
  );
  @override
  late final GeneratedColumn<int> startedAtMicros = GeneratedColumn<int>(
    'started_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMicrosMeta = const VerificationMeta(
    'endedAtMicros',
  );
  @override
  late final GeneratedColumn<int> endedAtMicros = GeneratedColumn<int>(
    'ended_at_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _studyDayMicrosMeta = const VerificationMeta(
    'studyDayMicros',
  );
  @override
  late final GeneratedColumn<int> studyDayMicros = GeneratedColumn<int>(
    'study_day_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cycleId,
    status,
    startedAtMicros,
    endedAtMicros,
    studyDayMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'training_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrainingSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('cycle_id')) {
      context.handle(
        _cycleIdMeta,
        cycleId.isAcceptableOrUnknown(data['cycle_id']!, _cycleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cycleIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('started_at_micros')) {
      context.handle(
        _startedAtMicrosMeta,
        startedAtMicros.isAcceptableOrUnknown(
          data['started_at_micros']!,
          _startedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtMicrosMeta);
    }
    if (data.containsKey('ended_at_micros')) {
      context.handle(
        _endedAtMicrosMeta,
        endedAtMicros.isAcceptableOrUnknown(
          data['ended_at_micros']!,
          _endedAtMicrosMeta,
        ),
      );
    }
    if (data.containsKey('study_day_micros')) {
      context.handle(
        _studyDayMicrosMeta,
        studyDayMicros.isAcceptableOrUnknown(
          data['study_day_micros']!,
          _studyDayMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_studyDayMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrainingSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrainingSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cycleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cycle_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_micros'],
      )!,
      endedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at_micros'],
      ),
      studyDayMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}study_day_micros'],
      )!,
    );
  }

  @override
  $TrainingSessionsTable createAlias(String alias) {
    return $TrainingSessionsTable(attachedDatabase, alias);
  }
}

class TrainingSession extends DataClass implements Insertable<TrainingSession> {
  final String id;
  final String cycleId;
  final String status;
  final int startedAtMicros;
  final int? endedAtMicros;
  final int studyDayMicros;
  const TrainingSession({
    required this.id,
    required this.cycleId,
    required this.status,
    required this.startedAtMicros,
    this.endedAtMicros,
    required this.studyDayMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['cycle_id'] = Variable<String>(cycleId);
    map['status'] = Variable<String>(status);
    map['started_at_micros'] = Variable<int>(startedAtMicros);
    if (!nullToAbsent || endedAtMicros != null) {
      map['ended_at_micros'] = Variable<int>(endedAtMicros);
    }
    map['study_day_micros'] = Variable<int>(studyDayMicros);
    return map;
  }

  TrainingSessionsCompanion toCompanion(bool nullToAbsent) {
    return TrainingSessionsCompanion(
      id: Value(id),
      cycleId: Value(cycleId),
      status: Value(status),
      startedAtMicros: Value(startedAtMicros),
      endedAtMicros: endedAtMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtMicros),
      studyDayMicros: Value(studyDayMicros),
    );
  }

  factory TrainingSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrainingSession(
      id: serializer.fromJson<String>(json['id']),
      cycleId: serializer.fromJson<String>(json['cycleId']),
      status: serializer.fromJson<String>(json['status']),
      startedAtMicros: serializer.fromJson<int>(json['startedAtMicros']),
      endedAtMicros: serializer.fromJson<int?>(json['endedAtMicros']),
      studyDayMicros: serializer.fromJson<int>(json['studyDayMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cycleId': serializer.toJson<String>(cycleId),
      'status': serializer.toJson<String>(status),
      'startedAtMicros': serializer.toJson<int>(startedAtMicros),
      'endedAtMicros': serializer.toJson<int?>(endedAtMicros),
      'studyDayMicros': serializer.toJson<int>(studyDayMicros),
    };
  }

  TrainingSession copyWith({
    String? id,
    String? cycleId,
    String? status,
    int? startedAtMicros,
    Value<int?> endedAtMicros = const Value.absent(),
    int? studyDayMicros,
  }) => TrainingSession(
    id: id ?? this.id,
    cycleId: cycleId ?? this.cycleId,
    status: status ?? this.status,
    startedAtMicros: startedAtMicros ?? this.startedAtMicros,
    endedAtMicros: endedAtMicros.present
        ? endedAtMicros.value
        : this.endedAtMicros,
    studyDayMicros: studyDayMicros ?? this.studyDayMicros,
  );
  TrainingSession copyWithCompanion(TrainingSessionsCompanion data) {
    return TrainingSession(
      id: data.id.present ? data.id.value : this.id,
      cycleId: data.cycleId.present ? data.cycleId.value : this.cycleId,
      status: data.status.present ? data.status.value : this.status,
      startedAtMicros: data.startedAtMicros.present
          ? data.startedAtMicros.value
          : this.startedAtMicros,
      endedAtMicros: data.endedAtMicros.present
          ? data.endedAtMicros.value
          : this.endedAtMicros,
      studyDayMicros: data.studyDayMicros.present
          ? data.studyDayMicros.value
          : this.studyDayMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrainingSession(')
          ..write('id: $id, ')
          ..write('cycleId: $cycleId, ')
          ..write('status: $status, ')
          ..write('startedAtMicros: $startedAtMicros, ')
          ..write('endedAtMicros: $endedAtMicros, ')
          ..write('studyDayMicros: $studyDayMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cycleId,
    status,
    startedAtMicros,
    endedAtMicros,
    studyDayMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrainingSession &&
          other.id == this.id &&
          other.cycleId == this.cycleId &&
          other.status == this.status &&
          other.startedAtMicros == this.startedAtMicros &&
          other.endedAtMicros == this.endedAtMicros &&
          other.studyDayMicros == this.studyDayMicros);
}

class TrainingSessionsCompanion extends UpdateCompanion<TrainingSession> {
  final Value<String> id;
  final Value<String> cycleId;
  final Value<String> status;
  final Value<int> startedAtMicros;
  final Value<int?> endedAtMicros;
  final Value<int> studyDayMicros;
  final Value<int> rowid;
  const TrainingSessionsCompanion({
    this.id = const Value.absent(),
    this.cycleId = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAtMicros = const Value.absent(),
    this.endedAtMicros = const Value.absent(),
    this.studyDayMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrainingSessionsCompanion.insert({
    required String id,
    required String cycleId,
    required String status,
    required int startedAtMicros,
    this.endedAtMicros = const Value.absent(),
    required int studyDayMicros,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       cycleId = Value(cycleId),
       status = Value(status),
       startedAtMicros = Value(startedAtMicros),
       studyDayMicros = Value(studyDayMicros);
  static Insertable<TrainingSession> custom({
    Expression<String>? id,
    Expression<String>? cycleId,
    Expression<String>? status,
    Expression<int>? startedAtMicros,
    Expression<int>? endedAtMicros,
    Expression<int>? studyDayMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cycleId != null) 'cycle_id': cycleId,
      if (status != null) 'status': status,
      if (startedAtMicros != null) 'started_at_micros': startedAtMicros,
      if (endedAtMicros != null) 'ended_at_micros': endedAtMicros,
      if (studyDayMicros != null) 'study_day_micros': studyDayMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrainingSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? cycleId,
    Value<String>? status,
    Value<int>? startedAtMicros,
    Value<int?>? endedAtMicros,
    Value<int>? studyDayMicros,
    Value<int>? rowid,
  }) {
    return TrainingSessionsCompanion(
      id: id ?? this.id,
      cycleId: cycleId ?? this.cycleId,
      status: status ?? this.status,
      startedAtMicros: startedAtMicros ?? this.startedAtMicros,
      endedAtMicros: endedAtMicros ?? this.endedAtMicros,
      studyDayMicros: studyDayMicros ?? this.studyDayMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cycleId.present) {
      map['cycle_id'] = Variable<String>(cycleId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAtMicros.present) {
      map['started_at_micros'] = Variable<int>(startedAtMicros.value);
    }
    if (endedAtMicros.present) {
      map['ended_at_micros'] = Variable<int>(endedAtMicros.value);
    }
    if (studyDayMicros.present) {
      map['study_day_micros'] = Variable<int>(studyDayMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrainingSessionsCompanion(')
          ..write('id: $id, ')
          ..write('cycleId: $cycleId, ')
          ..write('status: $status, ')
          ..write('startedAtMicros: $startedAtMicros, ')
          ..write('endedAtMicros: $endedAtMicros, ')
          ..write('studyDayMicros: $studyDayMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PuzzleAttemptsTable extends PuzzleAttempts
    with TableInfo<$PuzzleAttemptsTable, PuzzleAttempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PuzzleAttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blockIdMeta = const VerificationMeta(
    'blockId',
  );
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
    'block_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pgn_blocks (id)',
    ),
  );
  static const VerificationMeta _cycleIdMeta = const VerificationMeta(
    'cycleId',
  );
  @override
  late final GeneratedColumn<String> cycleId = GeneratedColumn<String>(
    'cycle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cycles (id)',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES training_sessions (id)',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureReasonMeta = const VerificationMeta(
    'failureReason',
  );
  @override
  late final GeneratedColumn<String> failureReason = GeneratedColumn<String>(
    'failure_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMicrosMeta = const VerificationMeta(
    'startedAtMicros',
  );
  @override
  late final GeneratedColumn<int> startedAtMicros = GeneratedColumn<int>(
    'started_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMicrosMeta = const VerificationMeta(
    'completedAtMicros',
  );
  @override
  late final GeneratedColumn<int> completedAtMicros = GeneratedColumn<int>(
    'completed_at_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeMillisecondsMeta =
      const VerificationMeta('activeMilliseconds');
  @override
  late final GeneratedColumn<int> activeMilliseconds = GeneratedColumn<int>(
    'active_milliseconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wrongMoveCountMeta = const VerificationMeta(
    'wrongMoveCount',
  );
  @override
  late final GeneratedColumn<int> wrongMoveCount = GeneratedColumn<int>(
    'wrong_move_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hintCountMeta = const VerificationMeta(
    'hintCount',
  );
  @override
  late final GeneratedColumn<int> hintCount = GeneratedColumn<int>(
    'hint_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _revealedMeta = const VerificationMeta(
    'revealed',
  );
  @override
  late final GeneratedColumn<bool> revealed = GeneratedColumn<bool>(
    'revealed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("revealed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    blockId,
    cycleId,
    sessionId,
    status,
    outcome,
    failureReason,
    startedAtMicros,
    completedAtMicros,
    activeMilliseconds,
    wrongMoveCount,
    hintCount,
    revealed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'puzzle_attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<PuzzleAttempt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('block_id')) {
      context.handle(
        _blockIdMeta,
        blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blockIdMeta);
    }
    if (data.containsKey('cycle_id')) {
      context.handle(
        _cycleIdMeta,
        cycleId.isAcceptableOrUnknown(data['cycle_id']!, _cycleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cycleIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    }
    if (data.containsKey('failure_reason')) {
      context.handle(
        _failureReasonMeta,
        failureReason.isAcceptableOrUnknown(
          data['failure_reason']!,
          _failureReasonMeta,
        ),
      );
    }
    if (data.containsKey('started_at_micros')) {
      context.handle(
        _startedAtMicrosMeta,
        startedAtMicros.isAcceptableOrUnknown(
          data['started_at_micros']!,
          _startedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtMicrosMeta);
    }
    if (data.containsKey('completed_at_micros')) {
      context.handle(
        _completedAtMicrosMeta,
        completedAtMicros.isAcceptableOrUnknown(
          data['completed_at_micros']!,
          _completedAtMicrosMeta,
        ),
      );
    }
    if (data.containsKey('active_milliseconds')) {
      context.handle(
        _activeMillisecondsMeta,
        activeMilliseconds.isAcceptableOrUnknown(
          data['active_milliseconds']!,
          _activeMillisecondsMeta,
        ),
      );
    }
    if (data.containsKey('wrong_move_count')) {
      context.handle(
        _wrongMoveCountMeta,
        wrongMoveCount.isAcceptableOrUnknown(
          data['wrong_move_count']!,
          _wrongMoveCountMeta,
        ),
      );
    }
    if (data.containsKey('hint_count')) {
      context.handle(
        _hintCountMeta,
        hintCount.isAcceptableOrUnknown(data['hint_count']!, _hintCountMeta),
      );
    }
    if (data.containsKey('revealed')) {
      context.handle(
        _revealedMeta,
        revealed.isAcceptableOrUnknown(data['revealed']!, _revealedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PuzzleAttempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PuzzleAttempt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      blockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_id'],
      )!,
      cycleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cycle_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      ),
      failureReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_reason'],
      ),
      startedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_micros'],
      )!,
      completedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at_micros'],
      ),
      activeMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active_milliseconds'],
      )!,
      wrongMoveCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wrong_move_count'],
      )!,
      hintCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hint_count'],
      )!,
      revealed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}revealed'],
      )!,
    );
  }

  @override
  $PuzzleAttemptsTable createAlias(String alias) {
    return $PuzzleAttemptsTable(attachedDatabase, alias);
  }
}

class PuzzleAttempt extends DataClass implements Insertable<PuzzleAttempt> {
  final String id;
  final String blockId;
  final String cycleId;
  final String sessionId;
  final String status;
  final String? outcome;
  final String? failureReason;
  final int startedAtMicros;
  final int? completedAtMicros;
  final int activeMilliseconds;
  final int wrongMoveCount;
  final int hintCount;
  final bool revealed;
  const PuzzleAttempt({
    required this.id,
    required this.blockId,
    required this.cycleId,
    required this.sessionId,
    required this.status,
    this.outcome,
    this.failureReason,
    required this.startedAtMicros,
    this.completedAtMicros,
    required this.activeMilliseconds,
    required this.wrongMoveCount,
    required this.hintCount,
    required this.revealed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['block_id'] = Variable<String>(blockId);
    map['cycle_id'] = Variable<String>(cycleId);
    map['session_id'] = Variable<String>(sessionId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || outcome != null) {
      map['outcome'] = Variable<String>(outcome);
    }
    if (!nullToAbsent || failureReason != null) {
      map['failure_reason'] = Variable<String>(failureReason);
    }
    map['started_at_micros'] = Variable<int>(startedAtMicros);
    if (!nullToAbsent || completedAtMicros != null) {
      map['completed_at_micros'] = Variable<int>(completedAtMicros);
    }
    map['active_milliseconds'] = Variable<int>(activeMilliseconds);
    map['wrong_move_count'] = Variable<int>(wrongMoveCount);
    map['hint_count'] = Variable<int>(hintCount);
    map['revealed'] = Variable<bool>(revealed);
    return map;
  }

  PuzzleAttemptsCompanion toCompanion(bool nullToAbsent) {
    return PuzzleAttemptsCompanion(
      id: Value(id),
      blockId: Value(blockId),
      cycleId: Value(cycleId),
      sessionId: Value(sessionId),
      status: Value(status),
      outcome: outcome == null && nullToAbsent
          ? const Value.absent()
          : Value(outcome),
      failureReason: failureReason == null && nullToAbsent
          ? const Value.absent()
          : Value(failureReason),
      startedAtMicros: Value(startedAtMicros),
      completedAtMicros: completedAtMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAtMicros),
      activeMilliseconds: Value(activeMilliseconds),
      wrongMoveCount: Value(wrongMoveCount),
      hintCount: Value(hintCount),
      revealed: Value(revealed),
    );
  }

  factory PuzzleAttempt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PuzzleAttempt(
      id: serializer.fromJson<String>(json['id']),
      blockId: serializer.fromJson<String>(json['blockId']),
      cycleId: serializer.fromJson<String>(json['cycleId']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      status: serializer.fromJson<String>(json['status']),
      outcome: serializer.fromJson<String?>(json['outcome']),
      failureReason: serializer.fromJson<String?>(json['failureReason']),
      startedAtMicros: serializer.fromJson<int>(json['startedAtMicros']),
      completedAtMicros: serializer.fromJson<int?>(json['completedAtMicros']),
      activeMilliseconds: serializer.fromJson<int>(json['activeMilliseconds']),
      wrongMoveCount: serializer.fromJson<int>(json['wrongMoveCount']),
      hintCount: serializer.fromJson<int>(json['hintCount']),
      revealed: serializer.fromJson<bool>(json['revealed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'blockId': serializer.toJson<String>(blockId),
      'cycleId': serializer.toJson<String>(cycleId),
      'sessionId': serializer.toJson<String>(sessionId),
      'status': serializer.toJson<String>(status),
      'outcome': serializer.toJson<String?>(outcome),
      'failureReason': serializer.toJson<String?>(failureReason),
      'startedAtMicros': serializer.toJson<int>(startedAtMicros),
      'completedAtMicros': serializer.toJson<int?>(completedAtMicros),
      'activeMilliseconds': serializer.toJson<int>(activeMilliseconds),
      'wrongMoveCount': serializer.toJson<int>(wrongMoveCount),
      'hintCount': serializer.toJson<int>(hintCount),
      'revealed': serializer.toJson<bool>(revealed),
    };
  }

  PuzzleAttempt copyWith({
    String? id,
    String? blockId,
    String? cycleId,
    String? sessionId,
    String? status,
    Value<String?> outcome = const Value.absent(),
    Value<String?> failureReason = const Value.absent(),
    int? startedAtMicros,
    Value<int?> completedAtMicros = const Value.absent(),
    int? activeMilliseconds,
    int? wrongMoveCount,
    int? hintCount,
    bool? revealed,
  }) => PuzzleAttempt(
    id: id ?? this.id,
    blockId: blockId ?? this.blockId,
    cycleId: cycleId ?? this.cycleId,
    sessionId: sessionId ?? this.sessionId,
    status: status ?? this.status,
    outcome: outcome.present ? outcome.value : this.outcome,
    failureReason: failureReason.present
        ? failureReason.value
        : this.failureReason,
    startedAtMicros: startedAtMicros ?? this.startedAtMicros,
    completedAtMicros: completedAtMicros.present
        ? completedAtMicros.value
        : this.completedAtMicros,
    activeMilliseconds: activeMilliseconds ?? this.activeMilliseconds,
    wrongMoveCount: wrongMoveCount ?? this.wrongMoveCount,
    hintCount: hintCount ?? this.hintCount,
    revealed: revealed ?? this.revealed,
  );
  PuzzleAttempt copyWithCompanion(PuzzleAttemptsCompanion data) {
    return PuzzleAttempt(
      id: data.id.present ? data.id.value : this.id,
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      cycleId: data.cycleId.present ? data.cycleId.value : this.cycleId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      status: data.status.present ? data.status.value : this.status,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      failureReason: data.failureReason.present
          ? data.failureReason.value
          : this.failureReason,
      startedAtMicros: data.startedAtMicros.present
          ? data.startedAtMicros.value
          : this.startedAtMicros,
      completedAtMicros: data.completedAtMicros.present
          ? data.completedAtMicros.value
          : this.completedAtMicros,
      activeMilliseconds: data.activeMilliseconds.present
          ? data.activeMilliseconds.value
          : this.activeMilliseconds,
      wrongMoveCount: data.wrongMoveCount.present
          ? data.wrongMoveCount.value
          : this.wrongMoveCount,
      hintCount: data.hintCount.present ? data.hintCount.value : this.hintCount,
      revealed: data.revealed.present ? data.revealed.value : this.revealed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PuzzleAttempt(')
          ..write('id: $id, ')
          ..write('blockId: $blockId, ')
          ..write('cycleId: $cycleId, ')
          ..write('sessionId: $sessionId, ')
          ..write('status: $status, ')
          ..write('outcome: $outcome, ')
          ..write('failureReason: $failureReason, ')
          ..write('startedAtMicros: $startedAtMicros, ')
          ..write('completedAtMicros: $completedAtMicros, ')
          ..write('activeMilliseconds: $activeMilliseconds, ')
          ..write('wrongMoveCount: $wrongMoveCount, ')
          ..write('hintCount: $hintCount, ')
          ..write('revealed: $revealed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    blockId,
    cycleId,
    sessionId,
    status,
    outcome,
    failureReason,
    startedAtMicros,
    completedAtMicros,
    activeMilliseconds,
    wrongMoveCount,
    hintCount,
    revealed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PuzzleAttempt &&
          other.id == this.id &&
          other.blockId == this.blockId &&
          other.cycleId == this.cycleId &&
          other.sessionId == this.sessionId &&
          other.status == this.status &&
          other.outcome == this.outcome &&
          other.failureReason == this.failureReason &&
          other.startedAtMicros == this.startedAtMicros &&
          other.completedAtMicros == this.completedAtMicros &&
          other.activeMilliseconds == this.activeMilliseconds &&
          other.wrongMoveCount == this.wrongMoveCount &&
          other.hintCount == this.hintCount &&
          other.revealed == this.revealed);
}

class PuzzleAttemptsCompanion extends UpdateCompanion<PuzzleAttempt> {
  final Value<String> id;
  final Value<String> blockId;
  final Value<String> cycleId;
  final Value<String> sessionId;
  final Value<String> status;
  final Value<String?> outcome;
  final Value<String?> failureReason;
  final Value<int> startedAtMicros;
  final Value<int?> completedAtMicros;
  final Value<int> activeMilliseconds;
  final Value<int> wrongMoveCount;
  final Value<int> hintCount;
  final Value<bool> revealed;
  final Value<int> rowid;
  const PuzzleAttemptsCompanion({
    this.id = const Value.absent(),
    this.blockId = const Value.absent(),
    this.cycleId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.status = const Value.absent(),
    this.outcome = const Value.absent(),
    this.failureReason = const Value.absent(),
    this.startedAtMicros = const Value.absent(),
    this.completedAtMicros = const Value.absent(),
    this.activeMilliseconds = const Value.absent(),
    this.wrongMoveCount = const Value.absent(),
    this.hintCount = const Value.absent(),
    this.revealed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PuzzleAttemptsCompanion.insert({
    required String id,
    required String blockId,
    required String cycleId,
    required String sessionId,
    required String status,
    this.outcome = const Value.absent(),
    this.failureReason = const Value.absent(),
    required int startedAtMicros,
    this.completedAtMicros = const Value.absent(),
    this.activeMilliseconds = const Value.absent(),
    this.wrongMoveCount = const Value.absent(),
    this.hintCount = const Value.absent(),
    this.revealed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       blockId = Value(blockId),
       cycleId = Value(cycleId),
       sessionId = Value(sessionId),
       status = Value(status),
       startedAtMicros = Value(startedAtMicros);
  static Insertable<PuzzleAttempt> custom({
    Expression<String>? id,
    Expression<String>? blockId,
    Expression<String>? cycleId,
    Expression<String>? sessionId,
    Expression<String>? status,
    Expression<String>? outcome,
    Expression<String>? failureReason,
    Expression<int>? startedAtMicros,
    Expression<int>? completedAtMicros,
    Expression<int>? activeMilliseconds,
    Expression<int>? wrongMoveCount,
    Expression<int>? hintCount,
    Expression<bool>? revealed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (blockId != null) 'block_id': blockId,
      if (cycleId != null) 'cycle_id': cycleId,
      if (sessionId != null) 'session_id': sessionId,
      if (status != null) 'status': status,
      if (outcome != null) 'outcome': outcome,
      if (failureReason != null) 'failure_reason': failureReason,
      if (startedAtMicros != null) 'started_at_micros': startedAtMicros,
      if (completedAtMicros != null) 'completed_at_micros': completedAtMicros,
      if (activeMilliseconds != null) 'active_milliseconds': activeMilliseconds,
      if (wrongMoveCount != null) 'wrong_move_count': wrongMoveCount,
      if (hintCount != null) 'hint_count': hintCount,
      if (revealed != null) 'revealed': revealed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PuzzleAttemptsCompanion copyWith({
    Value<String>? id,
    Value<String>? blockId,
    Value<String>? cycleId,
    Value<String>? sessionId,
    Value<String>? status,
    Value<String?>? outcome,
    Value<String?>? failureReason,
    Value<int>? startedAtMicros,
    Value<int?>? completedAtMicros,
    Value<int>? activeMilliseconds,
    Value<int>? wrongMoveCount,
    Value<int>? hintCount,
    Value<bool>? revealed,
    Value<int>? rowid,
  }) {
    return PuzzleAttemptsCompanion(
      id: id ?? this.id,
      blockId: blockId ?? this.blockId,
      cycleId: cycleId ?? this.cycleId,
      sessionId: sessionId ?? this.sessionId,
      status: status ?? this.status,
      outcome: outcome ?? this.outcome,
      failureReason: failureReason ?? this.failureReason,
      startedAtMicros: startedAtMicros ?? this.startedAtMicros,
      completedAtMicros: completedAtMicros ?? this.completedAtMicros,
      activeMilliseconds: activeMilliseconds ?? this.activeMilliseconds,
      wrongMoveCount: wrongMoveCount ?? this.wrongMoveCount,
      hintCount: hintCount ?? this.hintCount,
      revealed: revealed ?? this.revealed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (cycleId.present) {
      map['cycle_id'] = Variable<String>(cycleId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (failureReason.present) {
      map['failure_reason'] = Variable<String>(failureReason.value);
    }
    if (startedAtMicros.present) {
      map['started_at_micros'] = Variable<int>(startedAtMicros.value);
    }
    if (completedAtMicros.present) {
      map['completed_at_micros'] = Variable<int>(completedAtMicros.value);
    }
    if (activeMilliseconds.present) {
      map['active_milliseconds'] = Variable<int>(activeMilliseconds.value);
    }
    if (wrongMoveCount.present) {
      map['wrong_move_count'] = Variable<int>(wrongMoveCount.value);
    }
    if (hintCount.present) {
      map['hint_count'] = Variable<int>(hintCount.value);
    }
    if (revealed.present) {
      map['revealed'] = Variable<bool>(revealed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PuzzleAttemptsCompanion(')
          ..write('id: $id, ')
          ..write('blockId: $blockId, ')
          ..write('cycleId: $cycleId, ')
          ..write('sessionId: $sessionId, ')
          ..write('status: $status, ')
          ..write('outcome: $outcome, ')
          ..write('failureReason: $failureReason, ')
          ..write('startedAtMicros: $startedAtMicros, ')
          ..write('completedAtMicros: $completedAtMicros, ')
          ..write('activeMilliseconds: $activeMilliseconds, ')
          ..write('wrongMoveCount: $wrongMoveCount, ')
          ..write('hintCount: $hintCount, ')
          ..write('revealed: $revealed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttemptMovesTable extends AttemptMoves
    with TableInfo<$AttemptMovesTable, AttemptMove> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttemptMovesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptIdMeta = const VerificationMeta(
    'attemptId',
  );
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES puzzle_attempts (id)',
    ),
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moveMeta = const VerificationMeta('move');
  @override
  late final GeneratedColumn<String> move = GeneratedColumn<String>(
    'move',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legalMeta = const VerificationMeta('legal');
  @override
  late final GeneratedColumn<bool> legal = GeneratedColumn<bool>(
    'legal',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("legal" IN (0, 1))',
    ),
  );
  static const VerificationMeta _acceptedMeta = const VerificationMeta(
    'accepted',
  );
  @override
  late final GeneratedColumn<bool> accepted = GeneratedColumn<bool>(
    'accepted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("accepted" IN (0, 1))',
    ),
  );
  static const VerificationMeta _submittedAtMicrosMeta = const VerificationMeta(
    'submittedAtMicros',
  );
  @override
  late final GeneratedColumn<int> submittedAtMicros = GeneratedColumn<int>(
    'submitted_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    attemptId,
    ordinal,
    move,
    legal,
    accepted,
    submittedAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attempt_moves';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttemptMove> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('attempt_id')) {
      context.handle(
        _attemptIdMeta,
        attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_attemptIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('move')) {
      context.handle(
        _moveMeta,
        move.isAcceptableOrUnknown(data['move']!, _moveMeta),
      );
    } else if (isInserting) {
      context.missing(_moveMeta);
    }
    if (data.containsKey('legal')) {
      context.handle(
        _legalMeta,
        legal.isAcceptableOrUnknown(data['legal']!, _legalMeta),
      );
    } else if (isInserting) {
      context.missing(_legalMeta);
    }
    if (data.containsKey('accepted')) {
      context.handle(
        _acceptedMeta,
        accepted.isAcceptableOrUnknown(data['accepted']!, _acceptedMeta),
      );
    } else if (isInserting) {
      context.missing(_acceptedMeta);
    }
    if (data.containsKey('submitted_at_micros')) {
      context.handle(
        _submittedAtMicrosMeta,
        submittedAtMicros.isAcceptableOrUnknown(
          data['submitted_at_micros']!,
          _submittedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_submittedAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {attemptId, ordinal},
  ];
  @override
  AttemptMove map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttemptMove(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      attemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attempt_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      move: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}move'],
      )!,
      legal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}legal'],
      )!,
      accepted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}accepted'],
      )!,
      submittedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}submitted_at_micros'],
      )!,
    );
  }

  @override
  $AttemptMovesTable createAlias(String alias) {
    return $AttemptMovesTable(attachedDatabase, alias);
  }
}

class AttemptMove extends DataClass implements Insertable<AttemptMove> {
  final String id;
  final String attemptId;
  final int ordinal;
  final String move;
  final bool legal;
  final bool accepted;
  final int submittedAtMicros;
  const AttemptMove({
    required this.id,
    required this.attemptId,
    required this.ordinal,
    required this.move,
    required this.legal,
    required this.accepted,
    required this.submittedAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['attempt_id'] = Variable<String>(attemptId);
    map['ordinal'] = Variable<int>(ordinal);
    map['move'] = Variable<String>(move);
    map['legal'] = Variable<bool>(legal);
    map['accepted'] = Variable<bool>(accepted);
    map['submitted_at_micros'] = Variable<int>(submittedAtMicros);
    return map;
  }

  AttemptMovesCompanion toCompanion(bool nullToAbsent) {
    return AttemptMovesCompanion(
      id: Value(id),
      attemptId: Value(attemptId),
      ordinal: Value(ordinal),
      move: Value(move),
      legal: Value(legal),
      accepted: Value(accepted),
      submittedAtMicros: Value(submittedAtMicros),
    );
  }

  factory AttemptMove.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttemptMove(
      id: serializer.fromJson<String>(json['id']),
      attemptId: serializer.fromJson<String>(json['attemptId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      move: serializer.fromJson<String>(json['move']),
      legal: serializer.fromJson<bool>(json['legal']),
      accepted: serializer.fromJson<bool>(json['accepted']),
      submittedAtMicros: serializer.fromJson<int>(json['submittedAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'attemptId': serializer.toJson<String>(attemptId),
      'ordinal': serializer.toJson<int>(ordinal),
      'move': serializer.toJson<String>(move),
      'legal': serializer.toJson<bool>(legal),
      'accepted': serializer.toJson<bool>(accepted),
      'submittedAtMicros': serializer.toJson<int>(submittedAtMicros),
    };
  }

  AttemptMove copyWith({
    String? id,
    String? attemptId,
    int? ordinal,
    String? move,
    bool? legal,
    bool? accepted,
    int? submittedAtMicros,
  }) => AttemptMove(
    id: id ?? this.id,
    attemptId: attemptId ?? this.attemptId,
    ordinal: ordinal ?? this.ordinal,
    move: move ?? this.move,
    legal: legal ?? this.legal,
    accepted: accepted ?? this.accepted,
    submittedAtMicros: submittedAtMicros ?? this.submittedAtMicros,
  );
  AttemptMove copyWithCompanion(AttemptMovesCompanion data) {
    return AttemptMove(
      id: data.id.present ? data.id.value : this.id,
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      move: data.move.present ? data.move.value : this.move,
      legal: data.legal.present ? data.legal.value : this.legal,
      accepted: data.accepted.present ? data.accepted.value : this.accepted,
      submittedAtMicros: data.submittedAtMicros.present
          ? data.submittedAtMicros.value
          : this.submittedAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttemptMove(')
          ..write('id: $id, ')
          ..write('attemptId: $attemptId, ')
          ..write('ordinal: $ordinal, ')
          ..write('move: $move, ')
          ..write('legal: $legal, ')
          ..write('accepted: $accepted, ')
          ..write('submittedAtMicros: $submittedAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    attemptId,
    ordinal,
    move,
    legal,
    accepted,
    submittedAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttemptMove &&
          other.id == this.id &&
          other.attemptId == this.attemptId &&
          other.ordinal == this.ordinal &&
          other.move == this.move &&
          other.legal == this.legal &&
          other.accepted == this.accepted &&
          other.submittedAtMicros == this.submittedAtMicros);
}

class AttemptMovesCompanion extends UpdateCompanion<AttemptMove> {
  final Value<String> id;
  final Value<String> attemptId;
  final Value<int> ordinal;
  final Value<String> move;
  final Value<bool> legal;
  final Value<bool> accepted;
  final Value<int> submittedAtMicros;
  final Value<int> rowid;
  const AttemptMovesCompanion({
    this.id = const Value.absent(),
    this.attemptId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.move = const Value.absent(),
    this.legal = const Value.absent(),
    this.accepted = const Value.absent(),
    this.submittedAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttemptMovesCompanion.insert({
    required String id,
    required String attemptId,
    required int ordinal,
    required String move,
    required bool legal,
    required bool accepted,
    required int submittedAtMicros,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       attemptId = Value(attemptId),
       ordinal = Value(ordinal),
       move = Value(move),
       legal = Value(legal),
       accepted = Value(accepted),
       submittedAtMicros = Value(submittedAtMicros);
  static Insertable<AttemptMove> custom({
    Expression<String>? id,
    Expression<String>? attemptId,
    Expression<int>? ordinal,
    Expression<String>? move,
    Expression<bool>? legal,
    Expression<bool>? accepted,
    Expression<int>? submittedAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (attemptId != null) 'attempt_id': attemptId,
      if (ordinal != null) 'ordinal': ordinal,
      if (move != null) 'move': move,
      if (legal != null) 'legal': legal,
      if (accepted != null) 'accepted': accepted,
      if (submittedAtMicros != null) 'submitted_at_micros': submittedAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttemptMovesCompanion copyWith({
    Value<String>? id,
    Value<String>? attemptId,
    Value<int>? ordinal,
    Value<String>? move,
    Value<bool>? legal,
    Value<bool>? accepted,
    Value<int>? submittedAtMicros,
    Value<int>? rowid,
  }) {
    return AttemptMovesCompanion(
      id: id ?? this.id,
      attemptId: attemptId ?? this.attemptId,
      ordinal: ordinal ?? this.ordinal,
      move: move ?? this.move,
      legal: legal ?? this.legal,
      accepted: accepted ?? this.accepted,
      submittedAtMicros: submittedAtMicros ?? this.submittedAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (move.present) {
      map['move'] = Variable<String>(move.value);
    }
    if (legal.present) {
      map['legal'] = Variable<bool>(legal.value);
    }
    if (accepted.present) {
      map['accepted'] = Variable<bool>(accepted.value);
    }
    if (submittedAtMicros.present) {
      map['submitted_at_micros'] = Variable<int>(submittedAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttemptMovesCompanion(')
          ..write('id: $id, ')
          ..write('attemptId: $attemptId, ')
          ..write('ordinal: $ordinal, ')
          ..write('move: $move, ')
          ..write('legal: $legal, ')
          ..write('accepted: $accepted, ')
          ..write('submittedAtMicros: $submittedAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimingSegmentsTable extends TimingSegments
    with TableInfo<$TimingSegmentsTable, TimingSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimingSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptIdMeta = const VerificationMeta(
    'attemptId',
  );
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES puzzle_attempts (id)',
    ),
  );
  static const VerificationMeta _startedAtMicrosMeta = const VerificationMeta(
    'startedAtMicros',
  );
  @override
  late final GeneratedColumn<int> startedAtMicros = GeneratedColumn<int>(
    'started_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMicrosMeta = const VerificationMeta(
    'endedAtMicros',
  );
  @override
  late final GeneratedColumn<int> endedAtMicros = GeneratedColumn<int>(
    'ended_at_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeMillisecondsMeta =
      const VerificationMeta('activeMilliseconds');
  @override
  late final GeneratedColumn<int> activeMilliseconds = GeneratedColumn<int>(
    'active_milliseconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    attemptId,
    startedAtMicros,
    endedAtMicros,
    activeMilliseconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'timing_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimingSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('attempt_id')) {
      context.handle(
        _attemptIdMeta,
        attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_attemptIdMeta);
    }
    if (data.containsKey('started_at_micros')) {
      context.handle(
        _startedAtMicrosMeta,
        startedAtMicros.isAcceptableOrUnknown(
          data['started_at_micros']!,
          _startedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtMicrosMeta);
    }
    if (data.containsKey('ended_at_micros')) {
      context.handle(
        _endedAtMicrosMeta,
        endedAtMicros.isAcceptableOrUnknown(
          data['ended_at_micros']!,
          _endedAtMicrosMeta,
        ),
      );
    }
    if (data.containsKey('active_milliseconds')) {
      context.handle(
        _activeMillisecondsMeta,
        activeMilliseconds.isAcceptableOrUnknown(
          data['active_milliseconds']!,
          _activeMillisecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimingSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimingSegment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      attemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attempt_id'],
      )!,
      startedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_micros'],
      )!,
      endedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at_micros'],
      ),
      activeMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active_milliseconds'],
      ),
    );
  }

  @override
  $TimingSegmentsTable createAlias(String alias) {
    return $TimingSegmentsTable(attachedDatabase, alias);
  }
}

class TimingSegment extends DataClass implements Insertable<TimingSegment> {
  final String id;
  final String attemptId;
  final int startedAtMicros;
  final int? endedAtMicros;
  final int? activeMilliseconds;
  const TimingSegment({
    required this.id,
    required this.attemptId,
    required this.startedAtMicros,
    this.endedAtMicros,
    this.activeMilliseconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['attempt_id'] = Variable<String>(attemptId);
    map['started_at_micros'] = Variable<int>(startedAtMicros);
    if (!nullToAbsent || endedAtMicros != null) {
      map['ended_at_micros'] = Variable<int>(endedAtMicros);
    }
    if (!nullToAbsent || activeMilliseconds != null) {
      map['active_milliseconds'] = Variable<int>(activeMilliseconds);
    }
    return map;
  }

  TimingSegmentsCompanion toCompanion(bool nullToAbsent) {
    return TimingSegmentsCompanion(
      id: Value(id),
      attemptId: Value(attemptId),
      startedAtMicros: Value(startedAtMicros),
      endedAtMicros: endedAtMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtMicros),
      activeMilliseconds: activeMilliseconds == null && nullToAbsent
          ? const Value.absent()
          : Value(activeMilliseconds),
    );
  }

  factory TimingSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimingSegment(
      id: serializer.fromJson<String>(json['id']),
      attemptId: serializer.fromJson<String>(json['attemptId']),
      startedAtMicros: serializer.fromJson<int>(json['startedAtMicros']),
      endedAtMicros: serializer.fromJson<int?>(json['endedAtMicros']),
      activeMilliseconds: serializer.fromJson<int?>(json['activeMilliseconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'attemptId': serializer.toJson<String>(attemptId),
      'startedAtMicros': serializer.toJson<int>(startedAtMicros),
      'endedAtMicros': serializer.toJson<int?>(endedAtMicros),
      'activeMilliseconds': serializer.toJson<int?>(activeMilliseconds),
    };
  }

  TimingSegment copyWith({
    String? id,
    String? attemptId,
    int? startedAtMicros,
    Value<int?> endedAtMicros = const Value.absent(),
    Value<int?> activeMilliseconds = const Value.absent(),
  }) => TimingSegment(
    id: id ?? this.id,
    attemptId: attemptId ?? this.attemptId,
    startedAtMicros: startedAtMicros ?? this.startedAtMicros,
    endedAtMicros: endedAtMicros.present
        ? endedAtMicros.value
        : this.endedAtMicros,
    activeMilliseconds: activeMilliseconds.present
        ? activeMilliseconds.value
        : this.activeMilliseconds,
  );
  TimingSegment copyWithCompanion(TimingSegmentsCompanion data) {
    return TimingSegment(
      id: data.id.present ? data.id.value : this.id,
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      startedAtMicros: data.startedAtMicros.present
          ? data.startedAtMicros.value
          : this.startedAtMicros,
      endedAtMicros: data.endedAtMicros.present
          ? data.endedAtMicros.value
          : this.endedAtMicros,
      activeMilliseconds: data.activeMilliseconds.present
          ? data.activeMilliseconds.value
          : this.activeMilliseconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimingSegment(')
          ..write('id: $id, ')
          ..write('attemptId: $attemptId, ')
          ..write('startedAtMicros: $startedAtMicros, ')
          ..write('endedAtMicros: $endedAtMicros, ')
          ..write('activeMilliseconds: $activeMilliseconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    attemptId,
    startedAtMicros,
    endedAtMicros,
    activeMilliseconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimingSegment &&
          other.id == this.id &&
          other.attemptId == this.attemptId &&
          other.startedAtMicros == this.startedAtMicros &&
          other.endedAtMicros == this.endedAtMicros &&
          other.activeMilliseconds == this.activeMilliseconds);
}

class TimingSegmentsCompanion extends UpdateCompanion<TimingSegment> {
  final Value<String> id;
  final Value<String> attemptId;
  final Value<int> startedAtMicros;
  final Value<int?> endedAtMicros;
  final Value<int?> activeMilliseconds;
  final Value<int> rowid;
  const TimingSegmentsCompanion({
    this.id = const Value.absent(),
    this.attemptId = const Value.absent(),
    this.startedAtMicros = const Value.absent(),
    this.endedAtMicros = const Value.absent(),
    this.activeMilliseconds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimingSegmentsCompanion.insert({
    required String id,
    required String attemptId,
    required int startedAtMicros,
    this.endedAtMicros = const Value.absent(),
    this.activeMilliseconds = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       attemptId = Value(attemptId),
       startedAtMicros = Value(startedAtMicros);
  static Insertable<TimingSegment> custom({
    Expression<String>? id,
    Expression<String>? attemptId,
    Expression<int>? startedAtMicros,
    Expression<int>? endedAtMicros,
    Expression<int>? activeMilliseconds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (attemptId != null) 'attempt_id': attemptId,
      if (startedAtMicros != null) 'started_at_micros': startedAtMicros,
      if (endedAtMicros != null) 'ended_at_micros': endedAtMicros,
      if (activeMilliseconds != null) 'active_milliseconds': activeMilliseconds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimingSegmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? attemptId,
    Value<int>? startedAtMicros,
    Value<int?>? endedAtMicros,
    Value<int?>? activeMilliseconds,
    Value<int>? rowid,
  }) {
    return TimingSegmentsCompanion(
      id: id ?? this.id,
      attemptId: attemptId ?? this.attemptId,
      startedAtMicros: startedAtMicros ?? this.startedAtMicros,
      endedAtMicros: endedAtMicros ?? this.endedAtMicros,
      activeMilliseconds: activeMilliseconds ?? this.activeMilliseconds,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (startedAtMicros.present) {
      map['started_at_micros'] = Variable<int>(startedAtMicros.value);
    }
    if (endedAtMicros.present) {
      map['ended_at_micros'] = Variable<int>(endedAtMicros.value);
    }
    if (activeMilliseconds.present) {
      map['active_milliseconds'] = Variable<int>(activeMilliseconds.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimingSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('attemptId: $attemptId, ')
          ..write('startedAtMicros: $startedAtMicros, ')
          ..write('endedAtMicros: $endedAtMicros, ')
          ..write('activeMilliseconds: $activeMilliseconds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PgnSourcesTable pgnSources = $PgnSourcesTable(this);
  late final $PgnBlocksTable pgnBlocks = $PgnBlocksTable(this);
  late final $ImportJobsTable importJobs = $ImportJobsTable(this);
  late final $ImportDiagnosticsTable importDiagnostics =
      $ImportDiagnosticsTable(this);
  late final $TrainingSetsTable trainingSets = $TrainingSetsTable(this);
  late final $TrainingSetItemsTable trainingSetItems = $TrainingSetItemsTable(
    this,
  );
  late final $CyclesTable cycles = $CyclesTable(this);
  late final $TrainingSessionsTable trainingSessions = $TrainingSessionsTable(
    this,
  );
  late final $PuzzleAttemptsTable puzzleAttempts = $PuzzleAttemptsTable(this);
  late final $AttemptMovesTable attemptMoves = $AttemptMovesTable(this);
  late final $TimingSegmentsTable timingSegments = $TimingSegmentsTable(this);
  late final Index pgnBlocksSourceOrder = Index(
    'pgn_blocks_source_order',
    'CREATE INDEX pgn_blocks_source_order ON pgn_blocks (source_id, ordinal)',
  );
  late final Index pgnBlocksExerciseId = Index(
    'pgn_blocks_exercise_id',
    'CREATE INDEX pgn_blocks_exercise_id ON pgn_blocks (source_id, exercise_id)',
  );
  late final Index pgnBlocksContentType = Index(
    'pgn_blocks_content_type',
    'CREATE INDEX pgn_blocks_content_type ON pgn_blocks (content_type)',
  );
  late final Index pgnBlocksWhite = Index(
    'pgn_blocks_white',
    'CREATE INDEX pgn_blocks_white ON pgn_blocks (white)',
  );
  late final Index pgnBlocksBlack = Index(
    'pgn_blocks_black',
    'CREATE INDEX pgn_blocks_black ON pgn_blocks (black)',
  );
  late final Index pgnBlocksEvent = Index(
    'pgn_blocks_event',
    'CREATE INDEX pgn_blocks_event ON pgn_blocks (event)',
  );
  late final Index pgnBlocksResult = Index(
    'pgn_blocks_result',
    'CREATE INDEX pgn_blocks_result ON pgn_blocks (result)',
  );
  late final Index pgnBlocksSection = Index(
    'pgn_blocks_section',
    'CREATE INDEX pgn_blocks_section ON pgn_blocks (section)',
  );
  late final Index pgnBlocksTheme = Index(
    'pgn_blocks_theme',
    'CREATE INDEX pgn_blocks_theme ON pgn_blocks (theme)',
  );
  late final Index pgnBlocksDifficulty = Index(
    'pgn_blocks_difficulty',
    'CREATE INDEX pgn_blocks_difficulty ON pgn_blocks (difficulty)',
  );
  late final Index importJobsSource = Index(
    'import_jobs_source',
    'CREATE INDEX import_jobs_source ON import_jobs (source_id)',
  );
  late final Index importJobsStatus = Index(
    'import_jobs_status',
    'CREATE INDEX import_jobs_status ON import_jobs (status)',
  );
  late final Index importDiagnosticsJob = Index(
    'import_diagnostics_job',
    'CREATE INDEX import_diagnostics_job ON import_diagnostics (import_job_id)',
  );
  late final Index trainingSetsStatus = Index(
    'training_sets_status',
    'CREATE INDEX training_sets_status ON training_sets (status)',
  );
  late final Index trainingSetItemsBlock = Index(
    'training_set_items_block',
    'CREATE INDEX training_set_items_block ON training_set_items (block_id)',
  );
  late final Index trainingSetItemsOrder = Index(
    'training_set_items_order',
    'CREATE INDEX training_set_items_order ON training_set_items (training_set_id, position)',
  );
  late final Index cyclesOneActivePerSet = Index(
    'cycles_one_active_per_set',
    'CREATE UNIQUE INDEX cycles_one_active_per_set ON cycles (training_set_id) WHERE status = \'active\'',
  );
  late final Index cyclesSetStatus = Index(
    'cycles_set_status',
    'CREATE INDEX cycles_set_status ON cycles (training_set_id, status)',
  );
  late final Index trainingSessionsCycle = Index(
    'training_sessions_cycle',
    'CREATE INDEX training_sessions_cycle ON training_sessions (cycle_id, started_at_micros)',
  );
  late final Index puzzleAttemptsCycle = Index(
    'puzzle_attempts_cycle',
    'CREATE INDEX puzzle_attempts_cycle ON puzzle_attempts (cycle_id, started_at_micros)',
  );
  late final Index puzzleAttemptsBlock = Index(
    'puzzle_attempts_block',
    'CREATE INDEX puzzle_attempts_block ON puzzle_attempts (block_id, started_at_micros)',
  );
  late final Index puzzleAttemptsSession = Index(
    'puzzle_attempts_session',
    'CREATE INDEX puzzle_attempts_session ON puzzle_attempts (session_id)',
  );
  late final Index puzzleAttemptsOutcome = Index(
    'puzzle_attempts_outcome',
    'CREATE INDEX puzzle_attempts_outcome ON puzzle_attempts (outcome)',
  );
  late final Index attemptMovesAttemptOrder = Index(
    'attempt_moves_attempt_order',
    'CREATE INDEX attempt_moves_attempt_order ON attempt_moves (attempt_id, ordinal)',
  );
  late final Index timingSegmentsAttempt = Index(
    'timing_segments_attempt',
    'CREATE INDEX timing_segments_attempt ON timing_segments (attempt_id, started_at_micros)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    pgnSources,
    pgnBlocks,
    importJobs,
    importDiagnostics,
    trainingSets,
    trainingSetItems,
    cycles,
    trainingSessions,
    puzzleAttempts,
    attemptMoves,
    timingSegments,
    pgnBlocksSourceOrder,
    pgnBlocksExerciseId,
    pgnBlocksContentType,
    pgnBlocksWhite,
    pgnBlocksBlack,
    pgnBlocksEvent,
    pgnBlocksResult,
    pgnBlocksSection,
    pgnBlocksTheme,
    pgnBlocksDifficulty,
    importJobsSource,
    importJobsStatus,
    importDiagnosticsJob,
    trainingSetsStatus,
    trainingSetItemsBlock,
    trainingSetItemsOrder,
    cyclesOneActivePerSet,
    cyclesSetStatus,
    trainingSessionsCycle,
    puzzleAttemptsCycle,
    puzzleAttemptsBlock,
    puzzleAttemptsSession,
    puzzleAttemptsOutcome,
    attemptMovesAttemptOrder,
    timingSegmentsAttempt,
  ];
}

typedef $$PgnSourcesTableCreateCompanionBuilder = PgnSourcesCompanion Function({
  required String id,
  required String displayName,
  required String accessMode,
  Value<String?> managedPath,
  Value<String?> externalReference,
  Value<int?> sizeBytes,
  Value<int?> modifiedAtMicros,
  Value<String?> fingerprint,
  required int scannerVersion,
  required String importState,
  Value<int> safeCheckpoint,
  required int createdAtMicros,
  required int updatedAtMicros,
  Value<int> rowid,
});
typedef $$PgnSourcesTableUpdateCompanionBuilder = PgnSourcesCompanion Function({
  Value<String> id,
  Value<String> displayName,
  Value<String> accessMode,
  Value<String?> managedPath,
  Value<String?> externalReference,
  Value<int?> sizeBytes,
  Value<int?> modifiedAtMicros,
  Value<String?> fingerprint,
  Value<int> scannerVersion,
  Value<String> importState,
  Value<int> safeCheckpoint,
  Value<int> createdAtMicros,
  Value<int> updatedAtMicros,
  Value<int> rowid,
});

final class $$PgnSourcesTableReferences
    extends BaseReferences<_$AppDatabase, $PgnSourcesTable, PgnSource> {
  $$PgnSourcesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PgnBlocksTable, List<PgnBlock>>
  _pgnBlocksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.pgnBlocks,
    aliasName: 'pgn_sources__id__pgn_blocks__source_id',
  );

  $$PgnBlocksTableProcessedTableManager get pgnBlocksRefs {
    final manager = $$PgnBlocksTableTableManager(
      $_db,
      $_db.pgnBlocks,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_pgnBlocksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ImportJobsTable, List<ImportJob>>
  _importJobsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.importJobs,
    aliasName: 'pgn_sources__id__import_jobs__source_id',
  );

  $$ImportJobsTableProcessedTableManager get importJobsRefs {
    final manager = $$ImportJobsTableTableManager(
      $_db,
      $_db.importJobs,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_importJobsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PgnSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $PgnSourcesTable> {
  $$PgnSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accessMode => $composableBuilder(
    column: $table.accessMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get managedPath => $composableBuilder(
    column: $table.managedPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalReference => $composableBuilder(
    column: $table.externalReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modifiedAtMicros => $composableBuilder(
    column: $table.modifiedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scannerVersion => $composableBuilder(
    column: $table.scannerVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importState => $composableBuilder(
    column: $table.importState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get safeCheckpoint => $composableBuilder(
    column: $table.safeCheckpoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> pgnBlocksRefs(
    Expression<bool> Function($$PgnBlocksTableFilterComposer f) f,
  ) {
    final $$PgnBlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pgnBlocks,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PgnBlocksTableFilterComposer(
            $db: $db,
            $table: $db.pgnBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> importJobsRefs(
    Expression<bool> Function($$ImportJobsTableFilterComposer f) f,
  ) {
    final $$ImportJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.importJobs,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportJobsTableFilterComposer(
            $db: $db,
            $table: $db.importJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PgnSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $PgnSourcesTable> {
  $$PgnSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accessMode => $composableBuilder(
    column: $table.accessMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get managedPath => $composableBuilder(
    column: $table.managedPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalReference => $composableBuilder(
    column: $table.externalReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modifiedAtMicros => $composableBuilder(
    column: $table.modifiedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scannerVersion => $composableBuilder(
    column: $table.scannerVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importState => $composableBuilder(
    column: $table.importState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get safeCheckpoint => $composableBuilder(
    column: $table.safeCheckpoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PgnSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PgnSourcesTable> {
  $$PgnSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accessMode => $composableBuilder(
    column: $table.accessMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get managedPath => $composableBuilder(
    column: $table.managedPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get externalReference => $composableBuilder(
    column: $table.externalReference,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get modifiedAtMicros => $composableBuilder(
    column: $table.modifiedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scannerVersion => $composableBuilder(
    column: $table.scannerVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importState => $composableBuilder(
    column: $table.importState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get safeCheckpoint => $composableBuilder(
    column: $table.safeCheckpoint,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => column,
  );

  Expression<T> pgnBlocksRefs<T extends Object>(
    Expression<T> Function($$PgnBlocksTableAnnotationComposer a) f,
  ) {
    final $$PgnBlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pgnBlocks,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PgnBlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.pgnBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> importJobsRefs<T extends Object>(
    Expression<T> Function($$ImportJobsTableAnnotationComposer a) f,
  ) {
    final $$ImportJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.importJobs,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.importJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PgnSourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PgnSourcesTable,
          PgnSource,
          $$PgnSourcesTableFilterComposer,
          $$PgnSourcesTableOrderingComposer,
          $$PgnSourcesTableAnnotationComposer,
          $$PgnSourcesTableCreateCompanionBuilder,
          $$PgnSourcesTableUpdateCompanionBuilder,
          (PgnSource, $$PgnSourcesTableReferences),
          PgnSource,
          PrefetchHooks Function({bool pgnBlocksRefs, bool importJobsRefs})
        > {
  $$PgnSourcesTableTableManager(_$AppDatabase db, $PgnSourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PgnSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PgnSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PgnSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> accessMode = const Value.absent(),
                Value<String?> managedPath = const Value.absent(),
                Value<String?> externalReference = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<int?> modifiedAtMicros = const Value.absent(),
                Value<String?> fingerprint = const Value.absent(),
                Value<int> scannerVersion = const Value.absent(),
                Value<String> importState = const Value.absent(),
                Value<int> safeCheckpoint = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<int> updatedAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PgnSourcesCompanion(
                id: id,
                displayName: displayName,
                accessMode: accessMode,
                managedPath: managedPath,
                externalReference: externalReference,
                sizeBytes: sizeBytes,
                modifiedAtMicros: modifiedAtMicros,
                fingerprint: fingerprint,
                scannerVersion: scannerVersion,
                importState: importState,
                safeCheckpoint: safeCheckpoint,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                required String accessMode,
                Value<String?> managedPath = const Value.absent(),
                Value<String?> externalReference = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<int?> modifiedAtMicros = const Value.absent(),
                Value<String?> fingerprint = const Value.absent(),
                required int scannerVersion,
                required String importState,
                Value<int> safeCheckpoint = const Value.absent(),
                required int createdAtMicros,
                required int updatedAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => PgnSourcesCompanion.insert(
                id: id,
                displayName: displayName,
                accessMode: accessMode,
                managedPath: managedPath,
                externalReference: externalReference,
                sizeBytes: sizeBytes,
                modifiedAtMicros: modifiedAtMicros,
                fingerprint: fingerprint,
                scannerVersion: scannerVersion,
                importState: importState,
                safeCheckpoint: safeCheckpoint,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PgnSourcesTable, PgnSource>(table),
                  $$PgnSourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({pgnBlocksRefs = false, importJobsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (pgnBlocksRefs) db.pgnBlocks,
                    if (importJobsRefs) db.importJobs,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (pgnBlocksRefs)
                        await $_getPrefetchedData<
                          PgnSource,
                          $PgnSourcesTable,
                          PgnBlock
                        >(
                          currentTable: table,
                          referencedTable: $$PgnSourcesTableReferences
                              ._pgnBlocksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PgnSourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).pgnBlocksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (importJobsRefs)
                        await $_getPrefetchedData<
                          PgnSource,
                          $PgnSourcesTable,
                          ImportJob
                        >(
                          currentTable: table,
                          referencedTable: $$PgnSourcesTableReferences
                              ._importJobsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PgnSourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).importJobsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PgnSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PgnSourcesTable,
      PgnSource,
      $$PgnSourcesTableFilterComposer,
      $$PgnSourcesTableOrderingComposer,
      $$PgnSourcesTableAnnotationComposer,
      $$PgnSourcesTableCreateCompanionBuilder,
      $$PgnSourcesTableUpdateCompanionBuilder,
      (PgnSource, $$PgnSourcesTableReferences),
      PgnSource,
      PrefetchHooks Function({bool pgnBlocksRefs, bool importJobsRefs})
    >;
typedef $$PgnBlocksTableCreateCompanionBuilder = PgnBlocksCompanion Function({
  required String id,
  required String sourceId,
  required int startOffset,
  required int endOffset,
  required int ordinal,
  Value<String?> event,
  Value<String?> site,
  Value<String?> date,
  Value<String?> round,
  Value<String?> white,
  Value<String?> black,
  Value<String?> result,
  required String contentType,
  Value<String?> exerciseId,
  Value<String?> section,
  Value<int?> sequence,
  Value<String?> theme,
  Value<String?> difficulty,
  required String parseStatus,
  Value<String?> diagnosticSummary,
  Value<int> rowid,
});
typedef $$PgnBlocksTableUpdateCompanionBuilder = PgnBlocksCompanion Function({
  Value<String> id,
  Value<String> sourceId,
  Value<int> startOffset,
  Value<int> endOffset,
  Value<int> ordinal,
  Value<String?> event,
  Value<String?> site,
  Value<String?> date,
  Value<String?> round,
  Value<String?> white,
  Value<String?> black,
  Value<String?> result,
  Value<String> contentType,
  Value<String?> exerciseId,
  Value<String?> section,
  Value<int?> sequence,
  Value<String?> theme,
  Value<String?> difficulty,
  Value<String> parseStatus,
  Value<String?> diagnosticSummary,
  Value<int> rowid,
});

final class $$PgnBlocksTableReferences
    extends BaseReferences<_$AppDatabase, $PgnBlocksTable, PgnBlock> {
  $$PgnBlocksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PgnSourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.pgnSources.createAlias('pgn_blocks__source_id__pgn_sources__id');

  $$PgnSourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$PgnSourcesTableTableManager(
      $_db,
      $_db.pgnSources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TrainingSetItemsTable, List<TrainingSetItem>>
  _trainingSetItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.trainingSetItems,
    aliasName: 'pgn_blocks__id__training_set_items__block_id',
  );

  $$TrainingSetItemsTableProcessedTableManager get trainingSetItemsRefs {
    final manager = $$TrainingSetItemsTableTableManager(
      $_db,
      $_db.trainingSetItems,
    ).filter((f) => f.blockId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _trainingSetItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PuzzleAttemptsTable, List<PuzzleAttempt>>
  _puzzleAttemptsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.puzzleAttempts,
    aliasName: 'pgn_blocks__id__puzzle_attempts__block_id',
  );

  $$PuzzleAttemptsTableProcessedTableManager get puzzleAttemptsRefs {
    final manager = $$PuzzleAttemptsTableTableManager(
      $_db,
      $_db.puzzleAttempts,
    ).filter((f) => f.blockId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_puzzleAttemptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PgnBlocksTableFilterComposer
    extends Composer<_$AppDatabase, $PgnBlocksTable> {
  $$PgnBlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get event => $composableBuilder(
    column: $table.event,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get site => $composableBuilder(
    column: $table.site,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get round => $composableBuilder(
    column: $table.round,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get white => $composableBuilder(
    column: $table.white,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get black => $composableBuilder(
    column: $table.black,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parseStatus => $composableBuilder(
    column: $table.parseStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diagnosticSummary => $composableBuilder(
    column: $table.diagnosticSummary,
    builder: (column) => ColumnFilters(column),
  );

  $$PgnSourcesTableFilterComposer get sourceId {
    final $$PgnSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.pgnSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PgnSourcesTableFilterComposer(
            $db: $db,
            $table: $db.pgnSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> trainingSetItemsRefs(
    Expression<bool> Function($$TrainingSetItemsTableFilterComposer f) f,
  ) {
    final $$TrainingSetItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trainingSetItems,
      getReferencedColumn: (t) => t.blockId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingSetItemsTableFilterComposer(
            $db: $db,
            $table: $db.trainingSetItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> puzzleAttemptsRefs(
    Expression<bool> Function($$PuzzleAttemptsTableFilterComposer f) f,
  ) {
    final $$PuzzleAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.puzzleAttempts,
      getReferencedColumn: (t) => t.blockId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PuzzleAttemptsTableFilterComposer(
            $db: $db,
            $table: $db.puzzleAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PgnBlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $PgnBlocksTable> {
  $$PgnBlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get event => $composableBuilder(
    column: $table.event,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get site => $composableBuilder(
    column: $table.site,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get round => $composableBuilder(
    column: $table.round,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get white => $composableBuilder(
    column: $table.white,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get black => $composableBuilder(
    column: $table.black,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parseStatus => $composableBuilder(
    column: $table.parseStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diagnosticSummary => $composableBuilder(
    column: $table.diagnosticSummary,
    builder: (column) => ColumnOrderings(column),
  );

  $$PgnSourcesTableOrderingComposer get sourceId {
    final $$PgnSourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.pgnSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PgnSourcesTableOrderingComposer(
            $db: $db,
            $table: $db.pgnSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PgnBlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $PgnBlocksTable> {
  $$PgnBlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<String> get event =>
      $composableBuilder(column: $table.event, builder: (column) => column);

  GeneratedColumn<String> get site =>
      $composableBuilder(column: $table.site, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get round =>
      $composableBuilder(column: $table.round, builder: (column) => column);

  GeneratedColumn<String> get white =>
      $composableBuilder(column: $table.white, builder: (column) => column);

  GeneratedColumn<String> get black =>
      $composableBuilder(column: $table.black, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get section =>
      $composableBuilder(column: $table.section, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get theme =>
      $composableBuilder(column: $table.theme, builder: (column) => column);

  GeneratedColumn<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parseStatus => $composableBuilder(
    column: $table.parseStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get diagnosticSummary => $composableBuilder(
    column: $table.diagnosticSummary,
    builder: (column) => column,
  );

  $$PgnSourcesTableAnnotationComposer get sourceId {
    final $$PgnSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.pgnSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PgnSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.pgnSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> trainingSetItemsRefs<T extends Object>(
    Expression<T> Function($$TrainingSetItemsTableAnnotationComposer a) f,
  ) {
    final $$TrainingSetItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trainingSetItems,
      getReferencedColumn: (t) => t.blockId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingSetItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.trainingSetItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> puzzleAttemptsRefs<T extends Object>(
    Expression<T> Function($$PuzzleAttemptsTableAnnotationComposer a) f,
  ) {
    final $$PuzzleAttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.puzzleAttempts,
      getReferencedColumn: (t) => t.blockId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PuzzleAttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.puzzleAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PgnBlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PgnBlocksTable,
          PgnBlock,
          $$PgnBlocksTableFilterComposer,
          $$PgnBlocksTableOrderingComposer,
          $$PgnBlocksTableAnnotationComposer,
          $$PgnBlocksTableCreateCompanionBuilder,
          $$PgnBlocksTableUpdateCompanionBuilder,
          (PgnBlock, $$PgnBlocksTableReferences),
          PgnBlock,
          PrefetchHooks Function({
            bool sourceId,
            bool trainingSetItemsRefs,
            bool puzzleAttemptsRefs,
          })
        > {
  $$PgnBlocksTableTableManager(_$AppDatabase db, $PgnBlocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PgnBlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PgnBlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PgnBlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<int> startOffset = const Value.absent(),
                Value<int> endOffset = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<String?> event = const Value.absent(),
                Value<String?> site = const Value.absent(),
                Value<String?> date = const Value.absent(),
                Value<String?> round = const Value.absent(),
                Value<String?> white = const Value.absent(),
                Value<String?> black = const Value.absent(),
                Value<String?> result = const Value.absent(),
                Value<String> contentType = const Value.absent(),
                Value<String?> exerciseId = const Value.absent(),
                Value<String?> section = const Value.absent(),
                Value<int?> sequence = const Value.absent(),
                Value<String?> theme = const Value.absent(),
                Value<String?> difficulty = const Value.absent(),
                Value<String> parseStatus = const Value.absent(),
                Value<String?> diagnosticSummary = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PgnBlocksCompanion(
                id: id,
                sourceId: sourceId,
                startOffset: startOffset,
                endOffset: endOffset,
                ordinal: ordinal,
                event: event,
                site: site,
                date: date,
                round: round,
                white: white,
                black: black,
                result: result,
                contentType: contentType,
                exerciseId: exerciseId,
                section: section,
                sequence: sequence,
                theme: theme,
                difficulty: difficulty,
                parseStatus: parseStatus,
                diagnosticSummary: diagnosticSummary,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                required int startOffset,
                required int endOffset,
                required int ordinal,
                Value<String?> event = const Value.absent(),
                Value<String?> site = const Value.absent(),
                Value<String?> date = const Value.absent(),
                Value<String?> round = const Value.absent(),
                Value<String?> white = const Value.absent(),
                Value<String?> black = const Value.absent(),
                Value<String?> result = const Value.absent(),
                required String contentType,
                Value<String?> exerciseId = const Value.absent(),
                Value<String?> section = const Value.absent(),
                Value<int?> sequence = const Value.absent(),
                Value<String?> theme = const Value.absent(),
                Value<String?> difficulty = const Value.absent(),
                required String parseStatus,
                Value<String?> diagnosticSummary = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PgnBlocksCompanion.insert(
                id: id,
                sourceId: sourceId,
                startOffset: startOffset,
                endOffset: endOffset,
                ordinal: ordinal,
                event: event,
                site: site,
                date: date,
                round: round,
                white: white,
                black: black,
                result: result,
                contentType: contentType,
                exerciseId: exerciseId,
                section: section,
                sequence: sequence,
                theme: theme,
                difficulty: difficulty,
                parseStatus: parseStatus,
                diagnosticSummary: diagnosticSummary,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PgnBlocksTable, PgnBlock>(table),
                  $$PgnBlocksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sourceId = false,
                trainingSetItemsRefs = false,
                puzzleAttemptsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (trainingSetItemsRefs) db.trainingSetItems,
                    if (puzzleAttemptsRefs) db.puzzleAttempts,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sourceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceId,
                            referencedTable: $$PgnBlocksTableReferences
                                ._sourceIdTable(db),
                            referencedColumn: $$PgnBlocksTableReferences
                                ._sourceIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (trainingSetItemsRefs)
                        await $_getPrefetchedData<
                          PgnBlock,
                          $PgnBlocksTable,
                          TrainingSetItem
                        >(
                          currentTable: table,
                          referencedTable: $$PgnBlocksTableReferences
                              ._trainingSetItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PgnBlocksTableReferences(
                                db,
                                table,
                                p0,
                              ).trainingSetItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.blockId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (puzzleAttemptsRefs)
                        await $_getPrefetchedData<
                          PgnBlock,
                          $PgnBlocksTable,
                          PuzzleAttempt
                        >(
                          currentTable: table,
                          referencedTable: $$PgnBlocksTableReferences
                              ._puzzleAttemptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PgnBlocksTableReferences(
                                db,
                                table,
                                p0,
                              ).puzzleAttemptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.blockId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PgnBlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PgnBlocksTable,
      PgnBlock,
      $$PgnBlocksTableFilterComposer,
      $$PgnBlocksTableOrderingComposer,
      $$PgnBlocksTableAnnotationComposer,
      $$PgnBlocksTableCreateCompanionBuilder,
      $$PgnBlocksTableUpdateCompanionBuilder,
      (PgnBlock, $$PgnBlocksTableReferences),
      PgnBlock,
      PrefetchHooks Function({
        bool sourceId,
        bool trainingSetItemsRefs,
        bool puzzleAttemptsRefs,
      })
    >;
typedef $$ImportJobsTableCreateCompanionBuilder = ImportJobsCompanion Function({
  required String id,
  required String sourceId,
  required String status,
  Value<int> bytesProcessed,
  Value<int> blocksScanned,
  Value<int> blocksIndexed,
  Value<int> blocksSkipped,
  Value<int> diagnosticCount,
  Value<int> safeCheckpoint,
  Value<bool> cancellationRequested,
  required int startedAtMicros,
  Value<int?> finishedAtMicros,
  Value<int> rowid,
});
typedef $$ImportJobsTableUpdateCompanionBuilder = ImportJobsCompanion Function({
  Value<String> id,
  Value<String> sourceId,
  Value<String> status,
  Value<int> bytesProcessed,
  Value<int> blocksScanned,
  Value<int> blocksIndexed,
  Value<int> blocksSkipped,
  Value<int> diagnosticCount,
  Value<int> safeCheckpoint,
  Value<bool> cancellationRequested,
  Value<int> startedAtMicros,
  Value<int?> finishedAtMicros,
  Value<int> rowid,
});

final class $$ImportJobsTableReferences
    extends BaseReferences<_$AppDatabase, $ImportJobsTable, ImportJob> {
  $$ImportJobsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PgnSourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.pgnSources.createAlias('import_jobs__source_id__pgn_sources__id');

  $$PgnSourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$PgnSourcesTableTableManager(
      $_db,
      $_db.pgnSources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ImportDiagnosticsTable, List<ImportDiagnostic>>
  _importDiagnosticsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.importDiagnostics,
        aliasName: 'import_jobs__id__import_diagnostics__import_job_id',
      );

  $$ImportDiagnosticsTableProcessedTableManager get importDiagnosticsRefs {
    final manager = $$ImportDiagnosticsTableTableManager(
      $_db,
      $_db.importDiagnostics,
    ).filter((f) => f.importJobId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _importDiagnosticsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ImportJobsTableFilterComposer
    extends Composer<_$AppDatabase, $ImportJobsTable> {
  $$ImportJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytesProcessed => $composableBuilder(
    column: $table.bytesProcessed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blocksScanned => $composableBuilder(
    column: $table.blocksScanned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blocksIndexed => $composableBuilder(
    column: $table.blocksIndexed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blocksSkipped => $composableBuilder(
    column: $table.blocksSkipped,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diagnosticCount => $composableBuilder(
    column: $table.diagnosticCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get safeCheckpoint => $composableBuilder(
    column: $table.safeCheckpoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get cancellationRequested => $composableBuilder(
    column: $table.cancellationRequested,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finishedAtMicros => $composableBuilder(
    column: $table.finishedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  $$PgnSourcesTableFilterComposer get sourceId {
    final $$PgnSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.pgnSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PgnSourcesTableFilterComposer(
            $db: $db,
            $table: $db.pgnSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> importDiagnosticsRefs(
    Expression<bool> Function($$ImportDiagnosticsTableFilterComposer f) f,
  ) {
    final $$ImportDiagnosticsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.importDiagnostics,
      getReferencedColumn: (t) => t.importJobId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportDiagnosticsTableFilterComposer(
            $db: $db,
            $table: $db.importDiagnostics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ImportJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportJobsTable> {
  $$ImportJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytesProcessed => $composableBuilder(
    column: $table.bytesProcessed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blocksScanned => $composableBuilder(
    column: $table.blocksScanned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blocksIndexed => $composableBuilder(
    column: $table.blocksIndexed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blocksSkipped => $composableBuilder(
    column: $table.blocksSkipped,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diagnosticCount => $composableBuilder(
    column: $table.diagnosticCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get safeCheckpoint => $composableBuilder(
    column: $table.safeCheckpoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get cancellationRequested => $composableBuilder(
    column: $table.cancellationRequested,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finishedAtMicros => $composableBuilder(
    column: $table.finishedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  $$PgnSourcesTableOrderingComposer get sourceId {
    final $$PgnSourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.pgnSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PgnSourcesTableOrderingComposer(
            $db: $db,
            $table: $db.pgnSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportJobsTable> {
  $$ImportJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get bytesProcessed => $composableBuilder(
    column: $table.bytesProcessed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get blocksScanned => $composableBuilder(
    column: $table.blocksScanned,
    builder: (column) => column,
  );

  GeneratedColumn<int> get blocksIndexed => $composableBuilder(
    column: $table.blocksIndexed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get blocksSkipped => $composableBuilder(
    column: $table.blocksSkipped,
    builder: (column) => column,
  );

  GeneratedColumn<int> get diagnosticCount => $composableBuilder(
    column: $table.diagnosticCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get safeCheckpoint => $composableBuilder(
    column: $table.safeCheckpoint,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get cancellationRequested => $composableBuilder(
    column: $table.cancellationRequested,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get finishedAtMicros => $composableBuilder(
    column: $table.finishedAtMicros,
    builder: (column) => column,
  );

  $$PgnSourcesTableAnnotationComposer get sourceId {
    final $$PgnSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.pgnSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PgnSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.pgnSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> importDiagnosticsRefs<T extends Object>(
    Expression<T> Function($$ImportDiagnosticsTableAnnotationComposer a) f,
  ) {
    final $$ImportDiagnosticsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.importDiagnostics,
          getReferencedColumn: (t) => t.importJobId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ImportDiagnosticsTableAnnotationComposer(
                $db: $db,
                $table: $db.importDiagnostics,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ImportJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportJobsTable,
          ImportJob,
          $$ImportJobsTableFilterComposer,
          $$ImportJobsTableOrderingComposer,
          $$ImportJobsTableAnnotationComposer,
          $$ImportJobsTableCreateCompanionBuilder,
          $$ImportJobsTableUpdateCompanionBuilder,
          (ImportJob, $$ImportJobsTableReferences),
          ImportJob,
          PrefetchHooks Function({bool sourceId, bool importDiagnosticsRefs})
        > {
  $$ImportJobsTableTableManager(_$AppDatabase db, $ImportJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> bytesProcessed = const Value.absent(),
                Value<int> blocksScanned = const Value.absent(),
                Value<int> blocksIndexed = const Value.absent(),
                Value<int> blocksSkipped = const Value.absent(),
                Value<int> diagnosticCount = const Value.absent(),
                Value<int> safeCheckpoint = const Value.absent(),
                Value<bool> cancellationRequested = const Value.absent(),
                Value<int> startedAtMicros = const Value.absent(),
                Value<int?> finishedAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportJobsCompanion(
                id: id,
                sourceId: sourceId,
                status: status,
                bytesProcessed: bytesProcessed,
                blocksScanned: blocksScanned,
                blocksIndexed: blocksIndexed,
                blocksSkipped: blocksSkipped,
                diagnosticCount: diagnosticCount,
                safeCheckpoint: safeCheckpoint,
                cancellationRequested: cancellationRequested,
                startedAtMicros: startedAtMicros,
                finishedAtMicros: finishedAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                required String status,
                Value<int> bytesProcessed = const Value.absent(),
                Value<int> blocksScanned = const Value.absent(),
                Value<int> blocksIndexed = const Value.absent(),
                Value<int> blocksSkipped = const Value.absent(),
                Value<int> diagnosticCount = const Value.absent(),
                Value<int> safeCheckpoint = const Value.absent(),
                Value<bool> cancellationRequested = const Value.absent(),
                required int startedAtMicros,
                Value<int?> finishedAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportJobsCompanion.insert(
                id: id,
                sourceId: sourceId,
                status: status,
                bytesProcessed: bytesProcessed,
                blocksScanned: blocksScanned,
                blocksIndexed: blocksIndexed,
                blocksSkipped: blocksSkipped,
                diagnosticCount: diagnosticCount,
                safeCheckpoint: safeCheckpoint,
                cancellationRequested: cancellationRequested,
                startedAtMicros: startedAtMicros,
                finishedAtMicros: finishedAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ImportJobsTable, ImportJob>(table),
                  $$ImportJobsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sourceId = false, importDiagnosticsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (importDiagnosticsRefs) db.importDiagnostics,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sourceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceId,
                            referencedTable: $$ImportJobsTableReferences
                                ._sourceIdTable(db),
                            referencedColumn: $$ImportJobsTableReferences
                                ._sourceIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (importDiagnosticsRefs)
                        await $_getPrefetchedData<
                          ImportJob,
                          $ImportJobsTable,
                          ImportDiagnostic
                        >(
                          currentTable: table,
                          referencedTable: $$ImportJobsTableReferences
                              ._importDiagnosticsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ImportJobsTableReferences(
                                db,
                                table,
                                p0,
                              ).importDiagnosticsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.importJobId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ImportJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportJobsTable,
      ImportJob,
      $$ImportJobsTableFilterComposer,
      $$ImportJobsTableOrderingComposer,
      $$ImportJobsTableAnnotationComposer,
      $$ImportJobsTableCreateCompanionBuilder,
      $$ImportJobsTableUpdateCompanionBuilder,
      (ImportJob, $$ImportJobsTableReferences),
      ImportJob,
      PrefetchHooks Function({bool sourceId, bool importDiagnosticsRefs})
    >;
typedef $$ImportDiagnosticsTableCreateCompanionBuilder =
    ImportDiagnosticsCompanion Function({
      required String id,
      required String importJobId,
      required String severity,
      Value<int?> blockOrdinal,
      Value<int?> startOffset,
      Value<int?> endOffset,
      required String diagnosticCode,
      required String sanitizedMessage,
      required int createdAtMicros,
      Value<int> rowid,
    });
typedef $$ImportDiagnosticsTableUpdateCompanionBuilder =
    ImportDiagnosticsCompanion Function({
      Value<String> id,
      Value<String> importJobId,
      Value<String> severity,
      Value<int?> blockOrdinal,
      Value<int?> startOffset,
      Value<int?> endOffset,
      Value<String> diagnosticCode,
      Value<String> sanitizedMessage,
      Value<int> createdAtMicros,
      Value<int> rowid,
    });

final class $$ImportDiagnosticsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ImportDiagnosticsTable,
          ImportDiagnostic
        > {
  $$ImportDiagnosticsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ImportJobsTable _importJobIdTable(_$AppDatabase db) => db.importJobs
      .createAlias('import_diagnostics__import_job_id__import_jobs__id');

  $$ImportJobsTableProcessedTableManager get importJobId {
    final $_column = $_itemColumn<String>('import_job_id')!;

    final manager = $$ImportJobsTableTableManager(
      $_db,
      $_db.importJobs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_importJobIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ImportDiagnosticsTableFilterComposer
    extends Composer<_$AppDatabase, $ImportDiagnosticsTable> {
  $$ImportDiagnosticsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blockOrdinal => $composableBuilder(
    column: $table.blockOrdinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diagnosticCode => $composableBuilder(
    column: $table.diagnosticCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sanitizedMessage => $composableBuilder(
    column: $table.sanitizedMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  $$ImportJobsTableFilterComposer get importJobId {
    final $$ImportJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importJobId,
      referencedTable: $db.importJobs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportJobsTableFilterComposer(
            $db: $db,
            $table: $db.importJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportDiagnosticsTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportDiagnosticsTable> {
  $$ImportDiagnosticsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blockOrdinal => $composableBuilder(
    column: $table.blockOrdinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diagnosticCode => $composableBuilder(
    column: $table.diagnosticCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sanitizedMessage => $composableBuilder(
    column: $table.sanitizedMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  $$ImportJobsTableOrderingComposer get importJobId {
    final $$ImportJobsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importJobId,
      referencedTable: $db.importJobs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportJobsTableOrderingComposer(
            $db: $db,
            $table: $db.importJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportDiagnosticsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportDiagnosticsTable> {
  $$ImportDiagnosticsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<int> get blockOrdinal => $composableBuilder(
    column: $table.blockOrdinal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  GeneratedColumn<String> get diagnosticCode => $composableBuilder(
    column: $table.diagnosticCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sanitizedMessage => $composableBuilder(
    column: $table.sanitizedMessage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  $$ImportJobsTableAnnotationComposer get importJobId {
    final $$ImportJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importJobId,
      referencedTable: $db.importJobs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.importJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportDiagnosticsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportDiagnosticsTable,
          ImportDiagnostic,
          $$ImportDiagnosticsTableFilterComposer,
          $$ImportDiagnosticsTableOrderingComposer,
          $$ImportDiagnosticsTableAnnotationComposer,
          $$ImportDiagnosticsTableCreateCompanionBuilder,
          $$ImportDiagnosticsTableUpdateCompanionBuilder,
          (ImportDiagnostic, $$ImportDiagnosticsTableReferences),
          ImportDiagnostic,
          PrefetchHooks Function({bool importJobId})
        > {
  $$ImportDiagnosticsTableTableManager(
    _$AppDatabase db,
    $ImportDiagnosticsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportDiagnosticsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportDiagnosticsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportDiagnosticsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> importJobId = const Value.absent(),
                Value<String> severity = const Value.absent(),
                Value<int?> blockOrdinal = const Value.absent(),
                Value<int?> startOffset = const Value.absent(),
                Value<int?> endOffset = const Value.absent(),
                Value<String> diagnosticCode = const Value.absent(),
                Value<String> sanitizedMessage = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportDiagnosticsCompanion(
                id: id,
                importJobId: importJobId,
                severity: severity,
                blockOrdinal: blockOrdinal,
                startOffset: startOffset,
                endOffset: endOffset,
                diagnosticCode: diagnosticCode,
                sanitizedMessage: sanitizedMessage,
                createdAtMicros: createdAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String importJobId,
                required String severity,
                Value<int?> blockOrdinal = const Value.absent(),
                Value<int?> startOffset = const Value.absent(),
                Value<int?> endOffset = const Value.absent(),
                required String diagnosticCode,
                required String sanitizedMessage,
                required int createdAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => ImportDiagnosticsCompanion.insert(
                id: id,
                importJobId: importJobId,
                severity: severity,
                blockOrdinal: blockOrdinal,
                startOffset: startOffset,
                endOffset: endOffset,
                diagnosticCode: diagnosticCode,
                sanitizedMessage: sanitizedMessage,
                createdAtMicros: createdAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ImportDiagnosticsTable, ImportDiagnostic>(table),
                  $$ImportDiagnosticsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({importJobId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (importJobId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.importJobId,
                        referencedTable: $$ImportDiagnosticsTableReferences
                            ._importJobIdTable(db),
                        referencedColumn: $$ImportDiagnosticsTableReferences
                            ._importJobIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ImportDiagnosticsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportDiagnosticsTable,
      ImportDiagnostic,
      $$ImportDiagnosticsTableFilterComposer,
      $$ImportDiagnosticsTableOrderingComposer,
      $$ImportDiagnosticsTableAnnotationComposer,
      $$ImportDiagnosticsTableCreateCompanionBuilder,
      $$ImportDiagnosticsTableUpdateCompanionBuilder,
      (ImportDiagnostic, $$ImportDiagnosticsTableReferences),
      ImportDiagnostic,
      PrefetchHooks Function({bool importJobId})
    >;
typedef $$TrainingSetsTableCreateCompanionBuilder =
    TrainingSetsCompanion Function({
      required String id,
      required String name,
      Value<String> status,
      required int createdAtMicros,
      required int updatedAtMicros,
      Value<int?> archivedAtMicros,
      Value<int> rowid,
    });
typedef $$TrainingSetsTableUpdateCompanionBuilder =
    TrainingSetsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> status,
      Value<int> createdAtMicros,
      Value<int> updatedAtMicros,
      Value<int?> archivedAtMicros,
      Value<int> rowid,
    });

final class $$TrainingSetsTableReferences
    extends BaseReferences<_$AppDatabase, $TrainingSetsTable, TrainingSet> {
  $$TrainingSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TrainingSetItemsTable, List<TrainingSetItem>>
  _trainingSetItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.trainingSetItems,
    aliasName: 'training_sets__id__training_set_items__training_set_id',
  );

  $$TrainingSetItemsTableProcessedTableManager get trainingSetItemsRefs {
    final manager = $$TrainingSetItemsTableTableManager(
      $_db,
      $_db.trainingSetItems,
    ).filter((f) => f.trainingSetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _trainingSetItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CyclesTable, List<Cycle>> _cyclesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cycles,
    aliasName: 'training_sets__id__cycles__training_set_id',
  );

  $$CyclesTableProcessedTableManager get cyclesRefs {
    final manager = $$CyclesTableTableManager(
      $_db,
      $_db.cycles,
    ).filter((f) => f.trainingSetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cyclesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TrainingSetsTableFilterComposer
    extends Composer<_$AppDatabase, $TrainingSetsTable> {
  $$TrainingSetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archivedAtMicros => $composableBuilder(
    column: $table.archivedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> trainingSetItemsRefs(
    Expression<bool> Function($$TrainingSetItemsTableFilterComposer f) f,
  ) {
    final $$TrainingSetItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trainingSetItems,
      getReferencedColumn: (t) => t.trainingSetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingSetItemsTableFilterComposer(
            $db: $db,
            $table: $db.trainingSetItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cyclesRefs(
    Expression<bool> Function($$CyclesTableFilterComposer f) f,
  ) {
    final $$CyclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cycles,
      getReferencedColumn: (t) => t.trainingSetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CyclesTableFilterComposer(
            $db: $db,
            $table: $db.cycles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TrainingSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrainingSetsTable> {
  $$TrainingSetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedAtMicros => $composableBuilder(
    column: $table.archivedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrainingSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrainingSetsTable> {
  $$TrainingSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get archivedAtMicros => $composableBuilder(
    column: $table.archivedAtMicros,
    builder: (column) => column,
  );

  Expression<T> trainingSetItemsRefs<T extends Object>(
    Expression<T> Function($$TrainingSetItemsTableAnnotationComposer a) f,
  ) {
    final $$TrainingSetItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trainingSetItems,
      getReferencedColumn: (t) => t.trainingSetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingSetItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.trainingSetItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cyclesRefs<T extends Object>(
    Expression<T> Function($$CyclesTableAnnotationComposer a) f,
  ) {
    final $$CyclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cycles,
      getReferencedColumn: (t) => t.trainingSetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CyclesTableAnnotationComposer(
            $db: $db,
            $table: $db.cycles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TrainingSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrainingSetsTable,
          TrainingSet,
          $$TrainingSetsTableFilterComposer,
          $$TrainingSetsTableOrderingComposer,
          $$TrainingSetsTableAnnotationComposer,
          $$TrainingSetsTableCreateCompanionBuilder,
          $$TrainingSetsTableUpdateCompanionBuilder,
          (TrainingSet, $$TrainingSetsTableReferences),
          TrainingSet,
          PrefetchHooks Function({bool trainingSetItemsRefs, bool cyclesRefs})
        > {
  $$TrainingSetsTableTableManager(_$AppDatabase db, $TrainingSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrainingSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrainingSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrainingSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<int> updatedAtMicros = const Value.absent(),
                Value<int?> archivedAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainingSetsCompanion(
                id: id,
                name: name,
                status: status,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                archivedAtMicros: archivedAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> status = const Value.absent(),
                required int createdAtMicros,
                required int updatedAtMicros,
                Value<int?> archivedAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainingSetsCompanion.insert(
                id: id,
                name: name,
                status: status,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                archivedAtMicros: archivedAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrainingSetsTable, TrainingSet>(table),
                  $$TrainingSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({trainingSetItemsRefs = false, cyclesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (trainingSetItemsRefs) db.trainingSetItems,
                    if (cyclesRefs) db.cycles,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (trainingSetItemsRefs)
                        await $_getPrefetchedData<
                          TrainingSet,
                          $TrainingSetsTable,
                          TrainingSetItem
                        >(
                          currentTable: table,
                          referencedTable: $$TrainingSetsTableReferences
                              ._trainingSetItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TrainingSetsTableReferences(
                                db,
                                table,
                                p0,
                              ).trainingSetItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trainingSetId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cyclesRefs)
                        await $_getPrefetchedData<
                          TrainingSet,
                          $TrainingSetsTable,
                          Cycle
                        >(
                          currentTable: table,
                          referencedTable: $$TrainingSetsTableReferences
                              ._cyclesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TrainingSetsTableReferences(
                                db,
                                table,
                                p0,
                              ).cyclesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trainingSetId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TrainingSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrainingSetsTable,
      TrainingSet,
      $$TrainingSetsTableFilterComposer,
      $$TrainingSetsTableOrderingComposer,
      $$TrainingSetsTableAnnotationComposer,
      $$TrainingSetsTableCreateCompanionBuilder,
      $$TrainingSetsTableUpdateCompanionBuilder,
      (TrainingSet, $$TrainingSetsTableReferences),
      TrainingSet,
      PrefetchHooks Function({bool trainingSetItemsRefs, bool cyclesRefs})
    >;
typedef $$TrainingSetItemsTableCreateCompanionBuilder =
    TrainingSetItemsCompanion Function({
      required String id,
      required String trainingSetId,
      required String blockId,
      required int position,
      required String contentType,
      Value<String> state,
      required int addedAtMicros,
      Value<int> rowid,
    });
typedef $$TrainingSetItemsTableUpdateCompanionBuilder =
    TrainingSetItemsCompanion Function({
      Value<String> id,
      Value<String> trainingSetId,
      Value<String> blockId,
      Value<int> position,
      Value<String> contentType,
      Value<String> state,
      Value<int> addedAtMicros,
      Value<int> rowid,
    });

final class $$TrainingSetItemsTableReferences
    extends
        BaseReferences<_$AppDatabase, $TrainingSetItemsTable, TrainingSetItem> {
  $$TrainingSetItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TrainingSetsTable _trainingSetIdTable(_$AppDatabase db) => db
      .trainingSets
      .createAlias('training_set_items__training_set_id__training_sets__id');

  $$TrainingSetsTableProcessedTableManager get trainingSetId {
    final $_column = $_itemColumn<String>('training_set_id')!;

    final manager = $$TrainingSetsTableTableManager(
      $_db,
      $_db.trainingSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trainingSetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PgnBlocksTable _blockIdTable(_$AppDatabase db) =>
      db.pgnBlocks.createAlias('training_set_items__block_id__pgn_blocks__id');

  $$PgnBlocksTableProcessedTableManager get blockId {
    final $_column = $_itemColumn<String>('block_id')!;

    final manager = $$PgnBlocksTableTableManager(
      $_db,
      $_db.pgnBlocks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_blockIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TrainingSetItemsTableFilterComposer
    extends Composer<_$AppDatabase, $TrainingSetItemsTable> {
  $$TrainingSetItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAtMicros => $composableBuilder(
    column: $table.addedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  $$TrainingSetsTableFilterComposer get trainingSetId {
    final $$TrainingSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingSetId,
      referencedTable: $db.trainingSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingSetsTableFilterComposer(
            $db: $db,
            $table: $db.trainingSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PgnBlocksTableFilterComposer get blockId {
    final $$PgnBlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.blockId,
      referencedTable: $db.pgnBlocks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PgnBlocksTableFilterComposer(
            $db: $db,
            $table: $db.pgnBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrainingSetItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrainingSetItemsTable> {
  $$TrainingSetItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAtMicros => $composableBuilder(
    column: $table.addedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  $$TrainingSetsTableOrderingComposer get trainingSetId {
    final $$TrainingSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingSetId,
      referencedTable: $db.trainingSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingSetsTableOrderingComposer(
            $db: $db,
            $table: $db.trainingSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PgnBlocksTableOrderingComposer get blockId {
    final $$PgnBlocksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.blockId,
      referencedTable: $db.pgnBlocks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PgnBlocksTableOrderingComposer(
            $db: $db,
            $table: $db.pgnBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrainingSetItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrainingSetItemsTable> {
  $$TrainingSetItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get addedAtMicros => $composableBuilder(
    column: $table.addedAtMicros,
    builder: (column) => column,
  );

  $$TrainingSetsTableAnnotationComposer get trainingSetId {
    final $$TrainingSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingSetId,
      referencedTable: $db.trainingSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.trainingSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PgnBlocksTableAnnotationComposer get blockId {
    final $$PgnBlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.blockId,
      referencedTable: $db.pgnBlocks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PgnBlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.pgnBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrainingSetItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrainingSetItemsTable,
          TrainingSetItem,
          $$TrainingSetItemsTableFilterComposer,
          $$TrainingSetItemsTableOrderingComposer,
          $$TrainingSetItemsTableAnnotationComposer,
          $$TrainingSetItemsTableCreateCompanionBuilder,
          $$TrainingSetItemsTableUpdateCompanionBuilder,
          (TrainingSetItem, $$TrainingSetItemsTableReferences),
          TrainingSetItem,
          PrefetchHooks Function({bool trainingSetId, bool blockId})
        > {
  $$TrainingSetItemsTableTableManager(
    _$AppDatabase db,
    $TrainingSetItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrainingSetItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrainingSetItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrainingSetItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> trainingSetId = const Value.absent(),
                Value<String> blockId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> contentType = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> addedAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainingSetItemsCompanion(
                id: id,
                trainingSetId: trainingSetId,
                blockId: blockId,
                position: position,
                contentType: contentType,
                state: state,
                addedAtMicros: addedAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String trainingSetId,
                required String blockId,
                required int position,
                required String contentType,
                Value<String> state = const Value.absent(),
                required int addedAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => TrainingSetItemsCompanion.insert(
                id: id,
                trainingSetId: trainingSetId,
                blockId: blockId,
                position: position,
                contentType: contentType,
                state: state,
                addedAtMicros: addedAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrainingSetItemsTable, TrainingSetItem>(table),
                  $$TrainingSetItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trainingSetId = false, blockId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trainingSetId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trainingSetId,
                        referencedTable: $$TrainingSetItemsTableReferences
                            ._trainingSetIdTable(db),
                        referencedColumn: $$TrainingSetItemsTableReferences
                            ._trainingSetIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (blockId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.blockId,
                        referencedTable: $$TrainingSetItemsTableReferences
                            ._blockIdTable(db),
                        referencedColumn: $$TrainingSetItemsTableReferences
                            ._blockIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TrainingSetItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrainingSetItemsTable,
      TrainingSetItem,
      $$TrainingSetItemsTableFilterComposer,
      $$TrainingSetItemsTableOrderingComposer,
      $$TrainingSetItemsTableAnnotationComposer,
      $$TrainingSetItemsTableCreateCompanionBuilder,
      $$TrainingSetItemsTableUpdateCompanionBuilder,
      (TrainingSetItem, $$TrainingSetItemsTableReferences),
      TrainingSetItem,
      PrefetchHooks Function({bool trainingSetId, bool blockId})
    >;
typedef $$CyclesTableCreateCompanionBuilder = CyclesCompanion Function({
  required String id,
  required String trainingSetId,
  required String status,
  Value<int?> startedAtMicros,
  Value<int?> completedAtMicros,
  Value<int?> stoppedAtMicros,
  required int createdAtMicros,
  Value<int> rowid,
});
typedef $$CyclesTableUpdateCompanionBuilder = CyclesCompanion Function({
  Value<String> id,
  Value<String> trainingSetId,
  Value<String> status,
  Value<int?> startedAtMicros,
  Value<int?> completedAtMicros,
  Value<int?> stoppedAtMicros,
  Value<int> createdAtMicros,
  Value<int> rowid,
});

final class $$CyclesTableReferences
    extends BaseReferences<_$AppDatabase, $CyclesTable, Cycle> {
  $$CyclesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TrainingSetsTable _trainingSetIdTable(_$AppDatabase db) =>
      db.trainingSets.createAlias('cycles__training_set_id__training_sets__id');

  $$TrainingSetsTableProcessedTableManager get trainingSetId {
    final $_column = $_itemColumn<String>('training_set_id')!;

    final manager = $$TrainingSetsTableTableManager(
      $_db,
      $_db.trainingSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trainingSetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TrainingSessionsTable, List<TrainingSession>>
  _trainingSessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.trainingSessions,
    aliasName: 'cycles__id__training_sessions__cycle_id',
  );

  $$TrainingSessionsTableProcessedTableManager get trainingSessionsRefs {
    final manager = $$TrainingSessionsTableTableManager(
      $_db,
      $_db.trainingSessions,
    ).filter((f) => f.cycleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _trainingSessionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PuzzleAttemptsTable, List<PuzzleAttempt>>
  _puzzleAttemptsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.puzzleAttempts,
    aliasName: 'cycles__id__puzzle_attempts__cycle_id',
  );

  $$PuzzleAttemptsTableProcessedTableManager get puzzleAttemptsRefs {
    final manager = $$PuzzleAttemptsTableTableManager(
      $_db,
      $_db.puzzleAttempts,
    ).filter((f) => f.cycleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_puzzleAttemptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CyclesTableFilterComposer
    extends Composer<_$AppDatabase, $CyclesTable> {
  $$CyclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAtMicros => $composableBuilder(
    column: $table.completedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stoppedAtMicros => $composableBuilder(
    column: $table.stoppedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  $$TrainingSetsTableFilterComposer get trainingSetId {
    final $$TrainingSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingSetId,
      referencedTable: $db.trainingSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingSetsTableFilterComposer(
            $db: $db,
            $table: $db.trainingSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> trainingSessionsRefs(
    Expression<bool> Function($$TrainingSessionsTableFilterComposer f) f,
  ) {
    final $$TrainingSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trainingSessions,
      getReferencedColumn: (t) => t.cycleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingSessionsTableFilterComposer(
            $db: $db,
            $table: $db.trainingSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> puzzleAttemptsRefs(
    Expression<bool> Function($$PuzzleAttemptsTableFilterComposer f) f,
  ) {
    final $$PuzzleAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.puzzleAttempts,
      getReferencedColumn: (t) => t.cycleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PuzzleAttemptsTableFilterComposer(
            $db: $db,
            $table: $db.puzzleAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CyclesTableOrderingComposer
    extends Composer<_$AppDatabase, $CyclesTable> {
  $$CyclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAtMicros => $composableBuilder(
    column: $table.completedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stoppedAtMicros => $composableBuilder(
    column: $table.stoppedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  $$TrainingSetsTableOrderingComposer get trainingSetId {
    final $$TrainingSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingSetId,
      referencedTable: $db.trainingSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingSetsTableOrderingComposer(
            $db: $db,
            $table: $db.trainingSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CyclesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CyclesTable> {
  $$CyclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAtMicros => $composableBuilder(
    column: $table.completedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stoppedAtMicros => $composableBuilder(
    column: $table.stoppedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  $$TrainingSetsTableAnnotationComposer get trainingSetId {
    final $$TrainingSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingSetId,
      referencedTable: $db.trainingSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.trainingSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> trainingSessionsRefs<T extends Object>(
    Expression<T> Function($$TrainingSessionsTableAnnotationComposer a) f,
  ) {
    final $$TrainingSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trainingSessions,
      getReferencedColumn: (t) => t.cycleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.trainingSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> puzzleAttemptsRefs<T extends Object>(
    Expression<T> Function($$PuzzleAttemptsTableAnnotationComposer a) f,
  ) {
    final $$PuzzleAttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.puzzleAttempts,
      getReferencedColumn: (t) => t.cycleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PuzzleAttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.puzzleAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CyclesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CyclesTable,
          Cycle,
          $$CyclesTableFilterComposer,
          $$CyclesTableOrderingComposer,
          $$CyclesTableAnnotationComposer,
          $$CyclesTableCreateCompanionBuilder,
          $$CyclesTableUpdateCompanionBuilder,
          (Cycle, $$CyclesTableReferences),
          Cycle,
          PrefetchHooks Function({
            bool trainingSetId,
            bool trainingSessionsRefs,
            bool puzzleAttemptsRefs,
          })
        > {
  $$CyclesTableTableManager(_$AppDatabase db, $CyclesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CyclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CyclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CyclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> trainingSetId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> startedAtMicros = const Value.absent(),
                Value<int?> completedAtMicros = const Value.absent(),
                Value<int?> stoppedAtMicros = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CyclesCompanion(
                id: id,
                trainingSetId: trainingSetId,
                status: status,
                startedAtMicros: startedAtMicros,
                completedAtMicros: completedAtMicros,
                stoppedAtMicros: stoppedAtMicros,
                createdAtMicros: createdAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String trainingSetId,
                required String status,
                Value<int?> startedAtMicros = const Value.absent(),
                Value<int?> completedAtMicros = const Value.absent(),
                Value<int?> stoppedAtMicros = const Value.absent(),
                required int createdAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => CyclesCompanion.insert(
                id: id,
                trainingSetId: trainingSetId,
                status: status,
                startedAtMicros: startedAtMicros,
                completedAtMicros: completedAtMicros,
                stoppedAtMicros: stoppedAtMicros,
                createdAtMicros: createdAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CyclesTable, Cycle>(table),
                  $$CyclesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                trainingSetId = false,
                trainingSessionsRefs = false,
                puzzleAttemptsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (trainingSessionsRefs) db.trainingSessions,
                    if (puzzleAttemptsRefs) db.puzzleAttempts,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (trainingSetId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.trainingSetId,
                            referencedTable: $$CyclesTableReferences
                                ._trainingSetIdTable(db),
                            referencedColumn: $$CyclesTableReferences
                                ._trainingSetIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (trainingSessionsRefs)
                        await $_getPrefetchedData<
                          Cycle,
                          $CyclesTable,
                          TrainingSession
                        >(
                          currentTable: table,
                          referencedTable: $$CyclesTableReferences
                              ._trainingSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CyclesTableReferences(
                                db,
                                table,
                                p0,
                              ).trainingSessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cycleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (puzzleAttemptsRefs)
                        await $_getPrefetchedData<
                          Cycle,
                          $CyclesTable,
                          PuzzleAttempt
                        >(
                          currentTable: table,
                          referencedTable: $$CyclesTableReferences
                              ._puzzleAttemptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CyclesTableReferences(
                                db,
                                table,
                                p0,
                              ).puzzleAttemptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cycleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CyclesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CyclesTable,
      Cycle,
      $$CyclesTableFilterComposer,
      $$CyclesTableOrderingComposer,
      $$CyclesTableAnnotationComposer,
      $$CyclesTableCreateCompanionBuilder,
      $$CyclesTableUpdateCompanionBuilder,
      (Cycle, $$CyclesTableReferences),
      Cycle,
      PrefetchHooks Function({
        bool trainingSetId,
        bool trainingSessionsRefs,
        bool puzzleAttemptsRefs,
      })
    >;
typedef $$TrainingSessionsTableCreateCompanionBuilder =
    TrainingSessionsCompanion Function({
      required String id,
      required String cycleId,
      required String status,
      required int startedAtMicros,
      Value<int?> endedAtMicros,
      required int studyDayMicros,
      Value<int> rowid,
    });
typedef $$TrainingSessionsTableUpdateCompanionBuilder =
    TrainingSessionsCompanion Function({
      Value<String> id,
      Value<String> cycleId,
      Value<String> status,
      Value<int> startedAtMicros,
      Value<int?> endedAtMicros,
      Value<int> studyDayMicros,
      Value<int> rowid,
    });

final class $$TrainingSessionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $TrainingSessionsTable, TrainingSession> {
  $$TrainingSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CyclesTable _cycleIdTable(_$AppDatabase db) =>
      db.cycles.createAlias('training_sessions__cycle_id__cycles__id');

  $$CyclesTableProcessedTableManager get cycleId {
    final $_column = $_itemColumn<String>('cycle_id')!;

    final manager = $$CyclesTableTableManager(
      $_db,
      $_db.cycles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cycleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PuzzleAttemptsTable, List<PuzzleAttempt>>
  _puzzleAttemptsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.puzzleAttempts,
    aliasName: 'training_sessions__id__puzzle_attempts__session_id',
  );

  $$PuzzleAttemptsTableProcessedTableManager get puzzleAttemptsRefs {
    final manager = $$PuzzleAttemptsTableTableManager(
      $_db,
      $_db.puzzleAttempts,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_puzzleAttemptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TrainingSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $TrainingSessionsTable> {
  $$TrainingSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAtMicros => $composableBuilder(
    column: $table.endedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get studyDayMicros => $composableBuilder(
    column: $table.studyDayMicros,
    builder: (column) => ColumnFilters(column),
  );

  $$CyclesTableFilterComposer get cycleId {
    final $$CyclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cycleId,
      referencedTable: $db.cycles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CyclesTableFilterComposer(
            $db: $db,
            $table: $db.cycles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> puzzleAttemptsRefs(
    Expression<bool> Function($$PuzzleAttemptsTableFilterComposer f) f,
  ) {
    final $$PuzzleAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.puzzleAttempts,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PuzzleAttemptsTableFilterComposer(
            $db: $db,
            $table: $db.puzzleAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TrainingSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrainingSessionsTable> {
  $$TrainingSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAtMicros => $composableBuilder(
    column: $table.endedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get studyDayMicros => $composableBuilder(
    column: $table.studyDayMicros,
    builder: (column) => ColumnOrderings(column),
  );

  $$CyclesTableOrderingComposer get cycleId {
    final $$CyclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cycleId,
      referencedTable: $db.cycles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CyclesTableOrderingComposer(
            $db: $db,
            $table: $db.cycles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrainingSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrainingSessionsTable> {
  $$TrainingSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endedAtMicros => $composableBuilder(
    column: $table.endedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get studyDayMicros => $composableBuilder(
    column: $table.studyDayMicros,
    builder: (column) => column,
  );

  $$CyclesTableAnnotationComposer get cycleId {
    final $$CyclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cycleId,
      referencedTable: $db.cycles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CyclesTableAnnotationComposer(
            $db: $db,
            $table: $db.cycles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> puzzleAttemptsRefs<T extends Object>(
    Expression<T> Function($$PuzzleAttemptsTableAnnotationComposer a) f,
  ) {
    final $$PuzzleAttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.puzzleAttempts,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PuzzleAttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.puzzleAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TrainingSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrainingSessionsTable,
          TrainingSession,
          $$TrainingSessionsTableFilterComposer,
          $$TrainingSessionsTableOrderingComposer,
          $$TrainingSessionsTableAnnotationComposer,
          $$TrainingSessionsTableCreateCompanionBuilder,
          $$TrainingSessionsTableUpdateCompanionBuilder,
          (TrainingSession, $$TrainingSessionsTableReferences),
          TrainingSession,
          PrefetchHooks Function({bool cycleId, bool puzzleAttemptsRefs})
        > {
  $$TrainingSessionsTableTableManager(
    _$AppDatabase db,
    $TrainingSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrainingSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrainingSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrainingSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> cycleId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> startedAtMicros = const Value.absent(),
                Value<int?> endedAtMicros = const Value.absent(),
                Value<int> studyDayMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainingSessionsCompanion(
                id: id,
                cycleId: cycleId,
                status: status,
                startedAtMicros: startedAtMicros,
                endedAtMicros: endedAtMicros,
                studyDayMicros: studyDayMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String cycleId,
                required String status,
                required int startedAtMicros,
                Value<int?> endedAtMicros = const Value.absent(),
                required int studyDayMicros,
                Value<int> rowid = const Value.absent(),
              }) => TrainingSessionsCompanion.insert(
                id: id,
                cycleId: cycleId,
                status: status,
                startedAtMicros: startedAtMicros,
                endedAtMicros: endedAtMicros,
                studyDayMicros: studyDayMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrainingSessionsTable, TrainingSession>(table),
                  $$TrainingSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({cycleId = false, puzzleAttemptsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (puzzleAttemptsRefs) db.puzzleAttempts,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (cycleId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.cycleId,
                            referencedTable: $$TrainingSessionsTableReferences
                                ._cycleIdTable(db),
                            referencedColumn: $$TrainingSessionsTableReferences
                                ._cycleIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (puzzleAttemptsRefs)
                        await $_getPrefetchedData<
                          TrainingSession,
                          $TrainingSessionsTable,
                          PuzzleAttempt
                        >(
                          currentTable: table,
                          referencedTable: $$TrainingSessionsTableReferences
                              ._puzzleAttemptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TrainingSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).puzzleAttemptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TrainingSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrainingSessionsTable,
      TrainingSession,
      $$TrainingSessionsTableFilterComposer,
      $$TrainingSessionsTableOrderingComposer,
      $$TrainingSessionsTableAnnotationComposer,
      $$TrainingSessionsTableCreateCompanionBuilder,
      $$TrainingSessionsTableUpdateCompanionBuilder,
      (TrainingSession, $$TrainingSessionsTableReferences),
      TrainingSession,
      PrefetchHooks Function({bool cycleId, bool puzzleAttemptsRefs})
    >;
typedef $$PuzzleAttemptsTableCreateCompanionBuilder =
    PuzzleAttemptsCompanion Function({
      required String id,
      required String blockId,
      required String cycleId,
      required String sessionId,
      required String status,
      Value<String?> outcome,
      Value<String?> failureReason,
      required int startedAtMicros,
      Value<int?> completedAtMicros,
      Value<int> activeMilliseconds,
      Value<int> wrongMoveCount,
      Value<int> hintCount,
      Value<bool> revealed,
      Value<int> rowid,
    });
typedef $$PuzzleAttemptsTableUpdateCompanionBuilder =
    PuzzleAttemptsCompanion Function({
      Value<String> id,
      Value<String> blockId,
      Value<String> cycleId,
      Value<String> sessionId,
      Value<String> status,
      Value<String?> outcome,
      Value<String?> failureReason,
      Value<int> startedAtMicros,
      Value<int?> completedAtMicros,
      Value<int> activeMilliseconds,
      Value<int> wrongMoveCount,
      Value<int> hintCount,
      Value<bool> revealed,
      Value<int> rowid,
    });

final class $$PuzzleAttemptsTableReferences
    extends BaseReferences<_$AppDatabase, $PuzzleAttemptsTable, PuzzleAttempt> {
  $$PuzzleAttemptsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PgnBlocksTable _blockIdTable(_$AppDatabase db) =>
      db.pgnBlocks.createAlias('puzzle_attempts__block_id__pgn_blocks__id');

  $$PgnBlocksTableProcessedTableManager get blockId {
    final $_column = $_itemColumn<String>('block_id')!;

    final manager = $$PgnBlocksTableTableManager(
      $_db,
      $_db.pgnBlocks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_blockIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CyclesTable _cycleIdTable(_$AppDatabase db) =>
      db.cycles.createAlias('puzzle_attempts__cycle_id__cycles__id');

  $$CyclesTableProcessedTableManager get cycleId {
    final $_column = $_itemColumn<String>('cycle_id')!;

    final manager = $$CyclesTableTableManager(
      $_db,
      $_db.cycles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cycleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TrainingSessionsTable _sessionIdTable(_$AppDatabase db) => db
      .trainingSessions
      .createAlias('puzzle_attempts__session_id__training_sessions__id');

  $$TrainingSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$TrainingSessionsTableTableManager(
      $_db,
      $_db.trainingSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AttemptMovesTable, List<AttemptMove>>
  _attemptMovesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attemptMoves,
    aliasName: 'puzzle_attempts__id__attempt_moves__attempt_id',
  );

  $$AttemptMovesTableProcessedTableManager get attemptMovesRefs {
    final manager = $$AttemptMovesTableTableManager(
      $_db,
      $_db.attemptMoves,
    ).filter((f) => f.attemptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_attemptMovesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TimingSegmentsTable, List<TimingSegment>>
  _timingSegmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.timingSegments,
    aliasName: 'puzzle_attempts__id__timing_segments__attempt_id',
  );

  $$TimingSegmentsTableProcessedTableManager get timingSegmentsRefs {
    final manager = $$TimingSegmentsTableTableManager(
      $_db,
      $_db.timingSegments,
    ).filter((f) => f.attemptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_timingSegmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PuzzleAttemptsTableFilterComposer
    extends Composer<_$AppDatabase, $PuzzleAttemptsTable> {
  $$PuzzleAttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAtMicros => $composableBuilder(
    column: $table.completedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activeMilliseconds => $composableBuilder(
    column: $table.activeMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wrongMoveCount => $composableBuilder(
    column: $table.wrongMoveCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hintCount => $composableBuilder(
    column: $table.hintCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get revealed => $composableBuilder(
    column: $table.revealed,
    builder: (column) => ColumnFilters(column),
  );

  $$PgnBlocksTableFilterComposer get blockId {
    final $$PgnBlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.blockId,
      referencedTable: $db.pgnBlocks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PgnBlocksTableFilterComposer(
            $db: $db,
            $table: $db.pgnBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CyclesTableFilterComposer get cycleId {
    final $$CyclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cycleId,
      referencedTable: $db.cycles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CyclesTableFilterComposer(
            $db: $db,
            $table: $db.cycles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TrainingSessionsTableFilterComposer get sessionId {
    final $$TrainingSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.trainingSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingSessionsTableFilterComposer(
            $db: $db,
            $table: $db.trainingSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> attemptMovesRefs(
    Expression<bool> Function($$AttemptMovesTableFilterComposer f) f,
  ) {
    final $$AttemptMovesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attemptMoves,
      getReferencedColumn: (t) => t.attemptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptMovesTableFilterComposer(
            $db: $db,
            $table: $db.attemptMoves,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> timingSegmentsRefs(
    Expression<bool> Function($$TimingSegmentsTableFilterComposer f) f,
  ) {
    final $$TimingSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timingSegments,
      getReferencedColumn: (t) => t.attemptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimingSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.timingSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PuzzleAttemptsTableOrderingComposer
    extends Composer<_$AppDatabase, $PuzzleAttemptsTable> {
  $$PuzzleAttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAtMicros => $composableBuilder(
    column: $table.completedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activeMilliseconds => $composableBuilder(
    column: $table.activeMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wrongMoveCount => $composableBuilder(
    column: $table.wrongMoveCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hintCount => $composableBuilder(
    column: $table.hintCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get revealed => $composableBuilder(
    column: $table.revealed,
    builder: (column) => ColumnOrderings(column),
  );

  $$PgnBlocksTableOrderingComposer get blockId {
    final $$PgnBlocksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.blockId,
      referencedTable: $db.pgnBlocks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PgnBlocksTableOrderingComposer(
            $db: $db,
            $table: $db.pgnBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CyclesTableOrderingComposer get cycleId {
    final $$CyclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cycleId,
      referencedTable: $db.cycles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CyclesTableOrderingComposer(
            $db: $db,
            $table: $db.cycles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TrainingSessionsTableOrderingComposer get sessionId {
    final $$TrainingSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.trainingSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.trainingSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PuzzleAttemptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PuzzleAttemptsTable> {
  $$PuzzleAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAtMicros => $composableBuilder(
    column: $table.completedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get activeMilliseconds => $composableBuilder(
    column: $table.activeMilliseconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wrongMoveCount => $composableBuilder(
    column: $table.wrongMoveCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hintCount =>
      $composableBuilder(column: $table.hintCount, builder: (column) => column);

  GeneratedColumn<bool> get revealed =>
      $composableBuilder(column: $table.revealed, builder: (column) => column);

  $$PgnBlocksTableAnnotationComposer get blockId {
    final $$PgnBlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.blockId,
      referencedTable: $db.pgnBlocks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PgnBlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.pgnBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CyclesTableAnnotationComposer get cycleId {
    final $$CyclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cycleId,
      referencedTable: $db.cycles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CyclesTableAnnotationComposer(
            $db: $db,
            $table: $db.cycles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TrainingSessionsTableAnnotationComposer get sessionId {
    final $$TrainingSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.trainingSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.trainingSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> attemptMovesRefs<T extends Object>(
    Expression<T> Function($$AttemptMovesTableAnnotationComposer a) f,
  ) {
    final $$AttemptMovesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attemptMoves,
      getReferencedColumn: (t) => t.attemptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptMovesTableAnnotationComposer(
            $db: $db,
            $table: $db.attemptMoves,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> timingSegmentsRefs<T extends Object>(
    Expression<T> Function($$TimingSegmentsTableAnnotationComposer a) f,
  ) {
    final $$TimingSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timingSegments,
      getReferencedColumn: (t) => t.attemptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimingSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.timingSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PuzzleAttemptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PuzzleAttemptsTable,
          PuzzleAttempt,
          $$PuzzleAttemptsTableFilterComposer,
          $$PuzzleAttemptsTableOrderingComposer,
          $$PuzzleAttemptsTableAnnotationComposer,
          $$PuzzleAttemptsTableCreateCompanionBuilder,
          $$PuzzleAttemptsTableUpdateCompanionBuilder,
          (PuzzleAttempt, $$PuzzleAttemptsTableReferences),
          PuzzleAttempt,
          PrefetchHooks Function({
            bool blockId,
            bool cycleId,
            bool sessionId,
            bool attemptMovesRefs,
            bool timingSegmentsRefs,
          })
        > {
  $$PuzzleAttemptsTableTableManager(
    _$AppDatabase db,
    $PuzzleAttemptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PuzzleAttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PuzzleAttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PuzzleAttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> blockId = const Value.absent(),
                Value<String> cycleId = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> outcome = const Value.absent(),
                Value<String?> failureReason = const Value.absent(),
                Value<int> startedAtMicros = const Value.absent(),
                Value<int?> completedAtMicros = const Value.absent(),
                Value<int> activeMilliseconds = const Value.absent(),
                Value<int> wrongMoveCount = const Value.absent(),
                Value<int> hintCount = const Value.absent(),
                Value<bool> revealed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PuzzleAttemptsCompanion(
                id: id,
                blockId: blockId,
                cycleId: cycleId,
                sessionId: sessionId,
                status: status,
                outcome: outcome,
                failureReason: failureReason,
                startedAtMicros: startedAtMicros,
                completedAtMicros: completedAtMicros,
                activeMilliseconds: activeMilliseconds,
                wrongMoveCount: wrongMoveCount,
                hintCount: hintCount,
                revealed: revealed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String blockId,
                required String cycleId,
                required String sessionId,
                required String status,
                Value<String?> outcome = const Value.absent(),
                Value<String?> failureReason = const Value.absent(),
                required int startedAtMicros,
                Value<int?> completedAtMicros = const Value.absent(),
                Value<int> activeMilliseconds = const Value.absent(),
                Value<int> wrongMoveCount = const Value.absent(),
                Value<int> hintCount = const Value.absent(),
                Value<bool> revealed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PuzzleAttemptsCompanion.insert(
                id: id,
                blockId: blockId,
                cycleId: cycleId,
                sessionId: sessionId,
                status: status,
                outcome: outcome,
                failureReason: failureReason,
                startedAtMicros: startedAtMicros,
                completedAtMicros: completedAtMicros,
                activeMilliseconds: activeMilliseconds,
                wrongMoveCount: wrongMoveCount,
                hintCount: hintCount,
                revealed: revealed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PuzzleAttemptsTable, PuzzleAttempt>(table),
                  $$PuzzleAttemptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                blockId = false,
                cycleId = false,
                sessionId = false,
                attemptMovesRefs = false,
                timingSegmentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (attemptMovesRefs) db.attemptMoves,
                    if (timingSegmentsRefs) db.timingSegments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (blockId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.blockId,
                            referencedTable: $$PuzzleAttemptsTableReferences
                                ._blockIdTable(db),
                            referencedColumn: $$PuzzleAttemptsTableReferences
                                ._blockIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (cycleId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.cycleId,
                            referencedTable: $$PuzzleAttemptsTableReferences
                                ._cycleIdTable(db),
                            referencedColumn: $$PuzzleAttemptsTableReferences
                                ._cycleIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (sessionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sessionId,
                            referencedTable: $$PuzzleAttemptsTableReferences
                                ._sessionIdTable(db),
                            referencedColumn: $$PuzzleAttemptsTableReferences
                                ._sessionIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (attemptMovesRefs)
                        await $_getPrefetchedData<
                          PuzzleAttempt,
                          $PuzzleAttemptsTable,
                          AttemptMove
                        >(
                          currentTable: table,
                          referencedTable: $$PuzzleAttemptsTableReferences
                              ._attemptMovesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PuzzleAttemptsTableReferences(
                                db,
                                table,
                                p0,
                              ).attemptMovesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.attemptId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (timingSegmentsRefs)
                        await $_getPrefetchedData<
                          PuzzleAttempt,
                          $PuzzleAttemptsTable,
                          TimingSegment
                        >(
                          currentTable: table,
                          referencedTable: $$PuzzleAttemptsTableReferences
                              ._timingSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PuzzleAttemptsTableReferences(
                                db,
                                table,
                                p0,
                              ).timingSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.attemptId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PuzzleAttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PuzzleAttemptsTable,
      PuzzleAttempt,
      $$PuzzleAttemptsTableFilterComposer,
      $$PuzzleAttemptsTableOrderingComposer,
      $$PuzzleAttemptsTableAnnotationComposer,
      $$PuzzleAttemptsTableCreateCompanionBuilder,
      $$PuzzleAttemptsTableUpdateCompanionBuilder,
      (PuzzleAttempt, $$PuzzleAttemptsTableReferences),
      PuzzleAttempt,
      PrefetchHooks Function({
        bool blockId,
        bool cycleId,
        bool sessionId,
        bool attemptMovesRefs,
        bool timingSegmentsRefs,
      })
    >;
typedef $$AttemptMovesTableCreateCompanionBuilder =
    AttemptMovesCompanion Function({
      required String id,
      required String attemptId,
      required int ordinal,
      required String move,
      required bool legal,
      required bool accepted,
      required int submittedAtMicros,
      Value<int> rowid,
    });
typedef $$AttemptMovesTableUpdateCompanionBuilder =
    AttemptMovesCompanion Function({
      Value<String> id,
      Value<String> attemptId,
      Value<int> ordinal,
      Value<String> move,
      Value<bool> legal,
      Value<bool> accepted,
      Value<int> submittedAtMicros,
      Value<int> rowid,
    });

final class $$AttemptMovesTableReferences
    extends BaseReferences<_$AppDatabase, $AttemptMovesTable, AttemptMove> {
  $$AttemptMovesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PuzzleAttemptsTable _attemptIdTable(_$AppDatabase db) => db
      .puzzleAttempts
      .createAlias('attempt_moves__attempt_id__puzzle_attempts__id');

  $$PuzzleAttemptsTableProcessedTableManager get attemptId {
    final $_column = $_itemColumn<String>('attempt_id')!;

    final manager = $$PuzzleAttemptsTableTableManager(
      $_db,
      $_db.puzzleAttempts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_attemptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttemptMovesTableFilterComposer
    extends Composer<_$AppDatabase, $AttemptMovesTable> {
  $$AttemptMovesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get move => $composableBuilder(
    column: $table.move,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get legal => $composableBuilder(
    column: $table.legal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get accepted => $composableBuilder(
    column: $table.accepted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get submittedAtMicros => $composableBuilder(
    column: $table.submittedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  $$PuzzleAttemptsTableFilterComposer get attemptId {
    final $$PuzzleAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.puzzleAttempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PuzzleAttemptsTableFilterComposer(
            $db: $db,
            $table: $db.puzzleAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttemptMovesTableOrderingComposer
    extends Composer<_$AppDatabase, $AttemptMovesTable> {
  $$AttemptMovesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get move => $composableBuilder(
    column: $table.move,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get legal => $composableBuilder(
    column: $table.legal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get accepted => $composableBuilder(
    column: $table.accepted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get submittedAtMicros => $composableBuilder(
    column: $table.submittedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  $$PuzzleAttemptsTableOrderingComposer get attemptId {
    final $$PuzzleAttemptsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.puzzleAttempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PuzzleAttemptsTableOrderingComposer(
            $db: $db,
            $table: $db.puzzleAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttemptMovesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttemptMovesTable> {
  $$AttemptMovesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<String> get move =>
      $composableBuilder(column: $table.move, builder: (column) => column);

  GeneratedColumn<bool> get legal =>
      $composableBuilder(column: $table.legal, builder: (column) => column);

  GeneratedColumn<bool> get accepted =>
      $composableBuilder(column: $table.accepted, builder: (column) => column);

  GeneratedColumn<int> get submittedAtMicros => $composableBuilder(
    column: $table.submittedAtMicros,
    builder: (column) => column,
  );

  $$PuzzleAttemptsTableAnnotationComposer get attemptId {
    final $$PuzzleAttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.puzzleAttempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PuzzleAttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.puzzleAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttemptMovesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttemptMovesTable,
          AttemptMove,
          $$AttemptMovesTableFilterComposer,
          $$AttemptMovesTableOrderingComposer,
          $$AttemptMovesTableAnnotationComposer,
          $$AttemptMovesTableCreateCompanionBuilder,
          $$AttemptMovesTableUpdateCompanionBuilder,
          (AttemptMove, $$AttemptMovesTableReferences),
          AttemptMove,
          PrefetchHooks Function({bool attemptId})
        > {
  $$AttemptMovesTableTableManager(_$AppDatabase db, $AttemptMovesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttemptMovesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttemptMovesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttemptMovesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> attemptId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<String> move = const Value.absent(),
                Value<bool> legal = const Value.absent(),
                Value<bool> accepted = const Value.absent(),
                Value<int> submittedAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttemptMovesCompanion(
                id: id,
                attemptId: attemptId,
                ordinal: ordinal,
                move: move,
                legal: legal,
                accepted: accepted,
                submittedAtMicros: submittedAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String attemptId,
                required int ordinal,
                required String move,
                required bool legal,
                required bool accepted,
                required int submittedAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => AttemptMovesCompanion.insert(
                id: id,
                attemptId: attemptId,
                ordinal: ordinal,
                move: move,
                legal: legal,
                accepted: accepted,
                submittedAtMicros: submittedAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttemptMovesTable, AttemptMove>(table),
                  $$AttemptMovesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({attemptId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (attemptId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.attemptId,
                        referencedTable: $$AttemptMovesTableReferences
                            ._attemptIdTable(db),
                        referencedColumn: $$AttemptMovesTableReferences
                            ._attemptIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttemptMovesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttemptMovesTable,
      AttemptMove,
      $$AttemptMovesTableFilterComposer,
      $$AttemptMovesTableOrderingComposer,
      $$AttemptMovesTableAnnotationComposer,
      $$AttemptMovesTableCreateCompanionBuilder,
      $$AttemptMovesTableUpdateCompanionBuilder,
      (AttemptMove, $$AttemptMovesTableReferences),
      AttemptMove,
      PrefetchHooks Function({bool attemptId})
    >;
typedef $$TimingSegmentsTableCreateCompanionBuilder =
    TimingSegmentsCompanion Function({
      required String id,
      required String attemptId,
      required int startedAtMicros,
      Value<int?> endedAtMicros,
      Value<int?> activeMilliseconds,
      Value<int> rowid,
    });
typedef $$TimingSegmentsTableUpdateCompanionBuilder =
    TimingSegmentsCompanion Function({
      Value<String> id,
      Value<String> attemptId,
      Value<int> startedAtMicros,
      Value<int?> endedAtMicros,
      Value<int?> activeMilliseconds,
      Value<int> rowid,
    });

final class $$TimingSegmentsTableReferences
    extends BaseReferences<_$AppDatabase, $TimingSegmentsTable, TimingSegment> {
  $$TimingSegmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PuzzleAttemptsTable _attemptIdTable(_$AppDatabase db) => db
      .puzzleAttempts
      .createAlias('timing_segments__attempt_id__puzzle_attempts__id');

  $$PuzzleAttemptsTableProcessedTableManager get attemptId {
    final $_column = $_itemColumn<String>('attempt_id')!;

    final manager = $$PuzzleAttemptsTableTableManager(
      $_db,
      $_db.puzzleAttempts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_attemptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TimingSegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $TimingSegmentsTable> {
  $$TimingSegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAtMicros => $composableBuilder(
    column: $table.endedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activeMilliseconds => $composableBuilder(
    column: $table.activeMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  $$PuzzleAttemptsTableFilterComposer get attemptId {
    final $$PuzzleAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.puzzleAttempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PuzzleAttemptsTableFilterComposer(
            $db: $db,
            $table: $db.puzzleAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimingSegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $TimingSegmentsTable> {
  $$TimingSegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAtMicros => $composableBuilder(
    column: $table.endedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activeMilliseconds => $composableBuilder(
    column: $table.activeMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  $$PuzzleAttemptsTableOrderingComposer get attemptId {
    final $$PuzzleAttemptsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.puzzleAttempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PuzzleAttemptsTableOrderingComposer(
            $db: $db,
            $table: $db.puzzleAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimingSegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TimingSegmentsTable> {
  $$TimingSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endedAtMicros => $composableBuilder(
    column: $table.endedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get activeMilliseconds => $composableBuilder(
    column: $table.activeMilliseconds,
    builder: (column) => column,
  );

  $$PuzzleAttemptsTableAnnotationComposer get attemptId {
    final $$PuzzleAttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.puzzleAttempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PuzzleAttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.puzzleAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimingSegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TimingSegmentsTable,
          TimingSegment,
          $$TimingSegmentsTableFilterComposer,
          $$TimingSegmentsTableOrderingComposer,
          $$TimingSegmentsTableAnnotationComposer,
          $$TimingSegmentsTableCreateCompanionBuilder,
          $$TimingSegmentsTableUpdateCompanionBuilder,
          (TimingSegment, $$TimingSegmentsTableReferences),
          TimingSegment,
          PrefetchHooks Function({bool attemptId})
        > {
  $$TimingSegmentsTableTableManager(
    _$AppDatabase db,
    $TimingSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimingSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimingSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimingSegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> attemptId = const Value.absent(),
                Value<int> startedAtMicros = const Value.absent(),
                Value<int?> endedAtMicros = const Value.absent(),
                Value<int?> activeMilliseconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimingSegmentsCompanion(
                id: id,
                attemptId: attemptId,
                startedAtMicros: startedAtMicros,
                endedAtMicros: endedAtMicros,
                activeMilliseconds: activeMilliseconds,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String attemptId,
                required int startedAtMicros,
                Value<int?> endedAtMicros = const Value.absent(),
                Value<int?> activeMilliseconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimingSegmentsCompanion.insert(
                id: id,
                attemptId: attemptId,
                startedAtMicros: startedAtMicros,
                endedAtMicros: endedAtMicros,
                activeMilliseconds: activeMilliseconds,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TimingSegmentsTable, TimingSegment>(table),
                  $$TimingSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({attemptId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (attemptId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.attemptId,
                        referencedTable: $$TimingSegmentsTableReferences
                            ._attemptIdTable(db),
                        referencedColumn: $$TimingSegmentsTableReferences
                            ._attemptIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TimingSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TimingSegmentsTable,
      TimingSegment,
      $$TimingSegmentsTableFilterComposer,
      $$TimingSegmentsTableOrderingComposer,
      $$TimingSegmentsTableAnnotationComposer,
      $$TimingSegmentsTableCreateCompanionBuilder,
      $$TimingSegmentsTableUpdateCompanionBuilder,
      (TimingSegment, $$TimingSegmentsTableReferences),
      TimingSegment,
      PrefetchHooks Function({bool attemptId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PgnSourcesTableTableManager get pgnSources =>
      $$PgnSourcesTableTableManager(_db, _db.pgnSources);
  $$PgnBlocksTableTableManager get pgnBlocks =>
      $$PgnBlocksTableTableManager(_db, _db.pgnBlocks);
  $$ImportJobsTableTableManager get importJobs =>
      $$ImportJobsTableTableManager(_db, _db.importJobs);
  $$ImportDiagnosticsTableTableManager get importDiagnostics =>
      $$ImportDiagnosticsTableTableManager(_db, _db.importDiagnostics);
  $$TrainingSetsTableTableManager get trainingSets =>
      $$TrainingSetsTableTableManager(_db, _db.trainingSets);
  $$TrainingSetItemsTableTableManager get trainingSetItems =>
      $$TrainingSetItemsTableTableManager(_db, _db.trainingSetItems);
  $$CyclesTableTableManager get cycles =>
      $$CyclesTableTableManager(_db, _db.cycles);
  $$TrainingSessionsTableTableManager get trainingSessions =>
      $$TrainingSessionsTableTableManager(_db, _db.trainingSessions);
  $$PuzzleAttemptsTableTableManager get puzzleAttempts =>
      $$PuzzleAttemptsTableTableManager(_db, _db.puzzleAttempts);
  $$AttemptMovesTableTableManager get attemptMoves =>
      $$AttemptMovesTableTableManager(_db, _db.attemptMoves);
  $$TimingSegmentsTableTableManager get timingSegments =>
      $$TimingSegmentsTableTableManager(_db, _db.timingSegments);
}
