/// Fixed task ids for the capacity beta trial mission.
abstract final class CapacityBetaMissionTaskIds {
  CapacityBetaMissionTaskIds._();

  static const firstYesMoment = 'first_yes_moment';
  static const threeYesMoments = 'three_yes_moments';
  static const pullReason = 'pull_reason';
  static const decisionOutcome = 'decision_outcome';
  static const laterCost = 'later_cost';
  static const reviewLoop = 'review_loop';
  static const activationFit = 'activation_fit';
  static const weeklyReview = 'weekly_review';
  static const boundaryResponse = 'boundary_response';
  static const proInterest = 'pro_interest';

  static const coreTasks = [
    firstYesMoment,
    threeYesMoments,
    pullReason,
    decisionOutcome,
    laterCost,
    reviewLoop,
    activationFit,
    weeklyReview,
    boundaryResponse,
  ];

  static const coreTaskCount = 9;

  static const all = [...coreTasks, proInterest];
}

enum CapacityBetaMissionTaskStatus {
  notStarted,
  ready,
  done,
  optional,
}

/// One mission task row — fixed labels and routes only.
class CapacityBetaMissionTask {
  const CapacityBetaMissionTask({
    required this.id,
    required this.label,
    required this.status,
    required this.statusLabel,
    required this.route,
    required this.ctaLabel,
    this.isOptional = false,
  });

  final String id;
  final String label;
  final CapacityBetaMissionTaskStatus status;
  final String statusLabel;
  final String route;
  final String ctaLabel;
  final bool isOptional;

  bool get isDone => status == CapacityBetaMissionTaskStatus.done;
}

/// Local mission metadata — timestamps and dismiss only.
class CapacityBetaMissionRecord {
  const CapacityBetaMissionRecord({
    this.startedAt,
    this.completedAt,
    this.dismissed = false,
  });

  static const empty = CapacityBetaMissionRecord();

  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool dismissed;

  bool get isDismissed => dismissed;

  Map<String, dynamic> toJson() => {
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        'dismissed': dismissed,
      };

  static CapacityBetaMissionRecord? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final startedRaw = json['startedAt'];
    final completedRaw = json['completedAt'];
    return CapacityBetaMissionRecord(
      startedAt: startedRaw is String ? DateTime.tryParse(startedRaw) : null,
      completedAt:
          completedRaw is String ? DateTime.tryParse(completedRaw) : null,
      dismissed: json['dismissed'] == true,
    );
  }

  CapacityBetaMissionRecord copyWith({
    DateTime? startedAt,
    DateTime? completedAt,
    bool? dismissed,
  }) =>
      CapacityBetaMissionRecord(
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        dismissed: dismissed ?? this.dismissed,
      );
}

/// Engine input — counts and flags only.
class CapacityBetaMissionInput {
  const CapacityBetaMissionInput({
    required this.sampleMode,
    required this.capacityWedgeActive,
    required this.capacityMomentCount,
    required this.activationTarget,
    required this.pullReasonRecordCount,
    required this.outcomeRecordCount,
    required this.laterCostRecordCount,
    required this.weeklyReviewAvailable,
    required this.boundaryResponseSelected,
    required this.activationFitComplete,
    required this.proInterestCaptured,
    required this.missionRecord,
  });

  final bool sampleMode;
  final bool capacityWedgeActive;
  final int capacityMomentCount;
  final int activationTarget;
  final int pullReasonRecordCount;
  final int outcomeRecordCount;
  final int laterCostRecordCount;
  final bool weeklyReviewAvailable;
  final bool boundaryResponseSelected;
  final bool activationFitComplete;
  final bool proInterestCaptured;
  final CapacityBetaMissionRecord missionRecord;
}

/// Mission result for cards and screen.
class CapacityBetaMissionResult {
  const CapacityBetaMissionResult({
    required this.hasMission,
    required this.showOnArchiveHome,
    required this.title,
    required this.subtitle,
    required this.calmNote,
    required this.skipNote,
    required this.progressLabel,
    required this.completedCoreTaskCount,
    required this.coreTaskCount,
    required this.tasks,
    required this.openMissionCta,
    required this.dismissCta,
    required this.viewBetaSignalsCta,
    required this.betaSignalsRoute,
  });

  static const hidden = CapacityBetaMissionResult(
    hasMission: false,
    showOnArchiveHome: false,
    title: '',
    subtitle: '',
    calmNote: '',
    skipNote: '',
    progressLabel: '',
    completedCoreTaskCount: 0,
    coreTaskCount: 0,
    tasks: [],
    openMissionCta: '',
    dismissCta: '',
    viewBetaSignalsCta: '',
    betaSignalsRoute: '',
  );

  final bool hasMission;
  final bool showOnArchiveHome;
  final String title;
  final String subtitle;
  final String calmNote;
  final String skipNote;
  final String progressLabel;
  final int completedCoreTaskCount;
  final int coreTaskCount;
  final List<CapacityBetaMissionTask> tasks;
  final String openMissionCta;
  final String dismissCta;
  final String viewBetaSignalsCta;
  final String betaSignalsRoute;
}
