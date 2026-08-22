import 'dart:io';

import 'package:archiveme_mobile/features/search/reflection_text_processor.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_005_hybrid_search.dart';
import 'package:archiveme_mobile/workers/embedding/embedding_index_worker_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../storage/sqlite/support/sqlite_test_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  group('EmbeddingIndexWorkerService.indexTranscript', () {
    late Directory dir;
    late String dbPath;
    late AppSqliteDatabase sqlite;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('embedding_transcript_');
      dbPath = '${dir.path}/transcript.sqlite';
      sqlite = await AppSqliteDatabase.open(
        filePath: dbPath,
        password: testSqliteEncryptionPassword,
      );
      await sqlite.database.execute('''
        INSERT INTO journal_entries (
          id, created_at, updated_at, deleted_at, is_archived,
          transcript, has_verified_proof, payload_json
        ) VALUES (
          'entry-summary', 1, 1, NULL, 0, 'summary text', 0, '{}'
        )
      ''');
    });

    tearDown(() async {
      await EmbeddingIndexWorkerService.instance.dispose();
      await sqlite.close();
      await dir.delete(recursive: true);
    });

    test('embeds llmSummary and rejects legacy raw text payloads', () async {
      const llmSummary =
          'Quiet morning walk helped me reset before a busy workday ahead.';
      expect(llmSummary.length, greaterThanOrEqualTo(ReflectionTextProcessor.minTextChars));

      final indexed = await EmbeddingIndexWorkerService.instance.indexTranscript(
        filePath: dbPath,
        entryId: 'entry-summary',
        llmSummary: llmSummary,
        encryptionPassword: testSqliteEncryptionPassword,
      );

      expect(indexed, isTrue);

      final repo = MemoryTranscriptSearchRepository(sqlite);
      final embeddings = await repo.loadEmbeddingsFor(['entry-summary']);
      expect(embeddings, contains('entry-summary'));

      final legacyRejected = await EmbeddingIndexWorkerService.instance.dispatch<bool>(
        operation: EmbeddingIndexWorkerOperations.indexTranscript,
        payload: {
          'filePath': dbPath,
          'encryptionPassword': testSqliteEncryptionPassword,
          'entryId': 'entry-legacy',
          'text': 'This raw STT ramble should never be embedded into vec storage anymore.',
        },
      );
      expect(legacyRejected, isFalse);

      final rows = await sqlite.database.query(
        Migration005HybridSearch.embeddingsTable,
      );
      expect(rows, hasLength(1));
      expect(rows.single['entry_id'], 'entry-summary');
    });
  });
}
