/// Beta tester signals and outcomes — measurement only, no product expansion.
enum BetaDecisionSignal {
  understoodPromise,
  misunderstoodAsGenericJournal,
  misunderstoodAsChatbot,
  misunderstoodAsTherapy,
  tappedRecord,
  savedFirstMoment,
  returnedDay2,
  reachedThreeMoments,
  sawFirstProof,
  proofFeltMeaningful,
  willingToPayForLongerTrail,
  askedForHistory,
  askedForExport,
  askedForReport,
  askedForReminder,
  hesitatedAtCapture,
  confusedWhatToWrite,
}

/// Highest-priority next build branch from beta evidence.
enum BetaNextBuildRecommendation {
  fixRecordOnboardingCopy,
  fixCaptureFriction,
  addReturnReason,
  improveProofEmotionalClarity,
  sharpenProPackaging,
  expandProUtility,
  holdDoNotExpand,
  insufficientData,
  noFailingBranch,
}

/// One tester session mapped to observed signals.
class BetaTesterOutcome {
  const BetaTesterOutcome({
    required this.testerId,
    required this.signals,
    this.notes,
    this.loggedAt,
  });

  final String testerId;
  final Set<BetaDecisionSignal> signals;
  final String? notes;
  final DateTime? loggedAt;

  bool has(BetaDecisionSignal signal) => signals.contains(signal);

  bool get misunderstood =>
      has(BetaDecisionSignal.misunderstoodAsGenericJournal) ||
      has(BetaDecisionSignal.misunderstoodAsChatbot) ||
      has(BetaDecisionSignal.misunderstoodAsTherapy) ||
      !has(BetaDecisionSignal.understoodPromise);

  bool get askedForUtilityExpansion =>
      has(BetaDecisionSignal.askedForHistory) ||
      has(BetaDecisionSignal.askedForExport) ||
      has(BetaDecisionSignal.askedForReport);

  bool get reachedProof =>
      has(BetaDecisionSignal.reachedThreeMoments) ||
      has(BetaDecisionSignal.sawFirstProof);

  Map<String, dynamic> toJson() => {
    'testerId': testerId,
    'signals': signals.map((signal) => signal.name).toList(),
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
    if (loggedAt != null) 'loggedAt': loggedAt!.toUtc().toIso8601String(),
  };

  factory BetaTesterOutcome.fromJson(Map<String, dynamic> json) {
    final rawSignals = json['signals'];
    final signals = <BetaDecisionSignal>{};
    if (rawSignals is List) {
      for (final value in rawSignals) {
        if (value is! String) continue;
        final signal = BetaDecisionSignal.values
            .where((candidate) => candidate.name == value)
            .firstOrNull;
        if (signal != null) signals.add(signal);
      }
    }
    final loggedAtRaw = json['loggedAt'];
    DateTime? loggedAt;
    if (loggedAtRaw is String && loggedAtRaw.isNotEmpty) {
      loggedAt = DateTime.tryParse(loggedAtRaw);
    }
    return BetaTesterOutcome(
      testerId: (json['testerId'] as String?)?.trim().isNotEmpty == true
          ? (json['testerId'] as String).trim()
          : 'tester-unknown',
      signals: signals,
      notes: (json['notes'] as String?)?.trim(),
      loggedAt: loggedAt,
    );
  }
}

/// Cohort-level recommendation from aggregated tester outcomes.
class BetaDecisionResult {
  const BetaDecisionResult({
    required this.primaryRecommendation,
    required this.reason,
    required this.evidenceCounts,
    required this.nextActionCopy,
    required this.testerCount,
    required this.failingBranchCounts,
    required this.expansionAllowed,
  });

  final BetaNextBuildRecommendation primaryRecommendation;
  final String reason;
  final Map<BetaDecisionSignal, int> evidenceCounts;
  final String nextActionCopy;
  final int testerCount;
  final Map<BetaNextBuildRecommendation, int> failingBranchCounts;
  final bool expansionAllowed;
}

/// Manual beta interview questions — see docs/BETA_DECISION_SYSTEM.md.
abstract final class BetaTesterOutcomeChecklist {
  BetaTesterOutcomeChecklist._();

  static const fivePersonRound = 5;
  static const twentyPersonThreshold = 20;

  static const interviewQuestions = <String>[
    'What do you think this app does?',
    'What would you record here?',
    'Did "Save one real moment" make sense?',
    'Did "1 Save → 2 Compare → 3 First thread" help?',
    'Would you come back when the same thing happens again?',
    'What felt confusing?',
    'Would you pay to keep the longer proof trail if it showed you something true?',
  ];
}
