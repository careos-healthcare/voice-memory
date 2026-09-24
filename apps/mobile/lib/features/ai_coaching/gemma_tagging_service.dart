import 'dart:io';

import 'package:archiveme_mobile/core/hardware/hardware_state_provider.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/ai_coaching/gemma_json_parser.dart';
import 'package:archiveme_mobile/services/ai/ai_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// Tags and a folder name extracted from one transcript.
class ContextTagResult {
  const ContextTagResult({required this.tags, required this.folder});

  final List<String> tags;
  final String folder;
}

typedef GemmaJsonCompleter =
    Future<String> Function({
      required String systemPrompt,
      required String userPrompt,
    });

const contextTagSystemPrompt = '''
Return only JSON. Do not add commentary.
Use this shape: {"tags":["word","word","word"],"folder":"Name"}
tags is 3 to 5 short labels from the voice note.
folder is one primary folder category.
''';

const contextTagPrompt = contextTagSystemPrompt;

/// Parses a strict JSON tag payload. Extra tags beyond 5 are dropped.
ContextTagResult? parseContextTagJson(String raw) {
  final decoded = decodeGemmaJson(raw);
  if (decoded is! Map) return null;
  final folder = decoded['folder'];
  final tags = decoded['tags'];
  if (folder is! String || tags is! List) return null;
  final cleaned = <String>[];
  for (final tag in tags) {
    if (tag is! String) continue;
    final trimmed = tag.trim();
    if (trimmed.isEmpty || cleaned.contains(trimmed)) continue;
    cleaned.add(trimmed);
    if (cleaned.length == 5) break;
  }
  if (cleaned.length < 3 || folder.trim().isEmpty) return null;
  return ContextTagResult(tags: cleaned, folder: folder.trim());
}

class GemmaTaggingService {
  GemmaTaggingService({
    required GemmaJsonCompleter completer,
    HardwareSnapshot snapshot = HardwareSnapshot.relaxed,
    HeavyWorkScheduler? scheduler,
  }) : _completer = completer,
       _snapshot = snapshot,
       _scheduler = scheduler ?? HeavyWorkScheduler();

  final GemmaJsonCompleter _completer;
  final HardwareSnapshot _snapshot;
  final HeavyWorkScheduler _scheduler;

  Future<ContextTagResult?> tagTranscript(
    String transcript, {
    bool forceImmediate = false,
  }) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return Future.value();
    return _scheduler.run(
      snapshot: _snapshot,
      forceImmediate: forceImmediate,
      deferredValue: null,
      task: () async {
        final raw = await _completer(
          systemPrompt: contextTagSystemPrompt,
          userPrompt: 'Voice note:\n$trimmed',
        );
        return parseContextTagJson(raw);
      },
    );
  }
}

class ContextTagStore {
  ContextTagStore(this._db);

  final Database _db;
  var _ready = false;

  static const table = 'context_auto_tags';

  Future<void> _ensure() async {
    if (_ready) return;
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        entry_id TEXT NOT NULL,
        tag TEXT NOT NULL,
        folder TEXT NOT NULL,
        position INTEGER NOT NULL,
        PRIMARY KEY (entry_id, tag)
      )
    ''');
    _ready = true;
  }

  Future<void> save(String entryId, ContextTagResult result) async {
    await _ensure();
    await _db.delete(table, where: 'entry_id = ?', whereArgs: [entryId]);
    for (var i = 0; i < result.tags.length; i++) {
      await _db.insert(table, {
        'entry_id': entryId,
        'tag': result.tags[i],
        'folder': result.folder,
        'position': i,
      });
    }
  }

  Future<ContextTagResult?> read(String entryId) async {
    await _ensure();
    final rows = await _db.query(
      table,
      where: 'entry_id = ?',
      whereArgs: [entryId],
      orderBy: 'position',
    );
    if (rows.isEmpty) return null;
    return ContextTagResult(
      tags: [for (final row in rows) row['tag']! as String],
      folder: rows.first['folder']! as String,
    );
  }
}

/// Called after a transcript is accepted. Tests replace [afterSuccess].
abstract final class TranscriptionCompletionHooks {
  static Future<void> Function(String transcript, {String? entryId})?
  afterSuccess;

  static ContextTagStore? tagStore;
}

/// Remembers where accepted tags should be written. Safe to call on every
/// database open; tagging itself waits for a transcript and an installed model.
void bindContextAutoTagging(Database database) {
  TranscriptionCompletionHooks.tagStore = ContextTagStore(database);
}

class GemmaTaggingNotifier extends Notifier<ContextTagResult?> {
  GemmaTaggingNotifier(this._service, this._store, this.entryId);

  final GemmaTaggingService _service;
  final ContextTagStore? _store;
  final String entryId;

  @override
  ContextTagResult? build() => null;

  Future<void> tag(String transcript) async {
    final result = await _service.tagTranscript(transcript);
    if (result == null) return;
    await _store?.save(entryId, result);
    state = result;
  }
}

/// On-device tagging after a transcript is saved. Skipped in tests, on web,
/// and when the local model or tag table is not available.
Future<void> runBuiltInContextTagging(
  String transcript, {
  String? entryId,
}) async {
  if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
  if (entryId == null || entryId.isEmpty) return;
  final store = TranscriptionCompletionHooks.tagStore;
  if (store == null || !AIService.hasLocalGemmaModel) return;
  try {
    final snapshot = await _readHardwareSnapshot();
    final service = GemmaTaggingService(
      completer: ({required String systemPrompt, required String userPrompt}) =>
          AIService().completeLocally(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
          ),
      snapshot: snapshot,
    );
    final result = await service.tagTranscript(transcript);
    if (result == null) return;
    await store.save(entryId, result);
  } on Object catch (error, stackTrace) {
    AppLogger.debug(
      'Context tagging skipped',
      name: 'context_tags',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

Future<HardwareSnapshot> _readHardwareSnapshot() async {
  try {
    final raw = await const MethodChannel(
      'com.archiveme/hardware_monitor',
    ).invokeMethod<Map<Object?, Object?>>('getHardwareSnapshot');
    if (raw == null) return HardwareSnapshot.relaxed;
    return HardwareSnapshot.fromMap(raw);
  } on Object {
    return HardwareSnapshot.relaxed;
  }
}
