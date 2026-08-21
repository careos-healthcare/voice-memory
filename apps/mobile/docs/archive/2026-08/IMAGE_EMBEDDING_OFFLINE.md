# On-device image embeddings

Journal photo attachments are processed entirely on-device. No image bytes or
embedding vectors are uploaded.

## Pipeline

1. **Capture** — `ImageEvidenceStore.persist` writes the blob under app documents.
2. **Preprocess** — `ImageProcessor.prepareModelInput` resizes to 224×224 and
   applies ImageNet normalization (NCHW float tensor).
3. **Infer** — `LocalVisualProjectionInference` (default) or bundled ONNX encoder
   (`assets/models/image_encoder.onnx` via `OnnxImageEmbeddingInference`).
4. **Index** — `ImageAttachmentEmbeddingRepository` stores 768-d vectors in SQLite
   (`journal_image_embeddings` + optional `journal_image_vec` sqlite-vec table).
5. **Search** — `HybridSearchEngine` fuses transcript and image vector hits.

## Zero-network enforcement

- `OfflineImageEmbeddingGuard.runOffline` wraps all embedding work in
  `ImageEmbeddingService.indexJournalAttachment`.
- `HttpTransport` calls `OfflineImageEmbeddingGuard.assertOfflineBlocked` so HTTP
  cannot run while embedding is in-flight.
- Vision code lives under `lib/features/vision/` and must not import `http`, `dio`,
  or remote API clients (see `test/features/vision/offline_image_embedding_guard_test.dart`).

## Optional ONNX model

Add a 768-d vision encoder ONNX file at:

```
apps/mobile/assets/models/image_encoder.onnx
```

Register the asset in `pubspec.yaml` and call `ImageEmbeddingService.create()` at
startup to prefer ONNX over the local projection fallback.

## Usage

After saving an image caption entry, indexing runs automatically via
`CapturePipelineService.saveImageCaptionEntry`. Manual indexing:

```dart
final service = ImageEmbeddingService(
  inference: LocalVisualProjectionInference(),
  repository: ImageAttachmentEmbeddingRepository(sqlite),
);
await service.indexJournalAttachment(
  entryId: entry.id,
  evidence: entry.imageEvidence!,
);
```

Search by image embedding through hybrid retrieval:

```dart
final hits = await hybridSearchEngine.search(
  queryEmbedding: queryVector,
  limit: 20,
);
```
