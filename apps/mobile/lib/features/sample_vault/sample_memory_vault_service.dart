import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/sample_vault/sample_vault_embedder.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// One preloaded moment from the sample vault.
class SampleVaultEntry {
  const SampleVaultEntry({
    required this.id,
    required this.theme,
    required this.title,
    required this.body,
  });

  final String id;
  final String theme;
  final String title;
  final String body;
}

/// A sample moment ranked by semantic similarity.
class SampleVaultHit {
  const SampleVaultHit({
    required this.entry,
    required this.relevance,
  });

  final SampleVaultEntry entry;
  final double relevance;
}

/// Searches the shipped sample vault with sqlite-vec when it is available.
class SampleMemoryVaultService {
  SampleMemoryVaultService({this.filePath});

  static const assetPath = 'assets/sample_vault/sample_vault.db';
  static const entriesTable = 'sample_entries';
  static const vecTable = 'sample_vault_vec';

  /// sqlite-vec nearest-neighbor query used when the extension is loaded.
  static const vecQuery = '''
    SELECT entry_id, distance
    FROM sample_vault_vec
    WHERE embedding MATCH ? AND k = ?
    ORDER BY distance
  ''';

  final String? filePath;
  Database? _db;

  Future<List<SampleVaultHit>> search(String query, {int limit = 5}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || limit <= 0) return const [];
    final db = await _database();
    final embedding = SampleVaultEmbedder.embed(trimmed);
    final vecHits = await _vecSearch(db, embedding, limit);
    if (vecHits.isNotEmpty) return vecHits;
    return _cosineSearch(db, embedding, limit);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _database() async {
    final open = _db;
    if (open != null) return open;
    final raw = filePath ?? await _copyAsset();
    final path = p.isAbsolute(raw) ? raw : p.join(Directory.current.path, raw);
    final writable = filePath == null;
    final db = await openDatabase(
      path,
      readOnly: !writable,
      singleInstance: false,
    );
    if (writable) await _prepareVec(db);
    _db = db;
    return db;
  }

  Future<String> _copyAsset() async {
    final data = await rootBundle.load(assetPath);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sample_vault.db');
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    return file.path;
  }

  Future<void> _prepareVec(Database db) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS $vecTable USING vec0(
          entry_id TEXT PRIMARY KEY,
          embedding float[${SampleVaultEmbedder.dimensions}]
        )
      ''');
      final existing = await db.rawQuery('SELECT COUNT(*) AS count FROM $vecTable');
      final count = existing.first['count'] as int? ?? 0;
      if (count > 0) return;
      final rows = await db.query(
        entriesTable,
        columns: ['id', 'embedding'],
      );
      for (final row in rows) {
        await db.rawInsert(
          'INSERT INTO $vecTable(entry_id, embedding) VALUES (?, ?)',
          [row['id'], row['embedding']],
        );
      }
    } on Object {
      // The sample rows stay searchable by the stored embeddings.
    }
  }

  Future<List<SampleVaultHit>> _vecSearch(
    Database db,
    Float32List embedding,
    int limit,
  ) async {
    try {
      final rows = await db.rawQuery(vecQuery, [
        SampleVaultEmbedder.toBlob(embedding),
        limit,
      ]);
      if (rows.isEmpty) return const [];
      final hits = <SampleVaultHit>[];
      for (final row in rows) {
        final id = row['entry_id'] as String? ?? '';
        final distance = (row['distance'] as num?)?.toDouble() ?? 0;
        final entry = await _entry(db, id);
        if (entry == null) continue;
        hits.add(
          SampleVaultHit(entry: entry, relevance: 1 / (1 + distance)),
        );
      }
      return hits;
    } on Object {
      return const [];
    }
  }

  Future<List<SampleVaultHit>> _cosineSearch(
    Database db,
    Float32List embedding,
    int limit,
  ) async {
    final rows = await db.query(
      entriesTable,
      columns: ['id', 'theme', 'title', 'body', 'embedding'],
    );
    final hits = <SampleVaultHit>[];
    for (final row in rows) {
      final blob = row['embedding'];
      if (blob is! Uint8List || blob.isEmpty) continue;
      final stored = SampleVaultEmbedder.fromBlob(blob);
      final relevance = SampleVaultEmbedder.cosine(embedding, stored);
      hits.add(
        SampleVaultHit(
          entry: SampleVaultEntry(
            id: row['id'] as String? ?? '',
            theme: row['theme'] as String? ?? '',
            title: row['title'] as String? ?? '',
            body: row['body'] as String? ?? '',
          ),
          relevance: relevance,
        ),
      );
    }
    hits.sort((a, b) {
      final byScore = b.relevance.compareTo(a.relevance);
      if (byScore != 0) return byScore;
      return a.entry.id.compareTo(b.entry.id);
    });
    return hits.take(limit).toList(growable: false);
  }

  Future<SampleVaultEntry?> _entry(Database db, String id) async {
    final rows = await db.query(
      entriesTable,
      columns: ['id', 'theme', 'title', 'body'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return SampleVaultEntry(
      id: row['id'] as String? ?? '',
      theme: row['theme'] as String? ?? '',
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
    );
  }
}
