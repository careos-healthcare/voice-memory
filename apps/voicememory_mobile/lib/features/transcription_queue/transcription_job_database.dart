import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../../services/local_storage/encrypted_sqlite_text_codec.dart';
import 'transcription_job.dart';

typedef TranscriptionClock = DateTime Function();
typedef TranscriptionTokenFactory = String Function();

/// Versioned SQLite persistence and state transitions for transcription jobs.
class TranscriptionJobDatabase {
  TranscriptionJobDatabase._(
    this._database, {
    required this.databasePath,
    required this._clock,
    required this._tokenFactory,
    this._textCodec,
  }) {
    late final StreamController<List<TranscriptionJob>> controller;
    controller = StreamController<List<TranscriptionJob>>.broadcast(
      sync: true,
      onListen: () {
        if (!_closed) controller.add(listJobs());
      },
    );
    _changes = controller;
  }

  static const int currentSchemaVersion = 3;

  final Database _database;
  final String databasePath;
  final TranscriptionClock _clock;
  final TranscriptionTokenFactory _tokenFactory;
  final EncryptedSqliteTextCodec? _textCodec;
  late final StreamController<List<TranscriptionJob>> _changes;
  bool _closed = false;

  static TranscriptionJobDatabase open({
    required String databasePath,
    TranscriptionClock? clock,
    TranscriptionTokenFactory? tokenFactory,
    EncryptedSqliteTextCodec? textCodec,
  }) {
    final file = File(databasePath);
    file.parent.createSync(recursive: true);
    final database = sqlite3.open(databasePath);
    try {
      database.execute('PRAGMA journal_mode = WAL');
      database.execute('PRAGMA synchronous = FULL');
      database.execute('PRAGMA foreign_keys = ON');
      _migrate(database);
      if (textCodec != null) {
        _encryptSensitiveColumns(database, textCodec);
      }
      return TranscriptionJobDatabase._(
        database,
        databasePath: databasePath,
        clock: clock ?? DateTime.now,
        tokenFactory: tokenFactory ?? _randomToken,
        textCodec: textCodec,
      );
    } catch (_) {
      database.close();
      rethrow;
    }
  }

  int get schemaVersion => _database.userVersion;

  /// A broadcast stream that emits immutable snapshots after every mutation.
  Stream<List<TranscriptionJob>> get watchJobs => _changes.stream;

  List<TranscriptionJob> listJobs() {
    _ensureOpen();
    final rows = _database.select(
      'SELECT * FROM transcription_jobs ORDER BY created_at, id',
    );
    return List<TranscriptionJob>.unmodifiable(rows.map(_jobFromRow));
  }

  TranscriptionJob? getJob(String id) {
    _ensureOpen();
    final rows = _database.select(
      'SELECT * FROM transcription_jobs WHERE id = ?',
      [id],
    );
    return rows.isEmpty ? null : _jobFromRow(rows.single);
  }

  void insertJob(TranscriptionJob job) {
    _ensureOpen();
    _database.execute(
      '''
      INSERT INTO transcription_jobs (
        id, entry_id, audio_path, source_file_name, duration_seconds,
        status, created_at, updated_at,
        attempt_count, next_attempt_at, last_error, transcript, lease_token,
        lease_expires_at, completed_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        job.id,
        job.entryId,
        _encode(job.audioPath),
        _encode(job.sourceFileName),
        job.durationSeconds,
        job.status.storageValue,
        _milliseconds(job.createdAt),
        _milliseconds(job.updatedAt),
        job.attemptCount,
        _nullableMilliseconds(job.nextAttemptAt),
        job.lastError,
        _encode(job.transcript),
        job.leaseToken,
        _nullableMilliseconds(job.leaseExpiresAt),
        _nullableMilliseconds(job.completedAt),
      ],
    );
    _emit();
  }

  /// Atomically claims the oldest eligible job.
  TranscriptionJob? acquireLease({
    Duration leaseDuration = const Duration(minutes: 5),
  }) {
    _ensureOpen();
    if (leaseDuration <= Duration.zero) {
      throw ArgumentError.value(
        leaseDuration,
        'leaseDuration',
        'must be positive',
      );
    }

    final now = _clock().toUtc();
    final token = _tokenFactory();
    TranscriptionJob? acquired;
    _transaction(() {
      final rows = _database.select(
        '''
        SELECT id FROM transcription_jobs
        WHERE (
          status = ?
          OR (status = ? AND next_attempt_at <= ?)
        )
        ORDER BY created_at, id
        LIMIT 1
        ''',
        [
          TranscriptionJobStatus.queued.storageValue,
          TranscriptionJobStatus.retryWaiting.storageValue,
          _milliseconds(now),
        ],
      );
      if (rows.isEmpty) return;

      final id = rows.single['id'] as String;
      _database.execute(
        '''
        UPDATE transcription_jobs
        SET status = ?, lease_token = ?, lease_expires_at = ?, updated_at = ?,
            next_attempt_at = NULL
        WHERE id = ? AND (
          status = ?
          OR (status = ? AND next_attempt_at <= ?)
        )
        ''',
        [
          TranscriptionJobStatus.processing.storageValue,
          token,
          _milliseconds(now.add(leaseDuration)),
          _milliseconds(now),
          id,
          TranscriptionJobStatus.queued.storageValue,
          TranscriptionJobStatus.retryWaiting.storageValue,
          _milliseconds(now),
        ],
      );
      if (_database.updatedRows == 1) {
        acquired = getJob(id);
      }
    });
    if (acquired != null) _emit();
    return acquired;
  }

  TranscriptionJob complete({
    required String id,
    required String leaseToken,
    required String transcript,
  }) {
    final now = _clock().toUtc();
    _updateLeased(
      id: id,
      leaseToken: leaseToken,
      sql: '''
        UPDATE transcription_jobs
        SET status = ?, transcript = ?, completed_at = ?, updated_at = ?,
            lease_token = NULL, lease_expires_at = NULL, last_error = NULL,
            next_attempt_at = NULL
        WHERE id = ? AND status = ? AND lease_token = ?
      ''',
      parameters: [
        TranscriptionJobStatus.completed.storageValue,
        _encode(transcript),
        _milliseconds(now),
        _milliseconds(now),
        id,
        TranscriptionJobStatus.processing.storageValue,
        leaseToken,
      ],
    );
    return getJob(id)!;
  }

  /// Records a failed attempt and schedules exponential backoff.
  TranscriptionJob retry({
    required String id,
    required String leaseToken,
    required String error,
    Duration baseDelay = const Duration(seconds: 5),
    Duration maxDelay = const Duration(hours: 1),
    int maxAttempts = 5,
  }) {
    if (baseDelay <= Duration.zero || maxDelay <= Duration.zero) {
      throw ArgumentError('Retry delays must be positive.');
    }
    if (maxAttempts < 1) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be positive');
    }

    final existing = _requireLease(id, leaseToken);
    final attemptCount = existing.attemptCount + 1;
    final now = _clock().toUtc();
    final exhausted = attemptCount >= maxAttempts;
    final delay = _retryDelay(
      attemptCount: attemptCount,
      baseDelay: baseDelay,
      maxDelay: maxDelay,
    );
    _updateLeased(
      id: id,
      leaseToken: leaseToken,
      sql: '''
        UPDATE transcription_jobs
        SET status = ?, attempt_count = ?, next_attempt_at = ?,
            last_error = ?, updated_at = ?, lease_token = NULL,
            lease_expires_at = NULL
        WHERE id = ? AND status = ? AND lease_token = ?
      ''',
      parameters: [
        (exhausted
                ? TranscriptionJobStatus.failed
                : TranscriptionJobStatus.retryWaiting)
            .storageValue,
        attemptCount,
        exhausted ? null : _milliseconds(now.add(delay)),
        error,
        _milliseconds(now),
        id,
        TranscriptionJobStatus.processing.storageValue,
        leaseToken,
      ],
    );
    return getJob(id)!;
  }

  TranscriptionJob fail({
    required String id,
    required String leaseToken,
    required String error,
  }) {
    final now = _clock().toUtc();
    _updateLeased(
      id: id,
      leaseToken: leaseToken,
      sql: '''
        UPDATE transcription_jobs
        SET status = ?, last_error = ?, updated_at = ?, lease_token = NULL,
            lease_expires_at = NULL, next_attempt_at = NULL
        WHERE id = ? AND status = ? AND lease_token = ?
      ''',
      parameters: [
        TranscriptionJobStatus.failed.storageValue,
        error,
        _milliseconds(now),
        id,
        TranscriptionJobStatus.processing.storageValue,
        leaseToken,
      ],
    );
    return getJob(id)!;
  }

  /// Cancels a pending job. A currently leased job requires its lease token.
  TranscriptionJob cancel(String id, {String? leaseToken}) {
    _ensureOpen();
    final existing = getJob(id);
    if (existing == null) throw StateError('Transcription job not found: $id');
    if (existing.isTerminal) {
      throw StateError('Transcription job is already terminal: $id');
    }
    if (existing.status == TranscriptionJobStatus.processing &&
        existing.leaseToken != leaseToken) {
      throw StateError('The transcription lease is no longer owned.');
    }

    final now = _clock().toUtc();
    _database.execute(
      '''
      UPDATE transcription_jobs
      SET status = ?, updated_at = ?, lease_token = NULL,
          lease_expires_at = NULL, next_attempt_at = NULL
      WHERE id = ?
      ''',
      [TranscriptionJobStatus.cancelled.storageValue, _milliseconds(now), id],
    );
    _emit();
    return getJob(id)!;
  }

  void deleteJob(String id) {
    _ensureOpen();
    _database.execute('DELETE FROM transcription_jobs WHERE id = ?', [id]);
    if (_database.updatedRows != 1) {
      throw StateError('Transcription job not found: $id');
    }
    _emit();
  }

  void replaceAll(List<TranscriptionJob> jobs) {
    _ensureOpen();
    _transaction(() {
      _database.execute('DELETE FROM transcription_jobs');
      for (final job in jobs) {
        _database.execute(
          '''
          INSERT INTO transcription_jobs (
            id, entry_id, audio_path, source_file_name, duration_seconds,
            status, created_at, updated_at, attempt_count, next_attempt_at,
            last_error, transcript, lease_token, lease_expires_at, completed_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            job.id,
            job.entryId,
            _encode(job.audioPath),
            _encode(job.sourceFileName),
            job.durationSeconds,
            job.status.storageValue,
            _milliseconds(job.createdAt),
            _milliseconds(job.updatedAt),
            job.attemptCount,
            _nullableMilliseconds(job.nextAttemptAt),
            job.lastError,
            _encode(job.transcript),
            job.leaseToken,
            _nullableMilliseconds(job.leaseExpiresAt),
            _nullableMilliseconds(job.completedAt),
          ],
        );
      }
    });
    _emit();
  }

  /// Repairs abandoned leases and fails active jobs whose durable audio is gone.
  TranscriptionReconciliationResult reconcile() {
    _ensureOpen();
    final now = _clock().toUtc();
    var expired = 0;
    var missing = 0;
    _transaction(() {
      _database.execute(
        '''
        UPDATE transcription_jobs
        SET status = ?, lease_token = NULL, lease_expires_at = NULL,
            updated_at = ?
        WHERE status = ? AND lease_expires_at <= ?
        ''',
        [
          TranscriptionJobStatus.queued.storageValue,
          _milliseconds(now),
          TranscriptionJobStatus.processing.storageValue,
          _milliseconds(now),
        ],
      );
      expired = _database.updatedRows;

      final active = _database.select(
        '''
        SELECT id, audio_path FROM transcription_jobs
        WHERE status IN (?, ?, ?)
        ''',
        [
          TranscriptionJobStatus.queued.storageValue,
          TranscriptionJobStatus.processing.storageValue,
          TranscriptionJobStatus.retryWaiting.storageValue,
        ],
      );
      for (final row in active) {
        if (File(_decode(row['audio_path'] as String)!).existsSync()) continue;
        _database.execute(
          '''
          UPDATE transcription_jobs
          SET status = ?, last_error = ?, updated_at = ?, lease_token = NULL,
              lease_expires_at = NULL, next_attempt_at = NULL
          WHERE id = ?
          ''',
          [
            TranscriptionJobStatus.failed.storageValue,
            'audio_file_missing',
            _milliseconds(now),
            row['id'],
          ],
        );
        missing += _database.updatedRows;
      }
    });
    if (expired > 0 || missing > 0) _emit();
    return TranscriptionReconciliationResult(
      expiredLeasesRecovered: expired,
      missingAudioFailed: missing,
    );
  }

  TranscriptionDatabaseIntegrity checkIntegrity() {
    _ensureOpen();
    final messages = _database
        .select('PRAGMA integrity_check')
        .map((row) => row.values.first.toString())
        .toList(growable: false);
    return TranscriptionDatabaseIntegrity(List<String>.unmodifiable(messages));
  }

  void checkpoint() {
    _ensureOpen();
    _database.execute('PRAGMA wal_checkpoint(FULL)');
  }

  /// Creates a transactionally consistent standalone database for backup.
  File createSnapshot(String destinationPath) {
    _ensureOpen();
    final destination = File(destinationPath);
    destination.parent.createSync(recursive: true);
    if (destination.existsSync()) destination.deleteSync();
    _database.execute('PRAGMA wal_checkpoint(FULL)');
    _database.execute('VACUUM INTO ?', [destinationPath]);
    return destination;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _changes.close();
    _database.close();
  }

  static void _migrate(Database database) {
    final version = database.userVersion;
    if (version > currentSchemaVersion) {
      throw StateError(
        'Transcription database version $version is newer than supported '
        'version $currentSchemaVersion.',
      );
    }

    database.execute('BEGIN IMMEDIATE');
    try {
      if (version < 1) {
        database.execute('''
          CREATE TABLE transcription_jobs (
            id TEXT PRIMARY KEY NOT NULL,
            audio_path TEXT NOT NULL UNIQUE,
            status TEXT NOT NULL CHECK (
              status IN (
                'queued', 'leased', 'retry_waiting',
                'completed', 'failed', 'cancelled'
              )
            ),
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
            next_attempt_at INTEGER,
            last_error TEXT,
            transcript TEXT,
            lease_token TEXT,
            lease_expires_at INTEGER
          )
        ''');
        database.execute(
          'CREATE INDEX transcription_jobs_ready_idx '
          'ON transcription_jobs(status, next_attempt_at, created_at)',
        );
      }
      if (version < 2) {
        database.execute(
          "ALTER TABLE transcription_jobs ADD COLUMN "
          "source_file_name TEXT NOT NULL DEFAULT ''",
        );
        database.execute(
          'ALTER TABLE transcription_jobs ADD COLUMN completed_at INTEGER',
        );
        database.execute(
          'CREATE INDEX transcription_jobs_lease_idx '
          'ON transcription_jobs(status, lease_expires_at)',
        );
      }
      if (version < 3) {
        database.execute('''
          CREATE TABLE transcription_jobs_v3 (
            id TEXT PRIMARY KEY NOT NULL,
            entry_id TEXT NOT NULL UNIQUE,
            audio_path TEXT NOT NULL UNIQUE,
            source_file_name TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL CHECK (duration_seconds >= 0),
            status TEXT NOT NULL CHECK (
              status IN (
                'queued', 'processing', 'retry_waiting',
                'completed', 'failed', 'cancelled'
              )
            ),
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
            next_attempt_at INTEGER,
            last_error TEXT,
            transcript TEXT,
            lease_token TEXT,
            lease_expires_at INTEGER,
            completed_at INTEGER
          )
        ''');
        database.execute('''
          INSERT INTO transcription_jobs_v3 (
            id, entry_id, audio_path, source_file_name, duration_seconds,
            status, created_at, updated_at, attempt_count, next_attempt_at,
            last_error, transcript, lease_token, lease_expires_at, completed_at
          )
          SELECT id, id, audio_path, source_file_name, 0,
            CASE WHEN status = 'leased' THEN 'processing' ELSE status END,
            created_at, updated_at, attempt_count, next_attempt_at,
            last_error, transcript, lease_token, lease_expires_at, completed_at
          FROM transcription_jobs
        ''');
        database.execute('DROP TABLE transcription_jobs');
        database.execute(
          'ALTER TABLE transcription_jobs_v3 RENAME TO transcription_jobs',
        );
        database.execute(
          'CREATE INDEX transcription_jobs_ready_idx '
          'ON transcription_jobs(status, next_attempt_at, created_at)',
        );
        database.execute(
          'CREATE INDEX transcription_jobs_lease_idx '
          'ON transcription_jobs(status, lease_expires_at)',
        );
      }
      database.userVersion = currentSchemaVersion;
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  void _updateLeased({
    required String id,
    required String leaseToken,
    required String sql,
    required List<Object?> parameters,
  }) {
    _ensureOpen();
    _database.execute(sql, parameters);
    if (_database.updatedRows != 1) {
      throw StateError('The transcription lease is no longer owned for $id.');
    }
    _emit();
  }

  TranscriptionJob _requireLease(String id, String token) {
    final job = getJob(id);
    if (job == null ||
        job.status != TranscriptionJobStatus.processing ||
        job.leaseToken != token) {
      throw StateError('The transcription lease is no longer owned for $id.');
    }
    return job;
  }

  void _transaction(void Function() action) {
    _database.execute('BEGIN IMMEDIATE');
    try {
      action();
      _database.execute('COMMIT');
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(listJobs());
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Transcription database is closed.');
  }

  String? _encode(String? value) => _textCodec?.encode(value) ?? value;

  String? _decode(String? value) => _textCodec?.decode(value) ?? value;

  static void _encryptSensitiveColumns(
    Database database,
    EncryptedSqliteTextCodec codec,
  ) {
    final rows = database.select(
      'SELECT id, audio_path, source_file_name, transcript '
      'FROM transcription_jobs',
    );
    database.execute('BEGIN IMMEDIATE');
    try {
      for (final row in rows) {
        database.execute(
          'UPDATE transcription_jobs SET audio_path = ?, '
          'source_file_name = ?, transcript = ? WHERE id = ?',
          [
            codec.encode(row['audio_path'] as String?),
            codec.encode(row['source_file_name'] as String?),
            codec.encode(row['transcript'] as String?),
            row['id'],
          ],
        );
      }
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  TranscriptionJob _jobFromRow(Row row) {
    DateTime? date(String column) {
      final value = row[column] as int?;
      return value == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }

    return TranscriptionJob(
      id: row['id'] as String,
      entryId: row['entry_id'] as String,
      audioPath: _decode(row['audio_path'] as String)!,
      sourceFileName: _decode(row['source_file_name'] as String)!,
      durationSeconds: row['duration_seconds'] as int,
      status: TranscriptionJobStatus.fromStorage(row['status'] as String),
      createdAt: date('created_at')!,
      updatedAt: date('updated_at')!,
      attemptCount: row['attempt_count'] as int,
      nextAttemptAt: date('next_attempt_at'),
      lastError: row['last_error'] as String?,
      transcript: _decode(row['transcript'] as String?),
      leaseToken: row['lease_token'] as String?,
      leaseExpiresAt: date('lease_expires_at'),
      completedAt: date('completed_at'),
    );
  }

  static Duration _retryDelay({
    required int attemptCount,
    required Duration baseDelay,
    required Duration maxDelay,
  }) {
    final exponent = min(attemptCount - 1, 30);
    final microseconds = min(
      baseDelay.inMicroseconds * (1 << exponent),
      maxDelay.inMicroseconds,
    );
    return Duration(microseconds: microseconds);
  }

  static int _milliseconds(DateTime value) =>
      value.toUtc().millisecondsSinceEpoch;

  static int? _nullableMilliseconds(DateTime? value) =>
      value == null ? null : _milliseconds(value);

  static String _randomToken() {
    final random = Random.secure();
    return List<String>.generate(
      4,
      (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
  }
}
