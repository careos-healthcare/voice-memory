import 'dart:convert';

/// A journal-linked action item extracted from reflection graph storage.
class TaskNode {
  const TaskNode({
    required this.id,
    required this.entryId,
    required this.label,
    required this.updatedAt,
    this.isCompleted = false,
  });

  final String id;
  final String entryId;
  final String label;
  final DateTime updatedAt;
  final bool isCompleted;

  TaskNode copyWith({
    String? label,
    DateTime? updatedAt,
    bool? isCompleted,
  }) {
    return TaskNode(
      id: id,
      entryId: entryId,
      label: label ?? this.label,
      updatedAt: updatedAt ?? this.updatedAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  factory TaskNode.fromStorageRow(Map<String, dynamic> row) {
    final payloadRaw = row['payload_json'];
    var isCompleted = false;
    if (payloadRaw is String && payloadRaw.isNotEmpty) {
      try {
        final payload = jsonDecode(payloadRaw);
        if (payload is Map && payload['isCompleted'] == true) {
          isCompleted = true;
        }
      } on Object {
        // Ignore malformed task payloads.
      }
    }

    return TaskNode(
      id: row['id'] as String? ?? '',
      entryId: row['entry_id'] as String? ?? '',
      label: row['label'] as String? ?? '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at'] as int? ?? 0,
        isUtc: true,
      ),
      isCompleted: isCompleted,
    );
  }
}

/// Keyset cursor for task-node infinite scroll (`updated_at` + `id`).
class TaskNodeFeedCursor {
  const TaskNodeFeedCursor({
    required this.updatedAt,
    required this.id,
  });

  final DateTime updatedAt;
  final String id;
}
