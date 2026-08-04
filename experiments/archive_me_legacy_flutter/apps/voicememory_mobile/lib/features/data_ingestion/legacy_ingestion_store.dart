import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../services/ai/sqlite_vec_vector_store.dart';
import '../../services/local_storage/encrypted_sqlite_text_codec.dart';
import 'markdown_vault_models.dart';

final class PreparedMarkdownNote {
  const PreparedMarkdownNote({required this.note, required this.chunks});

  final ParsedMarkdownNote note;
  final List<EmbeddedMarkdownChunk> chunks;
}

final class LegacyStoreWriteResult {
  const LegacyStoreWriteResult({
    required this.insertedNotes,
    required this.insertedChunks,
    required this.skippedNotes,
    required this.sqliteWriteTime,
  });

  final List<ParsedMarkdownNote> insertedNotes;
  final int insertedChunks;
  final int skippedNotes;
  final Duration sqliteWriteTime;
}

final class LegacyDedupeResult {
  const LegacyDedupeResult({required this.notes, required this.skipped});

  final List<ParsedMarkdownNote> notes;
  final int skipped;
}

final class LegacySweepNote {
  LegacySweepNote({
    required this.id,
    required this.title,
    required this.markdown,
    required Iterable<String> tags,
  }) : tags = Set.unmodifiable(tags);

  final String id;
  final String title;
  final String markdown;
  final Set<String> tags;
}

/// Authoritative encrypted-column SQLite store for imported markdown notes.
///
/// Titles, paths, markdown, metadata, links, chunk text, and embeddings are
/// AES-GCM encrypted before SQLite sees them. The sqlite-vec table is a local,
/// disposable acceleration cache and never becomes the source of truth.
final class LegacyIngestionStore {
  LegacyIngestionStore._(this._database, this._codec, this.vectorStore);

  final Database _database;
  final EncryptedSqliteTextCodec _codec;
  final SqliteVecVectorStore vectorStore;
  bool _closed = false;

  static Future<LegacyIngestionStore> open({
    required String databasePath,
    required EncryptedSqliteTextCodec codec,
    required SqliteVecVectorStore vectorStore,
  }) async {
    final database = sqlite3.open(databasePath)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA synchronous = NORMAL')
      ..execute('PRAGMA foreign_keys = ON')
      ..execute('PRAGMA busy_timeout = 5000')
      ..execute('''
        CREATE TABLE IF NOT EXISTS legacy_notes(
          id TEXT PRIMARY KEY,
          title_hash TEXT NOT NULL UNIQUE,
          content_hash TEXT NOT NULL UNIQUE,
          relative_path_enc TEXT NOT NULL,
          title_enc TEXT NOT NULL,
          markdown_enc TEXT NOT NULL,
          tags_enc TEXT NOT NULL,
          aliases_enc TEXT NOT NULL,
          created_at INTEGER,
          imported_at INTEGER NOT NULL,
          is_digested INTEGER NOT NULL DEFAULT 0
        )
      ''')
      ..execute('''
        CREATE TABLE IF NOT EXISTS legacy_links(
          source_note_id TEXT NOT NULL,
          target_title_hash TEXT NOT NULL,
          target_title_enc TEXT NOT NULL,
          alias_enc TEXT,
          PRIMARY KEY(source_note_id, target_title_hash),
          FOREIGN KEY(source_note_id) REFERENCES legacy_notes(id)
            ON DELETE CASCADE
        )
      ''')
      ..execute('''
        CREATE TABLE IF NOT EXISTS legacy_chunks(
          id TEXT PRIMARY KEY,
          note_id TEXT NOT NULL,
          chunk_index INTEGER NOT NULL,
          start_char INTEGER NOT NULL,
          end_char INTEGER NOT NULL,
          text_enc TEXT NOT NULL,
          embedding_enc TEXT NOT NULL,
          FOREIGN KEY(note_id) REFERENCES legacy_notes(id) ON DELETE CASCADE,
          UNIQUE(note_id, chunk_index)
        )
      ''')
      ..execute(
        'CREATE INDEX IF NOT EXISTS legacy_chunks_note '
        'ON legacy_chunks(note_id)',
      );
    final noteColumns = database
        .select('PRAGMA table_info(legacy_notes)')
        .map((row) => row['name'] as String)
        .toSet();
    if (!noteColumns.contains('is_digested')) {
      database.execute(
        'ALTER TABLE legacy_notes '
        'ADD COLUMN is_digested INTEGER NOT NULL DEFAULT 0',
      );
    }
    database.execute(
      'CREATE INDEX IF NOT EXISTS legacy_notes_digest '
      'ON legacy_notes(is_digested, imported_at)',
    );
    return LegacyIngestionStore._(database, codec, vectorStore);
  }

  LegacyDedupeResult deduplicate(List<ParsedMarkdownNote> notes) {
    _ensureOpen();
    final fresh = <ParsedMarkdownNote>[];
    var skipped = 0;
    final statement = _database.prepare(
      'SELECT id FROM legacy_notes '
      'WHERE title_hash = ? OR content_hash = ? LIMIT 1',
    );
    try {
      for (final note in notes) {
        if (statement.select([note.titleHash, note.contentHash]).isEmpty) {
          fresh.add(note);
        } else {
          skipped++;
        }
      }
    } finally {
      statement.close();
    }
    return LegacyDedupeResult(
      notes: List.unmodifiable(fresh),
      skipped: skipped,
    );
  }

  LegacyStoreWriteResult writeBatch(List<PreparedMarkdownNote> batch) {
    _ensureOpen();
    if (batch.isEmpty) {
      return const LegacyStoreWriteResult(
        insertedNotes: [],
        insertedChunks: 0,
        skippedNotes: 0,
        sqliteWriteTime: Duration.zero,
      );
    }
    final watch = Stopwatch()..start();
    final inserted = <ParsedMarkdownNote>[];
    var insertedChunks = 0;
    var skipped = 0;
    final vectors = <SqliteVecRecord>[];
    final dedupe = _database.prepare(
      'SELECT id FROM legacy_notes '
      'WHERE title_hash = ? OR content_hash = ? LIMIT 1',
    );
    final insertNote = _database.prepare('''
      INSERT INTO legacy_notes(
        id, title_hash, content_hash, relative_path_enc, title_enc,
        markdown_enc, tags_enc, aliases_enc, created_at, imported_at,
        is_digested
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
    ''');
    final insertLink = _database.prepare('''
      INSERT OR IGNORE INTO legacy_links(
        source_note_id, target_title_hash, target_title_enc, alias_enc
      ) VALUES (?, ?, ?, ?)
    ''');
    final insertChunk = _database.prepare('''
      INSERT INTO legacy_chunks(
        id, note_id, chunk_index, start_char, end_char, text_enc, embedding_enc
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''');
    _database.execute('BEGIN IMMEDIATE');
    try {
      for (final item in batch) {
        final note = item.note;
        if (dedupe.select([note.titleHash, note.contentHash]).isNotEmpty) {
          skipped++;
          continue;
        }
        insertNote.execute([
          note.id,
          note.titleHash,
          note.contentHash,
          _encode(note.relativePath),
          _encode(note.title),
          _encode(note.markdown),
          _encode(jsonEncode(note.tags)),
          _encode(jsonEncode(note.aliases)),
          note.createdAt?.millisecondsSinceEpoch,
          DateTime.now().toUtc().millisecondsSinceEpoch,
        ]);
        for (final link in note.links) {
          insertLink.execute([
            note.id,
            _titleHash(link.target),
            _encode(link.target),
            _codec.encode(link.alias),
          ]);
        }
        for (final embedded in item.chunks) {
          final id = '${note.id}:chunk:${embedded.chunk.index}';
          insertChunk.execute([
            id,
            note.id,
            embedded.chunk.index,
            embedded.chunk.start,
            embedded.chunk.end,
            _encode(embedded.chunk.text),
            _encode(base64Encode(_embeddingBytes(embedded.embedding))),
          ]);
          vectors.add(
            SqliteVecRecord(
              entryId: id,
              embedding: embedded.embedding,
              clusterType: 'legacy_markdown',
              updatedAt: DateTime.now().toUtc(),
              confidence: 1,
              nodeIds: [note.id],
              tags: note.tags,
            ),
          );
          insertedChunks++;
        }
        inserted.add(note);
      }
      _database.execute('COMMIT');
    } on Object {
      _database.execute('ROLLBACK');
      rethrow;
    } finally {
      dedupe.close();
      insertNote.close();
      insertLink.close();
      insertChunk.close();
    }
    if (vectors.isNotEmpty && vectorStore.isAccelerated) {
      try {
        vectorStore.upsertAll(vectors);
      } on Object {
        // sqlite-vec is a disposable cache. The encrypted authoritative
        // transaction has committed and must not be reported as failed.
      }
    }
    return LegacyStoreWriteResult(
      insertedNotes: List.unmodifiable(inserted),
      insertedChunks: insertedChunks,
      skippedNotes: skipped,
      sqliteWriteTime: watch.elapsed,
    );
  }

  int noteCount() {
    _ensureOpen();
    return _database
            .select('SELECT COUNT(*) AS value FROM legacy_notes')
            .single['value']
        as int;
  }

  int undigestedNoteCount() {
    _ensureOpen();
    return _database
            .select(
              'SELECT COUNT(*) AS value FROM legacy_notes '
              'WHERE is_digested = 0',
            )
            .single['value']
        as int;
  }

  List<LegacySweepNote> readUndigestedNotes({int limit = 50}) {
    _ensureOpen();
    final boundedLimit = limit.clamp(1, 50);
    final rows = _database.select(
      '''
      SELECT id, title_enc, markdown_enc, tags_enc
      FROM legacy_notes
      WHERE is_digested = 0
      ORDER BY imported_at ASC, id ASC
      LIMIT ?
      ''',
      [boundedLimit],
    );
    return List.unmodifiable(
      rows.map(
        (row) => LegacySweepNote(
          id: row['id'] as String,
          title: _codec.decode(row['title_enc'] as String) ?? '',
          markdown: _codec.decode(row['markdown_enc'] as String) ?? '',
          tags:
              (jsonDecode(_codec.decode(row['tags_enc'] as String) ?? '[]')
                      as List)
                  .whereType<String>(),
        ),
      ),
    );
  }

  void markDigested(Iterable<String> noteIds) {
    _ensureOpen();
    final ids = noteIds.toSet();
    if (ids.isEmpty) return;
    final statement = _database.prepare(
      'UPDATE legacy_notes SET is_digested = 1 WHERE id = ?',
    );
    _database.execute('BEGIN IMMEDIATE');
    try {
      for (final id in ids) {
        statement.execute([id]);
      }
      _database.execute('COMMIT');
    } on Object {
      _database.execute('ROLLBACK');
      rethrow;
    } finally {
      statement.close();
    }
  }

  void clear() {
    _ensureOpen();
    _database.execute('BEGIN IMMEDIATE');
    try {
      _database
        ..execute('DELETE FROM legacy_links')
        ..execute('DELETE FROM legacy_chunks')
        ..execute('DELETE FROM legacy_notes')
        ..execute('COMMIT');
    } on Object {
      _database.execute('ROLLBACK');
      rethrow;
    }
    if (vectorStore.isAccelerated) vectorStore.clear();
  }

  void close() {
    if (_closed) return;
    _closed = true;
    vectorStore.close();
    _database.close();
  }

  String _encode(String value) => _codec.encode(value)!;

  void _ensureOpen() {
    if (_closed) throw StateError('Legacy ingestion store is closed.');
  }

  static Uint8List _embeddingBytes(Float32List embedding) => embedding.buffer
      .asUint8List(embedding.offsetInBytes, embedding.lengthInBytes);

  static String _titleHash(String title) {
    final normalized = title.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    return sha256.convert(utf8.encode(normalized)).toString();
  }
}
