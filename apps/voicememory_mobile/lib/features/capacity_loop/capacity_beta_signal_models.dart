/// Local beta verdict — cautious, not PMF proof.
enum CapacityBetaSignalVerdict {
  strong,
  promising,
  weak,
  unclear,
}

/// Read-only capacity beta signal snapshot — counts and fixed labels only.
class CapacityBetaSignalSnapshot {
  const CapacityBetaSignalSnapshot({
    required this.hasCapacityEvidence,
    required this.capacityMomentCount,
    required this.activationTarget,
    required this.activationReached,
    required this.fitResponseLabel,
    required this.pullReasonRecordCount,
    required this.outcomeRecordCount,
    required this.laterCostRecordCount,
    required this.weeklyReviewAvailable,
    required this.boundaryResponseSelected,
    required this.boundaryResponseCopied,
    required this.proInterestCaptured,
    required this.paymentSignalLabel,
    required this.verdict,
    required this.verdictLabel,
    required this.exportSummary,
  });

  static const empty = CapacityBetaSignalSnapshot(
    hasCapacityEvidence: false,
    capacityMomentCount: 0,
    activationTarget: 3,
    activationReached: false,
    fitResponseLabel: 'not answered',
    pullReasonRecordCount: 0,
    outcomeRecordCount: 0,
    laterCostRecordCount: 0,
    weeklyReviewAvailable: false,
    boundaryResponseSelected: false,
    boundaryResponseCopied: false,
    proInterestCaptured: false,
    paymentSignalLabel: 'Payment signal not tracked yet',
    verdict: CapacityBetaSignalVerdict.weak,
    verdictLabel: 'Weak activation signal',
    exportSummary:
        'ArchiveMe capacity beta signal: 0 yes moments, fit response not answered.',
  );

  final bool hasCapacityEvidence;
  final int capacityMomentCount;
  final int activationTarget;
  final bool activationReached;
  final String fitResponseLabel;
  final int pullReasonRecordCount;
  final int outcomeRecordCount;
  final int laterCostRecordCount;
  final bool weeklyReviewAvailable;
  final bool boundaryResponseSelected;
  final bool boundaryResponseCopied;
  final bool proInterestCaptured;
  final String paymentSignalLabel;
  final CapacityBetaSignalVerdict verdict;
  final String verdictLabel;
  final String exportSummary;
}

/// Engine input — metadata counts and store records only.
class CapacityBetaSignalInput {
  const CapacityBetaSignalInput({
    required this.capacityMomentCount,
    required this.capacityEvidenceCount,
    required this.capacityWedgeActive,
    required this.activationTarget,
    required this.fitResponseLabel,
    required this.fitIsPositive,
    required this.fitIsUnclear,
    required this.pullReasonRecordCount,
    required this.outcomeRecordCount,
    required this.laterCostRecordCount,
    required this.weeklyReviewAvailable,
    required this.boundaryResponseSelected,
    required this.boundaryResponseCopied,
    required this.proInterestCaptured,
    required this.trackPaymentSignal,
  });

  final int capacityMomentCount;
  final int capacityEvidenceCount;
  final bool capacityWedgeActive;
  final int activationTarget;
  final String fitResponseLabel;
  final bool fitIsPositive;
  final bool fitIsUnclear;
  final int pullReasonRecordCount;
  final int outcomeRecordCount;
  final int laterCostRecordCount;
  final bool weeklyReviewAvailable;
  final bool boundaryResponseSelected;
  final bool boundaryResponseCopied;
  final bool proInterestCaptured;
  final bool trackPaymentSignal;
}
