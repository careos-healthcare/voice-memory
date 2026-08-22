/// Fixed cost-type identifiers for later-cost check-ins — no free text.
abstract final class CapacityCostTypeIds {
  CapacityCostTypeIds._();

  static const time = 'time';
  static const energy = 'energy';
  static const attention = 'attention';
  static const workSpillover = 'work_spillover';
  static const resentment = 'resentment';
  static const none = 'none';

  static const List<String> all = [time, energy, attention, workSpillover, resentment, none];
}

/// Local check-in status — metadata only.
enum CapacityCostRecordStatus { answered, skipped }

/// One local later-cost check-in linked to a saved moment.
class CapacityCostRecord {
  const CapacityCostRecord({
    required this.sourceEntryId,
    required this.costTypeIds,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String sourceEntryId;
  final List<String> costTypeIds;
  final CapacityCostRecordStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasLaterCost =>
      status == CapacityCostRecordStatus.answered &&
      costTypeIds.isNotEmpty &&
      !costTypeIds.every((id) => id == CapacityCostTypeIds.none);

  Map<String, dynamic> toJson() => {
    'sourceEntryId': sourceEntryId,
    'costTypeIds': costTypeIds,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static CapacityCostRecord? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final entryId = map['sourceEntryId'] as String?;
    if (entryId == null || entryId.isEmpty) return null;
    final status = _parseStatus(map['status'] as String?);
    if (status == null) return null;
    final created = DateTime.tryParse(map['createdAt'] as String? ?? '');
    final updated = DateTime.tryParse(map['updatedAt'] as String? ?? '');
    if (created == null || updated == null) return null;
    final rawTypes = map['costTypeIds'];
    final types = rawTypes is List
        ? rawTypes.map((e) => e.toString()).toList()
        : const <String>[];
    return CapacityCostRecord(
      sourceEntryId: entryId,
      costTypeIds: types,
      status: status,
      createdAt: created,
      updatedAt: updated,
    );
  }

  static CapacityCostRecordStatus? _parseStatus(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final value in CapacityCostRecordStatus.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// Engine input for later-cost check-in surfaces.
class CapacityCostInput {
  const CapacityCostInput({
    required this.realSavedMomentCount,
    required this.capacityEvidenceCount,
    required this.capacityWedgeActive,
    required this.sampleMode,
    required this.records,
    this.pendingEntryId,
    this.capacityMomentCount = 0,
  });

  final int realSavedMomentCount;
  final int capacityEvidenceCount;
  final bool capacityWedgeActive;
  final bool sampleMode;
  final List<CapacityCostRecord> records;
  final String? pendingEntryId;
  final int capacityMomentCount;
}

/// Archive Home / prompt result — counts and copy only.
class CapacityCostCheckinResult {
  const CapacityCostCheckinResult({
    required this.hasCard,
    required this.showOnArchiveHome,
    required this.title,
    required this.body,
    required this.helperText,
    required this.primaryCtaLabel,
    required this.secondaryCtaLabel,
    required this.pendingEntryId,
    required this.recordedCostCount,
    required this.earlyStateBody,
  });

  static const hidden = CapacityCostCheckinResult(
    hasCard: false,
    showOnArchiveHome: false,
    title: '',
    body: '',
    helperText: '',
    primaryCtaLabel: '',
    secondaryCtaLabel: '',
    pendingEntryId: '',
    recordedCostCount: 0,
    earlyStateBody: '',
  );

  final bool hasCard;
  final bool showOnArchiveHome;
  final String title;
  final String body;
  final String helperText;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;
  final String pendingEntryId;
  final int recordedCostCount;
  final String earlyStateBody;
}