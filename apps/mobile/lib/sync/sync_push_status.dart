/// Server-reported blob upsert status from `POST /api/sync/push`.
enum SyncBlobUpsertStatus {
  created,
  updated,
  existing;

  static SyncBlobUpsertStatus? parse(String? raw) {
    switch (raw) {
      case 'created':
        return SyncBlobUpsertStatus.created;
      case 'updated':
        return SyncBlobUpsertStatus.updated;
      case 'existing':
        return SyncBlobUpsertStatus.existing;
      default:
        return null;
    }
  }
}

class SyncBlobStatusMatrixEntry {
  const SyncBlobStatusMatrixEntry({
    required this.id,
    required this.type,
    required this.status,
  });

  factory SyncBlobStatusMatrixEntry.fromJson(Map<String, dynamic> json) {
    return SyncBlobStatusMatrixEntry(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      status:
          SyncBlobUpsertStatus.parse(json['status'] as String?) ??
          SyncBlobUpsertStatus.updated,
    );
  }

  final String id;
  final String type;
  final SyncBlobUpsertStatus status;

  bool get applied =>
      status == SyncBlobUpsertStatus.created ||
      status == SyncBlobUpsertStatus.updated ||
      status == SyncBlobUpsertStatus.existing;
}

class SyncPushStatusMatrix {
  const SyncPushStatusMatrix(this.entries);

  factory SyncPushStatusMatrix.fromResponse(Map<String, dynamic> body) {
    final raw = body['statusMatrix'];
    if (raw is! List) return const SyncPushStatusMatrix([]);
    return SyncPushStatusMatrix(
      raw
          .whereType<Map>()
          .map(
            (entry) => SyncBlobStatusMatrixEntry.fromJson(
              Map<String, dynamic>.from(entry),
            ),
          )
          .toList(),
    );
  }

  final List<SyncBlobStatusMatrixEntry> entries;

  bool blobApplied(String blobId) =>
      entries.any((entry) => entry.id == blobId && entry.applied);

  int get createdCount => entries
      .where((entry) => entry.status == SyncBlobUpsertStatus.created)
      .length;

  int get updatedCount => entries
      .where((entry) => entry.status == SyncBlobUpsertStatus.updated)
      .length;

  int get existingCount => entries
      .where((entry) => entry.status == SyncBlobUpsertStatus.existing)
      .length;
}

/// Summary of draining the drift-backed encrypted sync outbox.
class SyncOutboxDrainResult {
  const SyncOutboxDrainResult({
    required this.pushedCount,
    required this.remaining,
    required this.responseBody,
    required this.matrix,
  });

  final int pushedCount;
  final int remaining;
  final Map<String, dynamic> responseBody;
  final SyncPushStatusMatrix matrix;
}
