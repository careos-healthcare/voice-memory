import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/recent_entry_snippet_cache.dart';
import 'package:archiveme_mobile/sync/ulid.dart';
import 'package:sqflite/sqflite.dart';

/// Writes a quick-capture row straight into encrypted SQLite.
///
/// Does not open capture UI, load sqlite-vec, or start embedding / LLM workers.
abstract final class QuickCaptureHeadlessWriter {
  QuickCaptureHeadlessWriter._();

  static const _reflection = Reflection(
    mood: '',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  );

  static Future<JournalEntry> writeText({
    required Database database,
    required File snippetFile,
    required String text,
    DateTime? createdAt,
    String? entryId,
  }) async {
    final transcript = text.trim();
    if (transcript.isEmpty) {
      throw ArgumentError.value(text, 'text', 'must not be empty');
    }
    final created = (createdAt ?? DateTime.now()).toUtc();
    final entry = JournalEntry(
      id: entryId ?? generateUlid(created),
      createdAt: created,
      transcript: transcript,
      durationSeconds: 0,
      reflection: _reflection,
    );
    final millis = created.millisecondsSinceEpoch;
    await database.insert('journal_entries', {
      'id': entry.id,
      'created_at': millis,
      'updated_at': millis,
      'deleted_at': null,
      'is_archived': 0,
      'transcript': transcript,
      'has_verified_proof': 0,
      'payload_json': jsonEncode(entry.toResidualJson()),
      'is_time_capsule': 0,
    });
    RecentEntrySnippetCache.instance.pushSnippet(
      id: entry.id,
      createdAt: created,
      text: transcript,
    );
    await RecentEntrySnippetCache.instance.persistToFile(snippetFile);
    return entry;
  }
}
