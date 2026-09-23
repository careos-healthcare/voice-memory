import 'dart:typed_data';

import 'package:archiveme_mobile/core/database/vector_store.dart';
import 'package:archiveme_mobile/features/attachments/local_ocr_processor.dart';
import 'package:archiveme_mobile/features/sample_vault/sample_vault_embedder.dart';
import 'package:archiveme_mobile/features/search/entity_extraction_worker.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_023_attachment_text.dart';
import 'package:sqflite/sqflite.dart';

/// A moment after its photo text, embedding, and entities are stored.
class AttachmentIngestionResult {
  const AttachmentIngestionResult({
    required this.document,
    required this.embedding,
    required this.vectorHit,
    required this.entityIds,
  });

  final OcrDocument document;
  final VectorStoreRow embedding;
  final VectorStoreHit? vectorHit;
  final List<String> entityIds;
}

/// Saves OCR text on the moment, embeds it, and links named entities.
class AttachmentOcrIngestion {
  const AttachmentOcrIngestion({
    required this.processor,
    this.embed = SampleVaultEmbedder.embed,
    this.entities = const EntityExtractionWorker(),
  });

  final LocalOcrProcessor processor;
  final Float32List Function(String text) embed;
  final EntityExtractionWorker entities;

  Future<AttachmentIngestionResult> ingest({
    required DatabaseExecutor db,
    required String entryId,
    required Uint8List imageBytes,
    required String filePath,
    String? attachmentId,
  }) async {
    final document = await processor.processBytes(imageBytes);
    final updated = await db.update(
      Migration023AttachmentText.journalEntriesTable,
      {Migration023AttachmentText.column: document.text},
      where: 'id = ?',
      whereArgs: [entryId],
    );
    if (updated == 0) {
      throw StateError('Missing moment $entryId');
    }
    final vector = embed(document.text);
    final row = VectorStoreRow(id: entryId, values: vector);
    final hits = VectorStore.scan(rows: [row], query: vector, limit: 1);
    await db.insert(Migration023AttachmentText.attachmentsTable, {
      'id': attachmentId ?? '$entryId-attachment',
      'entry_id': entryId,
      'file_path': filePath,
      'attachment_text': document.text,
      'embedding': SampleVaultEmbedder.toBlob(vector),
    });
    final extraction = document.text.trim().isEmpty
        ? null
        : await entities.processEntry(
            db: db,
            entryId: entryId,
            transcript: document.text,
          );
    return AttachmentIngestionResult(
      document: document,
      embedding: row,
      vectorHit: hits.isEmpty ? null : hits.first,
      entityIds: extraction?.entityIds ?? const [],
    );
  }
}
