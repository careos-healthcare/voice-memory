/// Local belief evolution — JSON shape ready for future backend sync.
class BeliefVersionRecord {
  const BeliefVersionRecord({
    required this.id,
    required this.beliefText,
    required this.confidence,
    required this.recordedAt,
    required this.supportingEntryIds,
    this.serverId,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String id;
  final String beliefText;
  final int confidence;
  final String recordedAt;
  final List<String> supportingEntryIds;
  final String? serverId;
  final int schemaVersion;

  int get year =>
      DateTime.tryParse(recordedAt)?.toLocal().year ?? DateTime.now().year;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'beliefText': beliefText,
    'confidence': confidence,
    'recordedAt': recordedAt,
    'supportingEntryIds': supportingEntryIds,
    if (serverId != null) 'serverId': serverId,
  };

  static BeliefVersionRecord? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final text = json['beliefText']?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final ids = (json['supportingEntryIds'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    return BeliefVersionRecord(
      id: json['id']?.toString() ?? '',
      beliefText: text,
      confidence: (json['confidence'] as num?)?.toInt().clamp(0, 100) ?? 0,
      recordedAt:
          json['recordedAt']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      supportingEntryIds: ids,
      serverId: json['serverId']?.toString(),
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
    );
  }

  BeliefVersionRecord copyWith({
    int? confidence,
    List<String>? supportingEntryIds,
    String? serverId,
  }) {
    return BeliefVersionRecord(
      id: id,
      beliefText: beliefText,
      confidence: confidence ?? this.confidence,
      recordedAt: recordedAt,
      supportingEntryIds: supportingEntryIds ?? this.supportingEntryIds,
      serverId: serverId ?? this.serverId,
      schemaVersion: schemaVersion,
    );
  }
}

class BeliefEvolutionState {
  const BeliefEvolutionState({
    required this.versions,
    this.firstBelief,
    this.currentBelief,
    this.lastSyncedAt,
    this.schemaVersion = BeliefVersionRecord.currentSchemaVersion,
  });

  final List<BeliefVersionRecord> versions;
  final BeliefVersionRecord? firstBelief;
  final BeliefVersionRecord? currentBelief;
  final String? lastSyncedAt;
  final int schemaVersion;

  bool get hasEvolution => versions.length >= 2;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'versions': versions.map((v) => v.toJson()).toList(),
    if (firstBelief != null) 'firstBelief': firstBelief!.toJson(),
    if (currentBelief != null) 'currentBelief': currentBelief!.toJson(),
    if (lastSyncedAt != null) 'lastSyncedAt': lastSyncedAt,
  };

  static BeliefEvolutionState empty() =>
      const BeliefEvolutionState(versions: []);

  static BeliefEvolutionState fromJson(Map<String, dynamic>? json) {
    if (json == null) return BeliefEvolutionState.empty();
    final rawVersions = json['versions'] as List<dynamic>? ?? [];
    final versions = <BeliefVersionRecord>[];
    for (final item in rawVersions) {
      if (item is Map<String, dynamic>) {
        final v = BeliefVersionRecord.fromJson(item);
        if (v != null) versions.add(v);
      } else if (item is Map) {
        final v = BeliefVersionRecord.fromJson(Map<String, dynamic>.from(item));
        if (v != null) versions.add(v);
      }
    }
    versions.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    var first = BeliefVersionRecord.fromJson(
      json['firstBelief'] as Map<String, dynamic>?,
    );
    var current = BeliefVersionRecord.fromJson(
      json['currentBelief'] as Map<String, dynamic>?,
    );
    first ??= versions.isNotEmpty ? versions.first : null;
    current ??= versions.isNotEmpty ? versions.last : null;

    return BeliefEvolutionState(
      versions: versions,
      firstBelief: first,
      currentBelief: current,
      lastSyncedAt: json['lastSyncedAt']?.toString(),
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ??
          BeliefVersionRecord.currentSchemaVersion,
    );
  }

  BeliefEvolutionState copyWith({
    List<BeliefVersionRecord>? versions,
    BeliefVersionRecord? firstBelief,
    BeliefVersionRecord? currentBelief,
    String? lastSyncedAt,
  }) {
    final nextVersions = versions ?? this.versions;
    return BeliefEvolutionState(
      versions: nextVersions,
      firstBelief:
          firstBelief ?? (nextVersions.isNotEmpty ? nextVersions.first : null),
      currentBelief:
          currentBelief ?? (nextVersions.isNotEmpty ? nextVersions.last : null),
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      schemaVersion: schemaVersion,
    );
  }
}

class BeliefEvidenceLine {
  const BeliefEvidenceLine({
    required this.entryId,
    required this.quote,
    required this.dateLabel,
  });

  final String entryId;
  final String quote;
  final String dateLabel;
}

/// One version leg: belief → supporting evidence recordings.
class BeliefEvolutionBlock {
  const BeliefEvolutionBlock({required this.version, required this.evidence});

  final BeliefVersionRecord version;
  final List<BeliefEvidenceLine> evidence;
}

class BeliefEvolutionTimeline {
  const BeliefEvolutionTimeline({
    required this.blocks,
    required this.firstBelief,
    required this.currentBelief,
  });

  final List<BeliefEvolutionBlock> blocks;
  final BeliefVersionRecord? firstBelief;
  final BeliefVersionRecord? currentBelief;

  bool get isEmpty => blocks.isEmpty;

  bool get hasEvolution =>
      firstBelief != null &&
      currentBelief != null &&
      firstBelief!.id != currentBelief!.id;
}