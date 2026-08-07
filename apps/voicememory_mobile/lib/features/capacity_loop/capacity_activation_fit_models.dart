/// Fixed response ids for capacity activation fit check.
abstract final class CapacityActivationFitResponseIds {
  CapacityActivationFitResponseIds._();

  static const fits = 'fits';
  static const partly = 'partly';
  static const notYet = 'not_yet';
  static const tooEarly = 'too_early';

  static const all = [fits, partly, notYet, tooEarly];
}

/// Source tag for activation fit records.
abstract final class CapacityActivationFitSource {
  CapacityActivationFitSource._();

  static const capacityLoopActivation = 'capacity_loop_activation';
}

enum CapacityActivationFitStatus { answered, skipped }

/// Local activation fit record — fixed ids and counts only.
class CapacityActivationFitRecord {
  const CapacityActivationFitRecord({
    required this.responseId,
    required this.source,
    required this.activationEntryCount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String responseId;
  final String source;
  final int activationEntryCount;
  final CapacityActivationFitStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isAnswered =>
      status == CapacityActivationFitStatus.answered && responseId.isNotEmpty;

  bool get isSkipped => status == CapacityActivationFitStatus.skipped;

  bool get isComplete => isAnswered || isSkipped;

  Map<String, dynamic> toJson() => {
    'responseId': responseId,
    'source': source,
    'activationEntryCount': activationEntryCount,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static CapacityActivationFitRecord? fromJson(Map<String, dynamic> json) {
    final source = json['source'];
    final statusRaw = json['status'];
    final createdAtRaw = json['createdAt'];
    final updatedAtRaw = json['updatedAt'];
    if (source is! String || source.isEmpty) return null;
    if (statusRaw is! String) return null;
    if (createdAtRaw is! String || updatedAtRaw is! String) return null;
    final createdAt = DateTime.tryParse(createdAtRaw);
    final updatedAt = DateTime.tryParse(updatedAtRaw);
    if (createdAt == null || updatedAt == null) return null;
    final status = switch (statusRaw) {
      'answered' => CapacityActivationFitStatus.answered,
      'skipped' => CapacityActivationFitStatus.skipped,
      _ => null,
    };
    if (status == null) return null;
    final responseId = json['responseId'];
    final activationEntryCount = json['activationEntryCount'];
    return CapacityActivationFitRecord(
      responseId: responseId is String ? responseId : '',
      source: source,
      activationEntryCount: activationEntryCount is int
          ? activationEntryCount
          : 0,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Engine input — metadata counts only.
class CapacityActivationFitInput {
  const CapacityActivationFitInput({
    required this.sampleMode,
    required this.capacityWedgeActive,
    required this.capacityEvidenceCount,
    required this.capacityMomentCount,
    required this.pendingPullReasonOnHome,
    required this.pendingDecisionOutcomeOnHome,
    required this.pendingCostCheckinOnHome,
    required this.threeMomentActivationOnHome,
    this.record,
  });

  final bool sampleMode;
  final bool capacityWedgeActive;
  final int capacityEvidenceCount;
  final int capacityMomentCount;
  final bool pendingPullReasonOnHome;
  final bool pendingDecisionOutcomeOnHome;
  final bool pendingCostCheckinOnHome;
  final bool threeMomentActivationOnHome;
  final CapacityActivationFitRecord? record;
}

/// Card / loop result — no journal text.
class CapacityActivationFitResult {
  const CapacityActivationFitResult({
    required this.hasCard,
    required this.showOnArchiveHome,
    required this.showOnCapacityLoop,
    required this.showAnsweredLineOnCapacityLoop,
    required this.title,
    required this.body,
    required this.primaryCtaLabel,
    required this.secondaryCtaLabel,
    required this.answeredSummaryLine,
    required this.activationEntryCount,
  });

  static const hidden = CapacityActivationFitResult(
    hasCard: false,
    showOnArchiveHome: false,
    showOnCapacityLoop: false,
    showAnsweredLineOnCapacityLoop: false,
    title: '',
    body: '',
    primaryCtaLabel: '',
    secondaryCtaLabel: '',
    answeredSummaryLine: '',
    activationEntryCount: 0,
  );

  final bool hasCard;
  final bool showOnArchiveHome;
  final bool showOnCapacityLoop;
  final bool showAnsweredLineOnCapacityLoop;
  final String title;
  final String body;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;
  final String answeredSummaryLine;
  final int activationEntryCount;
}
