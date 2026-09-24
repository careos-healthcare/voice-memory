import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter/foundation.dart';

/// In-memory preview of the newest saved moments.
///
/// Filled when the journal opens, before sqlite-vec or the archive query, so
/// the home feed can paint on the first interactive frame.
final class RecentEntrySnippetCache {
  RecentEntrySnippetCache._();

  static final RecentEntrySnippetCache instance = RecentEntrySnippetCache._();

  static const int maxEntries = 8;
  static const int maxChars = 140;
  static const String fileName = 'recent_entry_snippets_v1.json';

  final List<RecentEntrySnippet> _items = [];

  List<RecentEntrySnippet> get snippets => List.unmodifiable(_items);

  /// Prepends one saved moment without reloading the journal.
  void pushSnippet({
    required String id,
    required DateTime createdAt,
    required String text,
  }) {
    if (id.isEmpty) return;
    _items.removeWhere((item) => item.id == id);
    _items.add(
      RecentEntrySnippet(
        id: id,
        createdAt: createdAt,
        text: _truncate(text),
      ),
    );
    _trim();
  }

  /// Merges a widget snapshot written beside the account database.
  Future<void> hydrateFromFile(File file) async {
    if (!await file.exists()) return;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) return;
    for (final item in decoded) {
      if (item is! Map) continue;
      final id = item['id'] as String? ?? '';
      final createdAt = DateTime.tryParse(item['createdAt'] as String? ?? '');
      if (id.isEmpty || createdAt == null) continue;
      pushSnippet(
        id: id,
        createdAt: createdAt,
        text: item['text'] as String? ?? '',
      );
    }
  }

  Future<void> persistToFile(File file) async {
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    final payload = [
      for (final snippet in _items)
        {
          'id': snippet.id,
          'createdAt': snippet.createdAt.toUtc().toIso8601String(),
          'text': snippet.text,
        },
    ];
    await file.writeAsString(jsonEncode(payload));
  }

  void remember(List<JournalEntry> entries) {
    final active = entries.where((entry) => !entry.isDeleted).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _items
      ..clear()
      ..addAll(
        active.take(maxEntries).map((entry) {
          return RecentEntrySnippet(
            id: entry.id,
            createdAt: entry.createdAt,
            text: _truncate(entry.transcript),
          );
        }),
      );
    _trim();
  }

  void _trim() {
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_items.length > maxEntries) {
      _items.removeRange(maxEntries, _items.length);
    }
  }

  /// Lightweight entries the archive feed can show before the sqlite page loads.
  List<JournalEntry> previewEntries() {
    return [
      for (final snippet in _items)
        JournalEntry.stored(
          id: snippet.id,
          createdAt: snippet.createdAt,
          transcript: snippet.text,
          durationSeconds: 0,
          reflection: const Reflection(
            mood: '',
            emotionalIntensity: 0,
            recurringThemes: [],
            exactLanguagePattern: '',
            concreteObservation: '',
            repeatedSignal: '',
          ),
          sync: JournalSyncMetadata(
            createdAt: snippet.createdAt,
            entryId: snippet.id,
          ),
          display: const JournalDisplayMetadata(),
          proof: const JournalProofData(),
        ),
    ];
  }

  void clear() => _items.clear();

  static String _truncate(String transcript) {
    final compact = transcript.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.length <= maxChars) return compact;
    return '${compact.substring(0, maxChars).trim()}…';
  }

  @visibleForTesting
  static void resetForTest() => instance.clear();
}

final class RecentEntrySnippet {
  const RecentEntrySnippet({
    required this.id,
    required this.createdAt,
    required this.text,
  });

  final String id;
  final DateTime createdAt;
  final String text;
}
