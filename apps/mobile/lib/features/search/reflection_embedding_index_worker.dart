import 'dart:async';
import 'dart:convert';

import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/features/search/offline_reflection_search_guard.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_repository.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_text.dart';
import 'package:archiveme_mobile/features/search/reflection_text_processor.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/workers/embedding/embedding_index_worker_service.dart';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

/// Background worker that embeds reflections and LLM summaries off the UI thread.
class ReflectionEmbeddingIndexWorker {
  ReflectionEmbeddingIndexWorker({
    required ReflectionEmbeddingRepository repository,
    required JournalStore journalStore,
    required String sqliteFilePath,
    String? sqliteKeyAlias,
    String? sqliteEncryptionPassword,
    EmbeddingIndexWorkerService? embeddingWorker,
    Duration debounce = const Duration(milliseconds: 350),
  }) : _repository = repository,
       _journalStore = journalStore,
       _sqliteFilePath = sqliteFilePath,
       _sqliteKeyAlias = sqliteKeyAlias,
       _sqliteEncryptionPassword = sqliteEncryptionPassword,
       _embeddingWorker =
           embeddingWorker ?? EmbeddingIndexWorkerService.instance,
       _debounce = debounce;

  final ReflectionEmbeddingRepository _repository;
  final JournalStore _journalStore;
  final String _sqliteFilePath;
  final String? _sqliteKeyAlias;
  final String? _sqliteEncryptionPassword;
  final EmbeddingIndexWorkerService _embeddingWorker;
  final Duration _debounce;

  final Set<String> _queuedEntryIds = <String>{};
  final Map<String, String> _pendingReflectionText = {};
  final Map<String, String> _pendingLlmSummaries = {};
  Timer? _debounceTimer;
  var _flushInFlight = false;

  void enqueue(JournalEntry entry) {
    if (entry.isDeleted) return;
    _queuedEntryIds.add(entry.id);
    _scheduleFlush();
  }

  /// Stages the compressed local-LLM journal summary for vec0 transcript indexing.
  void stageLlmSummary({
    required String entryId,
    required String llmSummary,
  }) {
    final trimmed = llmSummary.trim();
    if (entryId.isEmpty ||
        trimmed.length < ReflectionTextProcessor.minTextChars) {
      return;
    }
    _pendingLlmSummaries[entryId] = trimmed;
    _queuedEntryIds.add(entryId);
    _scheduleFlush();
  }

  void enqueueReflectionDto({
    required String entryId,
    required ReflectionDto reflection,
  }) {
    if (entryId.isEmpty) return;
    _pendingReflectionText[entryId] = ReflectionEmbeddingText.fromReflectionDto(
      reflection,
    );
    _queuedEntryIds.add(entryId);
    _scheduleFlush();
  }

  Future<void> indexAllPending(JournalStore journalStore) async {
    final entries = await journalStore.loadAllIncludingTombstones();
    for (final entry in entries) {
      if (entry.isDeleted) continue;
      _queuedEntryIds.add(entry.id);
    }
    if (_queuedEntryIds.isNotEmpty) {
      await flush();
    }
  }

  void _scheduleFlush() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      unawaited(flush());
    });
  }

  /// Test hook: cancels a pending debounced flush so it cannot fire after the
  /// test completes and run against a database the next test is about to close.
  /// Only cancels the timer — it never disposes the worker or closes the DB, so
  /// shared setUpAll harnesses keep working. See flutter_test_config.dart.
  void quiesceForTest() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  Future<int> flush() async {
    if (_flushInFlight) return 0;
    _flushInFlight = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;

    try {
      if (_queuedEntryIds.isEmpty) return 0;
      final ids = _queuedEntryIds.toList(growable: false);
      _queuedEntryIds.clear();
      var indexed = 0;
      for (final entryId in ids) {
        final didIndex = await _indexEntryId(entryId);
        if (didIndex) indexed++;
      }
      return indexed;
    } on DatabaseException catch (e) {
      // A debounced background flush can race app/DB shutdown (and, in tests,
      // teardown) and find the connection already closed. That is expected
      // best-effort behaviour, not a failure — stop quietly rather than leak an
      // unhandled error.
      if (e.isDatabaseClosedError()) return 0;
      rethrow;
    } finally {
      _flushInFlight = false;
    }
  }

  Future<bool> indexEntry(JournalEntry entry) async {
    if (entry.isDeleted) {
      await _repository.deleteEmbedding(entry.id);
      return false;
    }
    return _indexReflection(
      entryId: entry.id,
      text: ReflectionEmbeddingText.fromEntry(entry),
    );
  }

  Future<bool> indexReflectionDto({
    required String entryId,
    required ReflectionDto reflection,
  }) {
    return _indexReflection(
      entryId: entryId,
      text: ReflectionEmbeddingText.fromReflectionDto(reflection),
    );
  }

  Future<bool> _indexEntryId(String entryId) async {
    var indexed = false;

    final pendingText = _pendingReflectionText.remove(entryId);
    if (pendingText != null) {
      indexed =
          await _indexReflection(entryId: entryId, text: pendingText) ||
          indexed;
    } else {
      final entry = await _journalStore.getById(entryId);
      if (entry != null) {
        indexed = await indexEntry(entry) || indexed;
      }
    }

    final pendingSummary = _pendingLlmSummaries.remove(entryId);
    if (pendingSummary != null) {
      await _indexLlmSummary(entryId: entryId, llmSummary: pendingSummary);
    }

    return indexed;
  }

  Future<bool> _indexReflection({
    required String entryId,
    required String text,
  }) async {
    final resolved = text.trim();
    if (resolved.length < ReflectionTextProcessor.minTextChars) {
      return false;
    }

    final contentHash = _hashText(resolved);
    final existingHash = await _repository.readContentHash(entryId);
    if (existingHash == contentHash) {
      return false;
    }

    return OfflineReflectionSearchGuard.runOffline(() {
      return _embeddingWorker.indexReflection(
        filePath: _sqliteFilePath,
        entryId: entryId,
        text: resolved,
        contentHash: contentHash,
        keyAlias: _sqliteKeyAlias,
        encryptionPassword: _sqliteEncryptionPassword,
      );
    });
  }

  Future<void> _indexLlmSummary({
    required String entryId,
    required String llmSummary,
  }) async {
    final resolved = llmSummary.trim();
    if (resolved.length < ReflectionTextProcessor.minTextChars) {
      return;
    }

    try {
      await OfflineReflectionSearchGuard.runOffline(() {
        return _embeddingWorker.indexTranscript(
          filePath: _sqliteFilePath,
          entryId: entryId,
          llmSummary: resolved,
          keyAlias: _sqliteKeyAlias,
          encryptionPassword: _sqliteEncryptionPassword,
        );
      });
    } on Object {
      // Transcript vectors require a matching journal_entries row in SQLite.
    }
  }

  static String _hashText(String text) {
    return sha256.convert(utf8.encode(text)).toString();
  }

  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _queuedEntryIds.clear();
    _pendingReflectionText.clear();
    _pendingLlmSummaries.clear();
  }
}
