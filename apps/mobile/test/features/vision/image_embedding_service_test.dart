import 'dart:io';
import 'dart:typed_data';
import '../../storage/sqlite/support/sqlite_test_database.dart';

import 'package:archiveme_mobile/features/insight_engine/hybrid_search_engine.dart';
import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/features/vision/image_embedding_service.dart';
import 'package:archiveme_mobile/features/vision/image_processor.dart';
import 'package:archiveme_mobile/features/vision/local_visual_projection_inference.dart';
import 'package:archiveme_mobile/features/vision/offline_image_embedding_guard.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/image_attachment_embedding_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

JournalEntry _entry({required String id}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 3, 1),
    transcript: 'photo caption',
    durationSeconds: 0,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 0,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

Future<File> _writeTempPng(
  Directory dir, {
  required int r,
  required int g,
  required int b,
}) async {
  final image = img.Image(width: 128, height: 96);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  final file = File('${dir.path}/sample_$r$g$b.png');
  await file.writeAsBytes(img.encodePng(image));
  return file;
}

Future<List<double>> _embeddingForFile(File file) async {
  const processor = ImageProcessor();
  final inference = LocalVisualProjectionInference();
  final bytes = await file.readAsBytes();
  final tensor = processor.prepareModelInput(bytes);
  return inference.embed(tensor);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  group('ImageEmbeddingService', () {
    late Directory tempDir;
    late AppSqliteDatabase db;
    late ImageAttachmentEmbeddingRepository imageRepo;
    late ImageEmbeddingService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('image_embed_test_');
      db = await openTestAppSqliteDatabase();
      imageRepo = ImageAttachmentEmbeddingRepository(db);
      service = ImageEmbeddingService(
        inference: LocalVisualProjectionInference(),
        repository: imageRepo,
        journalSqlite: JournalSqliteRepository(db),
      );
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('indexes embedding from local file under offline guard', () async {
      final png = await _writeTempPng(tempDir, r: 10, g: 180, b: 40);
      final evidence = ImageEvidence(
        evidenceId: 'ev-1',
        caption: 'garden photo',
        mimeType: 'image/png',
        attachedAt: DateTime.utc(2026, 3, 1),
        localPath: png.path,
      );

      await OfflineImageEmbeddingGuard.runOffline(() async {
        await service.indexJournalAttachment(
          entryId: 'entry-1',
          evidence: evidence,
          journalEntryForMirror: _entry(id: 'entry-1'),
        );
      });

      final query = await _embeddingForFile(png);
      final hits = await imageRepo.vectorSearchByEntry(
        queryEmbedding: query,
        limit: 3,
      );
      expect(hits, contains('entry-1'));
    });

    test('stores searchable 768-d embedding linked to entry', () async {
      final png = await _writeTempPng(tempDir, r: 220, g: 20, b: 90);
      final evidence = ImageEvidence(
        evidenceId: 'ev-red',
        caption: 'red scene',
        mimeType: 'image/png',
        attachedAt: DateTime.utc(2026, 3, 1),
        localPath: png.path,
      );

      await service.indexJournalAttachment(
        entryId: 'entry-red',
        evidence: evidence,
        journalEntryForMirror: _entry(id: 'entry-red'),
      );

      final query = await _embeddingForFile(png);
      final hits = await imageRepo.vectorSearchByEntry(
        queryEmbedding: query,
        limit: 3,
      );

      expect(hits.first, 'entry-red');
      expect(query.length, imageEmbeddingDimensions);
    });

    test('hybrid search includes image attachment vectors', () async {
      final png = await _writeTempPng(tempDir, r: 30, g: 30, b: 200);
      final evidence = ImageEvidence(
        evidenceId: 'ev-blue',
        caption: 'blue scene',
        mimeType: 'image/png',
        attachedAt: DateTime.utc(2026, 3, 1),
        localPath: png.path,
      );

      await service.indexJournalAttachment(
        entryId: 'entry-blue',
        evidence: evidence,
        journalEntryForMirror: _entry(id: 'entry-blue'),
      );

      final searchRepo = MemoryTranscriptSearchRepository(db);
      final engine = HybridSearchEngine(
        repository: searchRepo,
        imageRepository: imageRepo,
      );

      final query = await _embeddingForFile(png);
      final hits = await engine.search(queryEmbedding: query, limit: 5);

      expect(hits.map((hit) => hit.entryId), contains('entry-blue'));
    });
  });
}
