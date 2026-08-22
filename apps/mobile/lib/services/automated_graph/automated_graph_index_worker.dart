import 'dart:async';
import 'dart:convert';

import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/automated_graph/automated_graph_embedding_text.dart';
import 'package:archiveme_mobile/services/automated_graph/automated_graph_service.dart';
import 'package:archiveme_mobile/features/search/reflection_text_processor.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:crypto/crypto.dart';

/// Debounced queue that builds automated knowledge-graph edges after journal saves.
class AutomatedGraphIndexWorker {
  AutomatedGraphIndexWorker({
    required AutomatedGraphService graphService,
    required JournalStore journalStore,
    Duration debounce = const Duration(milliseconds: 350),
  }) : _graphService = graphService,
       _journalStore = journalStore,
       _debounce = debounce;

  final AutomatedGraphService _graphService;
  final JournalStore _journalStore;
  final Duration _debounce;

  final Set<String> _queuedEntryIds = <String>{};
  Timer? _debounceTimer;
  var _flushInFlight = false;

  void enqueue(JournalEntry entry) {
    if (entry.isDeleted) return;
    _queuedEntryIds.add(entry.id);
    _scheduleFlush();
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
      var built = 0;
      for (final entryId in ids) {
        final didBuild = await _buildForEntryId(entryId);
        if (didBuild) built++;
      }
      return built;
    } finally {
      _flushInFlight = false;
    }
  }

  Future<bool> buildForEntry(JournalEntry entry) {
    if (entry.isDeleted) return Future.value(false);
    return _buildGraph(
      entryId: entry.id,
      text: AutomatedGraphEmbeddingText.fromEntry(entry),
    );
  }

  Future<bool> _buildForEntryId(String entryId) async {
    final entry = await _journalStore.getById(entryId);
    if (entry == null) return false;
    return buildForEntry(entry);
  }

  Future<bool> _buildGraph({
    required String entryId,
    required String text,
  }) async {
    final resolved = text.trim();
    if (resolved.length < ReflectionTextProcessor.minTextChars) {
      return false;
    }

    final result = await _graphService.buildGraphForEntry(
      entryId: entryId,
      text: resolved,
      contentHash: _hashText(resolved),
    );
    return result != null;
  }

  static String _hashText(String text) {
    return sha256.convert(utf8.encode(text)).toString();
  }

  void _scheduleFlush() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      unawaited(flush());
    });
  }

  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _queuedEntryIds.clear();
  }
}
