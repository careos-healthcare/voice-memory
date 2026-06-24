/// Fixed template ids for capacity boundary responses.
abstract final class CapacityBoundaryResponseIds {
  CapacityBoundaryResponseIds._();

  static const checkCapacityComeBack = 'check_capacity_come_back';
  static const checkCommitmentsFirst = 'check_commitments_first';
  static const cannotAnswerNow = 'cannot_answer_now';
  static const wantToHelpCheck = 'want_to_help_check';
  static const needPauseBeforeYes = 'need_pause_before_yes';

  static const all = [
    checkCapacityComeBack,
    checkCommitmentsFirst,
    cannotAnswerNow,
    wantToHelpCheck,
    needPauseBeforeYes,
  ];
}

/// One safe default response template — no user-authored text.
class CapacityBoundaryResponseTemplate {
  const CapacityBoundaryResponseTemplate({
    required this.id,
    required this.text,
  });

  final String id;
  final String text;
}

/// Local selection record — response id and timestamps only.
class CapacityBoundaryResponseSelection {
  const CapacityBoundaryResponseSelection({
    required this.responseId,
    required this.selectedAt,
    this.lastCopiedAt,
    this.dismissed = false,
  });

  final String responseId;
  final DateTime selectedAt;
  final DateTime? lastCopiedAt;
  final bool dismissed;

  bool get hasSelection => responseId.isNotEmpty && !dismissed;

  Map<String, dynamic> toJson() => {
        'responseId': responseId,
        'selectedAt': selectedAt.toIso8601String(),
        if (lastCopiedAt != null)
          'lastCopiedAt': lastCopiedAt!.toIso8601String(),
        'dismissed': dismissed,
      };

  static CapacityBoundaryResponseSelection? fromJson(Map<String, dynamic> json) {
    final responseId = json['responseId'];
    final selectedAtRaw = json['selectedAt'];
    if (responseId is! String || responseId.isEmpty) return null;
    if (selectedAtRaw is! String) return null;
    final selectedAt = DateTime.tryParse(selectedAtRaw);
    if (selectedAt == null) return null;
    final lastCopiedRaw = json['lastCopiedAt'];
    final lastCopiedAt =
        lastCopiedRaw is String ? DateTime.tryParse(lastCopiedRaw) : null;
    final dismissed = json['dismissed'] == true;
    return CapacityBoundaryResponseSelection(
      responseId: responseId,
      selectedAt: selectedAt,
      lastCopiedAt: lastCopiedAt,
      dismissed: dismissed,
    );
  }

  CapacityBoundaryResponseSelection copyWith({
    String? responseId,
    DateTime? selectedAt,
    DateTime? lastCopiedAt,
    bool? dismissed,
  }) =>
      CapacityBoundaryResponseSelection(
        responseId: responseId ?? this.responseId,
        selectedAt: selectedAt ?? this.selectedAt,
        lastCopiedAt: lastCopiedAt ?? this.lastCopiedAt,
        dismissed: dismissed ?? this.dismissed,
      );
}

/// Gate inputs — metadata counts only.
class CapacityBoundaryResponseGateInput {
  const CapacityBoundaryResponseGateInput({
    required this.sampleMode,
    required this.realSavedMomentCount,
    required this.capacityEvidenceCount,
    required this.capacityWedgeActive,
    required this.capacityMomentCount,
    required this.outcomeOrCostRecordCount,
  });

  final bool sampleMode;
  final int realSavedMomentCount;
  final int capacityEvidenceCount;
  final bool capacityWedgeActive;
  final int capacityMomentCount;
  final int outcomeOrCostRecordCount;
}

/// Engine inputs for boundary response surfaces.
class CapacityBoundaryResponseInput {
  const CapacityBoundaryResponseInput({
    required this.sampleMode,
    required this.realSavedMomentCount,
    required this.capacityWedgeActive,
    required this.capacityMomentCount,
    required this.capacityEvidenceCount,
    required this.outcomeOrCostRecordCount,
    required this.pendingDecisionOutcome,
    required this.pendingCostCheckin,
    required this.beforeYesPauseOnHome,
    required this.weeklyReviewOnHome,
    required this.pendingPullReasonOnHome,
    this.mostCommonPullReasonId,
    this.selection,
  });

  final bool sampleMode;
  final int realSavedMomentCount;
  final bool capacityWedgeActive;
  final int capacityMomentCount;
  final int capacityEvidenceCount;
  final int outcomeOrCostRecordCount;
  final bool pendingDecisionOutcome;
  final bool pendingCostCheckin;
  final bool beforeYesPauseOnHome;
  final bool weeklyReviewOnHome;
  final bool pendingPullReasonOnHome;
  final String? mostCommonPullReasonId;
  final CapacityBoundaryResponseSelection? selection;

  CapacityBoundaryResponseInput copyWith({
    int? capacityMomentCount,
    int? capacityEvidenceCount,
    int? outcomeOrCostRecordCount,
    CapacityBoundaryResponseSelection? selection,
  }) =>
      CapacityBoundaryResponseInput(
        sampleMode: sampleMode,
        realSavedMomentCount: realSavedMomentCount,
        capacityWedgeActive: capacityWedgeActive,
        capacityMomentCount: capacityMomentCount ?? this.capacityMomentCount,
        capacityEvidenceCount:
            capacityEvidenceCount ?? this.capacityEvidenceCount,
        outcomeOrCostRecordCount:
            outcomeOrCostRecordCount ?? this.outcomeOrCostRecordCount,
        pendingDecisionOutcome: pendingDecisionOutcome,
        pendingCostCheckin: pendingCostCheckin,
        beforeYesPauseOnHome: beforeYesPauseOnHome,
        weeklyReviewOnHome: weeklyReviewOnHome,
        pendingPullReasonOnHome: pendingPullReasonOnHome,
        mostCommonPullReasonId: mostCommonPullReasonId,
        selection: selection ?? this.selection,
      );
}

/// Result for cards, screens, and loop/weekly integrations.
class CapacityBoundaryResponseResult {
  const CapacityBoundaryResponseResult({
    required this.hasFeature,
    required this.showOnArchiveHome,
    required this.showOnCapacityLoop,
    required this.showOnWeeklyReview,
    required this.showOnRecord,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.selectedResponseId,
    required this.selectedResponseText,
    required this.templates,
    required this.primaryCtaLabel,
    required this.secondaryCtaLabel,
    required this.primaryRoute,
    required this.cardSummary,
    this.recommendedResponseNote = '',
  });

  final bool hasFeature;
  final bool showOnArchiveHome;
  final bool showOnCapacityLoop;
  final bool showOnWeeklyReview;
  final bool showOnRecord;
  final String title;
  final String subtitle;
  final String body;
  final String selectedResponseId;
  final String selectedResponseText;
  final List<CapacityBoundaryResponseTemplate> templates;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;
  final String primaryRoute;
  final String cardSummary;
  final String recommendedResponseNote;

  bool get hasSelection => selectedResponseText.isNotEmpty;

  static const hidden = CapacityBoundaryResponseResult(
    hasFeature: false,
    showOnArchiveHome: false,
    showOnCapacityLoop: false,
    showOnWeeklyReview: false,
    showOnRecord: false,
    title: '',
    subtitle: '',
    body: '',
    selectedResponseId: '',
    selectedResponseText: '',
    templates: [],
    primaryCtaLabel: '',
    secondaryCtaLabel: '',
    primaryRoute: '',
    cardSummary: '',
    recommendedResponseNote: '',
  );
}
