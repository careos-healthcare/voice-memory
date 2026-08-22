// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $JournalEntriesTable extends JournalEntries
    with TableInfo<$JournalEntriesTable, JournalEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<int> isArchived = GeneratedColumn<int>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transcriptMeta = const VerificationMeta(
    'transcript',
  );
  @override
  late final GeneratedColumn<String> transcript = GeneratedColumn<String>(
    'transcript',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hasVerifiedProofMeta = const VerificationMeta(
    'hasVerifiedProof',
  );
  @override
  late final GeneratedColumn<int> hasVerifiedProof = GeneratedColumn<int>(
    'has_verified_proof',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    isArchived,
    transcript,
    hasVerifiedProof,
    payloadJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<JournalEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    } else if (isInserting) {
      context.missing(_isArchivedMeta);
    }
    if (data.containsKey('transcript')) {
      context.handle(
        _transcriptMeta,
        transcript.isAcceptableOrUnknown(data['transcript']!, _transcriptMeta),
      );
    } else if (isInserting) {
      context.missing(_transcriptMeta);
    }
    if (data.containsKey('has_verified_proof')) {
      context.handle(
        _hasVerifiedProofMeta,
        hasVerifiedProof.isAcceptableOrUnknown(
          data['has_verified_proof']!,
          _hasVerifiedProofMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hasVerifiedProofMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JournalEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_archived'],
      )!,
      transcript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript'],
      )!,
      hasVerifiedProof: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}has_verified_proof'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
    );
  }

  @override
  $JournalEntriesTable createAlias(String alias) {
    return $JournalEntriesTable(attachedDatabase, alias);
  }
}

class JournalEntryRow extends DataClass implements Insertable<JournalEntryRow> {
  final String id;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final int isArchived;
  final String transcript;
  final int hasVerifiedProof;
  final String? payloadJson;
  const JournalEntryRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.isArchived,
    required this.transcript,
    required this.hasVerifiedProof,
    this.payloadJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['is_archived'] = Variable<int>(isArchived);
    map['transcript'] = Variable<String>(transcript);
    map['has_verified_proof'] = Variable<int>(hasVerifiedProof);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    return map;
  }

  JournalEntriesCompanion toCompanion(bool nullToAbsent) {
    return JournalEntriesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      isArchived: Value(isArchived),
      transcript: Value(transcript),
      hasVerifiedProof: Value(hasVerifiedProof),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
    );
  }

  factory JournalEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalEntryRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      isArchived: serializer.fromJson<int>(json['isArchived']),
      transcript: serializer.fromJson<String>(json['transcript']),
      hasVerifiedProof: serializer.fromJson<int>(json['hasVerifiedProof']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'isArchived': serializer.toJson<int>(isArchived),
      'transcript': serializer.toJson<String>(transcript),
      'hasVerifiedProof': serializer.toJson<int>(hasVerifiedProof),
      'payloadJson': serializer.toJson<String?>(payloadJson),
    };
  }

  JournalEntryRow copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    int? isArchived,
    String? transcript,
    int? hasVerifiedProof,
    Value<String?> payloadJson = const Value.absent(),
  }) => JournalEntryRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    isArchived: isArchived ?? this.isArchived,
    transcript: transcript ?? this.transcript,
    hasVerifiedProof: hasVerifiedProof ?? this.hasVerifiedProof,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
  );
  JournalEntryRow copyWithCompanion(JournalEntriesCompanion data) {
    return JournalEntryRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      transcript: data.transcript.present
          ? data.transcript.value
          : this.transcript,
      hasVerifiedProof: data.hasVerifiedProof.present
          ? data.hasVerifiedProof.value
          : this.hasVerifiedProof,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntryRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isArchived: $isArchived, ')
          ..write('transcript: $transcript, ')
          ..write('hasVerifiedProof: $hasVerifiedProof, ')
          ..write('payloadJson: $payloadJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    isArchived,
    transcript,
    hasVerifiedProof,
    payloadJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalEntryRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.isArchived == this.isArchived &&
          other.transcript == this.transcript &&
          other.hasVerifiedProof == this.hasVerifiedProof &&
          other.payloadJson == this.payloadJson);
}

class JournalEntriesCompanion extends UpdateCompanion<JournalEntryRow> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> isArchived;
  final Value<String> transcript;
  final Value<int> hasVerifiedProof;
  final Value<String?> payloadJson;
  final Value<int> rowid;
  const JournalEntriesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.transcript = const Value.absent(),
    this.hasVerifiedProof = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalEntriesCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required int isArchived,
    required String transcript,
    required int hasVerifiedProof,
    this.payloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       isArchived = Value(isArchived),
       transcript = Value(transcript),
       hasVerifiedProof = Value(hasVerifiedProof);
  static Insertable<JournalEntryRow> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? isArchived,
    Expression<String>? transcript,
    Expression<int>? hasVerifiedProof,
    Expression<String>? payloadJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (isArchived != null) 'is_archived': isArchived,
      if (transcript != null) 'transcript': transcript,
      if (hasVerifiedProof != null) 'has_verified_proof': hasVerifiedProof,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalEntriesCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? isArchived,
    Value<String>? transcript,
    Value<int>? hasVerifiedProof,
    Value<String?>? payloadJson,
    Value<int>? rowid,
  }) {
    return JournalEntriesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isArchived: isArchived ?? this.isArchived,
      transcript: transcript ?? this.transcript,
      hasVerifiedProof: hasVerifiedProof ?? this.hasVerifiedProof,
      payloadJson: payloadJson ?? this.payloadJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<int>(isArchived.value);
    }
    if (transcript.present) {
      map['transcript'] = Variable<String>(transcript.value);
    }
    if (hasVerifiedProof.present) {
      map['has_verified_proof'] = Variable<int>(hasVerifiedProof.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntriesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isArchived: $isArchived, ')
          ..write('transcript: $transcript, ')
          ..write('hasVerifiedProof: $hasVerifiedProof, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxEntriesTable extends SyncOutboxEntries
    with TableInfo<$SyncOutboxEntriesTable, SyncOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _outboxIdMeta = const VerificationMeta(
    'outboxId',
  );
  @override
  late final GeneratedColumn<String> outboxId = GeneratedColumn<String>(
    'outbox_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blobIdMeta = const VerificationMeta('blobId');
  @override
  late final GeneratedColumn<String> blobId = GeneratedColumn<String>(
    'blob_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blobTypeMeta = const VerificationMeta(
    'blobType',
  );
  @override
  late final GeneratedColumn<String> blobType = GeneratedColumn<String>(
    'blob_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<int> nextRetryAt = GeneratedColumn<int>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    outboxId,
    blobId,
    blobType,
    payloadJson,
    status,
    attemptCount,
    lastError,
    createdAt,
    updatedAt,
    nextRetryAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('outbox_id')) {
      context.handle(
        _outboxIdMeta,
        outboxId.isAcceptableOrUnknown(data['outbox_id']!, _outboxIdMeta),
      );
    } else if (isInserting) {
      context.missing(_outboxIdMeta);
    }
    if (data.containsKey('blob_id')) {
      context.handle(
        _blobIdMeta,
        blobId.isAcceptableOrUnknown(data['blob_id']!, _blobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blobIdMeta);
    }
    if (data.containsKey('blob_type')) {
      context.handle(
        _blobTypeMeta,
        blobType.isAcceptableOrUnknown(data['blob_type']!, _blobTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_blobTypeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attemptCountMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {outboxId};
  @override
  SyncOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxRow(
      outboxId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outbox_id'],
      )!,
      blobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_id'],
      )!,
      blobType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_type'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_retry_at'],
      ),
    );
  }

  @override
  $SyncOutboxEntriesTable createAlias(String alias) {
    return $SyncOutboxEntriesTable(attachedDatabase, alias);
  }
}

class SyncOutboxRow extends DataClass implements Insertable<SyncOutboxRow> {
  final String outboxId;
  final String blobId;
  final String blobType;
  final String payloadJson;
  final String status;
  final int attemptCount;
  final String? lastError;
  final int createdAt;
  final int updatedAt;
  final int? nextRetryAt;
  const SyncOutboxRow({
    required this.outboxId,
    required this.blobId,
    required this.blobType,
    required this.payloadJson,
    required this.status,
    required this.attemptCount,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
    this.nextRetryAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['outbox_id'] = Variable<String>(outboxId);
    map['blob_id'] = Variable<String>(blobId);
    map['blob_type'] = Variable<String>(blobType);
    map['payload_json'] = Variable<String>(payloadJson);
    map['status'] = Variable<String>(status);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<int>(nextRetryAt);
    }
    return map;
  }

  SyncOutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxEntriesCompanion(
      outboxId: Value(outboxId),
      blobId: Value(blobId),
      blobType: Value(blobType),
      payloadJson: Value(payloadJson),
      status: Value(status),
      attemptCount: Value(attemptCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
    );
  }

  factory SyncOutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxRow(
      outboxId: serializer.fromJson<String>(json['outboxId']),
      blobId: serializer.fromJson<String>(json['blobId']),
      blobType: serializer.fromJson<String>(json['blobType']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      status: serializer.fromJson<String>(json['status']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      nextRetryAt: serializer.fromJson<int?>(json['nextRetryAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'outboxId': serializer.toJson<String>(outboxId),
      'blobId': serializer.toJson<String>(blobId),
      'blobType': serializer.toJson<String>(blobType),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'status': serializer.toJson<String>(status),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'nextRetryAt': serializer.toJson<int?>(nextRetryAt),
    };
  }

  SyncOutboxRow copyWith({
    String? outboxId,
    String? blobId,
    String? blobType,
    String? payloadJson,
    String? status,
    int? attemptCount,
    Value<String?> lastError = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> nextRetryAt = const Value.absent(),
  }) => SyncOutboxRow(
    outboxId: outboxId ?? this.outboxId,
    blobId: blobId ?? this.blobId,
    blobType: blobType ?? this.blobType,
    payloadJson: payloadJson ?? this.payloadJson,
    status: status ?? this.status,
    attemptCount: attemptCount ?? this.attemptCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
  );
  SyncOutboxRow copyWithCompanion(SyncOutboxEntriesCompanion data) {
    return SyncOutboxRow(
      outboxId: data.outboxId.present ? data.outboxId.value : this.outboxId,
      blobId: data.blobId.present ? data.blobId.value : this.blobId,
      blobType: data.blobType.present ? data.blobType.value : this.blobType,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      status: data.status.present ? data.status.value : this.status,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxRow(')
          ..write('outboxId: $outboxId, ')
          ..write('blobId: $blobId, ')
          ..write('blobType: $blobType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('nextRetryAt: $nextRetryAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    outboxId,
    blobId,
    blobType,
    payloadJson,
    status,
    attemptCount,
    lastError,
    createdAt,
    updatedAt,
    nextRetryAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxRow &&
          other.outboxId == this.outboxId &&
          other.blobId == this.blobId &&
          other.blobType == this.blobType &&
          other.payloadJson == this.payloadJson &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.nextRetryAt == this.nextRetryAt);
}

class SyncOutboxEntriesCompanion extends UpdateCompanion<SyncOutboxRow> {
  final Value<String> outboxId;
  final Value<String> blobId;
  final Value<String> blobType;
  final Value<String> payloadJson;
  final Value<String> status;
  final Value<int> attemptCount;
  final Value<String?> lastError;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> nextRetryAt;
  final Value<int> rowid;
  const SyncOutboxEntriesCompanion({
    this.outboxId = const Value.absent(),
    this.blobId = const Value.absent(),
    this.blobType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxEntriesCompanion.insert({
    required String outboxId,
    required String blobId,
    required String blobType,
    required String payloadJson,
    required String status,
    required int attemptCount,
    this.lastError = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.nextRetryAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : outboxId = Value(outboxId),
       blobId = Value(blobId),
       blobType = Value(blobType),
       payloadJson = Value(payloadJson),
       status = Value(status),
       attemptCount = Value(attemptCount),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SyncOutboxRow> custom({
    Expression<String>? outboxId,
    Expression<String>? blobId,
    Expression<String>? blobType,
    Expression<String>? payloadJson,
    Expression<String>? status,
    Expression<int>? attemptCount,
    Expression<String>? lastError,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? nextRetryAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (outboxId != null) 'outbox_id': outboxId,
      if (blobId != null) 'blob_id': blobId,
      if (blobType != null) 'blob_type': blobType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxEntriesCompanion copyWith({
    Value<String>? outboxId,
    Value<String>? blobId,
    Value<String>? blobType,
    Value<String>? payloadJson,
    Value<String>? status,
    Value<int>? attemptCount,
    Value<String?>? lastError,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? nextRetryAt,
    Value<int>? rowid,
  }) {
    return SyncOutboxEntriesCompanion(
      outboxId: outboxId ?? this.outboxId,
      blobId: blobId ?? this.blobId,
      blobType: blobType ?? this.blobType,
      payloadJson: payloadJson ?? this.payloadJson,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (outboxId.present) {
      map['outbox_id'] = Variable<String>(outboxId.value);
    }
    if (blobId.present) {
      map['blob_id'] = Variable<String>(blobId.value);
    }
    if (blobType.present) {
      map['blob_type'] = Variable<String>(blobType.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<int>(nextRetryAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxEntriesCompanion(')
          ..write('outboxId: $outboxId, ')
          ..write('blobId: $blobId, ')
          ..write('blobType: $blobType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReflectionEmbeddingsTable extends ReflectionEmbeddings
    with TableInfo<$ReflectionEmbeddingsTable, ReflectionEmbeddingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReflectionEmbeddingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _embeddingMeta = const VerificationMeta(
    'embedding',
  );
  @override
  late final GeneratedColumn<Uint8List> embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dimensionsMeta = const VerificationMeta(
    'dimensions',
  );
  @override
  late final GeneratedColumn<int> dimensions = GeneratedColumn<int>(
    'dimensions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entryId,
    embedding,
    dimensions,
    contentHash,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reflection_embeddings';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReflectionEmbeddingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('embedding')) {
      context.handle(
        _embeddingMeta,
        embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta),
      );
    } else if (isInserting) {
      context.missing(_embeddingMeta);
    }
    if (data.containsKey('dimensions')) {
      context.handle(
        _dimensionsMeta,
        dimensions.isAcceptableOrUnknown(data['dimensions']!, _dimensionsMeta),
      );
    } else if (isInserting) {
      context.missing(_dimensionsMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId};
  @override
  ReflectionEmbeddingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReflectionEmbeddingRow(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      embedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}embedding'],
      )!,
      dimensions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dimensions'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReflectionEmbeddingsTable createAlias(String alias) {
    return $ReflectionEmbeddingsTable(attachedDatabase, alias);
  }
}

class ReflectionEmbeddingRow extends DataClass
    implements Insertable<ReflectionEmbeddingRow> {
  final String entryId;
  final Uint8List embedding;
  final int dimensions;
  final String contentHash;
  final int updatedAt;
  const ReflectionEmbeddingRow({
    required this.entryId,
    required this.embedding,
    required this.dimensions,
    required this.contentHash,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['embedding'] = Variable<Uint8List>(embedding);
    map['dimensions'] = Variable<int>(dimensions);
    map['content_hash'] = Variable<String>(contentHash);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ReflectionEmbeddingsCompanion toCompanion(bool nullToAbsent) {
    return ReflectionEmbeddingsCompanion(
      entryId: Value(entryId),
      embedding: Value(embedding),
      dimensions: Value(dimensions),
      contentHash: Value(contentHash),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReflectionEmbeddingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReflectionEmbeddingRow(
      entryId: serializer.fromJson<String>(json['entryId']),
      embedding: serializer.fromJson<Uint8List>(json['embedding']),
      dimensions: serializer.fromJson<int>(json['dimensions']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'embedding': serializer.toJson<Uint8List>(embedding),
      'dimensions': serializer.toJson<int>(dimensions),
      'contentHash': serializer.toJson<String>(contentHash),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ReflectionEmbeddingRow copyWith({
    String? entryId,
    Uint8List? embedding,
    int? dimensions,
    String? contentHash,
    int? updatedAt,
  }) => ReflectionEmbeddingRow(
    entryId: entryId ?? this.entryId,
    embedding: embedding ?? this.embedding,
    dimensions: dimensions ?? this.dimensions,
    contentHash: contentHash ?? this.contentHash,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReflectionEmbeddingRow copyWithCompanion(ReflectionEmbeddingsCompanion data) {
    return ReflectionEmbeddingRow(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      dimensions: data.dimensions.present
          ? data.dimensions.value
          : this.dimensions,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReflectionEmbeddingRow(')
          ..write('entryId: $entryId, ')
          ..write('embedding: $embedding, ')
          ..write('dimensions: $dimensions, ')
          ..write('contentHash: $contentHash, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    entryId,
    $driftBlobEquality.hash(embedding),
    dimensions,
    contentHash,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReflectionEmbeddingRow &&
          other.entryId == this.entryId &&
          $driftBlobEquality.equals(other.embedding, this.embedding) &&
          other.dimensions == this.dimensions &&
          other.contentHash == this.contentHash &&
          other.updatedAt == this.updatedAt);
}

class ReflectionEmbeddingsCompanion
    extends UpdateCompanion<ReflectionEmbeddingRow> {
  final Value<String> entryId;
  final Value<Uint8List> embedding;
  final Value<int> dimensions;
  final Value<String> contentHash;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ReflectionEmbeddingsCompanion({
    this.entryId = const Value.absent(),
    this.embedding = const Value.absent(),
    this.dimensions = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReflectionEmbeddingsCompanion.insert({
    required String entryId,
    required Uint8List embedding,
    required int dimensions,
    required String contentHash,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       embedding = Value(embedding),
       dimensions = Value(dimensions),
       contentHash = Value(contentHash),
       updatedAt = Value(updatedAt);
  static Insertable<ReflectionEmbeddingRow> custom({
    Expression<String>? entryId,
    Expression<Uint8List>? embedding,
    Expression<int>? dimensions,
    Expression<String>? contentHash,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (embedding != null) 'embedding': embedding,
      if (dimensions != null) 'dimensions': dimensions,
      if (contentHash != null) 'content_hash': contentHash,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReflectionEmbeddingsCompanion copyWith({
    Value<String>? entryId,
    Value<Uint8List>? embedding,
    Value<int>? dimensions,
    Value<String>? contentHash,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReflectionEmbeddingsCompanion(
      entryId: entryId ?? this.entryId,
      embedding: embedding ?? this.embedding,
      dimensions: dimensions ?? this.dimensions,
      contentHash: contentHash ?? this.contentHash,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(embedding.value);
    }
    if (dimensions.present) {
      map['dimensions'] = Variable<int>(dimensions.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReflectionEmbeddingsCompanion(')
          ..write('entryId: $entryId, ')
          ..write('embedding: $embedding, ')
          ..write('dimensions: $dimensions, ')
          ..write('contentHash: $contentHash, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReflectionGraphNodesTable extends ReflectionGraphNodes
    with TableInfo<$ReflectionGraphNodesTable, ReflectionGraphNodeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReflectionGraphNodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES journal_entries (id)',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entryId,
    kind,
    label,
    payloadJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reflection_graph_nodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReflectionGraphNodeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReflectionGraphNodeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReflectionGraphNodeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReflectionGraphNodesTable createAlias(String alias) {
    return $ReflectionGraphNodesTable(attachedDatabase, alias);
  }
}

class ReflectionGraphNodeRow extends DataClass
    implements Insertable<ReflectionGraphNodeRow> {
  final String id;
  final String entryId;
  final String kind;
  final String label;
  final String? payloadJson;
  final int updatedAt;
  const ReflectionGraphNodeRow({
    required this.id,
    required this.entryId,
    required this.kind,
    required this.label,
    this.payloadJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entry_id'] = Variable<String>(entryId);
    map['kind'] = Variable<String>(kind);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ReflectionGraphNodesCompanion toCompanion(bool nullToAbsent) {
    return ReflectionGraphNodesCompanion(
      id: Value(id),
      entryId: Value(entryId),
      kind: Value(kind),
      label: Value(label),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReflectionGraphNodeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReflectionGraphNodeRow(
      id: serializer.fromJson<String>(json['id']),
      entryId: serializer.fromJson<String>(json['entryId']),
      kind: serializer.fromJson<String>(json['kind']),
      label: serializer.fromJson<String>(json['label']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entryId': serializer.toJson<String>(entryId),
      'kind': serializer.toJson<String>(kind),
      'label': serializer.toJson<String>(label),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ReflectionGraphNodeRow copyWith({
    String? id,
    String? entryId,
    String? kind,
    String? label,
    Value<String?> payloadJson = const Value.absent(),
    int? updatedAt,
  }) => ReflectionGraphNodeRow(
    id: id ?? this.id,
    entryId: entryId ?? this.entryId,
    kind: kind ?? this.kind,
    label: label ?? this.label,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReflectionGraphNodeRow copyWithCompanion(ReflectionGraphNodesCompanion data) {
    return ReflectionGraphNodeRow(
      id: data.id.present ? data.id.value : this.id,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      kind: data.kind.present ? data.kind.value : this.kind,
      label: data.label.present ? data.label.value : this.label,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReflectionGraphNodeRow(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, entryId, kind, label, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReflectionGraphNodeRow &&
          other.id == this.id &&
          other.entryId == this.entryId &&
          other.kind == this.kind &&
          other.label == this.label &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class ReflectionGraphNodesCompanion
    extends UpdateCompanion<ReflectionGraphNodeRow> {
  final Value<String> id;
  final Value<String> entryId;
  final Value<String> kind;
  final Value<String> label;
  final Value<String?> payloadJson;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ReflectionGraphNodesCompanion({
    this.id = const Value.absent(),
    this.entryId = const Value.absent(),
    this.kind = const Value.absent(),
    this.label = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReflectionGraphNodesCompanion.insert({
    required String id,
    required String entryId,
    required String kind,
    required String label,
    this.payloadJson = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entryId = Value(entryId),
       kind = Value(kind),
       label = Value(label),
       updatedAt = Value(updatedAt);
  static Insertable<ReflectionGraphNodeRow> custom({
    Expression<String>? id,
    Expression<String>? entryId,
    Expression<String>? kind,
    Expression<String>? label,
    Expression<String>? payloadJson,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entryId != null) 'entry_id': entryId,
      if (kind != null) 'kind': kind,
      if (label != null) 'label': label,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReflectionGraphNodesCompanion copyWith({
    Value<String>? id,
    Value<String>? entryId,
    Value<String>? kind,
    Value<String>? label,
    Value<String?>? payloadJson,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReflectionGraphNodesCompanion(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReflectionGraphNodesCompanion(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSqliteMetaTable extends AppSqliteMeta
    with TableInfo<$AppSqliteMetaTable, AppSqliteMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSqliteMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_sqlite_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSqliteMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSqliteMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSqliteMetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSqliteMetaTable createAlias(String alias) {
    return $AppSqliteMetaTable(attachedDatabase, alias);
  }
}

class AppSqliteMetaRow extends DataClass
    implements Insertable<AppSqliteMetaRow> {
  final String key;
  final String value;
  const AppSqliteMetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSqliteMetaCompanion toCompanion(bool nullToAbsent) {
    return AppSqliteMetaCompanion(key: Value(key), value: Value(value));
  }

  factory AppSqliteMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSqliteMetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSqliteMetaRow copyWith({String? key, String? value}) =>
      AppSqliteMetaRow(key: key ?? this.key, value: value ?? this.value);
  AppSqliteMetaRow copyWithCompanion(AppSqliteMetaCompanion data) {
    return AppSqliteMetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSqliteMetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSqliteMetaRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSqliteMetaCompanion extends UpdateCompanion<AppSqliteMetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSqliteMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSqliteMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSqliteMetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSqliteMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSqliteMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSqliteMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntryEdgesTable extends EntryEdges
    with TableInfo<$EntryEdgesTable, EntryEdgeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntryEdgesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceEntryIdMeta = const VerificationMeta(
    'sourceEntryId',
  );
  @override
  late final GeneratedColumn<String> sourceEntryId = GeneratedColumn<String>(
    'source_entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetEntryIdMeta = const VerificationMeta(
    'targetEntryId',
  );
  @override
  late final GeneratedColumn<String> targetEntryId = GeneratedColumn<String>(
    'target_entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relationMeta = const VerificationMeta(
    'relation',
  );
  @override
  late final GeneratedColumn<String> relation = GeneratedColumn<String>(
    'relation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('semantic_similarity'),
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceEntryId,
    targetEntryId,
    relation,
    weight,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entry_edges';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryEdgeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_entry_id')) {
      context.handle(
        _sourceEntryIdMeta,
        sourceEntryId.isAcceptableOrUnknown(
          data['source_entry_id']!,
          _sourceEntryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceEntryIdMeta);
    }
    if (data.containsKey('target_entry_id')) {
      context.handle(
        _targetEntryIdMeta,
        targetEntryId.isAcceptableOrUnknown(
          data['target_entry_id']!,
          _targetEntryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetEntryIdMeta);
    }
    if (data.containsKey('relation')) {
      context.handle(
        _relationMeta,
        relation.isAcceptableOrUnknown(data['relation']!, _relationMeta),
      );
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    } else if (isInserting) {
      context.missing(_weightMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceEntryId, targetEntryId};
  @override
  EntryEdgeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryEdgeRow(
      sourceEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_entry_id'],
      )!,
      targetEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_entry_id'],
      )!,
      relation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relation'],
      )!,
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EntryEdgesTable createAlias(String alias) {
    return $EntryEdgesTable(attachedDatabase, alias);
  }
}

class EntryEdgeRow extends DataClass implements Insertable<EntryEdgeRow> {
  final String sourceEntryId;
  final String targetEntryId;
  final String relation;
  final double weight;
  final int createdAt;
  const EntryEdgeRow({
    required this.sourceEntryId,
    required this.targetEntryId,
    required this.relation,
    required this.weight,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_entry_id'] = Variable<String>(sourceEntryId);
    map['target_entry_id'] = Variable<String>(targetEntryId);
    map['relation'] = Variable<String>(relation);
    map['weight'] = Variable<double>(weight);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  EntryEdgesCompanion toCompanion(bool nullToAbsent) {
    return EntryEdgesCompanion(
      sourceEntryId: Value(sourceEntryId),
      targetEntryId: Value(targetEntryId),
      relation: Value(relation),
      weight: Value(weight),
      createdAt: Value(createdAt),
    );
  }

  factory EntryEdgeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryEdgeRow(
      sourceEntryId: serializer.fromJson<String>(json['sourceEntryId']),
      targetEntryId: serializer.fromJson<String>(json['targetEntryId']),
      relation: serializer.fromJson<String>(json['relation']),
      weight: serializer.fromJson<double>(json['weight']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceEntryId': serializer.toJson<String>(sourceEntryId),
      'targetEntryId': serializer.toJson<String>(targetEntryId),
      'relation': serializer.toJson<String>(relation),
      'weight': serializer.toJson<double>(weight),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  EntryEdgeRow copyWith({
    String? sourceEntryId,
    String? targetEntryId,
    String? relation,
    double? weight,
    int? createdAt,
  }) => EntryEdgeRow(
    sourceEntryId: sourceEntryId ?? this.sourceEntryId,
    targetEntryId: targetEntryId ?? this.targetEntryId,
    relation: relation ?? this.relation,
    weight: weight ?? this.weight,
    createdAt: createdAt ?? this.createdAt,
  );
  EntryEdgeRow copyWithCompanion(EntryEdgesCompanion data) {
    return EntryEdgeRow(
      sourceEntryId: data.sourceEntryId.present
          ? data.sourceEntryId.value
          : this.sourceEntryId,
      targetEntryId: data.targetEntryId.present
          ? data.targetEntryId.value
          : this.targetEntryId,
      relation: data.relation.present ? data.relation.value : this.relation,
      weight: data.weight.present ? data.weight.value : this.weight,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryEdgeRow(')
          ..write('sourceEntryId: $sourceEntryId, ')
          ..write('targetEntryId: $targetEntryId, ')
          ..write('relation: $relation, ')
          ..write('weight: $weight, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sourceEntryId, targetEntryId, relation, weight, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryEdgeRow &&
          other.sourceEntryId == this.sourceEntryId &&
          other.targetEntryId == this.targetEntryId &&
          other.relation == this.relation &&
          other.weight == this.weight &&
          other.createdAt == this.createdAt);
}

class EntryEdgesCompanion extends UpdateCompanion<EntryEdgeRow> {
  final Value<String> sourceEntryId;
  final Value<String> targetEntryId;
  final Value<String> relation;
  final Value<double> weight;
  final Value<int> createdAt;
  final Value<int> rowid;
  const EntryEdgesCompanion({
    this.sourceEntryId = const Value.absent(),
    this.targetEntryId = const Value.absent(),
    this.relation = const Value.absent(),
    this.weight = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntryEdgesCompanion.insert({
    required String sourceEntryId,
    required String targetEntryId,
    this.relation = const Value.absent(),
    required double weight,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : sourceEntryId = Value(sourceEntryId),
       targetEntryId = Value(targetEntryId),
       weight = Value(weight),
       createdAt = Value(createdAt);
  static Insertable<EntryEdgeRow> custom({
    Expression<String>? sourceEntryId,
    Expression<String>? targetEntryId,
    Expression<String>? relation,
    Expression<double>? weight,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceEntryId != null) 'source_entry_id': sourceEntryId,
      if (targetEntryId != null) 'target_entry_id': targetEntryId,
      if (relation != null) 'relation': relation,
      if (weight != null) 'weight': weight,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntryEdgesCompanion copyWith({
    Value<String>? sourceEntryId,
    Value<String>? targetEntryId,
    Value<String>? relation,
    Value<double>? weight,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return EntryEdgesCompanion(
      sourceEntryId: sourceEntryId ?? this.sourceEntryId,
      targetEntryId: targetEntryId ?? this.targetEntryId,
      relation: relation ?? this.relation,
      weight: weight ?? this.weight,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceEntryId.present) {
      map['source_entry_id'] = Variable<String>(sourceEntryId.value);
    }
    if (targetEntryId.present) {
      map['target_entry_id'] = Variable<String>(targetEntryId.value);
    }
    if (relation.present) {
      map['relation'] = Variable<String>(relation.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntryEdgesCompanion(')
          ..write('sourceEntryId: $sourceEntryId, ')
          ..write('targetEntryId: $targetEntryId, ')
          ..write('relation: $relation, ')
          ..write('weight: $weight, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FactLedgerEntriesTable extends FactLedgerEntries
    with TableInfo<$FactLedgerEntriesTable, FactLedgerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FactLedgerEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceEntryIdMeta = const VerificationMeta(
    'sourceEntryId',
  );
  @override
  late final GeneratedColumn<String> sourceEntryId = GeneratedColumn<String>(
    'source_entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _factTypeMeta = const VerificationMeta(
    'factType',
  );
  @override
  late final GeneratedColumn<String> factType = GeneratedColumn<String>(
    'fact_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivePackIdMeta = const VerificationMeta(
    'archivePackId',
  );
  @override
  late final GeneratedColumn<String> archivePackId = GeneratedColumn<String>(
    'archive_pack_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archiveThreadIdMeta = const VerificationMeta(
    'archiveThreadId',
  );
  @override
  late final GeneratedColumn<String> archiveThreadId = GeneratedColumn<String>(
    'archive_thread_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _collectionIdsJsonMeta = const VerificationMeta(
    'collectionIdsJson',
  );
  @override
  late final GeneratedColumn<String> collectionIdsJson =
      GeneratedColumn<String>(
        'collection_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<int> isPinned = GeneratedColumn<int>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _preserveOriginalMeta = const VerificationMeta(
    'preserveOriginal',
  );
  @override
  late final GeneratedColumn<int> preserveOriginal = GeneratedColumn<int>(
    'preserve_original',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceEntryId,
    label,
    value,
    note,
    createdAt,
    updatedAt,
    factType,
    archivePackId,
    archiveThreadId,
    collectionIdsJson,
    isPinned,
    preserveOriginal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fact_ledger';
  @override
  VerificationContext validateIntegrity(
    Insertable<FactLedgerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_entry_id')) {
      context.handle(
        _sourceEntryIdMeta,
        sourceEntryId.isAcceptableOrUnknown(
          data['source_entry_id']!,
          _sourceEntryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceEntryIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('fact_type')) {
      context.handle(
        _factTypeMeta,
        factType.isAcceptableOrUnknown(data['fact_type']!, _factTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_factTypeMeta);
    }
    if (data.containsKey('archive_pack_id')) {
      context.handle(
        _archivePackIdMeta,
        archivePackId.isAcceptableOrUnknown(
          data['archive_pack_id']!,
          _archivePackIdMeta,
        ),
      );
    }
    if (data.containsKey('archive_thread_id')) {
      context.handle(
        _archiveThreadIdMeta,
        archiveThreadId.isAcceptableOrUnknown(
          data['archive_thread_id']!,
          _archiveThreadIdMeta,
        ),
      );
    }
    if (data.containsKey('collection_ids_json')) {
      context.handle(
        _collectionIdsJsonMeta,
        collectionIdsJson.isAcceptableOrUnknown(
          data['collection_ids_json']!,
          _collectionIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('preserve_original')) {
      context.handle(
        _preserveOriginalMeta,
        preserveOriginal.isAcceptableOrUnknown(
          data['preserve_original']!,
          _preserveOriginalMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FactLedgerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FactLedgerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_entry_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      factType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fact_type'],
      )!,
      archivePackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archive_pack_id'],
      ),
      archiveThreadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archive_thread_id'],
      ),
      collectionIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_ids_json'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_pinned'],
      )!,
      preserveOriginal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}preserve_original'],
      )!,
    );
  }

  @override
  $FactLedgerEntriesTable createAlias(String alias) {
    return $FactLedgerEntriesTable(attachedDatabase, alias);
  }
}

class FactLedgerRow extends DataClass implements Insertable<FactLedgerRow> {
  final String id;
  final String sourceEntryId;
  final String label;
  final String value;
  final String note;
  final int createdAt;
  final int updatedAt;
  final String factType;
  final String? archivePackId;
  final String? archiveThreadId;
  final String collectionIdsJson;
  final int isPinned;
  final int preserveOriginal;
  const FactLedgerRow({
    required this.id,
    required this.sourceEntryId,
    required this.label,
    required this.value,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.factType,
    this.archivePackId,
    this.archiveThreadId,
    required this.collectionIdsJson,
    required this.isPinned,
    required this.preserveOriginal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_entry_id'] = Variable<String>(sourceEntryId);
    map['label'] = Variable<String>(label);
    map['value'] = Variable<String>(value);
    map['note'] = Variable<String>(note);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['fact_type'] = Variable<String>(factType);
    if (!nullToAbsent || archivePackId != null) {
      map['archive_pack_id'] = Variable<String>(archivePackId);
    }
    if (!nullToAbsent || archiveThreadId != null) {
      map['archive_thread_id'] = Variable<String>(archiveThreadId);
    }
    map['collection_ids_json'] = Variable<String>(collectionIdsJson);
    map['is_pinned'] = Variable<int>(isPinned);
    map['preserve_original'] = Variable<int>(preserveOriginal);
    return map;
  }

  FactLedgerEntriesCompanion toCompanion(bool nullToAbsent) {
    return FactLedgerEntriesCompanion(
      id: Value(id),
      sourceEntryId: Value(sourceEntryId),
      label: Value(label),
      value: Value(value),
      note: Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      factType: Value(factType),
      archivePackId: archivePackId == null && nullToAbsent
          ? const Value.absent()
          : Value(archivePackId),
      archiveThreadId: archiveThreadId == null && nullToAbsent
          ? const Value.absent()
          : Value(archiveThreadId),
      collectionIdsJson: Value(collectionIdsJson),
      isPinned: Value(isPinned),
      preserveOriginal: Value(preserveOriginal),
    );
  }

  factory FactLedgerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FactLedgerRow(
      id: serializer.fromJson<String>(json['id']),
      sourceEntryId: serializer.fromJson<String>(json['sourceEntryId']),
      label: serializer.fromJson<String>(json['label']),
      value: serializer.fromJson<String>(json['value']),
      note: serializer.fromJson<String>(json['note']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      factType: serializer.fromJson<String>(json['factType']),
      archivePackId: serializer.fromJson<String?>(json['archivePackId']),
      archiveThreadId: serializer.fromJson<String?>(json['archiveThreadId']),
      collectionIdsJson: serializer.fromJson<String>(json['collectionIdsJson']),
      isPinned: serializer.fromJson<int>(json['isPinned']),
      preserveOriginal: serializer.fromJson<int>(json['preserveOriginal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceEntryId': serializer.toJson<String>(sourceEntryId),
      'label': serializer.toJson<String>(label),
      'value': serializer.toJson<String>(value),
      'note': serializer.toJson<String>(note),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'factType': serializer.toJson<String>(factType),
      'archivePackId': serializer.toJson<String?>(archivePackId),
      'archiveThreadId': serializer.toJson<String?>(archiveThreadId),
      'collectionIdsJson': serializer.toJson<String>(collectionIdsJson),
      'isPinned': serializer.toJson<int>(isPinned),
      'preserveOriginal': serializer.toJson<int>(preserveOriginal),
    };
  }

  FactLedgerRow copyWith({
    String? id,
    String? sourceEntryId,
    String? label,
    String? value,
    String? note,
    int? createdAt,
    int? updatedAt,
    String? factType,
    Value<String?> archivePackId = const Value.absent(),
    Value<String?> archiveThreadId = const Value.absent(),
    String? collectionIdsJson,
    int? isPinned,
    int? preserveOriginal,
  }) => FactLedgerRow(
    id: id ?? this.id,
    sourceEntryId: sourceEntryId ?? this.sourceEntryId,
    label: label ?? this.label,
    value: value ?? this.value,
    note: note ?? this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    factType: factType ?? this.factType,
    archivePackId: archivePackId.present
        ? archivePackId.value
        : this.archivePackId,
    archiveThreadId: archiveThreadId.present
        ? archiveThreadId.value
        : this.archiveThreadId,
    collectionIdsJson: collectionIdsJson ?? this.collectionIdsJson,
    isPinned: isPinned ?? this.isPinned,
    preserveOriginal: preserveOriginal ?? this.preserveOriginal,
  );
  FactLedgerRow copyWithCompanion(FactLedgerEntriesCompanion data) {
    return FactLedgerRow(
      id: data.id.present ? data.id.value : this.id,
      sourceEntryId: data.sourceEntryId.present
          ? data.sourceEntryId.value
          : this.sourceEntryId,
      label: data.label.present ? data.label.value : this.label,
      value: data.value.present ? data.value.value : this.value,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      factType: data.factType.present ? data.factType.value : this.factType,
      archivePackId: data.archivePackId.present
          ? data.archivePackId.value
          : this.archivePackId,
      archiveThreadId: data.archiveThreadId.present
          ? data.archiveThreadId.value
          : this.archiveThreadId,
      collectionIdsJson: data.collectionIdsJson.present
          ? data.collectionIdsJson.value
          : this.collectionIdsJson,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      preserveOriginal: data.preserveOriginal.present
          ? data.preserveOriginal.value
          : this.preserveOriginal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FactLedgerRow(')
          ..write('id: $id, ')
          ..write('sourceEntryId: $sourceEntryId, ')
          ..write('label: $label, ')
          ..write('value: $value, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('factType: $factType, ')
          ..write('archivePackId: $archivePackId, ')
          ..write('archiveThreadId: $archiveThreadId, ')
          ..write('collectionIdsJson: $collectionIdsJson, ')
          ..write('isPinned: $isPinned, ')
          ..write('preserveOriginal: $preserveOriginal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceEntryId,
    label,
    value,
    note,
    createdAt,
    updatedAt,
    factType,
    archivePackId,
    archiveThreadId,
    collectionIdsJson,
    isPinned,
    preserveOriginal,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FactLedgerRow &&
          other.id == this.id &&
          other.sourceEntryId == this.sourceEntryId &&
          other.label == this.label &&
          other.value == this.value &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.factType == this.factType &&
          other.archivePackId == this.archivePackId &&
          other.archiveThreadId == this.archiveThreadId &&
          other.collectionIdsJson == this.collectionIdsJson &&
          other.isPinned == this.isPinned &&
          other.preserveOriginal == this.preserveOriginal);
}

class FactLedgerEntriesCompanion extends UpdateCompanion<FactLedgerRow> {
  final Value<String> id;
  final Value<String> sourceEntryId;
  final Value<String> label;
  final Value<String> value;
  final Value<String> note;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> factType;
  final Value<String?> archivePackId;
  final Value<String?> archiveThreadId;
  final Value<String> collectionIdsJson;
  final Value<int> isPinned;
  final Value<int> preserveOriginal;
  final Value<int> rowid;
  const FactLedgerEntriesCompanion({
    this.id = const Value.absent(),
    this.sourceEntryId = const Value.absent(),
    this.label = const Value.absent(),
    this.value = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.factType = const Value.absent(),
    this.archivePackId = const Value.absent(),
    this.archiveThreadId = const Value.absent(),
    this.collectionIdsJson = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.preserveOriginal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FactLedgerEntriesCompanion.insert({
    required String id,
    required String sourceEntryId,
    required String label,
    required String value,
    this.note = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    required String factType,
    this.archivePackId = const Value.absent(),
    this.archiveThreadId = const Value.absent(),
    this.collectionIdsJson = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.preserveOriginal = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceEntryId = Value(sourceEntryId),
       label = Value(label),
       value = Value(value),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       factType = Value(factType);
  static Insertable<FactLedgerRow> custom({
    Expression<String>? id,
    Expression<String>? sourceEntryId,
    Expression<String>? label,
    Expression<String>? value,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? factType,
    Expression<String>? archivePackId,
    Expression<String>? archiveThreadId,
    Expression<String>? collectionIdsJson,
    Expression<int>? isPinned,
    Expression<int>? preserveOriginal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceEntryId != null) 'source_entry_id': sourceEntryId,
      if (label != null) 'label': label,
      if (value != null) 'value': value,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (factType != null) 'fact_type': factType,
      if (archivePackId != null) 'archive_pack_id': archivePackId,
      if (archiveThreadId != null) 'archive_thread_id': archiveThreadId,
      if (collectionIdsJson != null) 'collection_ids_json': collectionIdsJson,
      if (isPinned != null) 'is_pinned': isPinned,
      if (preserveOriginal != null) 'preserve_original': preserveOriginal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FactLedgerEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceEntryId,
    Value<String>? label,
    Value<String>? value,
    Value<String>? note,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? factType,
    Value<String?>? archivePackId,
    Value<String?>? archiveThreadId,
    Value<String>? collectionIdsJson,
    Value<int>? isPinned,
    Value<int>? preserveOriginal,
    Value<int>? rowid,
  }) {
    return FactLedgerEntriesCompanion(
      id: id ?? this.id,
      sourceEntryId: sourceEntryId ?? this.sourceEntryId,
      label: label ?? this.label,
      value: value ?? this.value,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      factType: factType ?? this.factType,
      archivePackId: archivePackId ?? this.archivePackId,
      archiveThreadId: archiveThreadId ?? this.archiveThreadId,
      collectionIdsJson: collectionIdsJson ?? this.collectionIdsJson,
      isPinned: isPinned ?? this.isPinned,
      preserveOriginal: preserveOriginal ?? this.preserveOriginal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceEntryId.present) {
      map['source_entry_id'] = Variable<String>(sourceEntryId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (factType.present) {
      map['fact_type'] = Variable<String>(factType.value);
    }
    if (archivePackId.present) {
      map['archive_pack_id'] = Variable<String>(archivePackId.value);
    }
    if (archiveThreadId.present) {
      map['archive_thread_id'] = Variable<String>(archiveThreadId.value);
    }
    if (collectionIdsJson.present) {
      map['collection_ids_json'] = Variable<String>(collectionIdsJson.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<int>(isPinned.value);
    }
    if (preserveOriginal.present) {
      map['preserve_original'] = Variable<int>(preserveOriginal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FactLedgerEntriesCompanion(')
          ..write('id: $id, ')
          ..write('sourceEntryId: $sourceEntryId, ')
          ..write('label: $label, ')
          ..write('value: $value, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('factType: $factType, ')
          ..write('archivePackId: $archivePackId, ')
          ..write('archiveThreadId: $archiveThreadId, ')
          ..write('collectionIdsJson: $collectionIdsJson, ')
          ..write('isPinned: $isPinned, ')
          ..write('preserveOriginal: $preserveOriginal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountIdentitiesTable extends AccountIdentities
    with TableInfo<$AccountIdentitiesTable, AccountIdentityRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountIdentitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'account_identities';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountIdentityRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountIdentityRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountIdentityRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AccountIdentitiesTable createAlias(String alias) {
    return $AccountIdentitiesTable(attachedDatabase, alias);
  }
}

class AccountIdentityRow extends DataClass
    implements Insertable<AccountIdentityRow> {
  final String id;
  final int createdAt;
  const AccountIdentityRow({required this.id, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  AccountIdentitiesCompanion toCompanion(bool nullToAbsent) {
    return AccountIdentitiesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
    );
  }

  factory AccountIdentityRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountIdentityRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  AccountIdentityRow copyWith({String? id, int? createdAt}) =>
      AccountIdentityRow(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
      );
  AccountIdentityRow copyWithCompanion(AccountIdentitiesCompanion data) {
    return AccountIdentityRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountIdentityRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountIdentityRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt);
}

class AccountIdentitiesCompanion extends UpdateCompanion<AccountIdentityRow> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> rowid;
  const AccountIdentitiesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountIdentitiesCompanion.insert({
    required String id,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt);
  static Insertable<AccountIdentityRow> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountIdentitiesCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return AccountIdentitiesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountIdentitiesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserRelationshipsTable extends UserRelationships
    with TableInfo<$UserRelationshipsTable, UserRelationshipRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserRelationshipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES account_identities (id)',
    ),
  );
  static const VerificationMeta _professionalIdMeta = const VerificationMeta(
    'professionalId',
  );
  @override
  late final GeneratedColumn<String> professionalId = GeneratedColumn<String>(
    'professional_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES account_identities (id)',
    ),
  );
  static const VerificationMeta _relationshipTypeMeta = const VerificationMeta(
    'relationshipType',
  );
  @override
  late final GeneratedColumn<String> relationshipType = GeneratedColumn<String>(
    'relationship_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _consentStatusMeta = const VerificationMeta(
    'consentStatus',
  );
  @override
  late final GeneratedColumn<String> consentStatus = GeneratedColumn<String>(
    'consent_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _agreedScopeMeta = const VerificationMeta(
    'agreedScope',
  );
  @override
  late final GeneratedColumn<String> agreedScope = GeneratedColumn<String>(
    'agreed_scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientId,
    professionalId,
    relationshipType,
    consentStatus,
    agreedScope,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_relationships';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserRelationshipRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('professional_id')) {
      context.handle(
        _professionalIdMeta,
        professionalId.isAcceptableOrUnknown(
          data['professional_id']!,
          _professionalIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_professionalIdMeta);
    }
    if (data.containsKey('relationship_type')) {
      context.handle(
        _relationshipTypeMeta,
        relationshipType.isAcceptableOrUnknown(
          data['relationship_type']!,
          _relationshipTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relationshipTypeMeta);
    }
    if (data.containsKey('consent_status')) {
      context.handle(
        _consentStatusMeta,
        consentStatus.isAcceptableOrUnknown(
          data['consent_status']!,
          _consentStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_consentStatusMeta);
    }
    if (data.containsKey('agreed_scope')) {
      context.handle(
        _agreedScopeMeta,
        agreedScope.isAcceptableOrUnknown(
          data['agreed_scope']!,
          _agreedScopeMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserRelationshipRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserRelationshipRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      professionalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}professional_id'],
      )!,
      relationshipType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relationship_type'],
      )!,
      consentStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}consent_status'],
      )!,
      agreedScope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agreed_scope'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserRelationshipsTable createAlias(String alias) {
    return $UserRelationshipsTable(attachedDatabase, alias);
  }
}

class UserRelationshipRow extends DataClass
    implements Insertable<UserRelationshipRow> {
  final String id;
  final String clientId;
  final String professionalId;
  final String relationshipType;
  final String consentStatus;
  final String agreedScope;
  final int createdAt;
  final int updatedAt;
  const UserRelationshipRow({
    required this.id,
    required this.clientId,
    required this.professionalId,
    required this.relationshipType,
    required this.consentStatus,
    required this.agreedScope,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['client_id'] = Variable<String>(clientId);
    map['professional_id'] = Variable<String>(professionalId);
    map['relationship_type'] = Variable<String>(relationshipType);
    map['consent_status'] = Variable<String>(consentStatus);
    map['agreed_scope'] = Variable<String>(agreedScope);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  UserRelationshipsCompanion toCompanion(bool nullToAbsent) {
    return UserRelationshipsCompanion(
      id: Value(id),
      clientId: Value(clientId),
      professionalId: Value(professionalId),
      relationshipType: Value(relationshipType),
      consentStatus: Value(consentStatus),
      agreedScope: Value(agreedScope),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserRelationshipRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserRelationshipRow(
      id: serializer.fromJson<String>(json['id']),
      clientId: serializer.fromJson<String>(json['clientId']),
      professionalId: serializer.fromJson<String>(json['professionalId']),
      relationshipType: serializer.fromJson<String>(json['relationshipType']),
      consentStatus: serializer.fromJson<String>(json['consentStatus']),
      agreedScope: serializer.fromJson<String>(json['agreedScope']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'clientId': serializer.toJson<String>(clientId),
      'professionalId': serializer.toJson<String>(professionalId),
      'relationshipType': serializer.toJson<String>(relationshipType),
      'consentStatus': serializer.toJson<String>(consentStatus),
      'agreedScope': serializer.toJson<String>(agreedScope),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  UserRelationshipRow copyWith({
    String? id,
    String? clientId,
    String? professionalId,
    String? relationshipType,
    String? consentStatus,
    String? agreedScope,
    int? createdAt,
    int? updatedAt,
  }) => UserRelationshipRow(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    professionalId: professionalId ?? this.professionalId,
    relationshipType: relationshipType ?? this.relationshipType,
    consentStatus: consentStatus ?? this.consentStatus,
    agreedScope: agreedScope ?? this.agreedScope,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserRelationshipRow copyWithCompanion(UserRelationshipsCompanion data) {
    return UserRelationshipRow(
      id: data.id.present ? data.id.value : this.id,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      professionalId: data.professionalId.present
          ? data.professionalId.value
          : this.professionalId,
      relationshipType: data.relationshipType.present
          ? data.relationshipType.value
          : this.relationshipType,
      consentStatus: data.consentStatus.present
          ? data.consentStatus.value
          : this.consentStatus,
      agreedScope: data.agreedScope.present
          ? data.agreedScope.value
          : this.agreedScope,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserRelationshipRow(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('professionalId: $professionalId, ')
          ..write('relationshipType: $relationshipType, ')
          ..write('consentStatus: $consentStatus, ')
          ..write('agreedScope: $agreedScope, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientId,
    professionalId,
    relationshipType,
    consentStatus,
    agreedScope,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserRelationshipRow &&
          other.id == this.id &&
          other.clientId == this.clientId &&
          other.professionalId == this.professionalId &&
          other.relationshipType == this.relationshipType &&
          other.consentStatus == this.consentStatus &&
          other.agreedScope == this.agreedScope &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserRelationshipsCompanion extends UpdateCompanion<UserRelationshipRow> {
  final Value<String> id;
  final Value<String> clientId;
  final Value<String> professionalId;
  final Value<String> relationshipType;
  final Value<String> consentStatus;
  final Value<String> agreedScope;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const UserRelationshipsCompanion({
    this.id = const Value.absent(),
    this.clientId = const Value.absent(),
    this.professionalId = const Value.absent(),
    this.relationshipType = const Value.absent(),
    this.consentStatus = const Value.absent(),
    this.agreedScope = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserRelationshipsCompanion.insert({
    required String id,
    required String clientId,
    required String professionalId,
    required String relationshipType,
    required String consentStatus,
    this.agreedScope = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientId = Value(clientId),
       professionalId = Value(professionalId),
       relationshipType = Value(relationshipType),
       consentStatus = Value(consentStatus),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<UserRelationshipRow> custom({
    Expression<String>? id,
    Expression<String>? clientId,
    Expression<String>? professionalId,
    Expression<String>? relationshipType,
    Expression<String>? consentStatus,
    Expression<String>? agreedScope,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientId != null) 'client_id': clientId,
      if (professionalId != null) 'professional_id': professionalId,
      if (relationshipType != null) 'relationship_type': relationshipType,
      if (consentStatus != null) 'consent_status': consentStatus,
      if (agreedScope != null) 'agreed_scope': agreedScope,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserRelationshipsCompanion copyWith({
    Value<String>? id,
    Value<String>? clientId,
    Value<String>? professionalId,
    Value<String>? relationshipType,
    Value<String>? consentStatus,
    Value<String>? agreedScope,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserRelationshipsCompanion(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      professionalId: professionalId ?? this.professionalId,
      relationshipType: relationshipType ?? this.relationshipType,
      consentStatus: consentStatus ?? this.consentStatus,
      agreedScope: agreedScope ?? this.agreedScope,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (professionalId.present) {
      map['professional_id'] = Variable<String>(professionalId.value);
    }
    if (relationshipType.present) {
      map['relationship_type'] = Variable<String>(relationshipType.value);
    }
    if (consentStatus.present) {
      map['consent_status'] = Variable<String>(consentStatus.value);
    }
    if (agreedScope.present) {
      map['agreed_scope'] = Variable<String>(agreedScope.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserRelationshipsCompanion(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('professionalId: $professionalId, ')
          ..write('relationshipType: $relationshipType, ')
          ..write('consentStatus: $consentStatus, ')
          ..write('agreedScope: $agreedScope, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountProStatusTable extends AccountProStatus
    with TableInfo<$AccountProStatusTable, AccountProStatusRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountProStatusTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isProMeta = const VerificationMeta('isPro');
  @override
  late final GeneratedColumn<int> isPro = GeneratedColumn<int>(
    'is_pro',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<String> tier = GeneratedColumn<String>(
    'tier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('free'),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  static const VerificationMeta _entitlementIdsJsonMeta =
      const VerificationMeta('entitlementIdsJson');
  @override
  late final GeneratedColumn<String> entitlementIdsJson =
      GeneratedColumn<String>(
        'entitlement_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _billingConnectedMeta = const VerificationMeta(
    'billingConnected',
  );
  @override
  late final GeneratedColumn<int> billingConnected = GeneratedColumn<int>(
    'billing_connected',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncedFromMeta = const VerificationMeta(
    'syncedFrom',
  );
  @override
  late final GeneratedColumn<String> syncedFrom = GeneratedColumn<String>(
    'synced_from',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    isPro,
    tier,
    source,
    entitlementIdsJson,
    billingConnected,
    syncedFrom,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'account_pro_status';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountProStatusRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('is_pro')) {
      context.handle(
        _isProMeta,
        isPro.isAcceptableOrUnknown(data['is_pro']!, _isProMeta),
      );
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('entitlement_ids_json')) {
      context.handle(
        _entitlementIdsJsonMeta,
        entitlementIdsJson.isAcceptableOrUnknown(
          data['entitlement_ids_json']!,
          _entitlementIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('billing_connected')) {
      context.handle(
        _billingConnectedMeta,
        billingConnected.isAcceptableOrUnknown(
          data['billing_connected']!,
          _billingConnectedMeta,
        ),
      );
    }
    if (data.containsKey('synced_from')) {
      context.handle(
        _syncedFromMeta,
        syncedFrom.isAcceptableOrUnknown(data['synced_from']!, _syncedFromMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountProStatusRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountProStatusRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      isPro: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_pro'],
      )!,
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      entitlementIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entitlement_ids_json'],
      )!,
      billingConnected: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}billing_connected'],
      )!,
      syncedFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synced_from'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AccountProStatusTable createAlias(String alias) {
    return $AccountProStatusTable(attachedDatabase, alias);
  }
}

class AccountProStatusRow extends DataClass
    implements Insertable<AccountProStatusRow> {
  final int id;
  final int isPro;
  final String tier;
  final String source;
  final String entitlementIdsJson;
  final int billingConnected;
  final String syncedFrom;
  final int updatedAt;
  const AccountProStatusRow({
    required this.id,
    required this.isPro,
    required this.tier,
    required this.source,
    required this.entitlementIdsJson,
    required this.billingConnected,
    required this.syncedFrom,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['is_pro'] = Variable<int>(isPro);
    map['tier'] = Variable<String>(tier);
    map['source'] = Variable<String>(source);
    map['entitlement_ids_json'] = Variable<String>(entitlementIdsJson);
    map['billing_connected'] = Variable<int>(billingConnected);
    map['synced_from'] = Variable<String>(syncedFrom);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AccountProStatusCompanion toCompanion(bool nullToAbsent) {
    return AccountProStatusCompanion(
      id: Value(id),
      isPro: Value(isPro),
      tier: Value(tier),
      source: Value(source),
      entitlementIdsJson: Value(entitlementIdsJson),
      billingConnected: Value(billingConnected),
      syncedFrom: Value(syncedFrom),
      updatedAt: Value(updatedAt),
    );
  }

  factory AccountProStatusRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountProStatusRow(
      id: serializer.fromJson<int>(json['id']),
      isPro: serializer.fromJson<int>(json['isPro']),
      tier: serializer.fromJson<String>(json['tier']),
      source: serializer.fromJson<String>(json['source']),
      entitlementIdsJson: serializer.fromJson<String>(
        json['entitlementIdsJson'],
      ),
      billingConnected: serializer.fromJson<int>(json['billingConnected']),
      syncedFrom: serializer.fromJson<String>(json['syncedFrom']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'isPro': serializer.toJson<int>(isPro),
      'tier': serializer.toJson<String>(tier),
      'source': serializer.toJson<String>(source),
      'entitlementIdsJson': serializer.toJson<String>(entitlementIdsJson),
      'billingConnected': serializer.toJson<int>(billingConnected),
      'syncedFrom': serializer.toJson<String>(syncedFrom),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AccountProStatusRow copyWith({
    int? id,
    int? isPro,
    String? tier,
    String? source,
    String? entitlementIdsJson,
    int? billingConnected,
    String? syncedFrom,
    int? updatedAt,
  }) => AccountProStatusRow(
    id: id ?? this.id,
    isPro: isPro ?? this.isPro,
    tier: tier ?? this.tier,
    source: source ?? this.source,
    entitlementIdsJson: entitlementIdsJson ?? this.entitlementIdsJson,
    billingConnected: billingConnected ?? this.billingConnected,
    syncedFrom: syncedFrom ?? this.syncedFrom,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AccountProStatusRow copyWithCompanion(AccountProStatusCompanion data) {
    return AccountProStatusRow(
      id: data.id.present ? data.id.value : this.id,
      isPro: data.isPro.present ? data.isPro.value : this.isPro,
      tier: data.tier.present ? data.tier.value : this.tier,
      source: data.source.present ? data.source.value : this.source,
      entitlementIdsJson: data.entitlementIdsJson.present
          ? data.entitlementIdsJson.value
          : this.entitlementIdsJson,
      billingConnected: data.billingConnected.present
          ? data.billingConnected.value
          : this.billingConnected,
      syncedFrom: data.syncedFrom.present
          ? data.syncedFrom.value
          : this.syncedFrom,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountProStatusRow(')
          ..write('id: $id, ')
          ..write('isPro: $isPro, ')
          ..write('tier: $tier, ')
          ..write('source: $source, ')
          ..write('entitlementIdsJson: $entitlementIdsJson, ')
          ..write('billingConnected: $billingConnected, ')
          ..write('syncedFrom: $syncedFrom, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    isPro,
    tier,
    source,
    entitlementIdsJson,
    billingConnected,
    syncedFrom,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountProStatusRow &&
          other.id == this.id &&
          other.isPro == this.isPro &&
          other.tier == this.tier &&
          other.source == this.source &&
          other.entitlementIdsJson == this.entitlementIdsJson &&
          other.billingConnected == this.billingConnected &&
          other.syncedFrom == this.syncedFrom &&
          other.updatedAt == this.updatedAt);
}

class AccountProStatusCompanion extends UpdateCompanion<AccountProStatusRow> {
  final Value<int> id;
  final Value<int> isPro;
  final Value<String> tier;
  final Value<String> source;
  final Value<String> entitlementIdsJson;
  final Value<int> billingConnected;
  final Value<String> syncedFrom;
  final Value<int> updatedAt;
  const AccountProStatusCompanion({
    this.id = const Value.absent(),
    this.isPro = const Value.absent(),
    this.tier = const Value.absent(),
    this.source = const Value.absent(),
    this.entitlementIdsJson = const Value.absent(),
    this.billingConnected = const Value.absent(),
    this.syncedFrom = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AccountProStatusCompanion.insert({
    this.id = const Value.absent(),
    this.isPro = const Value.absent(),
    this.tier = const Value.absent(),
    this.source = const Value.absent(),
    this.entitlementIdsJson = const Value.absent(),
    this.billingConnected = const Value.absent(),
    this.syncedFrom = const Value.absent(),
    required int updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<AccountProStatusRow> custom({
    Expression<int>? id,
    Expression<int>? isPro,
    Expression<String>? tier,
    Expression<String>? source,
    Expression<String>? entitlementIdsJson,
    Expression<int>? billingConnected,
    Expression<String>? syncedFrom,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (isPro != null) 'is_pro': isPro,
      if (tier != null) 'tier': tier,
      if (source != null) 'source': source,
      if (entitlementIdsJson != null)
        'entitlement_ids_json': entitlementIdsJson,
      if (billingConnected != null) 'billing_connected': billingConnected,
      if (syncedFrom != null) 'synced_from': syncedFrom,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AccountProStatusCompanion copyWith({
    Value<int>? id,
    Value<int>? isPro,
    Value<String>? tier,
    Value<String>? source,
    Value<String>? entitlementIdsJson,
    Value<int>? billingConnected,
    Value<String>? syncedFrom,
    Value<int>? updatedAt,
  }) {
    return AccountProStatusCompanion(
      id: id ?? this.id,
      isPro: isPro ?? this.isPro,
      tier: tier ?? this.tier,
      source: source ?? this.source,
      entitlementIdsJson: entitlementIdsJson ?? this.entitlementIdsJson,
      billingConnected: billingConnected ?? this.billingConnected,
      syncedFrom: syncedFrom ?? this.syncedFrom,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (isPro.present) {
      map['is_pro'] = Variable<int>(isPro.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(tier.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (entitlementIdsJson.present) {
      map['entitlement_ids_json'] = Variable<String>(entitlementIdsJson.value);
    }
    if (billingConnected.present) {
      map['billing_connected'] = Variable<int>(billingConnected.value);
    }
    if (syncedFrom.present) {
      map['synced_from'] = Variable<String>(syncedFrom.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountProStatusCompanion(')
          ..write('id: $id, ')
          ..write('isPro: $isPro, ')
          ..write('tier: $tier, ')
          ..write('source: $source, ')
          ..write('entitlementIdsJson: $entitlementIdsJson, ')
          ..write('billingConnected: $billingConnected, ')
          ..write('syncedFrom: $syncedFrom, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $MemoryTranscriptEmbeddingsTable extends MemoryTranscriptEmbeddings
    with
        TableInfo<
          $MemoryTranscriptEmbeddingsTable,
          MemoryTranscriptEmbeddingRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryTranscriptEmbeddingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES journal_entries (id)',
    ),
  );
  static const VerificationMeta _embeddingMeta = const VerificationMeta(
    'embedding',
  );
  @override
  late final GeneratedColumn<Uint8List> embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dimensionsMeta = const VerificationMeta(
    'dimensions',
  );
  @override
  late final GeneratedColumn<int> dimensions = GeneratedColumn<int>(
    'dimensions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entryId, embedding, dimensions];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_transcript_embeddings';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryTranscriptEmbeddingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('embedding')) {
      context.handle(
        _embeddingMeta,
        embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta),
      );
    } else if (isInserting) {
      context.missing(_embeddingMeta);
    }
    if (data.containsKey('dimensions')) {
      context.handle(
        _dimensionsMeta,
        dimensions.isAcceptableOrUnknown(data['dimensions']!, _dimensionsMeta),
      );
    } else if (isInserting) {
      context.missing(_dimensionsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId};
  @override
  MemoryTranscriptEmbeddingRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryTranscriptEmbeddingRow(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      embedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}embedding'],
      )!,
      dimensions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dimensions'],
      )!,
    );
  }

  @override
  $MemoryTranscriptEmbeddingsTable createAlias(String alias) {
    return $MemoryTranscriptEmbeddingsTable(attachedDatabase, alias);
  }
}

class MemoryTranscriptEmbeddingRow extends DataClass
    implements Insertable<MemoryTranscriptEmbeddingRow> {
  final String entryId;
  final Uint8List embedding;
  final int dimensions;
  const MemoryTranscriptEmbeddingRow({
    required this.entryId,
    required this.embedding,
    required this.dimensions,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['embedding'] = Variable<Uint8List>(embedding);
    map['dimensions'] = Variable<int>(dimensions);
    return map;
  }

  MemoryTranscriptEmbeddingsCompanion toCompanion(bool nullToAbsent) {
    return MemoryTranscriptEmbeddingsCompanion(
      entryId: Value(entryId),
      embedding: Value(embedding),
      dimensions: Value(dimensions),
    );
  }

  factory MemoryTranscriptEmbeddingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryTranscriptEmbeddingRow(
      entryId: serializer.fromJson<String>(json['entryId']),
      embedding: serializer.fromJson<Uint8List>(json['embedding']),
      dimensions: serializer.fromJson<int>(json['dimensions']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'embedding': serializer.toJson<Uint8List>(embedding),
      'dimensions': serializer.toJson<int>(dimensions),
    };
  }

  MemoryTranscriptEmbeddingRow copyWith({
    String? entryId,
    Uint8List? embedding,
    int? dimensions,
  }) => MemoryTranscriptEmbeddingRow(
    entryId: entryId ?? this.entryId,
    embedding: embedding ?? this.embedding,
    dimensions: dimensions ?? this.dimensions,
  );
  MemoryTranscriptEmbeddingRow copyWithCompanion(
    MemoryTranscriptEmbeddingsCompanion data,
  ) {
    return MemoryTranscriptEmbeddingRow(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      dimensions: data.dimensions.present
          ? data.dimensions.value
          : this.dimensions,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryTranscriptEmbeddingRow(')
          ..write('entryId: $entryId, ')
          ..write('embedding: $embedding, ')
          ..write('dimensions: $dimensions')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(entryId, $driftBlobEquality.hash(embedding), dimensions);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryTranscriptEmbeddingRow &&
          other.entryId == this.entryId &&
          $driftBlobEquality.equals(other.embedding, this.embedding) &&
          other.dimensions == this.dimensions);
}

class MemoryTranscriptEmbeddingsCompanion
    extends UpdateCompanion<MemoryTranscriptEmbeddingRow> {
  final Value<String> entryId;
  final Value<Uint8List> embedding;
  final Value<int> dimensions;
  final Value<int> rowid;
  const MemoryTranscriptEmbeddingsCompanion({
    this.entryId = const Value.absent(),
    this.embedding = const Value.absent(),
    this.dimensions = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryTranscriptEmbeddingsCompanion.insert({
    required String entryId,
    required Uint8List embedding,
    required int dimensions,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       embedding = Value(embedding),
       dimensions = Value(dimensions);
  static Insertable<MemoryTranscriptEmbeddingRow> custom({
    Expression<String>? entryId,
    Expression<Uint8List>? embedding,
    Expression<int>? dimensions,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (embedding != null) 'embedding': embedding,
      if (dimensions != null) 'dimensions': dimensions,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryTranscriptEmbeddingsCompanion copyWith({
    Value<String>? entryId,
    Value<Uint8List>? embedding,
    Value<int>? dimensions,
    Value<int>? rowid,
  }) {
    return MemoryTranscriptEmbeddingsCompanion(
      entryId: entryId ?? this.entryId,
      embedding: embedding ?? this.embedding,
      dimensions: dimensions ?? this.dimensions,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(embedding.value);
    }
    if (dimensions.present) {
      map['dimensions'] = Variable<int>(dimensions.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryTranscriptEmbeddingsCompanion(')
          ..write('entryId: $entryId, ')
          ..write('embedding: $embedding, ')
          ..write('dimensions: $dimensions, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JournalImageEmbeddingsTable extends JournalImageEmbeddings
    with TableInfo<$JournalImageEmbeddingsTable, JournalImageEmbeddingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalImageEmbeddingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _evidenceIdMeta = const VerificationMeta(
    'evidenceId',
  );
  @override
  late final GeneratedColumn<String> evidenceId = GeneratedColumn<String>(
    'evidence_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES journal_entries (id)',
    ),
  );
  static const VerificationMeta _embeddingMeta = const VerificationMeta(
    'embedding',
  );
  @override
  late final GeneratedColumn<Uint8List> embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dimensionsMeta = const VerificationMeta(
    'dimensions',
  );
  @override
  late final GeneratedColumn<int> dimensions = GeneratedColumn<int>(
    'dimensions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    evidenceId,
    entryId,
    embedding,
    dimensions,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_image_embeddings';
  @override
  VerificationContext validateIntegrity(
    Insertable<JournalImageEmbeddingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('evidence_id')) {
      context.handle(
        _evidenceIdMeta,
        evidenceId.isAcceptableOrUnknown(data['evidence_id']!, _evidenceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_evidenceIdMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('embedding')) {
      context.handle(
        _embeddingMeta,
        embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta),
      );
    } else if (isInserting) {
      context.missing(_embeddingMeta);
    }
    if (data.containsKey('dimensions')) {
      context.handle(
        _dimensionsMeta,
        dimensions.isAcceptableOrUnknown(data['dimensions']!, _dimensionsMeta),
      );
    } else if (isInserting) {
      context.missing(_dimensionsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {evidenceId};
  @override
  JournalImageEmbeddingRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalImageEmbeddingRow(
      evidenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_id'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      embedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}embedding'],
      )!,
      dimensions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dimensions'],
      )!,
    );
  }

  @override
  $JournalImageEmbeddingsTable createAlias(String alias) {
    return $JournalImageEmbeddingsTable(attachedDatabase, alias);
  }
}

class JournalImageEmbeddingRow extends DataClass
    implements Insertable<JournalImageEmbeddingRow> {
  final String evidenceId;
  final String entryId;
  final Uint8List embedding;
  final int dimensions;
  const JournalImageEmbeddingRow({
    required this.evidenceId,
    required this.entryId,
    required this.embedding,
    required this.dimensions,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['evidence_id'] = Variable<String>(evidenceId);
    map['entry_id'] = Variable<String>(entryId);
    map['embedding'] = Variable<Uint8List>(embedding);
    map['dimensions'] = Variable<int>(dimensions);
    return map;
  }

  JournalImageEmbeddingsCompanion toCompanion(bool nullToAbsent) {
    return JournalImageEmbeddingsCompanion(
      evidenceId: Value(evidenceId),
      entryId: Value(entryId),
      embedding: Value(embedding),
      dimensions: Value(dimensions),
    );
  }

  factory JournalImageEmbeddingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalImageEmbeddingRow(
      evidenceId: serializer.fromJson<String>(json['evidenceId']),
      entryId: serializer.fromJson<String>(json['entryId']),
      embedding: serializer.fromJson<Uint8List>(json['embedding']),
      dimensions: serializer.fromJson<int>(json['dimensions']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'evidenceId': serializer.toJson<String>(evidenceId),
      'entryId': serializer.toJson<String>(entryId),
      'embedding': serializer.toJson<Uint8List>(embedding),
      'dimensions': serializer.toJson<int>(dimensions),
    };
  }

  JournalImageEmbeddingRow copyWith({
    String? evidenceId,
    String? entryId,
    Uint8List? embedding,
    int? dimensions,
  }) => JournalImageEmbeddingRow(
    evidenceId: evidenceId ?? this.evidenceId,
    entryId: entryId ?? this.entryId,
    embedding: embedding ?? this.embedding,
    dimensions: dimensions ?? this.dimensions,
  );
  JournalImageEmbeddingRow copyWithCompanion(
    JournalImageEmbeddingsCompanion data,
  ) {
    return JournalImageEmbeddingRow(
      evidenceId: data.evidenceId.present
          ? data.evidenceId.value
          : this.evidenceId,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      dimensions: data.dimensions.present
          ? data.dimensions.value
          : this.dimensions,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalImageEmbeddingRow(')
          ..write('evidenceId: $evidenceId, ')
          ..write('entryId: $entryId, ')
          ..write('embedding: $embedding, ')
          ..write('dimensions: $dimensions')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    evidenceId,
    entryId,
    $driftBlobEquality.hash(embedding),
    dimensions,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalImageEmbeddingRow &&
          other.evidenceId == this.evidenceId &&
          other.entryId == this.entryId &&
          $driftBlobEquality.equals(other.embedding, this.embedding) &&
          other.dimensions == this.dimensions);
}

class JournalImageEmbeddingsCompanion
    extends UpdateCompanion<JournalImageEmbeddingRow> {
  final Value<String> evidenceId;
  final Value<String> entryId;
  final Value<Uint8List> embedding;
  final Value<int> dimensions;
  final Value<int> rowid;
  const JournalImageEmbeddingsCompanion({
    this.evidenceId = const Value.absent(),
    this.entryId = const Value.absent(),
    this.embedding = const Value.absent(),
    this.dimensions = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalImageEmbeddingsCompanion.insert({
    required String evidenceId,
    required String entryId,
    required Uint8List embedding,
    required int dimensions,
    this.rowid = const Value.absent(),
  }) : evidenceId = Value(evidenceId),
       entryId = Value(entryId),
       embedding = Value(embedding),
       dimensions = Value(dimensions);
  static Insertable<JournalImageEmbeddingRow> custom({
    Expression<String>? evidenceId,
    Expression<String>? entryId,
    Expression<Uint8List>? embedding,
    Expression<int>? dimensions,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (evidenceId != null) 'evidence_id': evidenceId,
      if (entryId != null) 'entry_id': entryId,
      if (embedding != null) 'embedding': embedding,
      if (dimensions != null) 'dimensions': dimensions,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalImageEmbeddingsCompanion copyWith({
    Value<String>? evidenceId,
    Value<String>? entryId,
    Value<Uint8List>? embedding,
    Value<int>? dimensions,
    Value<int>? rowid,
  }) {
    return JournalImageEmbeddingsCompanion(
      evidenceId: evidenceId ?? this.evidenceId,
      entryId: entryId ?? this.entryId,
      embedding: embedding ?? this.embedding,
      dimensions: dimensions ?? this.dimensions,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (evidenceId.present) {
      map['evidence_id'] = Variable<String>(evidenceId.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(embedding.value);
    }
    if (dimensions.present) {
      map['dimensions'] = Variable<int>(dimensions.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalImageEmbeddingsCompanion(')
          ..write('evidenceId: $evidenceId, ')
          ..write('entryId: $entryId, ')
          ..write('embedding: $embedding, ')
          ..write('dimensions: $dimensions, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuickCaptureOutboxEntriesTable extends QuickCaptureOutboxEntries
    with TableInfo<$QuickCaptureOutboxEntriesTable, QuickCaptureOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuickCaptureOutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _outboxIdMeta = const VerificationMeta(
    'outboxId',
  );
  @override
  late final GeneratedColumn<String> outboxId = GeneratedColumn<String>(
    'outbox_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _captureIdMeta = const VerificationMeta(
    'captureId',
  );
  @override
  late final GeneratedColumn<String> captureId = GeneratedColumn<String>(
    'capture_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
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
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    outboxId,
    captureId,
    kind,
    payloadJson,
    status,
    attemptCount,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quick_capture_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuickCaptureOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('outbox_id')) {
      context.handle(
        _outboxIdMeta,
        outboxId.isAcceptableOrUnknown(data['outbox_id']!, _outboxIdMeta),
      );
    } else if (isInserting) {
      context.missing(_outboxIdMeta);
    }
    if (data.containsKey('capture_id')) {
      context.handle(
        _captureIdMeta,
        captureId.isAcceptableOrUnknown(data['capture_id']!, _captureIdMeta),
      );
    } else if (isInserting) {
      context.missing(_captureIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {outboxId};
  @override
  QuickCaptureOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuickCaptureOutboxRow(
      outboxId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outbox_id'],
      )!,
      captureId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capture_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $QuickCaptureOutboxEntriesTable createAlias(String alias) {
    return $QuickCaptureOutboxEntriesTable(attachedDatabase, alias);
  }
}

class QuickCaptureOutboxRow extends DataClass
    implements Insertable<QuickCaptureOutboxRow> {
  final String outboxId;
  final String captureId;
  final String kind;
  final String payloadJson;
  final String status;
  final int attemptCount;
  final String? lastError;
  final int createdAt;
  final int updatedAt;
  const QuickCaptureOutboxRow({
    required this.outboxId,
    required this.captureId,
    required this.kind,
    required this.payloadJson,
    required this.status,
    required this.attemptCount,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['outbox_id'] = Variable<String>(outboxId);
    map['capture_id'] = Variable<String>(captureId);
    map['kind'] = Variable<String>(kind);
    map['payload_json'] = Variable<String>(payloadJson);
    map['status'] = Variable<String>(status);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  QuickCaptureOutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return QuickCaptureOutboxEntriesCompanion(
      outboxId: Value(outboxId),
      captureId: Value(captureId),
      kind: Value(kind),
      payloadJson: Value(payloadJson),
      status: Value(status),
      attemptCount: Value(attemptCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory QuickCaptureOutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuickCaptureOutboxRow(
      outboxId: serializer.fromJson<String>(json['outboxId']),
      captureId: serializer.fromJson<String>(json['captureId']),
      kind: serializer.fromJson<String>(json['kind']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      status: serializer.fromJson<String>(json['status']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'outboxId': serializer.toJson<String>(outboxId),
      'captureId': serializer.toJson<String>(captureId),
      'kind': serializer.toJson<String>(kind),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'status': serializer.toJson<String>(status),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  QuickCaptureOutboxRow copyWith({
    String? outboxId,
    String? captureId,
    String? kind,
    String? payloadJson,
    String? status,
    int? attemptCount,
    Value<String?> lastError = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => QuickCaptureOutboxRow(
    outboxId: outboxId ?? this.outboxId,
    captureId: captureId ?? this.captureId,
    kind: kind ?? this.kind,
    payloadJson: payloadJson ?? this.payloadJson,
    status: status ?? this.status,
    attemptCount: attemptCount ?? this.attemptCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  QuickCaptureOutboxRow copyWithCompanion(
    QuickCaptureOutboxEntriesCompanion data,
  ) {
    return QuickCaptureOutboxRow(
      outboxId: data.outboxId.present ? data.outboxId.value : this.outboxId,
      captureId: data.captureId.present ? data.captureId.value : this.captureId,
      kind: data.kind.present ? data.kind.value : this.kind,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      status: data.status.present ? data.status.value : this.status,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuickCaptureOutboxRow(')
          ..write('outboxId: $outboxId, ')
          ..write('captureId: $captureId, ')
          ..write('kind: $kind, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    outboxId,
    captureId,
    kind,
    payloadJson,
    status,
    attemptCount,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuickCaptureOutboxRow &&
          other.outboxId == this.outboxId &&
          other.captureId == this.captureId &&
          other.kind == this.kind &&
          other.payloadJson == this.payloadJson &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class QuickCaptureOutboxEntriesCompanion
    extends UpdateCompanion<QuickCaptureOutboxRow> {
  final Value<String> outboxId;
  final Value<String> captureId;
  final Value<String> kind;
  final Value<String> payloadJson;
  final Value<String> status;
  final Value<int> attemptCount;
  final Value<String?> lastError;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const QuickCaptureOutboxEntriesCompanion({
    this.outboxId = const Value.absent(),
    this.captureId = const Value.absent(),
    this.kind = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuickCaptureOutboxEntriesCompanion.insert({
    required String outboxId,
    required String captureId,
    required String kind,
    required String payloadJson,
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : outboxId = Value(outboxId),
       captureId = Value(captureId),
       kind = Value(kind),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<QuickCaptureOutboxRow> custom({
    Expression<String>? outboxId,
    Expression<String>? captureId,
    Expression<String>? kind,
    Expression<String>? payloadJson,
    Expression<String>? status,
    Expression<int>? attemptCount,
    Expression<String>? lastError,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (outboxId != null) 'outbox_id': outboxId,
      if (captureId != null) 'capture_id': captureId,
      if (kind != null) 'kind': kind,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuickCaptureOutboxEntriesCompanion copyWith({
    Value<String>? outboxId,
    Value<String>? captureId,
    Value<String>? kind,
    Value<String>? payloadJson,
    Value<String>? status,
    Value<int>? attemptCount,
    Value<String?>? lastError,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return QuickCaptureOutboxEntriesCompanion(
      outboxId: outboxId ?? this.outboxId,
      captureId: captureId ?? this.captureId,
      kind: kind ?? this.kind,
      payloadJson: payloadJson ?? this.payloadJson,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (outboxId.present) {
      map['outbox_id'] = Variable<String>(outboxId.value);
    }
    if (captureId.present) {
      map['capture_id'] = Variable<String>(captureId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuickCaptureOutboxEntriesCompanion(')
          ..write('outboxId: $outboxId, ')
          ..write('captureId: $captureId, ')
          ..write('kind: $kind, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EmbeddingDeferredQueueEntriesTable extends EmbeddingDeferredQueueEntries
    with
        TableInfo<
          $EmbeddingDeferredQueueEntriesTable,
          EmbeddingDeferredQueueRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmbeddingDeferredQueueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _queueIdMeta = const VerificationMeta(
    'queueId',
  );
  @override
  late final GeneratedColumn<String> queueId = GeneratedColumn<String>(
    'queue_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyTextMeta = const VerificationMeta(
    'bodyText',
  );
  @override
  late final GeneratedColumn<String> bodyText = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sqliteFilePathMeta = const VerificationMeta(
    'sqliteFilePath',
  );
  @override
  late final GeneratedColumn<String> sqliteFilePath = GeneratedColumn<String>(
    'sqlite_file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyAliasMeta = const VerificationMeta(
    'keyAlias',
  );
  @override
  late final GeneratedColumn<String> keyAlias = GeneratedColumn<String>(
    'key_alias',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptionPasswordMeta =
      const VerificationMeta('encryptionPassword');
  @override
  late final GeneratedColumn<String> encryptionPassword =
      GeneratedColumn<String>(
        'encryption_password',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    queueId,
    operation,
    entryId,
    bodyText,
    contentHash,
    sqliteFilePath,
    keyAlias,
    encryptionPassword,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'embedding_deferred_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<EmbeddingDeferredQueueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('queue_id')) {
      context.handle(
        _queueIdMeta,
        queueId.isAcceptableOrUnknown(data['queue_id']!, _queueIdMeta),
      );
    } else if (isInserting) {
      context.missing(_queueIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyTextMeta,
        bodyText.isAcceptableOrUnknown(data['text']!, _bodyTextMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyTextMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    if (data.containsKey('sqlite_file_path')) {
      context.handle(
        _sqliteFilePathMeta,
        sqliteFilePath.isAcceptableOrUnknown(
          data['sqlite_file_path']!,
          _sqliteFilePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sqliteFilePathMeta);
    }
    if (data.containsKey('key_alias')) {
      context.handle(
        _keyAliasMeta,
        keyAlias.isAcceptableOrUnknown(data['key_alias']!, _keyAliasMeta),
      );
    }
    if (data.containsKey('encryption_password')) {
      context.handle(
        _encryptionPasswordMeta,
        encryptionPassword.isAcceptableOrUnknown(
          data['encryption_password']!,
          _encryptionPasswordMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {queueId};
  @override
  EmbeddingDeferredQueueRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EmbeddingDeferredQueueRow(
      queueId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}queue_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      bodyText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
      sqliteFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sqlite_file_path'],
      )!,
      keyAlias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_alias'],
      ),
      encryptionPassword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encryption_password'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EmbeddingDeferredQueueEntriesTable createAlias(String alias) {
    return $EmbeddingDeferredQueueEntriesTable(attachedDatabase, alias);
  }
}

class EmbeddingDeferredQueueRow extends DataClass
    implements Insertable<EmbeddingDeferredQueueRow> {
  final String queueId;
  final String operation;
  final String entryId;
  final String bodyText;
  final String? contentHash;
  final String sqliteFilePath;
  final String? keyAlias;
  final String? encryptionPassword;
  final int createdAt;
  final int updatedAt;
  const EmbeddingDeferredQueueRow({
    required this.queueId,
    required this.operation,
    required this.entryId,
    required this.bodyText,
    this.contentHash,
    required this.sqliteFilePath,
    this.keyAlias,
    this.encryptionPassword,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['queue_id'] = Variable<String>(queueId);
    map['operation'] = Variable<String>(operation);
    map['entry_id'] = Variable<String>(entryId);
    map['text'] = Variable<String>(bodyText);
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    map['sqlite_file_path'] = Variable<String>(sqliteFilePath);
    if (!nullToAbsent || keyAlias != null) {
      map['key_alias'] = Variable<String>(keyAlias);
    }
    if (!nullToAbsent || encryptionPassword != null) {
      map['encryption_password'] = Variable<String>(encryptionPassword);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  EmbeddingDeferredQueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return EmbeddingDeferredQueueEntriesCompanion(
      queueId: Value(queueId),
      operation: Value(operation),
      entryId: Value(entryId),
      bodyText: Value(bodyText),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      sqliteFilePath: Value(sqliteFilePath),
      keyAlias: keyAlias == null && nullToAbsent
          ? const Value.absent()
          : Value(keyAlias),
      encryptionPassword: encryptionPassword == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptionPassword),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory EmbeddingDeferredQueueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EmbeddingDeferredQueueRow(
      queueId: serializer.fromJson<String>(json['queueId']),
      operation: serializer.fromJson<String>(json['operation']),
      entryId: serializer.fromJson<String>(json['entryId']),
      bodyText: serializer.fromJson<String>(json['bodyText']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      sqliteFilePath: serializer.fromJson<String>(json['sqliteFilePath']),
      keyAlias: serializer.fromJson<String?>(json['keyAlias']),
      encryptionPassword: serializer.fromJson<String?>(
        json['encryptionPassword'],
      ),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'queueId': serializer.toJson<String>(queueId),
      'operation': serializer.toJson<String>(operation),
      'entryId': serializer.toJson<String>(entryId),
      'bodyText': serializer.toJson<String>(bodyText),
      'contentHash': serializer.toJson<String?>(contentHash),
      'sqliteFilePath': serializer.toJson<String>(sqliteFilePath),
      'keyAlias': serializer.toJson<String?>(keyAlias),
      'encryptionPassword': serializer.toJson<String?>(encryptionPassword),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  EmbeddingDeferredQueueRow copyWith({
    String? queueId,
    String? operation,
    String? entryId,
    String? bodyText,
    Value<String?> contentHash = const Value.absent(),
    String? sqliteFilePath,
    Value<String?> keyAlias = const Value.absent(),
    Value<String?> encryptionPassword = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => EmbeddingDeferredQueueRow(
    queueId: queueId ?? this.queueId,
    operation: operation ?? this.operation,
    entryId: entryId ?? this.entryId,
    bodyText: bodyText ?? this.bodyText,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    sqliteFilePath: sqliteFilePath ?? this.sqliteFilePath,
    keyAlias: keyAlias.present ? keyAlias.value : this.keyAlias,
    encryptionPassword: encryptionPassword.present
        ? encryptionPassword.value
        : this.encryptionPassword,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EmbeddingDeferredQueueRow copyWithCompanion(
    EmbeddingDeferredQueueEntriesCompanion data,
  ) {
    return EmbeddingDeferredQueueRow(
      queueId: data.queueId.present ? data.queueId.value : this.queueId,
      operation: data.operation.present ? data.operation.value : this.operation,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      bodyText: data.bodyText.present ? data.bodyText.value : this.bodyText,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      sqliteFilePath: data.sqliteFilePath.present
          ? data.sqliteFilePath.value
          : this.sqliteFilePath,
      keyAlias: data.keyAlias.present ? data.keyAlias.value : this.keyAlias,
      encryptionPassword: data.encryptionPassword.present
          ? data.encryptionPassword.value
          : this.encryptionPassword,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EmbeddingDeferredQueueRow(')
          ..write('queueId: $queueId, ')
          ..write('operation: $operation, ')
          ..write('entryId: $entryId, ')
          ..write('bodyText: $bodyText, ')
          ..write('contentHash: $contentHash, ')
          ..write('sqliteFilePath: $sqliteFilePath, ')
          ..write('keyAlias: $keyAlias, ')
          ..write('encryptionPassword: $encryptionPassword, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    queueId,
    operation,
    entryId,
    bodyText,
    contentHash,
    sqliteFilePath,
    keyAlias,
    encryptionPassword,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmbeddingDeferredQueueRow &&
          other.queueId == this.queueId &&
          other.operation == this.operation &&
          other.entryId == this.entryId &&
          other.bodyText == this.bodyText &&
          other.contentHash == this.contentHash &&
          other.sqliteFilePath == this.sqliteFilePath &&
          other.keyAlias == this.keyAlias &&
          other.encryptionPassword == this.encryptionPassword &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class EmbeddingDeferredQueueEntriesCompanion
    extends UpdateCompanion<EmbeddingDeferredQueueRow> {
  final Value<String> queueId;
  final Value<String> operation;
  final Value<String> entryId;
  final Value<String> bodyText;
  final Value<String?> contentHash;
  final Value<String> sqliteFilePath;
  final Value<String?> keyAlias;
  final Value<String?> encryptionPassword;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const EmbeddingDeferredQueueEntriesCompanion({
    this.queueId = const Value.absent(),
    this.operation = const Value.absent(),
    this.entryId = const Value.absent(),
    this.bodyText = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.sqliteFilePath = const Value.absent(),
    this.keyAlias = const Value.absent(),
    this.encryptionPassword = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EmbeddingDeferredQueueEntriesCompanion.insert({
    required String queueId,
    required String operation,
    required String entryId,
    required String bodyText,
    this.contentHash = const Value.absent(),
    required String sqliteFilePath,
    this.keyAlias = const Value.absent(),
    this.encryptionPassword = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : queueId = Value(queueId),
       operation = Value(operation),
       entryId = Value(entryId),
       bodyText = Value(bodyText),
       sqliteFilePath = Value(sqliteFilePath),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<EmbeddingDeferredQueueRow> custom({
    Expression<String>? queueId,
    Expression<String>? operation,
    Expression<String>? entryId,
    Expression<String>? bodyText,
    Expression<String>? contentHash,
    Expression<String>? sqliteFilePath,
    Expression<String>? keyAlias,
    Expression<String>? encryptionPassword,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (queueId != null) 'queue_id': queueId,
      if (operation != null) 'operation': operation,
      if (entryId != null) 'entry_id': entryId,
      if (bodyText != null) 'text': bodyText,
      if (contentHash != null) 'content_hash': contentHash,
      if (sqliteFilePath != null) 'sqlite_file_path': sqliteFilePath,
      if (keyAlias != null) 'key_alias': keyAlias,
      if (encryptionPassword != null) 'encryption_password': encryptionPassword,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EmbeddingDeferredQueueEntriesCompanion copyWith({
    Value<String>? queueId,
    Value<String>? operation,
    Value<String>? entryId,
    Value<String>? bodyText,
    Value<String?>? contentHash,
    Value<String>? sqliteFilePath,
    Value<String?>? keyAlias,
    Value<String?>? encryptionPassword,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return EmbeddingDeferredQueueEntriesCompanion(
      queueId: queueId ?? this.queueId,
      operation: operation ?? this.operation,
      entryId: entryId ?? this.entryId,
      bodyText: bodyText ?? this.bodyText,
      contentHash: contentHash ?? this.contentHash,
      sqliteFilePath: sqliteFilePath ?? this.sqliteFilePath,
      keyAlias: keyAlias ?? this.keyAlias,
      encryptionPassword: encryptionPassword ?? this.encryptionPassword,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (queueId.present) {
      map['queue_id'] = Variable<String>(queueId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (bodyText.present) {
      map['text'] = Variable<String>(bodyText.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (sqliteFilePath.present) {
      map['sqlite_file_path'] = Variable<String>(sqliteFilePath.value);
    }
    if (keyAlias.present) {
      map['key_alias'] = Variable<String>(keyAlias.value);
    }
    if (encryptionPassword.present) {
      map['encryption_password'] = Variable<String>(encryptionPassword.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmbeddingDeferredQueueEntriesCompanion(')
          ..write('queueId: $queueId, ')
          ..write('operation: $operation, ')
          ..write('entryId: $entryId, ')
          ..write('bodyText: $bodyText, ')
          ..write('contentHash: $contentHash, ')
          ..write('sqliteFilePath: $sqliteFilePath, ')
          ..write('keyAlias: $keyAlias, ')
          ..write('encryptionPassword: $encryptionPassword, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AudioProcessingQueueEntriesTable extends AudioProcessingQueueEntries
    with TableInfo<$AudioProcessingQueueEntriesTable, AudioProcessingQueueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioProcessingQueueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    filePath,
    timestamp,
    durationMs,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_processing_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<AudioProcessingQueueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AudioProcessingQueueRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioProcessingQueueRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $AudioProcessingQueueEntriesTable createAlias(String alias) {
    return $AudioProcessingQueueEntriesTable(attachedDatabase, alias);
  }
}

class AudioProcessingQueueRow extends DataClass
    implements Insertable<AudioProcessingQueueRow> {
  final String id;
  final String filePath;
  final int timestamp;
  final int durationMs;
  final String status;
  const AudioProcessingQueueRow({
    required this.id,
    required this.filePath,
    required this.timestamp,
    required this.durationMs,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['file_path'] = Variable<String>(filePath);
    map['timestamp'] = Variable<int>(timestamp);
    map['duration_ms'] = Variable<int>(durationMs);
    map['status'] = Variable<String>(status);
    return map;
  }

  AudioProcessingQueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return AudioProcessingQueueEntriesCompanion(
      id: Value(id),
      filePath: Value(filePath),
      timestamp: Value(timestamp),
      durationMs: Value(durationMs),
      status: Value(status),
    );
  }

  factory AudioProcessingQueueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioProcessingQueueRow(
      id: serializer.fromJson<String>(json['id']),
      filePath: serializer.fromJson<String>(json['filePath']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'filePath': serializer.toJson<String>(filePath),
      'timestamp': serializer.toJson<int>(timestamp),
      'durationMs': serializer.toJson<int>(durationMs),
      'status': serializer.toJson<String>(status),
    };
  }

  AudioProcessingQueueRow copyWith({
    String? id,
    String? filePath,
    int? timestamp,
    int? durationMs,
    String? status,
  }) => AudioProcessingQueueRow(
    id: id ?? this.id,
    filePath: filePath ?? this.filePath,
    timestamp: timestamp ?? this.timestamp,
    durationMs: durationMs ?? this.durationMs,
    status: status ?? this.status,
  );
  AudioProcessingQueueRow copyWithCompanion(
    AudioProcessingQueueEntriesCompanion data,
  ) {
    return AudioProcessingQueueRow(
      id: data.id.present ? data.id.value : this.id,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioProcessingQueueRow(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('timestamp: $timestamp, ')
          ..write('durationMs: $durationMs, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, filePath, timestamp, durationMs, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioProcessingQueueRow &&
          other.id == this.id &&
          other.filePath == this.filePath &&
          other.timestamp == this.timestamp &&
          other.durationMs == this.durationMs &&
          other.status == this.status);
}

class AudioProcessingQueueEntriesCompanion
    extends UpdateCompanion<AudioProcessingQueueRow> {
  final Value<String> id;
  final Value<String> filePath;
  final Value<int> timestamp;
  final Value<int> durationMs;
  final Value<String> status;
  final Value<int> rowid;
  const AudioProcessingQueueEntriesCompanion({
    this.id = const Value.absent(),
    this.filePath = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioProcessingQueueEntriesCompanion.insert({
    required String id,
    required String filePath,
    required int timestamp,
    required int durationMs,
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       filePath = Value(filePath),
       timestamp = Value(timestamp),
       durationMs = Value(durationMs);
  static Insertable<AudioProcessingQueueRow> custom({
    Expression<String>? id,
    Expression<String>? filePath,
    Expression<int>? timestamp,
    Expression<int>? durationMs,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filePath != null) 'file_path': filePath,
      if (timestamp != null) 'timestamp': timestamp,
      if (durationMs != null) 'duration_ms': durationMs,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioProcessingQueueEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? filePath,
    Value<int>? timestamp,
    Value<int>? durationMs,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return AudioProcessingQueueEntriesCompanion(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      timestamp: timestamp ?? this.timestamp,
      durationMs: durationMs ?? this.durationMs,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioProcessingQueueEntriesCompanion(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('timestamp: $timestamp, ')
          ..write('durationMs: $durationMs, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CaptureAudioMetadataEntriesTable extends CaptureAudioMetadataEntries
    with TableInfo<$CaptureAudioMetadataEntriesTable, CaptureAudioMetadataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CaptureAudioMetadataEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    defaultValue: const Constant('pending_analysis'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, filePath, createdAt, status];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'capture_audio_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<CaptureAudioMetadataRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CaptureAudioMetadataRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CaptureAudioMetadataRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $CaptureAudioMetadataEntriesTable createAlias(String alias) {
    return $CaptureAudioMetadataEntriesTable(attachedDatabase, alias);
  }
}

class CaptureAudioMetadataRow extends DataClass
    implements Insertable<CaptureAudioMetadataRow> {
  final String id;
  final String filePath;
  final int createdAt;
  final String status;
  const CaptureAudioMetadataRow({
    required this.id,
    required this.filePath,
    required this.createdAt,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['file_path'] = Variable<String>(filePath);
    map['created_at'] = Variable<int>(createdAt);
    map['status'] = Variable<String>(status);
    return map;
  }

  CaptureAudioMetadataEntriesCompanion toCompanion(bool nullToAbsent) {
    return CaptureAudioMetadataEntriesCompanion(
      id: Value(id),
      filePath: Value(filePath),
      createdAt: Value(createdAt),
      status: Value(status),
    );
  }

  factory CaptureAudioMetadataRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CaptureAudioMetadataRow(
      id: serializer.fromJson<String>(json['id']),
      filePath: serializer.fromJson<String>(json['filePath']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'filePath': serializer.toJson<String>(filePath),
      'createdAt': serializer.toJson<int>(createdAt),
      'status': serializer.toJson<String>(status),
    };
  }

  CaptureAudioMetadataRow copyWith({
    String? id,
    String? filePath,
    int? createdAt,
    String? status,
  }) => CaptureAudioMetadataRow(
    id: id ?? this.id,
    filePath: filePath ?? this.filePath,
    createdAt: createdAt ?? this.createdAt,
    status: status ?? this.status,
  );
  CaptureAudioMetadataRow copyWithCompanion(
    CaptureAudioMetadataEntriesCompanion data,
  ) {
    return CaptureAudioMetadataRow(
      id: data.id.present ? data.id.value : this.id,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CaptureAudioMetadataRow(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, filePath, createdAt, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CaptureAudioMetadataRow &&
          other.id == this.id &&
          other.filePath == this.filePath &&
          other.createdAt == this.createdAt &&
          other.status == this.status);
}

class CaptureAudioMetadataEntriesCompanion
    extends UpdateCompanion<CaptureAudioMetadataRow> {
  final Value<String> id;
  final Value<String> filePath;
  final Value<int> createdAt;
  final Value<String> status;
  final Value<int> rowid;
  const CaptureAudioMetadataEntriesCompanion({
    this.id = const Value.absent(),
    this.filePath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CaptureAudioMetadataEntriesCompanion.insert({
    required String id,
    required String filePath,
    required int createdAt,
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       filePath = Value(filePath),
       createdAt = Value(createdAt);
  static Insertable<CaptureAudioMetadataRow> custom({
    Expression<String>? id,
    Expression<String>? filePath,
    Expression<int>? createdAt,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filePath != null) 'file_path': filePath,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CaptureAudioMetadataEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? filePath,
    Value<int>? createdAt,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return CaptureAudioMetadataEntriesCompanion(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CaptureAudioMetadataEntriesCompanion(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $JournalEntriesTable journalEntries = $JournalEntriesTable(this);
  late final $SyncOutboxEntriesTable syncOutboxEntries =
      $SyncOutboxEntriesTable(this);
  late final $ReflectionEmbeddingsTable reflectionEmbeddings =
      $ReflectionEmbeddingsTable(this);
  late final $ReflectionGraphNodesTable reflectionGraphNodes =
      $ReflectionGraphNodesTable(this);
  late final $AppSqliteMetaTable appSqliteMeta = $AppSqliteMetaTable(this);
  late final $EntryEdgesTable entryEdges = $EntryEdgesTable(this);
  late final $FactLedgerEntriesTable factLedgerEntries =
      $FactLedgerEntriesTable(this);
  late final $AccountIdentitiesTable accountIdentities =
      $AccountIdentitiesTable(this);
  late final $UserRelationshipsTable userRelationships =
      $UserRelationshipsTable(this);
  late final $AccountProStatusTable accountProStatus = $AccountProStatusTable(
    this,
  );
  late final $MemoryTranscriptEmbeddingsTable memoryTranscriptEmbeddings =
      $MemoryTranscriptEmbeddingsTable(this);
  late final $JournalImageEmbeddingsTable journalImageEmbeddings =
      $JournalImageEmbeddingsTable(this);
  late final $QuickCaptureOutboxEntriesTable quickCaptureOutboxEntries =
      $QuickCaptureOutboxEntriesTable(this);
  late final $EmbeddingDeferredQueueEntriesTable embeddingDeferredQueueEntries =
      $EmbeddingDeferredQueueEntriesTable(this);
  late final $AudioProcessingQueueEntriesTable audioProcessingQueueEntries =
      $AudioProcessingQueueEntriesTable(this);
  late final $CaptureAudioMetadataEntriesTable captureAudioMetadataEntries =
      $CaptureAudioMetadataEntriesTable(this);
  late final Index idxReflectionGraphNodesEntryId = Index(
    'idx_reflection_graph_nodes_entry_id',
    'CREATE INDEX idx_reflection_graph_nodes_entry_id ON reflection_graph_nodes (entry_id)',
  );
  late final Index idxReflectionGraphNodesKind = Index(
    'idx_reflection_graph_nodes_kind',
    'CREATE INDEX idx_reflection_graph_nodes_kind ON reflection_graph_nodes (kind)',
  );
  late final Index idxEntryEdgesSource = Index(
    'idx_entry_edges_source',
    'CREATE INDEX idx_entry_edges_source ON entry_edges (source_entry_id)',
  );
  late final Index idxEntryEdgesTarget = Index(
    'idx_entry_edges_target',
    'CREATE INDEX idx_entry_edges_target ON entry_edges (target_entry_id)',
  );
  late final Index idxFactLedgerSourceEntry = Index(
    'idx_fact_ledger_source_entry',
    'CREATE INDEX idx_fact_ledger_source_entry ON fact_ledger (source_entry_id)',
  );
  late final Index idxFactLedgerUpdatedAt = Index(
    'idx_fact_ledger_updated_at',
    'CREATE INDEX idx_fact_ledger_updated_at ON fact_ledger (updated_at)',
  );
  late final Index idxUserRelationshipsClient = Index(
    'idx_user_relationships_client',
    'CREATE INDEX idx_user_relationships_client ON user_relationships (client_id)',
  );
  late final Index idxUserRelationshipsProfessional = Index(
    'idx_user_relationships_professional',
    'CREATE INDEX idx_user_relationships_professional ON user_relationships (professional_id)',
  );
  late final Index idxUserRelationshipsStatus = Index(
    'idx_user_relationships_status',
    'CREATE INDEX idx_user_relationships_status ON user_relationships (consent_status)',
  );
  late final Index idxJournalImageEmbeddingsEntryId = Index(
    'idx_journal_image_embeddings_entry_id',
    'CREATE INDEX idx_journal_image_embeddings_entry_id ON journal_image_embeddings (entry_id)',
  );
  late final Index idxEmbeddingDeferredQueueCreated = Index(
    'idx_embedding_deferred_queue_created',
    'CREATE INDEX idx_embedding_deferred_queue_created ON embedding_deferred_queue (created_at)',
  );
  late final JournalDao journalDao = JournalDao(this as AppDatabase);
  late final ReflectionGraphDao reflectionGraphDao = ReflectionGraphDao(
    this as AppDatabase,
  );
  late final FactLedgerDao factLedgerDao = FactLedgerDao(this as AppDatabase);
  late final EntryEdgesDao entryEdgesDao = EntryEdgesDao(this as AppDatabase);
  late final AccountDao accountDao = AccountDao(this as AppDatabase);
  late final QueueDao queueDao = QueueDao(this as AppDatabase);
  late final TranscriptEmbeddingsDao transcriptEmbeddingsDao =
      TranscriptEmbeddingsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    journalEntries,
    syncOutboxEntries,
    reflectionEmbeddings,
    reflectionGraphNodes,
    appSqliteMeta,
    entryEdges,
    factLedgerEntries,
    accountIdentities,
    userRelationships,
    accountProStatus,
    memoryTranscriptEmbeddings,
    journalImageEmbeddings,
    quickCaptureOutboxEntries,
    embeddingDeferredQueueEntries,
    audioProcessingQueueEntries,
    captureAudioMetadataEntries,
    idxReflectionGraphNodesEntryId,
    idxReflectionGraphNodesKind,
    idxEntryEdgesSource,
    idxEntryEdgesTarget,
    idxFactLedgerSourceEntry,
    idxFactLedgerUpdatedAt,
    idxUserRelationshipsClient,
    idxUserRelationshipsProfessional,
    idxUserRelationshipsStatus,
    idxJournalImageEmbeddingsEntryId,
    idxEmbeddingDeferredQueueCreated,
  ];
}

typedef $$JournalEntriesTableCreateCompanionBuilder =
    JournalEntriesCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      required int isArchived,
      required String transcript,
      required int hasVerifiedProof,
      Value<String?> payloadJson,
      Value<int> rowid,
    });
typedef $$JournalEntriesTableUpdateCompanionBuilder =
    JournalEntriesCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> isArchived,
      Value<String> transcript,
      Value<int> hasVerifiedProof,
      Value<String?> payloadJson,
      Value<int> rowid,
    });

final class $$JournalEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $JournalEntriesTable, JournalEntryRow> {
  $$JournalEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $ReflectionGraphNodesTable,
    List<ReflectionGraphNodeRow>
  >
  _reflectionGraphNodesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.reflectionGraphNodes,
        aliasName: 'journal_entries__id__reflection_graph_nodes__entry_id',
      );

  $$ReflectionGraphNodesTableProcessedTableManager
  get reflectionGraphNodesRefs {
    final manager = $$ReflectionGraphNodesTableTableManager(
      $_db,
      $_db.reflectionGraphNodes,
    ).filter((f) => f.entryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _reflectionGraphNodesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $MemoryTranscriptEmbeddingsTable,
    List<MemoryTranscriptEmbeddingRow>
  >
  _memoryTranscriptEmbeddingsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.memoryTranscriptEmbeddings,
        aliasName:
            'journal_entries__id__memory_transcript_embeddings__entry_id',
      );

  $$MemoryTranscriptEmbeddingsTableProcessedTableManager
  get memoryTranscriptEmbeddingsRefs {
    final manager = $$MemoryTranscriptEmbeddingsTableTableManager(
      $_db,
      $_db.memoryTranscriptEmbeddings,
    ).filter((f) => f.entryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _memoryTranscriptEmbeddingsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $JournalImageEmbeddingsTable,
    List<JournalImageEmbeddingRow>
  >
  _journalImageEmbeddingsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.journalImageEmbeddings,
        aliasName: 'journal_entries__id__journal_image_embeddings__entry_id',
      );

  $$JournalImageEmbeddingsTableProcessedTableManager
  get journalImageEmbeddingsRefs {
    final manager = $$JournalImageEmbeddingsTableTableManager(
      $_db,
      $_db.journalImageEmbeddings,
    ).filter((f) => f.entryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _journalImageEmbeddingsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$JournalEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hasVerifiedProof => $composableBuilder(
    column: $table.hasVerifiedProof,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> reflectionGraphNodesRefs(
    Expression<bool> Function($$ReflectionGraphNodesTableFilterComposer f) f,
  ) {
    final $$ReflectionGraphNodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reflectionGraphNodes,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReflectionGraphNodesTableFilterComposer(
            $db: $db,
            $table: $db.reflectionGraphNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> memoryTranscriptEmbeddingsRefs(
    Expression<bool> Function($$MemoryTranscriptEmbeddingsTableFilterComposer f)
    f,
  ) {
    final $$MemoryTranscriptEmbeddingsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.memoryTranscriptEmbeddings,
          getReferencedColumn: (t) => t.entryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MemoryTranscriptEmbeddingsTableFilterComposer(
                $db: $db,
                $table: $db.memoryTranscriptEmbeddings,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> journalImageEmbeddingsRefs(
    Expression<bool> Function($$JournalImageEmbeddingsTableFilterComposer f) f,
  ) {
    final $$JournalImageEmbeddingsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.journalImageEmbeddings,
          getReferencedColumn: (t) => t.entryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$JournalImageEmbeddingsTableFilterComposer(
                $db: $db,
                $table: $db.journalImageEmbeddings,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$JournalEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hasVerifiedProof => $composableBuilder(
    column: $table.hasVerifiedProof,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JournalEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hasVerifiedProof => $composableBuilder(
    column: $table.hasVerifiedProof,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  Expression<T> reflectionGraphNodesRefs<T extends Object>(
    Expression<T> Function($$ReflectionGraphNodesTableAnnotationComposer a) f,
  ) {
    final $$ReflectionGraphNodesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.reflectionGraphNodes,
          getReferencedColumn: (t) => t.entryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ReflectionGraphNodesTableAnnotationComposer(
                $db: $db,
                $table: $db.reflectionGraphNodes,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> memoryTranscriptEmbeddingsRefs<T extends Object>(
    Expression<T> Function(
      $$MemoryTranscriptEmbeddingsTableAnnotationComposer a,
    )
    f,
  ) {
    final $$MemoryTranscriptEmbeddingsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.memoryTranscriptEmbeddings,
          getReferencedColumn: (t) => t.entryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MemoryTranscriptEmbeddingsTableAnnotationComposer(
                $db: $db,
                $table: $db.memoryTranscriptEmbeddings,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> journalImageEmbeddingsRefs<T extends Object>(
    Expression<T> Function($$JournalImageEmbeddingsTableAnnotationComposer a) f,
  ) {
    final $$JournalImageEmbeddingsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.journalImageEmbeddings,
          getReferencedColumn: (t) => t.entryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$JournalImageEmbeddingsTableAnnotationComposer(
                $db: $db,
                $table: $db.journalImageEmbeddings,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$JournalEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $JournalEntriesTable,
          JournalEntryRow,
          $$JournalEntriesTableFilterComposer,
          $$JournalEntriesTableOrderingComposer,
          $$JournalEntriesTableAnnotationComposer,
          $$JournalEntriesTableCreateCompanionBuilder,
          $$JournalEntriesTableUpdateCompanionBuilder,
          (JournalEntryRow, $$JournalEntriesTableReferences),
          JournalEntryRow,
          PrefetchHooks Function({
            bool reflectionGraphNodesRefs,
            bool memoryTranscriptEmbeddingsRefs,
            bool journalImageEmbeddingsRefs,
          })
        > {
  $$JournalEntriesTableTableManager(
    _$AppDatabase db,
    $JournalEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JournalEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JournalEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JournalEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> isArchived = const Value.absent(),
                Value<String> transcript = const Value.absent(),
                Value<int> hasVerifiedProof = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalEntriesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                isArchived: isArchived,
                transcript: transcript,
                hasVerifiedProof: hasVerifiedProof,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required int isArchived,
                required String transcript,
                required int hasVerifiedProof,
                Value<String?> payloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalEntriesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                isArchived: isArchived,
                transcript: transcript,
                hasVerifiedProof: hasVerifiedProof,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$JournalEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                reflectionGraphNodesRefs = false,
                memoryTranscriptEmbeddingsRefs = false,
                journalImageEmbeddingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (reflectionGraphNodesRefs) db.reflectionGraphNodes,
                    if (memoryTranscriptEmbeddingsRefs)
                      db.memoryTranscriptEmbeddings,
                    if (journalImageEmbeddingsRefs) db.journalImageEmbeddings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (reflectionGraphNodesRefs)
                        await $_getPrefetchedData<
                          JournalEntryRow,
                          $JournalEntriesTable,
                          ReflectionGraphNodeRow
                        >(
                          currentTable: table,
                          referencedTable: $$JournalEntriesTableReferences
                              ._reflectionGraphNodesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$JournalEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).reflectionGraphNodesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.entryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (memoryTranscriptEmbeddingsRefs)
                        await $_getPrefetchedData<
                          JournalEntryRow,
                          $JournalEntriesTable,
                          MemoryTranscriptEmbeddingRow
                        >(
                          currentTable: table,
                          referencedTable: $$JournalEntriesTableReferences
                              ._memoryTranscriptEmbeddingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$JournalEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).memoryTranscriptEmbeddingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.entryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (journalImageEmbeddingsRefs)
                        await $_getPrefetchedData<
                          JournalEntryRow,
                          $JournalEntriesTable,
                          JournalImageEmbeddingRow
                        >(
                          currentTable: table,
                          referencedTable: $$JournalEntriesTableReferences
                              ._journalImageEmbeddingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$JournalEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).journalImageEmbeddingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.entryId == item.id,
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

typedef $$JournalEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $JournalEntriesTable,
      JournalEntryRow,
      $$JournalEntriesTableFilterComposer,
      $$JournalEntriesTableOrderingComposer,
      $$JournalEntriesTableAnnotationComposer,
      $$JournalEntriesTableCreateCompanionBuilder,
      $$JournalEntriesTableUpdateCompanionBuilder,
      (JournalEntryRow, $$JournalEntriesTableReferences),
      JournalEntryRow,
      PrefetchHooks Function({
        bool reflectionGraphNodesRefs,
        bool memoryTranscriptEmbeddingsRefs,
        bool journalImageEmbeddingsRefs,
      })
    >;
typedef $$SyncOutboxEntriesTableCreateCompanionBuilder =
    SyncOutboxEntriesCompanion Function({
      required String outboxId,
      required String blobId,
      required String blobType,
      required String payloadJson,
      required String status,
      required int attemptCount,
      Value<String?> lastError,
      required int createdAt,
      required int updatedAt,
      Value<int?> nextRetryAt,
      Value<int> rowid,
    });
typedef $$SyncOutboxEntriesTableUpdateCompanionBuilder =
    SyncOutboxEntriesCompanion Function({
      Value<String> outboxId,
      Value<String> blobId,
      Value<String> blobType,
      Value<String> payloadJson,
      Value<String> status,
      Value<int> attemptCount,
      Value<String?> lastError,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> nextRetryAt,
      Value<int> rowid,
    });

class $$SyncOutboxEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxEntriesTable> {
  $$SyncOutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get outboxId => $composableBuilder(
    column: $table.outboxId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blobType => $composableBuilder(
    column: $table.blobType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxEntriesTable> {
  $$SyncOutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get outboxId => $composableBuilder(
    column: $table.outboxId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blobType => $composableBuilder(
    column: $table.blobType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxEntriesTable> {
  $$SyncOutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get outboxId =>
      $composableBuilder(column: $table.outboxId, builder: (column) => column);

  GeneratedColumn<String> get blobId =>
      $composableBuilder(column: $table.blobId, builder: (column) => column);

  GeneratedColumn<String> get blobType =>
      $composableBuilder(column: $table.blobType, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );
}

class $$SyncOutboxEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxEntriesTable,
          SyncOutboxRow,
          $$SyncOutboxEntriesTableFilterComposer,
          $$SyncOutboxEntriesTableOrderingComposer,
          $$SyncOutboxEntriesTableAnnotationComposer,
          $$SyncOutboxEntriesTableCreateCompanionBuilder,
          $$SyncOutboxEntriesTableUpdateCompanionBuilder,
          (
            SyncOutboxRow,
            BaseReferences<
              _$AppDatabase,
              $SyncOutboxEntriesTable,
              SyncOutboxRow
            >,
          ),
          SyncOutboxRow,
          PrefetchHooks Function()
        > {
  $$SyncOutboxEntriesTableTableManager(
    _$AppDatabase db,
    $SyncOutboxEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> outboxId = const Value.absent(),
                Value<String> blobId = const Value.absent(),
                Value<String> blobType = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> nextRetryAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxEntriesCompanion(
                outboxId: outboxId,
                blobId: blobId,
                blobType: blobType,
                payloadJson: payloadJson,
                status: status,
                attemptCount: attemptCount,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                nextRetryAt: nextRetryAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String outboxId,
                required String blobId,
                required String blobType,
                required String payloadJson,
                required String status,
                required int attemptCount,
                Value<String?> lastError = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> nextRetryAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxEntriesCompanion.insert(
                outboxId: outboxId,
                blobId: blobId,
                blobType: blobType,
                payloadJson: payloadJson,
                status: status,
                attemptCount: attemptCount,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                nextRetryAt: nextRetryAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxEntriesTable,
      SyncOutboxRow,
      $$SyncOutboxEntriesTableFilterComposer,
      $$SyncOutboxEntriesTableOrderingComposer,
      $$SyncOutboxEntriesTableAnnotationComposer,
      $$SyncOutboxEntriesTableCreateCompanionBuilder,
      $$SyncOutboxEntriesTableUpdateCompanionBuilder,
      (
        SyncOutboxRow,
        BaseReferences<_$AppDatabase, $SyncOutboxEntriesTable, SyncOutboxRow>,
      ),
      SyncOutboxRow,
      PrefetchHooks Function()
    >;
typedef $$ReflectionEmbeddingsTableCreateCompanionBuilder =
    ReflectionEmbeddingsCompanion Function({
      required String entryId,
      required Uint8List embedding,
      required int dimensions,
      required String contentHash,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ReflectionEmbeddingsTableUpdateCompanionBuilder =
    ReflectionEmbeddingsCompanion Function({
      Value<String> entryId,
      Value<Uint8List> embedding,
      Value<int> dimensions,
      Value<String> contentHash,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$ReflectionEmbeddingsTableFilterComposer
    extends Composer<_$AppDatabase, $ReflectionEmbeddingsTable> {
  $$ReflectionEmbeddingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReflectionEmbeddingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReflectionEmbeddingsTable> {
  $$ReflectionEmbeddingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReflectionEmbeddingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReflectionEmbeddingsTable> {
  $$ReflectionEmbeddingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReflectionEmbeddingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReflectionEmbeddingsTable,
          ReflectionEmbeddingRow,
          $$ReflectionEmbeddingsTableFilterComposer,
          $$ReflectionEmbeddingsTableOrderingComposer,
          $$ReflectionEmbeddingsTableAnnotationComposer,
          $$ReflectionEmbeddingsTableCreateCompanionBuilder,
          $$ReflectionEmbeddingsTableUpdateCompanionBuilder,
          (
            ReflectionEmbeddingRow,
            BaseReferences<
              _$AppDatabase,
              $ReflectionEmbeddingsTable,
              ReflectionEmbeddingRow
            >,
          ),
          ReflectionEmbeddingRow,
          PrefetchHooks Function()
        > {
  $$ReflectionEmbeddingsTableTableManager(
    _$AppDatabase db,
    $ReflectionEmbeddingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReflectionEmbeddingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReflectionEmbeddingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ReflectionEmbeddingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<Uint8List> embedding = const Value.absent(),
                Value<int> dimensions = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReflectionEmbeddingsCompanion(
                entryId: entryId,
                embedding: embedding,
                dimensions: dimensions,
                contentHash: contentHash,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required Uint8List embedding,
                required int dimensions,
                required String contentHash,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReflectionEmbeddingsCompanion.insert(
                entryId: entryId,
                embedding: embedding,
                dimensions: dimensions,
                contentHash: contentHash,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReflectionEmbeddingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReflectionEmbeddingsTable,
      ReflectionEmbeddingRow,
      $$ReflectionEmbeddingsTableFilterComposer,
      $$ReflectionEmbeddingsTableOrderingComposer,
      $$ReflectionEmbeddingsTableAnnotationComposer,
      $$ReflectionEmbeddingsTableCreateCompanionBuilder,
      $$ReflectionEmbeddingsTableUpdateCompanionBuilder,
      (
        ReflectionEmbeddingRow,
        BaseReferences<
          _$AppDatabase,
          $ReflectionEmbeddingsTable,
          ReflectionEmbeddingRow
        >,
      ),
      ReflectionEmbeddingRow,
      PrefetchHooks Function()
    >;
typedef $$ReflectionGraphNodesTableCreateCompanionBuilder =
    ReflectionGraphNodesCompanion Function({
      required String id,
      required String entryId,
      required String kind,
      required String label,
      Value<String?> payloadJson,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ReflectionGraphNodesTableUpdateCompanionBuilder =
    ReflectionGraphNodesCompanion Function({
      Value<String> id,
      Value<String> entryId,
      Value<String> kind,
      Value<String> label,
      Value<String?> payloadJson,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$ReflectionGraphNodesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ReflectionGraphNodesTable,
          ReflectionGraphNodeRow
        > {
  $$ReflectionGraphNodesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $JournalEntriesTable _entryIdTable(_$AppDatabase db) => db
      .journalEntries
      .createAlias('reflection_graph_nodes__entry_id__journal_entries__id');

  $$JournalEntriesTableProcessedTableManager get entryId {
    final $_column = $_itemColumn<String>('entry_id')!;

    final manager = $$JournalEntriesTableTableManager(
      $_db,
      $_db.journalEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReflectionGraphNodesTableFilterComposer
    extends Composer<_$AppDatabase, $ReflectionGraphNodesTable> {
  $$ReflectionGraphNodesTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$JournalEntriesTableFilterComposer get entryId {
    final $$JournalEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.journalEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JournalEntriesTableFilterComposer(
            $db: $db,
            $table: $db.journalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReflectionGraphNodesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReflectionGraphNodesTable> {
  $$ReflectionGraphNodesTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$JournalEntriesTableOrderingComposer get entryId {
    final $$JournalEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.journalEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JournalEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.journalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReflectionGraphNodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReflectionGraphNodesTable> {
  $$ReflectionGraphNodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$JournalEntriesTableAnnotationComposer get entryId {
    final $$JournalEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.journalEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JournalEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.journalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReflectionGraphNodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReflectionGraphNodesTable,
          ReflectionGraphNodeRow,
          $$ReflectionGraphNodesTableFilterComposer,
          $$ReflectionGraphNodesTableOrderingComposer,
          $$ReflectionGraphNodesTableAnnotationComposer,
          $$ReflectionGraphNodesTableCreateCompanionBuilder,
          $$ReflectionGraphNodesTableUpdateCompanionBuilder,
          (ReflectionGraphNodeRow, $$ReflectionGraphNodesTableReferences),
          ReflectionGraphNodeRow,
          PrefetchHooks Function({bool entryId})
        > {
  $$ReflectionGraphNodesTableTableManager(
    _$AppDatabase db,
    $ReflectionGraphNodesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReflectionGraphNodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReflectionGraphNodesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ReflectionGraphNodesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entryId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReflectionGraphNodesCompanion(
                id: id,
                entryId: entryId,
                kind: kind,
                label: label,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entryId,
                required String kind,
                required String label,
                Value<String?> payloadJson = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReflectionGraphNodesCompanion.insert(
                id: id,
                entryId: entryId,
                kind: kind,
                label: label,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReflectionGraphNodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({entryId = false}) {
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
                    if (entryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.entryId,
                                referencedTable:
                                    $$ReflectionGraphNodesTableReferences
                                        ._entryIdTable(db),
                                referencedColumn:
                                    $$ReflectionGraphNodesTableReferences
                                        ._entryIdTable(db)
                                        .id,
                              )
                              as T;
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

typedef $$ReflectionGraphNodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReflectionGraphNodesTable,
      ReflectionGraphNodeRow,
      $$ReflectionGraphNodesTableFilterComposer,
      $$ReflectionGraphNodesTableOrderingComposer,
      $$ReflectionGraphNodesTableAnnotationComposer,
      $$ReflectionGraphNodesTableCreateCompanionBuilder,
      $$ReflectionGraphNodesTableUpdateCompanionBuilder,
      (ReflectionGraphNodeRow, $$ReflectionGraphNodesTableReferences),
      ReflectionGraphNodeRow,
      PrefetchHooks Function({bool entryId})
    >;
typedef $$AppSqliteMetaTableCreateCompanionBuilder =
    AppSqliteMetaCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSqliteMetaTableUpdateCompanionBuilder =
    AppSqliteMetaCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSqliteMetaTableFilterComposer
    extends Composer<_$AppDatabase, $AppSqliteMetaTable> {
  $$AppSqliteMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSqliteMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSqliteMetaTable> {
  $$AppSqliteMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSqliteMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSqliteMetaTable> {
  $$AppSqliteMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSqliteMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSqliteMetaTable,
          AppSqliteMetaRow,
          $$AppSqliteMetaTableFilterComposer,
          $$AppSqliteMetaTableOrderingComposer,
          $$AppSqliteMetaTableAnnotationComposer,
          $$AppSqliteMetaTableCreateCompanionBuilder,
          $$AppSqliteMetaTableUpdateCompanionBuilder,
          (
            AppSqliteMetaRow,
            BaseReferences<
              _$AppDatabase,
              $AppSqliteMetaTable,
              AppSqliteMetaRow
            >,
          ),
          AppSqliteMetaRow,
          PrefetchHooks Function()
        > {
  $$AppSqliteMetaTableTableManager(_$AppDatabase db, $AppSqliteMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSqliteMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSqliteMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSqliteMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  AppSqliteMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSqliteMetaCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSqliteMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSqliteMetaTable,
      AppSqliteMetaRow,
      $$AppSqliteMetaTableFilterComposer,
      $$AppSqliteMetaTableOrderingComposer,
      $$AppSqliteMetaTableAnnotationComposer,
      $$AppSqliteMetaTableCreateCompanionBuilder,
      $$AppSqliteMetaTableUpdateCompanionBuilder,
      (
        AppSqliteMetaRow,
        BaseReferences<_$AppDatabase, $AppSqliteMetaTable, AppSqliteMetaRow>,
      ),
      AppSqliteMetaRow,
      PrefetchHooks Function()
    >;
typedef $$EntryEdgesTableCreateCompanionBuilder =
    EntryEdgesCompanion Function({
      required String sourceEntryId,
      required String targetEntryId,
      Value<String> relation,
      required double weight,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$EntryEdgesTableUpdateCompanionBuilder =
    EntryEdgesCompanion Function({
      Value<String> sourceEntryId,
      Value<String> targetEntryId,
      Value<String> relation,
      Value<double> weight,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$EntryEdgesTableFilterComposer
    extends Composer<_$AppDatabase, $EntryEdgesTable> {
  $$EntryEdgesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceEntryId => $composableBuilder(
    column: $table.sourceEntryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetEntryId => $composableBuilder(
    column: $table.targetEntryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relation => $composableBuilder(
    column: $table.relation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntryEdgesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntryEdgesTable> {
  $$EntryEdgesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceEntryId => $composableBuilder(
    column: $table.sourceEntryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetEntryId => $composableBuilder(
    column: $table.targetEntryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relation => $composableBuilder(
    column: $table.relation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntryEdgesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntryEdgesTable> {
  $$EntryEdgesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceEntryId => $composableBuilder(
    column: $table.sourceEntryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetEntryId => $composableBuilder(
    column: $table.targetEntryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relation =>
      $composableBuilder(column: $table.relation, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$EntryEdgesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntryEdgesTable,
          EntryEdgeRow,
          $$EntryEdgesTableFilterComposer,
          $$EntryEdgesTableOrderingComposer,
          $$EntryEdgesTableAnnotationComposer,
          $$EntryEdgesTableCreateCompanionBuilder,
          $$EntryEdgesTableUpdateCompanionBuilder,
          (
            EntryEdgeRow,
            BaseReferences<_$AppDatabase, $EntryEdgesTable, EntryEdgeRow>,
          ),
          EntryEdgeRow,
          PrefetchHooks Function()
        > {
  $$EntryEdgesTableTableManager(_$AppDatabase db, $EntryEdgesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntryEdgesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntryEdgesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntryEdgesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceEntryId = const Value.absent(),
                Value<String> targetEntryId = const Value.absent(),
                Value<String> relation = const Value.absent(),
                Value<double> weight = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntryEdgesCompanion(
                sourceEntryId: sourceEntryId,
                targetEntryId: targetEntryId,
                relation: relation,
                weight: weight,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceEntryId,
                required String targetEntryId,
                Value<String> relation = const Value.absent(),
                required double weight,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => EntryEdgesCompanion.insert(
                sourceEntryId: sourceEntryId,
                targetEntryId: targetEntryId,
                relation: relation,
                weight: weight,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntryEdgesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntryEdgesTable,
      EntryEdgeRow,
      $$EntryEdgesTableFilterComposer,
      $$EntryEdgesTableOrderingComposer,
      $$EntryEdgesTableAnnotationComposer,
      $$EntryEdgesTableCreateCompanionBuilder,
      $$EntryEdgesTableUpdateCompanionBuilder,
      (
        EntryEdgeRow,
        BaseReferences<_$AppDatabase, $EntryEdgesTable, EntryEdgeRow>,
      ),
      EntryEdgeRow,
      PrefetchHooks Function()
    >;
typedef $$FactLedgerEntriesTableCreateCompanionBuilder =
    FactLedgerEntriesCompanion Function({
      required String id,
      required String sourceEntryId,
      required String label,
      required String value,
      Value<String> note,
      required int createdAt,
      required int updatedAt,
      required String factType,
      Value<String?> archivePackId,
      Value<String?> archiveThreadId,
      Value<String> collectionIdsJson,
      Value<int> isPinned,
      Value<int> preserveOriginal,
      Value<int> rowid,
    });
typedef $$FactLedgerEntriesTableUpdateCompanionBuilder =
    FactLedgerEntriesCompanion Function({
      Value<String> id,
      Value<String> sourceEntryId,
      Value<String> label,
      Value<String> value,
      Value<String> note,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> factType,
      Value<String?> archivePackId,
      Value<String?> archiveThreadId,
      Value<String> collectionIdsJson,
      Value<int> isPinned,
      Value<int> preserveOriginal,
      Value<int> rowid,
    });

class $$FactLedgerEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $FactLedgerEntriesTable> {
  $$FactLedgerEntriesTableFilterComposer({
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

  ColumnFilters<String> get sourceEntryId => $composableBuilder(
    column: $table.sourceEntryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get factType => $composableBuilder(
    column: $table.factType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archivePackId => $composableBuilder(
    column: $table.archivePackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archiveThreadId => $composableBuilder(
    column: $table.archiveThreadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionIdsJson => $composableBuilder(
    column: $table.collectionIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get preserveOriginal => $composableBuilder(
    column: $table.preserveOriginal,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FactLedgerEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $FactLedgerEntriesTable> {
  $$FactLedgerEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get sourceEntryId => $composableBuilder(
    column: $table.sourceEntryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get factType => $composableBuilder(
    column: $table.factType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archivePackId => $composableBuilder(
    column: $table.archivePackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archiveThreadId => $composableBuilder(
    column: $table.archiveThreadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionIdsJson => $composableBuilder(
    column: $table.collectionIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get preserveOriginal => $composableBuilder(
    column: $table.preserveOriginal,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FactLedgerEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FactLedgerEntriesTable> {
  $$FactLedgerEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceEntryId => $composableBuilder(
    column: $table.sourceEntryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get factType =>
      $composableBuilder(column: $table.factType, builder: (column) => column);

  GeneratedColumn<String> get archivePackId => $composableBuilder(
    column: $table.archivePackId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get archiveThreadId => $composableBuilder(
    column: $table.archiveThreadId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get collectionIdsJson => $composableBuilder(
    column: $table.collectionIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<int> get preserveOriginal => $composableBuilder(
    column: $table.preserveOriginal,
    builder: (column) => column,
  );
}

class $$FactLedgerEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FactLedgerEntriesTable,
          FactLedgerRow,
          $$FactLedgerEntriesTableFilterComposer,
          $$FactLedgerEntriesTableOrderingComposer,
          $$FactLedgerEntriesTableAnnotationComposer,
          $$FactLedgerEntriesTableCreateCompanionBuilder,
          $$FactLedgerEntriesTableUpdateCompanionBuilder,
          (
            FactLedgerRow,
            BaseReferences<
              _$AppDatabase,
              $FactLedgerEntriesTable,
              FactLedgerRow
            >,
          ),
          FactLedgerRow,
          PrefetchHooks Function()
        > {
  $$FactLedgerEntriesTableTableManager(
    _$AppDatabase db,
    $FactLedgerEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FactLedgerEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FactLedgerEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FactLedgerEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceEntryId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> factType = const Value.absent(),
                Value<String?> archivePackId = const Value.absent(),
                Value<String?> archiveThreadId = const Value.absent(),
                Value<String> collectionIdsJson = const Value.absent(),
                Value<int> isPinned = const Value.absent(),
                Value<int> preserveOriginal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FactLedgerEntriesCompanion(
                id: id,
                sourceEntryId: sourceEntryId,
                label: label,
                value: value,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                factType: factType,
                archivePackId: archivePackId,
                archiveThreadId: archiveThreadId,
                collectionIdsJson: collectionIdsJson,
                isPinned: isPinned,
                preserveOriginal: preserveOriginal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceEntryId,
                required String label,
                required String value,
                Value<String> note = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                required String factType,
                Value<String?> archivePackId = const Value.absent(),
                Value<String?> archiveThreadId = const Value.absent(),
                Value<String> collectionIdsJson = const Value.absent(),
                Value<int> isPinned = const Value.absent(),
                Value<int> preserveOriginal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FactLedgerEntriesCompanion.insert(
                id: id,
                sourceEntryId: sourceEntryId,
                label: label,
                value: value,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                factType: factType,
                archivePackId: archivePackId,
                archiveThreadId: archiveThreadId,
                collectionIdsJson: collectionIdsJson,
                isPinned: isPinned,
                preserveOriginal: preserveOriginal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FactLedgerEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FactLedgerEntriesTable,
      FactLedgerRow,
      $$FactLedgerEntriesTableFilterComposer,
      $$FactLedgerEntriesTableOrderingComposer,
      $$FactLedgerEntriesTableAnnotationComposer,
      $$FactLedgerEntriesTableCreateCompanionBuilder,
      $$FactLedgerEntriesTableUpdateCompanionBuilder,
      (
        FactLedgerRow,
        BaseReferences<_$AppDatabase, $FactLedgerEntriesTable, FactLedgerRow>,
      ),
      FactLedgerRow,
      PrefetchHooks Function()
    >;
typedef $$AccountIdentitiesTableCreateCompanionBuilder =
    AccountIdentitiesCompanion Function({
      required String id,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$AccountIdentitiesTableUpdateCompanionBuilder =
    AccountIdentitiesCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$AccountIdentitiesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AccountIdentitiesTable,
          AccountIdentityRow
        > {
  $$AccountIdentitiesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$UserRelationshipsTable, List<UserRelationshipRow>>
  _client_accountTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.userRelationships,
    aliasName: 'account_identities__id__user_relationships__client_id',
  );

  $$UserRelationshipsTableProcessedTableManager get client_account {
    final manager = $$UserRelationshipsTableTableManager(
      $_db,
      $_db.userRelationships,
    ).filter((f) => f.clientId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_client_accountTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$UserRelationshipsTable, List<UserRelationshipRow>>
  _professional_accountTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.userRelationships,
    aliasName: 'account_identities__id__user_relationships__professional_id',
  );

  $$UserRelationshipsTableProcessedTableManager get professional_account {
    final manager = $$UserRelationshipsTableTableManager(
      $_db,
      $_db.userRelationships,
    ).filter((f) => f.professionalId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _professional_accountTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountIdentitiesTableFilterComposer
    extends Composer<_$AppDatabase, $AccountIdentitiesTable> {
  $$AccountIdentitiesTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> client_account(
    Expression<bool> Function($$UserRelationshipsTableFilterComposer f) f,
  ) {
    final $$UserRelationshipsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userRelationships,
      getReferencedColumn: (t) => t.clientId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserRelationshipsTableFilterComposer(
            $db: $db,
            $table: $db.userRelationships,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> professional_account(
    Expression<bool> Function($$UserRelationshipsTableFilterComposer f) f,
  ) {
    final $$UserRelationshipsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userRelationships,
      getReferencedColumn: (t) => t.professionalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserRelationshipsTableFilterComposer(
            $db: $db,
            $table: $db.userRelationships,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountIdentitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountIdentitiesTable> {
  $$AccountIdentitiesTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountIdentitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountIdentitiesTable> {
  $$AccountIdentitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> client_account<T extends Object>(
    Expression<T> Function($$UserRelationshipsTableAnnotationComposer a) f,
  ) {
    final $$UserRelationshipsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.userRelationships,
          getReferencedColumn: (t) => t.clientId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$UserRelationshipsTableAnnotationComposer(
                $db: $db,
                $table: $db.userRelationships,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> professional_account<T extends Object>(
    Expression<T> Function($$UserRelationshipsTableAnnotationComposer a) f,
  ) {
    final $$UserRelationshipsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.userRelationships,
          getReferencedColumn: (t) => t.professionalId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$UserRelationshipsTableAnnotationComposer(
                $db: $db,
                $table: $db.userRelationships,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AccountIdentitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountIdentitiesTable,
          AccountIdentityRow,
          $$AccountIdentitiesTableFilterComposer,
          $$AccountIdentitiesTableOrderingComposer,
          $$AccountIdentitiesTableAnnotationComposer,
          $$AccountIdentitiesTableCreateCompanionBuilder,
          $$AccountIdentitiesTableUpdateCompanionBuilder,
          (AccountIdentityRow, $$AccountIdentitiesTableReferences),
          AccountIdentityRow,
          PrefetchHooks Function({
            bool client_account,
            bool professional_account,
          })
        > {
  $$AccountIdentitiesTableTableManager(
    _$AppDatabase db,
    $AccountIdentitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountIdentitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountIdentitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountIdentitiesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountIdentitiesCompanion(
                id: id,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AccountIdentitiesCompanion.insert(
                id: id,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AccountIdentitiesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({client_account = false, professional_account = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (client_account) db.userRelationships,
                    if (professional_account) db.userRelationships,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (client_account)
                        await $_getPrefetchedData<
                          AccountIdentityRow,
                          $AccountIdentitiesTable,
                          UserRelationshipRow
                        >(
                          currentTable: table,
                          referencedTable: $$AccountIdentitiesTableReferences
                              ._client_accountTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountIdentitiesTableReferences(
                                db,
                                table,
                                p0,
                              ).client_account,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.clientId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (professional_account)
                        await $_getPrefetchedData<
                          AccountIdentityRow,
                          $AccountIdentitiesTable,
                          UserRelationshipRow
                        >(
                          currentTable: table,
                          referencedTable: $$AccountIdentitiesTableReferences
                              ._professional_accountTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountIdentitiesTableReferences(
                                db,
                                table,
                                p0,
                              ).professional_account,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.professionalId == item.id,
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

typedef $$AccountIdentitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountIdentitiesTable,
      AccountIdentityRow,
      $$AccountIdentitiesTableFilterComposer,
      $$AccountIdentitiesTableOrderingComposer,
      $$AccountIdentitiesTableAnnotationComposer,
      $$AccountIdentitiesTableCreateCompanionBuilder,
      $$AccountIdentitiesTableUpdateCompanionBuilder,
      (AccountIdentityRow, $$AccountIdentitiesTableReferences),
      AccountIdentityRow,
      PrefetchHooks Function({bool client_account, bool professional_account})
    >;
typedef $$UserRelationshipsTableCreateCompanionBuilder =
    UserRelationshipsCompanion Function({
      required String id,
      required String clientId,
      required String professionalId,
      required String relationshipType,
      required String consentStatus,
      Value<String> agreedScope,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$UserRelationshipsTableUpdateCompanionBuilder =
    UserRelationshipsCompanion Function({
      Value<String> id,
      Value<String> clientId,
      Value<String> professionalId,
      Value<String> relationshipType,
      Value<String> consentStatus,
      Value<String> agreedScope,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$UserRelationshipsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $UserRelationshipsTable,
          UserRelationshipRow
        > {
  $$UserRelationshipsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountIdentitiesTable _clientIdTable(_$AppDatabase db) => db
      .accountIdentities
      .createAlias('user_relationships__client_id__account_identities__id');

  $$AccountIdentitiesTableProcessedTableManager get clientId {
    final $_column = $_itemColumn<String>('client_id')!;

    final manager = $$AccountIdentitiesTableTableManager(
      $_db,
      $_db.accountIdentities,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_clientIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountIdentitiesTable _professionalIdTable(_$AppDatabase db) =>
      db.accountIdentities.createAlias(
        'user_relationships__professional_id__account_identities__id',
      );

  $$AccountIdentitiesTableProcessedTableManager get professionalId {
    final $_column = $_itemColumn<String>('professional_id')!;

    final manager = $$AccountIdentitiesTableTableManager(
      $_db,
      $_db.accountIdentities,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_professionalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$UserRelationshipsTableFilterComposer
    extends Composer<_$AppDatabase, $UserRelationshipsTable> {
  $$UserRelationshipsTableFilterComposer({
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

  ColumnFilters<String> get relationshipType => $composableBuilder(
    column: $table.relationshipType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get consentStatus => $composableBuilder(
    column: $table.consentStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agreedScope => $composableBuilder(
    column: $table.agreedScope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountIdentitiesTableFilterComposer get clientId {
    final $$AccountIdentitiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clientId,
      referencedTable: $db.accountIdentities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountIdentitiesTableFilterComposer(
            $db: $db,
            $table: $db.accountIdentities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountIdentitiesTableFilterComposer get professionalId {
    final $$AccountIdentitiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.professionalId,
      referencedTable: $db.accountIdentities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountIdentitiesTableFilterComposer(
            $db: $db,
            $table: $db.accountIdentities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserRelationshipsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserRelationshipsTable> {
  $$UserRelationshipsTableOrderingComposer({
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

  ColumnOrderings<String> get relationshipType => $composableBuilder(
    column: $table.relationshipType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get consentStatus => $composableBuilder(
    column: $table.consentStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agreedScope => $composableBuilder(
    column: $table.agreedScope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountIdentitiesTableOrderingComposer get clientId {
    final $$AccountIdentitiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clientId,
      referencedTable: $db.accountIdentities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountIdentitiesTableOrderingComposer(
            $db: $db,
            $table: $db.accountIdentities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountIdentitiesTableOrderingComposer get professionalId {
    final $$AccountIdentitiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.professionalId,
      referencedTable: $db.accountIdentities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountIdentitiesTableOrderingComposer(
            $db: $db,
            $table: $db.accountIdentities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserRelationshipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserRelationshipsTable> {
  $$UserRelationshipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get relationshipType => $composableBuilder(
    column: $table.relationshipType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get consentStatus => $composableBuilder(
    column: $table.consentStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get agreedScope => $composableBuilder(
    column: $table.agreedScope,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$AccountIdentitiesTableAnnotationComposer get clientId {
    final $$AccountIdentitiesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.clientId,
          referencedTable: $db.accountIdentities,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AccountIdentitiesTableAnnotationComposer(
                $db: $db,
                $table: $db.accountIdentities,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$AccountIdentitiesTableAnnotationComposer get professionalId {
    final $$AccountIdentitiesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.professionalId,
          referencedTable: $db.accountIdentities,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AccountIdentitiesTableAnnotationComposer(
                $db: $db,
                $table: $db.accountIdentities,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$UserRelationshipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserRelationshipsTable,
          UserRelationshipRow,
          $$UserRelationshipsTableFilterComposer,
          $$UserRelationshipsTableOrderingComposer,
          $$UserRelationshipsTableAnnotationComposer,
          $$UserRelationshipsTableCreateCompanionBuilder,
          $$UserRelationshipsTableUpdateCompanionBuilder,
          (UserRelationshipRow, $$UserRelationshipsTableReferences),
          UserRelationshipRow,
          PrefetchHooks Function({bool clientId, bool professionalId})
        > {
  $$UserRelationshipsTableTableManager(
    _$AppDatabase db,
    $UserRelationshipsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserRelationshipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserRelationshipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserRelationshipsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<String> professionalId = const Value.absent(),
                Value<String> relationshipType = const Value.absent(),
                Value<String> consentStatus = const Value.absent(),
                Value<String> agreedScope = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserRelationshipsCompanion(
                id: id,
                clientId: clientId,
                professionalId: professionalId,
                relationshipType: relationshipType,
                consentStatus: consentStatus,
                agreedScope: agreedScope,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String clientId,
                required String professionalId,
                required String relationshipType,
                required String consentStatus,
                Value<String> agreedScope = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UserRelationshipsCompanion.insert(
                id: id,
                clientId: clientId,
                professionalId: professionalId,
                relationshipType: relationshipType,
                consentStatus: consentStatus,
                agreedScope: agreedScope,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$UserRelationshipsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({clientId = false, professionalId = false}) {
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
                    if (clientId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.clientId,
                                referencedTable:
                                    $$UserRelationshipsTableReferences
                                        ._clientIdTable(db),
                                referencedColumn:
                                    $$UserRelationshipsTableReferences
                                        ._clientIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (professionalId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.professionalId,
                                referencedTable:
                                    $$UserRelationshipsTableReferences
                                        ._professionalIdTable(db),
                                referencedColumn:
                                    $$UserRelationshipsTableReferences
                                        ._professionalIdTable(db)
                                        .id,
                              )
                              as T;
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

typedef $$UserRelationshipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserRelationshipsTable,
      UserRelationshipRow,
      $$UserRelationshipsTableFilterComposer,
      $$UserRelationshipsTableOrderingComposer,
      $$UserRelationshipsTableAnnotationComposer,
      $$UserRelationshipsTableCreateCompanionBuilder,
      $$UserRelationshipsTableUpdateCompanionBuilder,
      (UserRelationshipRow, $$UserRelationshipsTableReferences),
      UserRelationshipRow,
      PrefetchHooks Function({bool clientId, bool professionalId})
    >;
typedef $$AccountProStatusTableCreateCompanionBuilder =
    AccountProStatusCompanion Function({
      Value<int> id,
      Value<int> isPro,
      Value<String> tier,
      Value<String> source,
      Value<String> entitlementIdsJson,
      Value<int> billingConnected,
      Value<String> syncedFrom,
      required int updatedAt,
    });
typedef $$AccountProStatusTableUpdateCompanionBuilder =
    AccountProStatusCompanion Function({
      Value<int> id,
      Value<int> isPro,
      Value<String> tier,
      Value<String> source,
      Value<String> entitlementIdsJson,
      Value<int> billingConnected,
      Value<String> syncedFrom,
      Value<int> updatedAt,
    });

class $$AccountProStatusTableFilterComposer
    extends Composer<_$AppDatabase, $AccountProStatusTable> {
  $$AccountProStatusTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isPro => $composableBuilder(
    column: $table.isPro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entitlementIdsJson => $composableBuilder(
    column: $table.entitlementIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get billingConnected => $composableBuilder(
    column: $table.billingConnected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncedFrom => $composableBuilder(
    column: $table.syncedFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountProStatusTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountProStatusTable> {
  $$AccountProStatusTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isPro => $composableBuilder(
    column: $table.isPro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entitlementIdsJson => $composableBuilder(
    column: $table.entitlementIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get billingConnected => $composableBuilder(
    column: $table.billingConnected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncedFrom => $composableBuilder(
    column: $table.syncedFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountProStatusTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountProStatusTable> {
  $$AccountProStatusTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get isPro =>
      $composableBuilder(column: $table.isPro, builder: (column) => column);

  GeneratedColumn<String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get entitlementIdsJson => $composableBuilder(
    column: $table.entitlementIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get billingConnected => $composableBuilder(
    column: $table.billingConnected,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncedFrom => $composableBuilder(
    column: $table.syncedFrom,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AccountProStatusTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountProStatusTable,
          AccountProStatusRow,
          $$AccountProStatusTableFilterComposer,
          $$AccountProStatusTableOrderingComposer,
          $$AccountProStatusTableAnnotationComposer,
          $$AccountProStatusTableCreateCompanionBuilder,
          $$AccountProStatusTableUpdateCompanionBuilder,
          (
            AccountProStatusRow,
            BaseReferences<
              _$AppDatabase,
              $AccountProStatusTable,
              AccountProStatusRow
            >,
          ),
          AccountProStatusRow,
          PrefetchHooks Function()
        > {
  $$AccountProStatusTableTableManager(
    _$AppDatabase db,
    $AccountProStatusTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountProStatusTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountProStatusTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountProStatusTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> isPro = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> entitlementIdsJson = const Value.absent(),
                Value<int> billingConnected = const Value.absent(),
                Value<String> syncedFrom = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => AccountProStatusCompanion(
                id: id,
                isPro: isPro,
                tier: tier,
                source: source,
                entitlementIdsJson: entitlementIdsJson,
                billingConnected: billingConnected,
                syncedFrom: syncedFrom,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> isPro = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> entitlementIdsJson = const Value.absent(),
                Value<int> billingConnected = const Value.absent(),
                Value<String> syncedFrom = const Value.absent(),
                required int updatedAt,
              }) => AccountProStatusCompanion.insert(
                id: id,
                isPro: isPro,
                tier: tier,
                source: source,
                entitlementIdsJson: entitlementIdsJson,
                billingConnected: billingConnected,
                syncedFrom: syncedFrom,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountProStatusTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountProStatusTable,
      AccountProStatusRow,
      $$AccountProStatusTableFilterComposer,
      $$AccountProStatusTableOrderingComposer,
      $$AccountProStatusTableAnnotationComposer,
      $$AccountProStatusTableCreateCompanionBuilder,
      $$AccountProStatusTableUpdateCompanionBuilder,
      (
        AccountProStatusRow,
        BaseReferences<
          _$AppDatabase,
          $AccountProStatusTable,
          AccountProStatusRow
        >,
      ),
      AccountProStatusRow,
      PrefetchHooks Function()
    >;
typedef $$MemoryTranscriptEmbeddingsTableCreateCompanionBuilder =
    MemoryTranscriptEmbeddingsCompanion Function({
      required String entryId,
      required Uint8List embedding,
      required int dimensions,
      Value<int> rowid,
    });
typedef $$MemoryTranscriptEmbeddingsTableUpdateCompanionBuilder =
    MemoryTranscriptEmbeddingsCompanion Function({
      Value<String> entryId,
      Value<Uint8List> embedding,
      Value<int> dimensions,
      Value<int> rowid,
    });

final class $$MemoryTranscriptEmbeddingsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MemoryTranscriptEmbeddingsTable,
          MemoryTranscriptEmbeddingRow
        > {
  $$MemoryTranscriptEmbeddingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $JournalEntriesTable _entryIdTable(_$AppDatabase db) =>
      db.journalEntries.createAlias(
        'memory_transcript_embeddings__entry_id__journal_entries__id',
      );

  $$JournalEntriesTableProcessedTableManager get entryId {
    final $_column = $_itemColumn<String>('entry_id')!;

    final manager = $$JournalEntriesTableTableManager(
      $_db,
      $_db.journalEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MemoryTranscriptEmbeddingsTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryTranscriptEmbeddingsTable> {
  $$MemoryTranscriptEmbeddingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => ColumnFilters(column),
  );

  $$JournalEntriesTableFilterComposer get entryId {
    final $$JournalEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.journalEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JournalEntriesTableFilterComposer(
            $db: $db,
            $table: $db.journalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryTranscriptEmbeddingsTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryTranscriptEmbeddingsTable> {
  $$MemoryTranscriptEmbeddingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => ColumnOrderings(column),
  );

  $$JournalEntriesTableOrderingComposer get entryId {
    final $$JournalEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.journalEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JournalEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.journalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryTranscriptEmbeddingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryTranscriptEmbeddingsTable> {
  $$MemoryTranscriptEmbeddingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => column,
  );

  $$JournalEntriesTableAnnotationComposer get entryId {
    final $$JournalEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.journalEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JournalEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.journalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryTranscriptEmbeddingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryTranscriptEmbeddingsTable,
          MemoryTranscriptEmbeddingRow,
          $$MemoryTranscriptEmbeddingsTableFilterComposer,
          $$MemoryTranscriptEmbeddingsTableOrderingComposer,
          $$MemoryTranscriptEmbeddingsTableAnnotationComposer,
          $$MemoryTranscriptEmbeddingsTableCreateCompanionBuilder,
          $$MemoryTranscriptEmbeddingsTableUpdateCompanionBuilder,
          (
            MemoryTranscriptEmbeddingRow,
            $$MemoryTranscriptEmbeddingsTableReferences,
          ),
          MemoryTranscriptEmbeddingRow,
          PrefetchHooks Function({bool entryId})
        > {
  $$MemoryTranscriptEmbeddingsTableTableManager(
    _$AppDatabase db,
    $MemoryTranscriptEmbeddingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryTranscriptEmbeddingsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MemoryTranscriptEmbeddingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MemoryTranscriptEmbeddingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<Uint8List> embedding = const Value.absent(),
                Value<int> dimensions = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryTranscriptEmbeddingsCompanion(
                entryId: entryId,
                embedding: embedding,
                dimensions: dimensions,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required Uint8List embedding,
                required int dimensions,
                Value<int> rowid = const Value.absent(),
              }) => MemoryTranscriptEmbeddingsCompanion.insert(
                entryId: entryId,
                embedding: embedding,
                dimensions: dimensions,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemoryTranscriptEmbeddingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({entryId = false}) {
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
                    if (entryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.entryId,
                                referencedTable:
                                    $$MemoryTranscriptEmbeddingsTableReferences
                                        ._entryIdTable(db),
                                referencedColumn:
                                    $$MemoryTranscriptEmbeddingsTableReferences
                                        ._entryIdTable(db)
                                        .id,
                              )
                              as T;
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

typedef $$MemoryTranscriptEmbeddingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryTranscriptEmbeddingsTable,
      MemoryTranscriptEmbeddingRow,
      $$MemoryTranscriptEmbeddingsTableFilterComposer,
      $$MemoryTranscriptEmbeddingsTableOrderingComposer,
      $$MemoryTranscriptEmbeddingsTableAnnotationComposer,
      $$MemoryTranscriptEmbeddingsTableCreateCompanionBuilder,
      $$MemoryTranscriptEmbeddingsTableUpdateCompanionBuilder,
      (
        MemoryTranscriptEmbeddingRow,
        $$MemoryTranscriptEmbeddingsTableReferences,
      ),
      MemoryTranscriptEmbeddingRow,
      PrefetchHooks Function({bool entryId})
    >;
typedef $$JournalImageEmbeddingsTableCreateCompanionBuilder =
    JournalImageEmbeddingsCompanion Function({
      required String evidenceId,
      required String entryId,
      required Uint8List embedding,
      required int dimensions,
      Value<int> rowid,
    });
typedef $$JournalImageEmbeddingsTableUpdateCompanionBuilder =
    JournalImageEmbeddingsCompanion Function({
      Value<String> evidenceId,
      Value<String> entryId,
      Value<Uint8List> embedding,
      Value<int> dimensions,
      Value<int> rowid,
    });

final class $$JournalImageEmbeddingsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $JournalImageEmbeddingsTable,
          JournalImageEmbeddingRow
        > {
  $$JournalImageEmbeddingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $JournalEntriesTable _entryIdTable(_$AppDatabase db) => db
      .journalEntries
      .createAlias('journal_image_embeddings__entry_id__journal_entries__id');

  $$JournalEntriesTableProcessedTableManager get entryId {
    final $_column = $_itemColumn<String>('entry_id')!;

    final manager = $$JournalEntriesTableTableManager(
      $_db,
      $_db.journalEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$JournalImageEmbeddingsTableFilterComposer
    extends Composer<_$AppDatabase, $JournalImageEmbeddingsTable> {
  $$JournalImageEmbeddingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get evidenceId => $composableBuilder(
    column: $table.evidenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => ColumnFilters(column),
  );

  $$JournalEntriesTableFilterComposer get entryId {
    final $$JournalEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.journalEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JournalEntriesTableFilterComposer(
            $db: $db,
            $table: $db.journalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JournalImageEmbeddingsTableOrderingComposer
    extends Composer<_$AppDatabase, $JournalImageEmbeddingsTable> {
  $$JournalImageEmbeddingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get evidenceId => $composableBuilder(
    column: $table.evidenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => ColumnOrderings(column),
  );

  $$JournalEntriesTableOrderingComposer get entryId {
    final $$JournalEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.journalEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JournalEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.journalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JournalImageEmbeddingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $JournalImageEmbeddingsTable> {
  $$JournalImageEmbeddingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get evidenceId => $composableBuilder(
    column: $table.evidenceId,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => column,
  );

  $$JournalEntriesTableAnnotationComposer get entryId {
    final $$JournalEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.journalEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JournalEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.journalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JournalImageEmbeddingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $JournalImageEmbeddingsTable,
          JournalImageEmbeddingRow,
          $$JournalImageEmbeddingsTableFilterComposer,
          $$JournalImageEmbeddingsTableOrderingComposer,
          $$JournalImageEmbeddingsTableAnnotationComposer,
          $$JournalImageEmbeddingsTableCreateCompanionBuilder,
          $$JournalImageEmbeddingsTableUpdateCompanionBuilder,
          (JournalImageEmbeddingRow, $$JournalImageEmbeddingsTableReferences),
          JournalImageEmbeddingRow,
          PrefetchHooks Function({bool entryId})
        > {
  $$JournalImageEmbeddingsTableTableManager(
    _$AppDatabase db,
    $JournalImageEmbeddingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JournalImageEmbeddingsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$JournalImageEmbeddingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$JournalImageEmbeddingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> evidenceId = const Value.absent(),
                Value<String> entryId = const Value.absent(),
                Value<Uint8List> embedding = const Value.absent(),
                Value<int> dimensions = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalImageEmbeddingsCompanion(
                evidenceId: evidenceId,
                entryId: entryId,
                embedding: embedding,
                dimensions: dimensions,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String evidenceId,
                required String entryId,
                required Uint8List embedding,
                required int dimensions,
                Value<int> rowid = const Value.absent(),
              }) => JournalImageEmbeddingsCompanion.insert(
                evidenceId: evidenceId,
                entryId: entryId,
                embedding: embedding,
                dimensions: dimensions,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$JournalImageEmbeddingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({entryId = false}) {
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
                    if (entryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.entryId,
                                referencedTable:
                                    $$JournalImageEmbeddingsTableReferences
                                        ._entryIdTable(db),
                                referencedColumn:
                                    $$JournalImageEmbeddingsTableReferences
                                        ._entryIdTable(db)
                                        .id,
                              )
                              as T;
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

typedef $$JournalImageEmbeddingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $JournalImageEmbeddingsTable,
      JournalImageEmbeddingRow,
      $$JournalImageEmbeddingsTableFilterComposer,
      $$JournalImageEmbeddingsTableOrderingComposer,
      $$JournalImageEmbeddingsTableAnnotationComposer,
      $$JournalImageEmbeddingsTableCreateCompanionBuilder,
      $$JournalImageEmbeddingsTableUpdateCompanionBuilder,
      (JournalImageEmbeddingRow, $$JournalImageEmbeddingsTableReferences),
      JournalImageEmbeddingRow,
      PrefetchHooks Function({bool entryId})
    >;
typedef $$QuickCaptureOutboxEntriesTableCreateCompanionBuilder =
    QuickCaptureOutboxEntriesCompanion Function({
      required String outboxId,
      required String captureId,
      required String kind,
      required String payloadJson,
      Value<String> status,
      Value<int> attemptCount,
      Value<String?> lastError,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$QuickCaptureOutboxEntriesTableUpdateCompanionBuilder =
    QuickCaptureOutboxEntriesCompanion Function({
      Value<String> outboxId,
      Value<String> captureId,
      Value<String> kind,
      Value<String> payloadJson,
      Value<String> status,
      Value<int> attemptCount,
      Value<String?> lastError,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$QuickCaptureOutboxEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $QuickCaptureOutboxEntriesTable> {
  $$QuickCaptureOutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get outboxId => $composableBuilder(
    column: $table.outboxId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get captureId => $composableBuilder(
    column: $table.captureId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuickCaptureOutboxEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $QuickCaptureOutboxEntriesTable> {
  $$QuickCaptureOutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get outboxId => $composableBuilder(
    column: $table.outboxId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get captureId => $composableBuilder(
    column: $table.captureId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuickCaptureOutboxEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuickCaptureOutboxEntriesTable> {
  $$QuickCaptureOutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get outboxId =>
      $composableBuilder(column: $table.outboxId, builder: (column) => column);

  GeneratedColumn<String> get captureId =>
      $composableBuilder(column: $table.captureId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$QuickCaptureOutboxEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuickCaptureOutboxEntriesTable,
          QuickCaptureOutboxRow,
          $$QuickCaptureOutboxEntriesTableFilterComposer,
          $$QuickCaptureOutboxEntriesTableOrderingComposer,
          $$QuickCaptureOutboxEntriesTableAnnotationComposer,
          $$QuickCaptureOutboxEntriesTableCreateCompanionBuilder,
          $$QuickCaptureOutboxEntriesTableUpdateCompanionBuilder,
          (
            QuickCaptureOutboxRow,
            BaseReferences<
              _$AppDatabase,
              $QuickCaptureOutboxEntriesTable,
              QuickCaptureOutboxRow
            >,
          ),
          QuickCaptureOutboxRow,
          PrefetchHooks Function()
        > {
  $$QuickCaptureOutboxEntriesTableTableManager(
    _$AppDatabase db,
    $QuickCaptureOutboxEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuickCaptureOutboxEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$QuickCaptureOutboxEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$QuickCaptureOutboxEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> outboxId = const Value.absent(),
                Value<String> captureId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuickCaptureOutboxEntriesCompanion(
                outboxId: outboxId,
                captureId: captureId,
                kind: kind,
                payloadJson: payloadJson,
                status: status,
                attemptCount: attemptCount,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String outboxId,
                required String captureId,
                required String kind,
                required String payloadJson,
                Value<String> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => QuickCaptureOutboxEntriesCompanion.insert(
                outboxId: outboxId,
                captureId: captureId,
                kind: kind,
                payloadJson: payloadJson,
                status: status,
                attemptCount: attemptCount,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuickCaptureOutboxEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuickCaptureOutboxEntriesTable,
      QuickCaptureOutboxRow,
      $$QuickCaptureOutboxEntriesTableFilterComposer,
      $$QuickCaptureOutboxEntriesTableOrderingComposer,
      $$QuickCaptureOutboxEntriesTableAnnotationComposer,
      $$QuickCaptureOutboxEntriesTableCreateCompanionBuilder,
      $$QuickCaptureOutboxEntriesTableUpdateCompanionBuilder,
      (
        QuickCaptureOutboxRow,
        BaseReferences<
          _$AppDatabase,
          $QuickCaptureOutboxEntriesTable,
          QuickCaptureOutboxRow
        >,
      ),
      QuickCaptureOutboxRow,
      PrefetchHooks Function()
    >;
typedef $$EmbeddingDeferredQueueEntriesTableCreateCompanionBuilder =
    EmbeddingDeferredQueueEntriesCompanion Function({
      required String queueId,
      required String operation,
      required String entryId,
      required String bodyText,
      Value<String?> contentHash,
      required String sqliteFilePath,
      Value<String?> keyAlias,
      Value<String?> encryptionPassword,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$EmbeddingDeferredQueueEntriesTableUpdateCompanionBuilder =
    EmbeddingDeferredQueueEntriesCompanion Function({
      Value<String> queueId,
      Value<String> operation,
      Value<String> entryId,
      Value<String> bodyText,
      Value<String?> contentHash,
      Value<String> sqliteFilePath,
      Value<String?> keyAlias,
      Value<String?> encryptionPassword,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$EmbeddingDeferredQueueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EmbeddingDeferredQueueEntriesTable> {
  $$EmbeddingDeferredQueueEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get queueId => $composableBuilder(
    column: $table.queueId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyText => $composableBuilder(
    column: $table.bodyText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sqliteFilePath => $composableBuilder(
    column: $table.sqliteFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyAlias => $composableBuilder(
    column: $table.keyAlias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptionPassword => $composableBuilder(
    column: $table.encryptionPassword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EmbeddingDeferredQueueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EmbeddingDeferredQueueEntriesTable> {
  $$EmbeddingDeferredQueueEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get queueId => $composableBuilder(
    column: $table.queueId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyText => $composableBuilder(
    column: $table.bodyText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sqliteFilePath => $composableBuilder(
    column: $table.sqliteFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyAlias => $composableBuilder(
    column: $table.keyAlias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptionPassword => $composableBuilder(
    column: $table.encryptionPassword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmbeddingDeferredQueueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmbeddingDeferredQueueEntriesTable> {
  $$EmbeddingDeferredQueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get queueId =>
      $composableBuilder(column: $table.queueId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get bodyText =>
      $composableBuilder(column: $table.bodyText, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sqliteFilePath => $composableBuilder(
    column: $table.sqliteFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get keyAlias =>
      $composableBuilder(column: $table.keyAlias, builder: (column) => column);

  GeneratedColumn<String> get encryptionPassword => $composableBuilder(
    column: $table.encryptionPassword,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EmbeddingDeferredQueueEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmbeddingDeferredQueueEntriesTable,
          EmbeddingDeferredQueueRow,
          $$EmbeddingDeferredQueueEntriesTableFilterComposer,
          $$EmbeddingDeferredQueueEntriesTableOrderingComposer,
          $$EmbeddingDeferredQueueEntriesTableAnnotationComposer,
          $$EmbeddingDeferredQueueEntriesTableCreateCompanionBuilder,
          $$EmbeddingDeferredQueueEntriesTableUpdateCompanionBuilder,
          (
            EmbeddingDeferredQueueRow,
            BaseReferences<
              _$AppDatabase,
              $EmbeddingDeferredQueueEntriesTable,
              EmbeddingDeferredQueueRow
            >,
          ),
          EmbeddingDeferredQueueRow,
          PrefetchHooks Function()
        > {
  $$EmbeddingDeferredQueueEntriesTableTableManager(
    _$AppDatabase db,
    $EmbeddingDeferredQueueEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmbeddingDeferredQueueEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$EmbeddingDeferredQueueEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$EmbeddingDeferredQueueEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> queueId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> entryId = const Value.absent(),
                Value<String> bodyText = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<String> sqliteFilePath = const Value.absent(),
                Value<String?> keyAlias = const Value.absent(),
                Value<String?> encryptionPassword = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmbeddingDeferredQueueEntriesCompanion(
                queueId: queueId,
                operation: operation,
                entryId: entryId,
                bodyText: bodyText,
                contentHash: contentHash,
                sqliteFilePath: sqliteFilePath,
                keyAlias: keyAlias,
                encryptionPassword: encryptionPassword,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String queueId,
                required String operation,
                required String entryId,
                required String bodyText,
                Value<String?> contentHash = const Value.absent(),
                required String sqliteFilePath,
                Value<String?> keyAlias = const Value.absent(),
                Value<String?> encryptionPassword = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => EmbeddingDeferredQueueEntriesCompanion.insert(
                queueId: queueId,
                operation: operation,
                entryId: entryId,
                bodyText: bodyText,
                contentHash: contentHash,
                sqliteFilePath: sqliteFilePath,
                keyAlias: keyAlias,
                encryptionPassword: encryptionPassword,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EmbeddingDeferredQueueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmbeddingDeferredQueueEntriesTable,
      EmbeddingDeferredQueueRow,
      $$EmbeddingDeferredQueueEntriesTableFilterComposer,
      $$EmbeddingDeferredQueueEntriesTableOrderingComposer,
      $$EmbeddingDeferredQueueEntriesTableAnnotationComposer,
      $$EmbeddingDeferredQueueEntriesTableCreateCompanionBuilder,
      $$EmbeddingDeferredQueueEntriesTableUpdateCompanionBuilder,
      (
        EmbeddingDeferredQueueRow,
        BaseReferences<
          _$AppDatabase,
          $EmbeddingDeferredQueueEntriesTable,
          EmbeddingDeferredQueueRow
        >,
      ),
      EmbeddingDeferredQueueRow,
      PrefetchHooks Function()
    >;
typedef $$AudioProcessingQueueEntriesTableCreateCompanionBuilder =
    AudioProcessingQueueEntriesCompanion Function({
      required String id,
      required String filePath,
      required int timestamp,
      required int durationMs,
      Value<String> status,
      Value<int> rowid,
    });
typedef $$AudioProcessingQueueEntriesTableUpdateCompanionBuilder =
    AudioProcessingQueueEntriesCompanion Function({
      Value<String> id,
      Value<String> filePath,
      Value<int> timestamp,
      Value<int> durationMs,
      Value<String> status,
      Value<int> rowid,
    });

class $$AudioProcessingQueueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $AudioProcessingQueueEntriesTable> {
  $$AudioProcessingQueueEntriesTableFilterComposer({
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

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AudioProcessingQueueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $AudioProcessingQueueEntriesTable> {
  $$AudioProcessingQueueEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AudioProcessingQueueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudioProcessingQueueEntriesTable> {
  $$AudioProcessingQueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$AudioProcessingQueueEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AudioProcessingQueueEntriesTable,
          AudioProcessingQueueRow,
          $$AudioProcessingQueueEntriesTableFilterComposer,
          $$AudioProcessingQueueEntriesTableOrderingComposer,
          $$AudioProcessingQueueEntriesTableAnnotationComposer,
          $$AudioProcessingQueueEntriesTableCreateCompanionBuilder,
          $$AudioProcessingQueueEntriesTableUpdateCompanionBuilder,
          (
            AudioProcessingQueueRow,
            BaseReferences<
              _$AppDatabase,
              $AudioProcessingQueueEntriesTable,
              AudioProcessingQueueRow
            >,
          ),
          AudioProcessingQueueRow,
          PrefetchHooks Function()
        > {
  $$AudioProcessingQueueEntriesTableTableManager(
    _$AppDatabase db,
    $AudioProcessingQueueEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioProcessingQueueEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AudioProcessingQueueEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AudioProcessingQueueEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioProcessingQueueEntriesCompanion(
                id: id,
                filePath: filePath,
                timestamp: timestamp,
                durationMs: durationMs,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String filePath,
                required int timestamp,
                required int durationMs,
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioProcessingQueueEntriesCompanion.insert(
                id: id,
                filePath: filePath,
                timestamp: timestamp,
                durationMs: durationMs,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AudioProcessingQueueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AudioProcessingQueueEntriesTable,
      AudioProcessingQueueRow,
      $$AudioProcessingQueueEntriesTableFilterComposer,
      $$AudioProcessingQueueEntriesTableOrderingComposer,
      $$AudioProcessingQueueEntriesTableAnnotationComposer,
      $$AudioProcessingQueueEntriesTableCreateCompanionBuilder,
      $$AudioProcessingQueueEntriesTableUpdateCompanionBuilder,
      (
        AudioProcessingQueueRow,
        BaseReferences<
          _$AppDatabase,
          $AudioProcessingQueueEntriesTable,
          AudioProcessingQueueRow
        >,
      ),
      AudioProcessingQueueRow,
      PrefetchHooks Function()
    >;
typedef $$CaptureAudioMetadataEntriesTableCreateCompanionBuilder =
    CaptureAudioMetadataEntriesCompanion Function({
      required String id,
      required String filePath,
      required int createdAt,
      Value<String> status,
      Value<int> rowid,
    });
typedef $$CaptureAudioMetadataEntriesTableUpdateCompanionBuilder =
    CaptureAudioMetadataEntriesCompanion Function({
      Value<String> id,
      Value<String> filePath,
      Value<int> createdAt,
      Value<String> status,
      Value<int> rowid,
    });

class $$CaptureAudioMetadataEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CaptureAudioMetadataEntriesTable> {
  $$CaptureAudioMetadataEntriesTableFilterComposer({
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

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CaptureAudioMetadataEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CaptureAudioMetadataEntriesTable> {
  $$CaptureAudioMetadataEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CaptureAudioMetadataEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CaptureAudioMetadataEntriesTable> {
  $$CaptureAudioMetadataEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$CaptureAudioMetadataEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CaptureAudioMetadataEntriesTable,
          CaptureAudioMetadataRow,
          $$CaptureAudioMetadataEntriesTableFilterComposer,
          $$CaptureAudioMetadataEntriesTableOrderingComposer,
          $$CaptureAudioMetadataEntriesTableAnnotationComposer,
          $$CaptureAudioMetadataEntriesTableCreateCompanionBuilder,
          $$CaptureAudioMetadataEntriesTableUpdateCompanionBuilder,
          (
            CaptureAudioMetadataRow,
            BaseReferences<
              _$AppDatabase,
              $CaptureAudioMetadataEntriesTable,
              CaptureAudioMetadataRow
            >,
          ),
          CaptureAudioMetadataRow,
          PrefetchHooks Function()
        > {
  $$CaptureAudioMetadataEntriesTableTableManager(
    _$AppDatabase db,
    $CaptureAudioMetadataEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CaptureAudioMetadataEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CaptureAudioMetadataEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CaptureAudioMetadataEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaptureAudioMetadataEntriesCompanion(
                id: id,
                filePath: filePath,
                createdAt: createdAt,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String filePath,
                required int createdAt,
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaptureAudioMetadataEntriesCompanion.insert(
                id: id,
                filePath: filePath,
                createdAt: createdAt,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CaptureAudioMetadataEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CaptureAudioMetadataEntriesTable,
      CaptureAudioMetadataRow,
      $$CaptureAudioMetadataEntriesTableFilterComposer,
      $$CaptureAudioMetadataEntriesTableOrderingComposer,
      $$CaptureAudioMetadataEntriesTableAnnotationComposer,
      $$CaptureAudioMetadataEntriesTableCreateCompanionBuilder,
      $$CaptureAudioMetadataEntriesTableUpdateCompanionBuilder,
      (
        CaptureAudioMetadataRow,
        BaseReferences<
          _$AppDatabase,
          $CaptureAudioMetadataEntriesTable,
          CaptureAudioMetadataRow
        >,
      ),
      CaptureAudioMetadataRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$JournalEntriesTableTableManager get journalEntries =>
      $$JournalEntriesTableTableManager(_db, _db.journalEntries);
  $$SyncOutboxEntriesTableTableManager get syncOutboxEntries =>
      $$SyncOutboxEntriesTableTableManager(_db, _db.syncOutboxEntries);
  $$ReflectionEmbeddingsTableTableManager get reflectionEmbeddings =>
      $$ReflectionEmbeddingsTableTableManager(_db, _db.reflectionEmbeddings);
  $$ReflectionGraphNodesTableTableManager get reflectionGraphNodes =>
      $$ReflectionGraphNodesTableTableManager(_db, _db.reflectionGraphNodes);
  $$AppSqliteMetaTableTableManager get appSqliteMeta =>
      $$AppSqliteMetaTableTableManager(_db, _db.appSqliteMeta);
  $$EntryEdgesTableTableManager get entryEdges =>
      $$EntryEdgesTableTableManager(_db, _db.entryEdges);
  $$FactLedgerEntriesTableTableManager get factLedgerEntries =>
      $$FactLedgerEntriesTableTableManager(_db, _db.factLedgerEntries);
  $$AccountIdentitiesTableTableManager get accountIdentities =>
      $$AccountIdentitiesTableTableManager(_db, _db.accountIdentities);
  $$UserRelationshipsTableTableManager get userRelationships =>
      $$UserRelationshipsTableTableManager(_db, _db.userRelationships);
  $$AccountProStatusTableTableManager get accountProStatus =>
      $$AccountProStatusTableTableManager(_db, _db.accountProStatus);
  $$MemoryTranscriptEmbeddingsTableTableManager
  get memoryTranscriptEmbeddings =>
      $$MemoryTranscriptEmbeddingsTableTableManager(
        _db,
        _db.memoryTranscriptEmbeddings,
      );
  $$JournalImageEmbeddingsTableTableManager get journalImageEmbeddings =>
      $$JournalImageEmbeddingsTableTableManager(
        _db,
        _db.journalImageEmbeddings,
      );
  $$QuickCaptureOutboxEntriesTableTableManager get quickCaptureOutboxEntries =>
      $$QuickCaptureOutboxEntriesTableTableManager(
        _db,
        _db.quickCaptureOutboxEntries,
      );
  $$EmbeddingDeferredQueueEntriesTableTableManager
  get embeddingDeferredQueueEntries =>
      $$EmbeddingDeferredQueueEntriesTableTableManager(
        _db,
        _db.embeddingDeferredQueueEntries,
      );
  $$AudioProcessingQueueEntriesTableTableManager
  get audioProcessingQueueEntries =>
      $$AudioProcessingQueueEntriesTableTableManager(
        _db,
        _db.audioProcessingQueueEntries,
      );
  $$CaptureAudioMetadataEntriesTableTableManager
  get captureAudioMetadataEntries =>
      $$CaptureAudioMetadataEntriesTableTableManager(
        _db,
        _db.captureAudioMetadataEntries,
      );
}
