/// Fixed outcome identifiers — no free text.
abstract final class CapacityDecisionOutcomeIds {
  CapacityDecisionOutcomeIds._();

  static const saidYes = 'said_yes';
  static const saidNo = 'said_no';
  static const delayed = 'delayed';
  static const notSure = 'not_sure';

  static const all = [saidYes, saidNo, delayed, notSure];
}

enum CapacityDecisionOutcomeStatus {
  answered,
  skipped,
}

/// One local decision outcome linked to a saved moment.
class CapacityDecisionOutcomeRecord {
  const CapacityDecisionOutcomeRecord({
    required this.sourceEntryId,
    required this.outcomeId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String sourceEntryId;
  final String outcomeId;
  final CapacityDecisionOutcomeStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasOutcome =>
      status == CapacityDecisionOutcomeStatus.answered &&
      outcomeId.isNotEmpty;

  bool get showsPatternChange =>
      hasOutcome &&
      (outcomeId == CapacityDecisionOutcomeIds.saidNo ||
          outcomeId == CapacityDecisionOutcomeIds.delayed);

  Map<String, dynamic> toJson() => {
        'sourceEntryId': sourceEntryId,
        'outcomeId': outcomeId,
        'status': status.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static CapacityDecisionOutcomeRecord? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final entryId = map['sourceEntryId'] as String?;
    if (entryId == null || entryId.isEmpty) return null;
    final status = _parseStatus(map['status'] as String?);
    if (status == null) return null;
    final created = DateTime.tryParse(map['createdAt'] as String? ?? '');
    final updated = DateTime.tryParse(map['updatedAt'] as String? ?? '');
    if (created == null || updated == null) return null;
    return CapacityDecisionOutcomeRecord(
      sourceEntryId: entryId,
      outcomeId: (map['outcomeId'] as String?) ?? '',
      status: status,
      createdAt: created,
      updatedAt: updated,
    );
  }

  static CapacityDecisionOutcomeStatus? _parseStatus(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final value in CapacityDecisionOutcomeStatus.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

class CapacityDecisionOutcomeInput {
  const CapacityDecisionOutcomeInput({
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
  final List<CapacityDecisionOutcomeRecord> records;
  final String? pendingEntryId;
  final int capacityMomentCount;
}

class CapacityDecisionOutcomeResult {
  const CapacityDecisionOutcomeResult({
    required this.hasCard,
    required this.showOnArchiveHome,
    required this.title,
    required this.body,
    required this.helperText,
    required this.primaryCtaLabel,
    required this.secondaryCtaLabel,
    required this.pendingEntryId,
    required this.recordedOutcomeCount,
  });

  static const hidden = CapacityDecisionOutcomeResult(
    hasCard: false,
    showOnArchiveHome: false,
    title: '',
    body: '',
    helperText: '',
    primaryCtaLabel: '',
    secondaryCtaLabel: '',
    pendingEntryId: '',
    recordedOutcomeCount: 0,
  );

  final bool hasCard;
  final bool showOnArchiveHome;
  final String title;
  final String body;
  final String helperText;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;
  final String pendingEntryId;
  final int recordedOutcomeCount;
}
