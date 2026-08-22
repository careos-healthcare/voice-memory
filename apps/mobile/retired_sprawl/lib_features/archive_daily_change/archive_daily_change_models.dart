import 'package:archiveme_mobile/features/capacity_loop/capacity_activation_fit_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_boundary_response_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_cost_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_decision_outcome_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_pull_reason_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/quick_capture_friction_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Fixed change kinds for recent-activity detection — metadata only.
enum ArchiveDailyChangeKind {
  newYesMoment,
  urgencyPull,
  laterCost,
  boundarySelected,
  yesLoopReady,
  fitAnswered,
}

/// Sharpened interpretation types from combined local signals.
enum ArchiveDailyChangeResponseType {
  repeatedPullWithLaterCost,
  repeatedPullWithSaidYes,
  patternInterrupted,
  fitConfirmed,
  fitPartlyNewMoment,
  quickCaptureStillWork,
  waitingForNextMoment,
  noPullReasonYet,
  stillForming,
  recentChange,
  boundaryResponseSelected,
}

/// Local last-seen state — timestamps only.
class ArchiveDailyChangeState {
  const ArchiveDailyChangeState({this.lastSeenAt, this.dismissedAt});

  final DateTime? lastSeenAt;
  final DateTime? dismissedAt;

  static const empty = ArchiveDailyChangeState();

  Map<String, dynamic> toJson() => {
    if (lastSeenAt != null) 'lastSeenAt': lastSeenAt!.toUtc().toIso8601String(),
    if (dismissedAt != null)
      'dismissedAt': dismissedAt!.toUtc().toIso8601String(),
  };

  static ArchiveDailyChangeState fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    final lastSeenRaw = json['lastSeenAt'];
    final dismissedRaw = json['dismissedAt'];
    return ArchiveDailyChangeState(
      lastSeenAt: lastSeenRaw is String ? DateTime.tryParse(lastSeenRaw) : null,
      dismissedAt: dismissedRaw is String
          ? DateTime.tryParse(dismissedRaw)
          : null,
    );
  }

  ArchiveDailyChangeState copyWith({
    DateTime? lastSeenAt,
    DateTime? dismissedAt,
    bool clearDismissedAt = false,
  }) => ArchiveDailyChangeState(
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    dismissedAt: clearDismissedAt ? null : (dismissedAt ?? this.dismissedAt),
  );
}

/// Engine inputs — counts, ids, and timestamps only.
class ArchiveDailyChangeInput {
  const ArchiveDailyChangeInput({
    required this.sampleMode,
    required this.capacityWedgeActive,
    required this.realSavedMomentCount,
    required this.capacityMomentCount,
    required this.capacityEvidenceCount,
    required this.mostCommonPullReasonId,
    required this.pullReasonRecordCount,
    required this.state,
    required this.entries,
    required this.pullReasonRecords,
    required this.costRecords,
    required this.outcomeRecords,
    required this.boundarySelection,
    required this.activationFitRecord,
    required this.weeklyReviewAvailable,
    this.quickCaptureFrictionRecord,
  });

  final bool sampleMode;
  final bool capacityWedgeActive;
  final int realSavedMomentCount;
  final int capacityMomentCount;
  final int capacityEvidenceCount;
  final String? mostCommonPullReasonId;
  final int pullReasonRecordCount;
  final ArchiveDailyChangeState state;
  final List<JournalEntry> entries;
  final List<CapacityPullReasonRecord> pullReasonRecords;
  final List<CapacityCostRecord> costRecords;
  final List<CapacityDecisionOutcomeRecord> outcomeRecords;
  final CapacityBoundaryResponseSelection? boundarySelection;
  final CapacityActivationFitRecord? activationFitRecord;
  final bool weeklyReviewAvailable;
  final QuickCaptureFrictionRecord? quickCaptureFrictionRecord;
}

/// Result for Archive Home, capacity loop, and weekly review surfaces.
class ArchiveDailyChangeResult {
  const ArchiveDailyChangeResult({
    required this.hasFeature,
    required this.showOnArchiveHome,
    required this.showOnCapacityLoop,
    required this.showOnWeeklyReview,
    required this.responseType,
    required this.title,
    required this.changeLine,
    required this.repeatedLine,
    required this.alternativeLabel,
    required this.alternativeNextMove,
    required this.watchNextLine,
    required this.alternativeSectionTitle,
    required this.loopSectionTitle,
    required this.weeklySectionTitle,
  });

  final bool hasFeature;
  final bool showOnArchiveHome;
  final bool showOnCapacityLoop;
  final bool showOnWeeklyReview;
  final ArchiveDailyChangeResponseType? responseType;
  final String title;
  final String changeLine;
  final String repeatedLine;
  final String alternativeLabel;
  final String alternativeNextMove;
  final String watchNextLine;
  final String alternativeSectionTitle;
  final String loopSectionTitle;
  final String weeklySectionTitle;

  static const hidden = ArchiveDailyChangeResult(
    hasFeature: false,
    showOnArchiveHome: false,
    showOnCapacityLoop: false,
    showOnWeeklyReview: false,
    responseType: null,
    title: '',
    changeLine: '',
    repeatedLine: '',
    alternativeLabel: '',
    alternativeNextMove: '',
    watchNextLine: '',
    alternativeSectionTitle: '',
    loopSectionTitle: '',
    weeklySectionTitle: '',
  );
}