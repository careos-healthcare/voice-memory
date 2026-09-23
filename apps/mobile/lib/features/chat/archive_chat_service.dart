import 'dart:typed_data';

import 'package:archiveme_mobile/core/database/vector_store.dart';
import 'package:archiveme_mobile/core/execution/cancel_token.dart';
import 'package:archiveme_mobile/core/llm/llm_router.dart';
import 'package:archiveme_mobile/features/metadata/ambient_metadata.dart';
import 'package:archiveme_mobile/features/sample_vault/sample_vault_embedder.dart';
import 'package:archiveme_mobile/features/search/entity_extraction_worker.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_020_entity_graph.dart';
import 'package:sqflite/sqflite.dart';

/// One moment placed in the chat context window.
class ChatContextMoment {
  const ChatContextMoment({
    required this.entryId,
    required this.createdAt,
    required this.relativeTime,
    required this.location,
    required this.entities,
    required this.transcript,
    this.metadata,
  });

  factory ChatContextMoment.fromJson(Map<String, Object?> json) {
    final entities = json['entities'];
    return ChatContextMoment(
      entryId: '${json['entryId'] ?? ''}',
      createdAt:
          DateTime.tryParse('${json['createdAt'] ?? ''}')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      relativeTime: '${json['relativeTime'] ?? ''}',
      location: '${json['location'] ?? ''}',
      entities: entities is List
          ? [for (final name in entities) '$name']
          : const [],
      transcript: '${json['transcript'] ?? ''}',
      metadata: _metadataFrom(json['metadata']),
    );
  }

  final String entryId;
  final DateTime createdAt;
  final String relativeTime;
  final String location;
  final List<String> entities;
  final String transcript;
  final AmbientMetadata? metadata;

  String get label {
    final place = location.trim();
    if (place.isEmpty) return relativeTime;
    return '$relativeTime · $place';
  }

  String get preview {
    final note = transcript.trim();
    if (note.length <= 42) return note;
    return '${note.substring(0, 39)}...';
  }

  Map<String, Object?> toJson() => {
    'entryId': entryId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'relativeTime': relativeTime,
    'location': location,
    'entities': entities,
    'transcript': transcript,
    if (metadata != null) 'metadata': metadata!.toJson(),
  };
}

/// Retrieved moments plus the prompt sent to the language model.
class ArchiveChatRetrieval {
  const ArchiveChatRetrieval({
    required this.moments,
    required this.synthesized,
    required this.target,
  });

  final List<ChatContextMoment> moments;
  final String synthesized;
  final LlmExecutionTarget target;
}

/// Semantic search plus the entity graph, then a routed reply.
class ArchiveChatService {
  ArchiveChatService({
    this.database,
    LlmRouter? router,
    this.embed = SampleVaultEmbedder.embed,
    this.entities = const EntityExtractionWorker(),
    this.topK = 4,
    DateTime Function()? clock,
  }) : router = router ?? LlmRouter(),
       _clock = clock ?? DateTime.now;

  final DatabaseExecutor? database;
  final LlmRouter router;
  final Float32List Function(String text) embed;
  final EntityExtractionWorker entities;
  final int topK;
  final DateTime Function() _clock;

  Future<ArchiveChatRetrieval> retrieve(
    String prompt, {
    List<ChatTurn> history = const [],
  }) async {
    final now = _clock();
    final moments = await _rankMoments(prompt, now);
    final synthesized = _window(prompt, moments, history);
    return ArchiveChatRetrieval(
      moments: moments,
      synthesized: synthesized,
      target: router.targetFor(LlmWorkload.chatReply),
    );
  }

  Stream<String> streamReply({
    required String synthesized,
    required ExecutionCancelToken cancel,
  }) async* {
    cancel.throwIfCancelled();
    final result = await router.run(
      workload: LlmWorkload.chatReply,
      prompt: synthesized,
    );
    final tokens = result.text.split(RegExp(r'(?<=\s)'));
    final buffer = StringBuffer();
    for (final token in tokens) {
      cancel.throwIfCancelled();
      buffer.write(token);
      yield buffer.toString();
    }
  }

  Future<List<ChatContextMoment>> _rankMoments(String prompt, DateTime now) async {
    final database = this.database;
    if (database == null) return const [];
    final rows = await database.rawQuery('''
      SELECT id, created_at, transcript, ambient_metadata
      FROM journal_entries
      WHERE deleted_at IS NULL
    ''');
    final linked = await _linkedEntryIds(prompt);
    final query = embed(prompt);
    final vectors = <VectorStoreRow>[];
    final byId = <String, Map<String, Object?>>{};
    for (final row in rows) {
      final id = '${row['id']}';
      byId[id] = row;
      final transcript = '${row['transcript'] ?? ''}';
      if (transcript.trim().isEmpty) continue;
      vectors.add(VectorStoreRow(id: id, values: embed(transcript)));
    }
    final scored = <String, double>{};
    for (final hit in VectorStore.scan(rows: vectors, query: query, limit: topK)) {
      scored[hit.id] = hit.score;
    }
    for (final id in linked) {
      if (!byId.containsKey(id)) continue;
      scored[id] = (scored[id] ?? 0) + 1;
    }
    final ranked = scored.entries.toList()
      ..sort((a, b) {
        final byScore = b.value.compareTo(a.value);
        if (byScore != 0) return byScore;
        return a.key.compareTo(b.key);
      });
    final chosen = ranked.take(topK);
    final names = await _entityNamesByEntry(chosen.map((hit) => hit.key));
    return [
      for (final hit in chosen)
        _moment(byId[hit.key]!, names[hit.key] ?? const [], now),
    ];
  }

  Future<Set<String>> _linkedEntryIds(String prompt) async {
    final draft = entities.extract(prompt);
    final wanted = <String>{
      for (final entity in draft.entities)
        entityStorageId(entity.category, entity.name),
    };
    final database = this.database;
    if (database == null) return const {};
    final stored = await database.query(
      Migration020EntityGraph.entitiesTable,
      columns: ['id', 'name'],
    );
    final lower = prompt.toLowerCase();
    for (final row in stored) {
      final name = '${row['name'] ?? ''}'.trim();
      if (name.length < 2) continue;
      if (lower.contains(name.toLowerCase())) {
        wanted.add('${row['id']}');
      }
    }
    if (wanted.isEmpty) return const {};
    final marks = List.filled(wanted.length, '?').join(', ');
    final links = await database.rawQuery(
      '''
      SELECT entry_id FROM ${Migration020EntityGraph.entryEntitiesTable}
      WHERE entity_id IN ($marks)
      ''',
      wanted.toList(),
    );
    return {for (final row in links) '${row['entry_id']}'};
  }

  Future<Map<String, List<String>>> _entityNamesByEntry(
    Iterable<String> entryIds,
  ) async {
    final database = this.database;
    final ids = entryIds.toList();
    if (database == null || ids.isEmpty) return const {};
    final marks = List.filled(ids.length, '?').join(', ');
    final rows = await database.rawQuery(
      '''
      SELECT link.entry_id AS entry_id, entity.name AS name
      FROM ${Migration020EntityGraph.entryEntitiesTable} link
      JOIN ${Migration020EntityGraph.entitiesTable} entity
        ON entity.id = link.entity_id
      WHERE link.entry_id IN ($marks)
      ''',
      ids,
    );
    final names = <String, List<String>>{};
    for (final row in rows) {
      names.putIfAbsent('${row['entry_id']}', () => []).add('${row['name']}');
    }
    return names;
  }

  ChatContextMoment _moment(
    Map<String, Object?> row,
    List<String> entityNames,
    DateTime now,
  ) {
    final created = DateTime.fromMillisecondsSinceEpoch(
      (row['created_at'] as num?)?.toInt() ?? 0,
    );
    final metadata = AmbientMetadata.decode('${row['ambient_metadata'] ?? ''}');
    return ChatContextMoment(
      entryId: '${row['id']}',
      createdAt: created,
      relativeTime: relativeChatTime(created, now),
      location: metadata?.placeLabel ?? '',
      entities: entityNames,
      transcript: '${row['transcript'] ?? ''}',
      metadata: metadata,
    );
  }

  String _window(
    String prompt,
    List<ChatContextMoment> moments,
    List<ChatTurn> history,
  ) {
    final buffer = StringBuffer();
    for (final turn in history) {
      if (turn.body.trim().isEmpty) continue;
      buffer.writeln('${turn.role}: ${turn.body}');
    }
    buffer.writeln('Question: $prompt');
    for (final moment in moments) {
      final names = moment.entities.isEmpty
          ? ''
          : ' Entities: ${moment.entities.join(', ')}.';
      final place = moment.location.isEmpty
          ? ''
          : ' Place: ${moment.location}.';
      buffer.write(
        'Moment ${moment.entryId} (${moment.relativeTime}).$place$names '
        'Note: ${moment.transcript}\n',
      );
    }
    return buffer.toString();
  }
}

/// One earlier turn included in the next prompt.
class ChatTurn {
  const ChatTurn({required this.role, required this.body});

  final String role;
  final String body;
}

AmbientMetadata? _metadataFrom(Object? raw) {
  if (raw is! Map) return null;
  return AmbientMetadata.fromJson(Map<String, dynamic>.from(raw));
}

/// A short label such as "3 days ago".
String relativeChatTime(DateTime when, DateTime now) {
  final days = now.difference(when).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 30) return '$days days ago';
  final months = days ~/ 30;
  if (months <= 1) return '1 month ago';
  return '$months months ago';
}
