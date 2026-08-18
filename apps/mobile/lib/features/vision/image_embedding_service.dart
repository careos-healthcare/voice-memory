import 'package:archiveme_mobile/features/image_evidence/image_evidence_store.dart';
import 'package:archiveme_mobile/features/vision/image_embedding_inference.dart';
import 'package:archiveme_mobile/features/vision/image_processor.dart';
import 'package:archiveme_mobile/features/vision/local_visual_projection_inference.dart';
import 'package:archiveme_mobile/features/vision/offline_image_embedding_guard.dart';
import 'package:archiveme_mobile/features/vision/onnx_image_embedding_inference.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/sqlite/image_attachment_embedding_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';

/// End-to-end offline path: local bytes → tensor → embedding → sqlite-vec.
class ImageEmbeddingService {
  ImageEmbeddingService({
    ImageProcessor? processor,
    required ImageEmbeddingInference inference,
    required ImageAttachmentEmbeddingRepository repository,
    JournalSqliteRepository? journalSqlite,
  })  : _processor = processor ?? const ImageProcessor(),
        _inference = inference,
        _repository = repository,
        _journalSqlite = journalSqlite;

  final ImageProcessor _processor;
  final ImageEmbeddingInference _inference;
  final ImageAttachmentEmbeddingRepository _repository;
  final JournalSqliteRepository? _journalSqlite;

  /// Prefers bundled ONNX encoder; falls back to local visual projection.
  static Future<ImageEmbeddingService> create({
    required ImageAttachmentEmbeddingRepository repository,
    JournalSqliteRepository? journalSqlite,
    ImageEmbeddingInference? inferenceOverride,
  }) async {
    final inference = inferenceOverride ??
        await OnnxImageEmbeddingInference.tryCreateFromAsset() ??
        LocalVisualProjectionInference();
    return ImageEmbeddingService(
      inference: inference,
      repository: repository,
      journalSqlite: journalSqlite,
    );
  }

  /// Computes and stores an embedding for [evidence] linked to [entryId].
  ///
  /// Pass [journalEntryForMirror] when the local SQLite journal mirror must be
  /// updated before the foreign-key insert (e.g. immediately after capture save).
  ///
  /// Never uploads image bytes or vectors — see [OfflineImageEmbeddingGuard].
  Future<void> indexJournalAttachment({
    required String entryId,
    required ImageEvidence evidence,
    JournalEntry? journalEntryForMirror,
  }) {
    return OfflineImageEmbeddingGuard.runOffline(() async {
      if (entryId.isEmpty || evidence.evidenceId.isEmpty) return;

      final mirrorEntry = journalEntryForMirror;
      final journalSqlite = _journalSqlite;
      if (mirrorEntry != null && journalSqlite != null) {
        await journalSqlite.upsertEntries([mirrorEntry]);
      }

      final file = await ImageEvidenceStore.openBlob(evidence);
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final tensor = _processor.prepareModelInput(bytes);
      final embedding = await _inference.embed(tensor);

      await _repository.upsertEmbedding(
        evidenceId: evidence.evidenceId,
        entryId: entryId,
        embedding: embedding,
      );
    });
  }

  Future<void> deleteForEvidence(String evidenceId) {
    return _repository.deleteEmbedding(evidenceId);
  }

  Future<void> deleteForEntry(String entryId) {
    return _repository.deleteEmbeddingsForEntry(entryId);
  }
}
