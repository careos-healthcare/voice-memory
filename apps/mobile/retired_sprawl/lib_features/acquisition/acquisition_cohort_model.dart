import 'package:archiveme_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:archiveme_mobile/features/quality/first_insight_specificity_store.dart';

/// TestFlight / deep-link acquisition cohort identifiers.
enum AcquisitionCohortId {
  capacityYesDirect,
  proveEnoughDirect,
  genericArchive,
  unknown,
}

extension AcquisitionCohortIdIds on AcquisitionCohortId {
  String get id {
    switch (this) {
      case AcquisitionCohortId.capacityYesDirect:
        return 'capacity_yes_direct';
      case AcquisitionCohortId.proveEnoughDirect:
        return 'prove_enough_direct';
      case AcquisitionCohortId.genericArchive:
        return 'generic_archive';
      case AcquisitionCohortId.unknown:
        return 'unknown';
    }
  }

  String get label {
    switch (this) {
      case AcquisitionCohortId.capacityYesDirect:
        return 'Capacity yes — direct';
      case AcquisitionCohortId.proveEnoughDirect:
        return 'Prove enough — direct';
      case AcquisitionCohortId.genericArchive:
        return 'Generic archive';
      case AcquisitionCohortId.unknown:
        return 'Unknown';
    }
  }

  bool get usesFastPath =>
      this == AcquisitionCohortId.capacityYesDirect ||
      this == AcquisitionCohortId.proveEnoughDirect;

  String? get defaultLoopId {
    switch (this) {
      case AcquisitionCohortId.capacityYesDirect:
        return LoopModeIds.capacityYes;
      case AcquisitionCohortId.proveEnoughDirect:
        return LoopModeIds.proveEnough;
      case AcquisitionCohortId.genericArchive:
        return LoopModeIds.proveEnough;
      case AcquisitionCohortId.unknown:
        return LoopModeIds.proveEnough;
    }
  }

  String get startRoutePath {
    switch (this) {
      case AcquisitionCohortId.capacityYesDirect:
        return '/start/capacity-yes';
      case AcquisitionCohortId.proveEnoughDirect:
        return '/start/prove-enough';
      case AcquisitionCohortId.genericArchive:
        return '/start/prove-enough';
      case AcquisitionCohortId.unknown:
        return '/start/prove-enough';
    }
  }

  static AcquisitionCohortId? fromId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final id in AcquisitionCohortId.values) {
      if (id.id == raw) return id;
    }
    return null;
  }

  static AcquisitionCohortId? fromLoopParam(String? loop) {
    switch (loop) {
      case LoopModeIds.capacityYes:
      case 'capacity-yes':
        return AcquisitionCohortId.capacityYesDirect;
      case LoopModeIds.proveEnough:
      case 'prove-enough':
        return AcquisitionCohortId.proveEnoughDirect;
      default:
        return null;
    }
  }
}

/// Local acquisition cohort state for TestFlight wedge measurement.
class AcquisitionCohort {
  const AcquisitionCohort({
    required this.cohortId,
    required this.assignedAt, this.source = '',
    this.selectedLoopId,
    this.promiseShown = '',
    this.onboardingCompleted = false,
    this.firstMomentRecorded = false,
    this.secondMomentRecorded = false,
    this.thirdMomentRecorded = false,
    this.firstReadAccepted = false,
    this.firstReadRejected = false,
    this.firstInsightSpecificityRating,
    this.loopReviewReached = false,
    this.loopReviewConfirmed = false,
    this.paywallTeaserShown = false,
    this.paywallTeaserTapped = false,
  });

  final AcquisitionCohortId cohortId;
  final String source;
  final String? selectedLoopId;
  final String promiseShown;
  final DateTime assignedAt;
  final bool onboardingCompleted;
  final bool firstMomentRecorded;
  final bool secondMomentRecorded;
  final bool thirdMomentRecorded;
  final bool firstReadAccepted;
  final bool firstReadRejected;
  final FirstInsightSpecificityRating? firstInsightSpecificityRating;
  final bool loopReviewReached;
  final bool loopReviewConfirmed;
  final bool paywallTeaserShown;
  final bool paywallTeaserTapped;

  bool get usesFastPath => cohortId.usesFastPath;

  Map<String, dynamic> toJson() => {
    'cohortId': cohortId.id,
    'source': source,
    if (selectedLoopId != null) 'selectedLoopId': selectedLoopId,
    'promiseShown': promiseShown,
    'assignedAt': assignedAt.toUtc().toIso8601String(),
    'onboardingCompleted': onboardingCompleted,
    'firstMomentRecorded': firstMomentRecorded,
    'secondMomentRecorded': secondMomentRecorded,
    'thirdMomentRecorded': thirdMomentRecorded,
    'firstReadAccepted': firstReadAccepted,
    'firstReadRejected': firstReadRejected,
    if (firstInsightSpecificityRating != null)
      'firstInsightSpecificityRating': firstInsightSpecificityRating!.id,
    'loopReviewReached': loopReviewReached,
    'loopReviewConfirmed': loopReviewConfirmed,
    'paywallTeaserShown': paywallTeaserShown,
    'paywallTeaserTapped': paywallTeaserTapped,
  };

  static AcquisitionCohort? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final cohort = AcquisitionCohortIdIds.fromId(map['cohortId'] as String?);
    final assignedRaw = map['assignedAt'] as String?;
    if (cohort == null || assignedRaw == null) return null;
    final assignedAt = DateTime.tryParse(assignedRaw);
    if (assignedAt == null) return null;
    return AcquisitionCohort(
      cohortId: cohort,
      source: map['source'] as String? ?? '',
      selectedLoopId: map['selectedLoopId'] as String?,
      promiseShown: map['promiseShown'] as String? ?? '',
      assignedAt: assignedAt,
      onboardingCompleted: map['onboardingCompleted'] == true,
      firstMomentRecorded: map['firstMomentRecorded'] == true,
      secondMomentRecorded: map['secondMomentRecorded'] == true,
      thirdMomentRecorded: map['thirdMomentRecorded'] == true,
      firstReadAccepted: map['firstReadAccepted'] == true,
      firstReadRejected: map['firstReadRejected'] == true,
      firstInsightSpecificityRating: _specificityFromId(
        map['firstInsightSpecificityRating'] as String?,
      ),
      loopReviewReached: map['loopReviewReached'] == true,
      loopReviewConfirmed: map['loopReviewConfirmed'] == true,
      paywallTeaserShown: map['paywallTeaserShown'] == true,
      paywallTeaserTapped: map['paywallTeaserTapped'] == true,
    );
  }

  static FirstInsightSpecificityRating? _specificityFromId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in FirstInsightSpecificityRating.values) {
      if (value.id == raw) return value;
    }
    return null;
  }

  AcquisitionCohort copyWith({
    AcquisitionCohortId? cohortId,
    String? source,
    String? selectedLoopId,
    String? promiseShown,
    DateTime? assignedAt,
    bool? onboardingCompleted,
    bool? firstMomentRecorded,
    bool? secondMomentRecorded,
    bool? thirdMomentRecorded,
    bool? firstReadAccepted,
    bool? firstReadRejected,
    FirstInsightSpecificityRating? firstInsightSpecificityRating,
    bool? loopReviewReached,
    bool? loopReviewConfirmed,
    bool? paywallTeaserShown,
    bool? paywallTeaserTapped,
  }) {
    return AcquisitionCohort(
      cohortId: cohortId ?? this.cohortId,
      source: source ?? this.source,
      selectedLoopId: selectedLoopId ?? this.selectedLoopId,
      promiseShown: promiseShown ?? this.promiseShown,
      assignedAt: assignedAt ?? this.assignedAt,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      firstMomentRecorded: firstMomentRecorded ?? this.firstMomentRecorded,
      secondMomentRecorded: secondMomentRecorded ?? this.secondMomentRecorded,
      thirdMomentRecorded: thirdMomentRecorded ?? this.thirdMomentRecorded,
      firstReadAccepted: firstReadAccepted ?? this.firstReadAccepted,
      firstReadRejected: firstReadRejected ?? this.firstReadRejected,
      firstInsightSpecificityRating:
          firstInsightSpecificityRating ?? this.firstInsightSpecificityRating,
      loopReviewReached: loopReviewReached ?? this.loopReviewReached,
      loopReviewConfirmed: loopReviewConfirmed ?? this.loopReviewConfirmed,
      paywallTeaserShown: paywallTeaserShown ?? this.paywallTeaserShown,
      paywallTeaserTapped: paywallTeaserTapped ?? this.paywallTeaserTapped,
    );
  }
}