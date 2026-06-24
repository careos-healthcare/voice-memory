/// Fixed pull reason identifiers — no free text.
abstract final class CapacityPullReasonIds {
  CapacityPullReasonIds._();

  static const feltResponsible = 'felt_responsible';
  static const soundedUrgent = 'sounded_urgent';
  static const avoidDisappoint = 'avoid_disappoint';
  static const squeezeItIn = 'squeeze_it_in';
  static const wantedOpportunity = 'wanted_opportunity';
  static const answeredTooQuickly = 'answered_too_quickly';
  static const somethingElse = 'something_else';

  static const all = [
    feltResponsible,
    soundedUrgent,
    avoidDisappoint,
    squeezeItIn,
    wantedOpportunity,
    answeredTooQuickly,
    somethingElse,
  ];
}

enum CapacityPullReasonStatus {
  answered,
  skipped,
}

/// One local pull reason linked to a saved moment — ids only.
class CapacityPullReasonRecord {
  const CapacityPullReasonRecord({
    required this.sourceEntryId,
    required this.reasonIds,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String sourceEntryId;
  final List<String> reasonIds;
  final CapacityPullReasonStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasReasons =>
      status == CapacityPullReasonStatus.answered && reasonIds.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'sourceEntryId': sourceEntryId,
        'reasonIds': reasonIds,
        'status': status.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static CapacityPullReasonRecord? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final entryId = map['sourceEntryId'] as String?;
    if (entryId == null || entryId.isEmpty) return null;
    final status = _parseStatus(map['status'] as String?);
    if (status == null) return null;
    final created = DateTime.tryParse(map['createdAt'] as String? ?? '');
    final updated = DateTime.tryParse(map['updatedAt'] as String? ?? '');
    if (created == null || updated == null) return null;
    final rawIds = map['reasonIds'];
    final reasonIds = rawIds is List
        ? rawIds.whereType<String>().where((id) => id.isNotEmpty).toList()
        : const <String>[];
    return CapacityPullReasonRecord(
      sourceEntryId: entryId,
      reasonIds: reasonIds,
      status: status,
      createdAt: created,
      updatedAt: updated,
    );
  }

  static CapacityPullReasonStatus? _parseStatus(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final value in CapacityPullReasonStatus.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

class CapacityPullReasonInput {
  const CapacityPullReasonInput({
    required this.realSavedMomentCount,
    required this.capacityEvidenceCount,
    required this.capacityWedgeActive,
    required this.sampleMode,
    required this.records,
    this.pendingEntryId,
  });

  final int realSavedMomentCount;
  final int capacityEvidenceCount;
  final bool capacityWedgeActive;
  final bool sampleMode;
  final List<CapacityPullReasonRecord> records;
  final String? pendingEntryId;
}

class CapacityPullReasonResult {
  const CapacityPullReasonResult({
    required this.hasCard,
    required this.showOnArchiveHome,
    required this.title,
    required this.body,
    required this.primaryCtaLabel,
    required this.secondaryCtaLabel,
    required this.pendingEntryId,
    required this.recordedReasonCount,
  });

  static const hidden = CapacityPullReasonResult(
    hasCard: false,
    showOnArchiveHome: false,
    title: '',
    body: '',
    primaryCtaLabel: '',
    secondaryCtaLabel: '',
    pendingEntryId: '',
    recordedReasonCount: 0,
  );

  final bool hasCard;
  final bool showOnArchiveHome;
  final String title;
  final String body;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;
  final String pendingEntryId;
  final int recordedReasonCount;
}
