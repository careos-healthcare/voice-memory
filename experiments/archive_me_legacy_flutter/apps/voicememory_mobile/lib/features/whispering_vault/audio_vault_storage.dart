import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

typedef AudioVaultMasterKeyProvider = Future<SecretKey> Function();

final class AudioVaultRecord {
  const AudioVaultRecord({
    required this.id,
    required this.capturedAt,
    required this.extension,
    required this.duration,
    required this.hasAudio,
    required this.hasTranscript,
    required this.archived,
    this.audioExpiresAt,
  });

  final String id;
  final DateTime capturedAt;
  final String extension;
  final Duration duration;
  final bool hasAudio;
  final bool hasTranscript;
  final bool archived;
  final DateTime? audioExpiresAt;
}

final class AudioVaultStorage {
  AudioVaultStorage._({
    required this._database,
    required this.databasePath,
    required this._keyStore,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static AudioVaultStorage open({
    required String databasePath,
    required AudioVaultMasterKeyProvider keyStore,
    DateTime Function()? clock,
  }) {
    Directory(databasePath).parent.createSync(recursive: true);
    final database = sqlite3.open(databasePath)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA synchronous = FULL')
      ..execute('PRAGMA secure_delete = ON')
      ..execute('PRAGMA busy_timeout = 3000')
      ..execute('''
        CREATE TABLE IF NOT EXISTS whisper_audio (
          id TEXT PRIMARY KEY,
          captured_at INTEGER NOT NULL,
          duration_ms INTEGER NOT NULL,
          extension TEXT NOT NULL,
          audio_ciphertext BLOB,
          audio_nonce BLOB,
          audio_mac BLOB,
          transcript_ciphertext BLOB,
          transcript_nonce BLOB,
          transcript_mac BLOB,
          audio_expires_at INTEGER,
          archived INTEGER NOT NULL DEFAULT 0
        )
      ''')
      ..execute('''
        CREATE TABLE IF NOT EXISTS whisper_audio_chunks (
          record_id TEXT NOT NULL,
          chunk_index INTEGER NOT NULL,
          ciphertext BLOB NOT NULL,
          nonce BLOB NOT NULL,
          mac BLOB NOT NULL,
          PRIMARY KEY(record_id, chunk_index),
          FOREIGN KEY(record_id) REFERENCES whisper_audio(id) ON DELETE CASCADE
        )
      ''');
    return AudioVaultStorage._(
      database: database,
      databasePath: databasePath,
      keyStore: keyStore,
      clock: clock,
    );
  }

  static const maximumChunkBytes = 128 * 1024 * 1024;

  final Database _database;
  final String databasePath;
  final AudioVaultMasterKeyProvider _keyStore;
  final DateTime Function() _clock;
  final AesGcm _cipher = AesGcm.with256bits();
  final Random _random = Random.secure();
  bool _closed = false;

  Future<AudioVaultRecord> beginStream({
    Duration retention = const Duration(days: 7),
  }) async {
    _ensureOpen();
    final id = const Uuid().v4();
    final now = _clock().toUtc();
    _database.execute(
      'INSERT INTO whisper_audio '
      '(id, captured_at, duration_ms, extension, audio_expires_at, archived) '
      'VALUES (?, ?, 0, ?, ?, 0)',
      [
        id,
        now.millisecondsSinceEpoch,
        'wav',
        now.add(retention).millisecondsSinceEpoch,
      ],
    );
    return (await get(id))!;
  }

  Future<void> appendStreamChunk({
    required String id,
    required int index,
    required Uint8List pcmBytes,
  }) async {
    _ensureOpen();
    if (index < 0 || pcmBytes.isEmpty || pcmBytes.length > 1024 * 1024) {
      throw ArgumentError('Invalid PCM stream chunk.');
    }
    final nonce = _randomBytes(12);
    final working = Uint8List.fromList(pcmBytes);
    try {
      final box = await _cipher.encrypt(
        working,
        secretKey: await _keyStore(),
        nonce: nonce,
        aad: _aad(id, 'chunk:$index'),
      );
      _database.execute(
        'INSERT INTO whisper_audio_chunks '
        '(record_id, chunk_index, ciphertext, nonce, mac) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          id,
          index,
          Uint8List.fromList(box.cipherText),
          nonce,
          Uint8List.fromList(box.mac.bytes),
        ],
      );
    } finally {
      working.fillRange(0, working.length, 0);
    }
  }

  Future<AudioVaultRecord> finalizeStream({
    required String id,
    required Uint8List wavBytes,
    required Duration duration,
  }) async {
    _ensureOpen();
    if (wavBytes.length < 44 || wavBytes.length > maximumChunkBytes) {
      throw ArgumentError('Invalid completed WAV stream.');
    }
    final nonce = _randomBytes(12);
    final working = Uint8List.fromList(wavBytes);
    try {
      final box = await _cipher.encrypt(
        working,
        secretKey: await _keyStore(),
        nonce: nonce,
        aad: _aad(id, 'audio'),
      );
      _database.execute('BEGIN IMMEDIATE');
      try {
        _database.execute(
          'UPDATE whisper_audio SET duration_ms = ?, audio_ciphertext = ?, '
          'audio_nonce = ?, audio_mac = ? WHERE id = ?',
          [
            duration.inMilliseconds,
            Uint8List.fromList(box.cipherText),
            nonce,
            Uint8List.fromList(box.mac.bytes),
            id,
          ],
        );
        _database.execute(
          'DELETE FROM whisper_audio_chunks WHERE record_id = ?',
          [id],
        );
        _database.execute('COMMIT');
      } on Object {
        _database.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      working.fillRange(0, working.length, 0);
    }
    return (await get(id))!;
  }

  Future<AudioVaultRecord> sealChunk({
    required Uint8List bytes,
    required String extension,
    required Duration duration,
    Duration retention = const Duration(days: 7),
    String? id,
  }) async {
    _ensureOpen();
    final normalizedExtension = extension.toLowerCase().replaceFirst('.', '');
    if (!const {'wav', 'ogg', 'm4a'}.contains(normalizedExtension) ||
        bytes.isEmpty ||
        bytes.length > maximumChunkBytes ||
        duration < Duration.zero ||
        retention < Duration.zero) {
      throw ArgumentError('Invalid encrypted audio chunk.');
    }
    final recordId = id ?? const Uuid().v4();
    final now = _clock().toUtc();
    final nonce = _randomBytes(12);
    final working = Uint8List.fromList(bytes);
    try {
      final box = await _cipher.encrypt(
        working,
        secretKey: await _keyStore(),
        nonce: nonce,
        aad: _aad(recordId, 'audio'),
      );
      _database.execute(
        'INSERT INTO whisper_audio '
        '(id, captured_at, duration_ms, extension, audio_ciphertext, '
        'audio_nonce, audio_mac, audio_expires_at, archived) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)',
        [
          recordId,
          now.millisecondsSinceEpoch,
          duration.inMilliseconds,
          normalizedExtension,
          Uint8List.fromList(box.cipherText),
          nonce,
          Uint8List.fromList(box.mac.bytes),
          retention == Duration.zero
              ? now.millisecondsSinceEpoch
              : now.add(retention).millisecondsSinceEpoch,
        ],
      );
    } finally {
      working.fillRange(0, working.length, 0);
    }
    return (await get(recordId))!;
  }

  Future<AudioVaultRecord> ingestFile({
    required File plaintext,
    required Duration duration,
    Duration retention = const Duration(days: 7),
  }) async {
    if (!plaintext.existsSync() || plaintext.lengthSync() > maximumChunkBytes) {
      throw ArgumentError('Invalid plaintext audio file.');
    }
    final extension = plaintext.path.split('.').last;
    final bytes = Uint8List.fromList(await plaintext.readAsBytes());
    try {
      return await sealChunk(
        bytes: bytes,
        extension: extension,
        duration: duration,
        retention: retention,
      );
    } finally {
      bytes.fillRange(0, bytes.length, 0);
      if (plaintext.existsSync()) await plaintext.delete();
    }
  }

  Future<void> saveTranscript(String id, String transcript) async {
    _ensureOpen();
    final normalized = transcript.trim();
    if (normalized.isEmpty || normalized.length > 1000000) {
      throw ArgumentError.value(transcript, 'transcript');
    }
    if (await get(id) == null) throw StateError('Unknown audio record: $id');
    final nonce = _randomBytes(12);
    final clear = Uint8List.fromList(utf8.encode(normalized));
    try {
      final box = await _cipher.encrypt(
        clear,
        secretKey: await _keyStore(),
        nonce: nonce,
        aad: _aad(id, 'transcript'),
      );
      _database.execute(
        'UPDATE whisper_audio SET transcript_ciphertext = ?, '
        'transcript_nonce = ?, transcript_mac = ? WHERE id = ?',
        [
          Uint8List.fromList(box.cipherText),
          nonce,
          Uint8List.fromList(box.mac.bytes),
          id,
        ],
      );
    } finally {
      clear.fillRange(0, clear.length, 0);
    }
  }

  Future<String?> transcript(String id) async {
    _ensureOpen();
    final rows = _database.select(
      'SELECT transcript_ciphertext, transcript_nonce, transcript_mac '
      'FROM whisper_audio WHERE id = ?',
      [id],
    );
    if (rows.isEmpty || rows.single['transcript_ciphertext'] == null) {
      return null;
    }
    final clear = await _cipher.decrypt(
      SecretBox(
        rows.single['transcript_ciphertext'] as Uint8List,
        nonce: rows.single['transcript_nonce'] as Uint8List,
        mac: Mac(rows.single['transcript_mac'] as Uint8List),
      ),
      secretKey: await _keyStore(),
      aad: _aad(id, 'transcript'),
    );
    try {
      return utf8.decode(clear);
    } finally {
      clear.fillRange(0, clear.length, 0);
    }
  }

  Future<Uint8List> audio(String id) async {
    _ensureOpen();
    final rows = _database.select(
      'SELECT audio_ciphertext, audio_nonce, audio_mac FROM whisper_audio '
      'WHERE id = ?',
      [id],
    );
    if (rows.isEmpty || rows.single['audio_ciphertext'] == null) {
      throw StateError('Raw audio has been removed.');
    }
    return Uint8List.fromList(
      await _cipher.decrypt(
        SecretBox(
          rows.single['audio_ciphertext'] as Uint8List,
          nonce: rows.single['audio_nonce'] as Uint8List,
          mac: Mac(rows.single['audio_mac'] as Uint8List),
        ),
        secretKey: await _keyStore(),
        aad: _aad(id, 'audio'),
      ),
    );
  }

  Future<T> withPlaybackFile<T>(
    String id,
    Future<T> Function(File file) operation,
  ) async {
    final record = await get(id);
    if (record == null) throw StateError('Unknown audio record: $id');
    final bytes = await audio(id);
    final file = File(
      '${Directory.systemTemp.path}/whisper-$id.working.${record.extension}',
    );
    try {
      await file.writeAsBytes(bytes, flush: true);
      return await operation(file);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
      if (file.existsSync()) await file.delete();
    }
  }

  Future<void> setArchived(String id, bool archived) async {
    _ensureOpen();
    _database.execute('UPDATE whisper_audio SET archived = ? WHERE id = ?', [
      archived ? 1 : 0,
      id,
    ]);
  }

  Future<void> removeRawAudio(String id) async {
    _ensureOpen();
    _database.execute(
      'UPDATE whisper_audio SET audio_ciphertext = NULL, audio_nonce = NULL, '
      'audio_mac = NULL, audio_expires_at = NULL WHERE id = ?',
      [id],
    );
  }

  Future<List<String>> cleanupExpiredAudio() async {
    _ensureOpen();
    final now = _clock().toUtc().millisecondsSinceEpoch;
    final rows = _database.select(
      'SELECT id FROM whisper_audio WHERE archived = 0 AND '
      'audio_expires_at <= ?',
      [now],
    );
    final ids = rows.map((row) => row['id'] as String).toList();
    for (final id in ids) {
      _database.execute(
        'DELETE FROM whisper_audio_chunks WHERE record_id = ?',
        [id],
      );
    }
    _database.execute(
      'UPDATE whisper_audio SET audio_ciphertext = NULL, audio_nonce = NULL, '
      'audio_mac = NULL, audio_expires_at = NULL WHERE archived = 0 AND '
      'audio_expires_at <= ?',
      [now],
    );
    return List.unmodifiable(ids);
  }

  Future<AudioVaultRecord?> get(String id) async {
    _ensureOpen();
    final rows = _database.select(
      'SELECT id, captured_at, duration_ms, extension, audio_ciphertext, '
      'transcript_ciphertext, audio_expires_at, archived '
      'FROM whisper_audio WHERE id = ?',
      [id],
    );
    return rows.isEmpty ? null : _record(rows.single);
  }

  Future<List<AudioVaultRecord>> list() async {
    _ensureOpen();
    return List.unmodifiable(
      _database
          .select(
            'SELECT id, captured_at, duration_ms, extension, '
            'audio_ciphertext, transcript_ciphertext, audio_expires_at, '
            'archived FROM whisper_audio ORDER BY captured_at DESC',
          )
          .map(_record),
    );
  }

  void clear() {
    _database.execute('DELETE FROM whisper_audio_chunks');
    _database.execute('DELETE FROM whisper_audio');
  }

  void checkpoint() => _database.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  void close() {
    if (_closed) return;
    _closed = true;
    _database.close();
  }

  AudioVaultRecord _record(Row row) => AudioVaultRecord(
    id: row['id'] as String,
    capturedAt: DateTime.fromMillisecondsSinceEpoch(
      row['captured_at'] as int,
      isUtc: true,
    ),
    extension: row['extension'] as String,
    duration: Duration(milliseconds: row['duration_ms'] as int),
    hasAudio: row['audio_ciphertext'] != null,
    hasTranscript: row['transcript_ciphertext'] != null,
    archived: row['archived'] == 1,
    audioExpiresAt: row['audio_expires_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row['audio_expires_at'] as int,
            isUtc: true,
          ),
  );

  Uint8List _aad(String id, String field) =>
      Uint8List.fromList(utf8.encode('ArchiveMe.WhisperAudio.v1|$id|$field'));

  Uint8List _randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));

  void _ensureOpen() {
    if (_closed) throw StateError('Audio vault is closed.');
  }
}
