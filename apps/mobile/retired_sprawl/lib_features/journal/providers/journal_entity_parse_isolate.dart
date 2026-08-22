import 'dart:convert';
import 'dart:isolate';

import 'package:archiveme_mobile/features/journal/domain/task_node.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';

/// Parses journal SQLite rows into a normalized id → entry map.
///
/// Mirrors [JournalSqliteRepository] payload merge rules so decoding can run
/// off the UI isolate.
Map<String, JournalEntry> parseJournalEntryRows(
  List<Map<String, dynamic>> rows,
) {
  final entries = <String, JournalEntry>{};
  for (final row in rows) {
    final entry = _journalEntryFromRow(row);
    if (entry != null) {
      entries[entry.id] = entry;
    }
  }
  return entries;
}

/// Parses reflection-graph task rows into a normalized id → node map.
Map<String, TaskNode> parseTaskNodeRows(List<Map<String, dynamic>> rows) {
  final nodes = <String, TaskNode>{};
  for (final row in rows) {
    final node = TaskNode.fromStorageRow(row);
    if (node.id.isEmpty) continue;
    nodes[node.id] = node;
  }
  return nodes;
}

JournalEntry? _journalEntryFromRow(Map<String, dynamic> row) {
  final entryId = row['id'] as String? ?? '';
  if (entryId.isEmpty) return null;

  final payloadJson = row['payload_json'] as String?;
  if (payloadJson == null || payloadJson.isEmpty) {
    return _journalEntryFromColumnsOnly(row);
  }

  try {
    final payload = Map<String, dynamic>.from(
      jsonDecode(payloadJson) as Map,
    );
    if (_isLegacyFullPayload(payload)) {
      return JournalEntry.fromJson(payload);
    }

    return JournalEntry.fromJson(_mergeColumnsIntoPayload(row, payload));
  } on Object {
    return null;
  }
}

bool _isLegacyFullPayload(Map<String, dynamic> payload) {
  return payload.containsKey('id') && payload.containsKey('createdAt');
}

Map<String, dynamic> _mergeColumnsIntoPayload(
  Map<String, dynamic> row,
  Map<String, dynamic> payload,
) {
  return {
    ...payload,
    'id': row['id'] as String? ?? '',
    'createdAt': _isoFromMillis(row['created_at'] as int?),
    'updatedAt': _isoFromMillis(row['updated_at'] as int?),
    'transcript': row['transcript'] as String? ?? '',
    'isArchived': (row['is_archived'] as int? ?? 0) == 1,
    if (row['deleted_at'] != null)
      'deletedAt': _isoFromMillis(row['deleted_at'] as int),
  };
}

JournalEntry _journalEntryFromColumnsOnly(Map<String, dynamic> row) {
  return JournalEntry.fromJson({
    'id': row['id'] as String? ?? '',
    'createdAt': _isoFromMillis(row['created_at'] as int?),
    'updatedAt': _isoFromMillis(row['updated_at'] as int?),
    'transcript': row['transcript'] as String? ?? '',
    'durationSeconds': 0,
    'reflection': const Reflection(
      mood: 'neutral',
      emotionalIntensity: 0,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ).toJson(),
    'isArchived': (row['is_archived'] as int? ?? 0) == 1,
    if (row['deleted_at'] != null)
      'deletedAt': _isoFromMillis(row['deleted_at'] as int),
  });
}

String _isoFromMillis(int? millis) {
  return DateTime.fromMillisecondsSinceEpoch(
    millis ?? 0,
    isUtc: true,
  ).toIso8601String();
}

/// Top-level worker entry for the parse isolate pool.
void journalEntityParseWorkerMain(SendPort handshakePort) {
  final receivePort = ReceivePort();
  handshakePort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message is! Map<String, dynamic>) return;

    final replyPort = message['replyPort'];
    if (replyPort is! SendPort) return;

    final kind = message['kind'] as String? ?? '';
    final rows = message['rows'];
    if (rows is! List) {
      replyPort.send(<String, Object>{});
      return;
    }

    final typedRows = rows
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);

    final result = switch (kind) {
      'journalEntries' => parseJournalEntryRows(typedRows),
      'taskNodes' => parseTaskNodeRows(typedRows),
      _ => <String, Object>{},
    };

    replyPort.send(result);
  });
}
