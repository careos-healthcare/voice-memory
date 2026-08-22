import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';

/// What kind of thing the proof is claiming to be.
enum ProofType { currentObservation, repeatedSignal, change, unresolved }

/// Direction of a pattern across comparable evidence windows.
enum ProofTrend { increasing, decreasing, stable, mixed, insufficientEvidence }

/// How the quality of the evidence itself moved across comparable windows.
enum ProofStrengthOverTime {
  stronger,
  weaker,
  unchanged,
  mixed,
  insufficientEvidence,
}

/// Deterministic, structural reasons a proof dimension could not be
/// established. Each maps to one plain-language line, and none of them ask for
/// generic "more journaling".
enum MissingEvidenceReason {
  needsAnotherDistinctSource,
  needsMoreSpecificQuote,
  needsNewerEvidence,
  needsContradictionResolution,
  needsValidThenSource,
  needsValidNowSource,
}

/// Counts plus the window they were counted in. Deliberately not a rate: sparse
/// logging must never be turned into an implied daily frequency.
class ProofFrequency {
  const ProofFrequency({
    required this.distinctMoments,
    required this.windowStart,
    required this.windowEnd,
  });

  factory ProofFrequency.fromJson(Map<String, dynamic> json) => ProofFrequency(
    distinctMoments: json['distinctMoments'] as int? ?? 0,
    windowStart: _date(json['windowStart']),
    windowEnd: _date(json['windowEnd']),
  );

  const ProofFrequency.none()
    : distinctMoments = 0,
      windowStart = null,
      windowEnd = null;

  /// Distinct verified source moments, never citation count.
  final int distinctMoments;
  final DateTime? windowStart;
  final DateTime? windowEnd;

  /// A single moment can never establish repetition.
  bool get established => distinctMoments >= 2;

  int? get windowDays => windowStart == null || windowEnd == null
      ? null
      : windowEnd!.difference(windowStart!).inDays;

  Map<String, dynamic> toJson() => {
    'distinctMoments': distinctMoments,
    'windowStart': windowStart?.toUtc().toIso8601String(),
    'windowEnd': windowEnd?.toUtc().toIso8601String(),
  };

  static DateTime? _date(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.parse(value) : null;
}

/// Thresholds for the soft, non-safety dimensions of a proof receipt.
///
/// These govern what may be *claimed about* already-verified evidence. They can
/// never admit evidence the verifier rejected, so they are ordinary constants
/// rather than part of the weighted scoring configuration.
class ProofQualityThresholds {
  const ProofQualityThresholds({
    this.minimumMomentsForRepeat = 2,
    this.minimumMomentsForTrend = 3,
    this.minimumWordsForSpecificQuote = 4,
    this.staleAfterDays = 90,
    this.strengthMarginWords = 1,
  });

  final int minimumMomentsForRepeat;
  final int minimumMomentsForTrend;
  final int minimumWordsForSpecificQuote;
  final int staleAfterDays;

  /// Average quote length must move by more than this to count as a change, so
  /// one slightly longer sentence cannot read as "getting stronger".
  final int strengthMarginWords;
}

/// Computes every proof-quality dimension from verified evidence only.
///
/// Nothing here reads model wording: a trend the model asserted but the dated
/// evidence does not support resolves to [ProofTrend.insufficientEvidence].
class ProofQualityCalculator {
  const ProofQualityCalculator({
    this.thresholds = const ProofQualityThresholds(),
  });

  static const int verifierVersion = 1;
  static const int scorerVersion = 1;

  final ProofQualityThresholds thresholds;

  ProofQualityReceipt build({
    required List<VerifiedProofClaim> claims,
    required ProofConfidenceBand confidenceBand,
    required Set<ProofClaimKind> unsupportedClaims,
    required DateTime now,
    int configVersion = 1,
  }) {
    final evidence = claims.expand((claim) => claim.evidence).toList();
    final supporting = _byRole(evidence, ProofEvidenceRole.support);
    final counterexamples = _byRole(evidence, ProofEvidenceRole.counterexample);
    final contradictions = _byRole(evidence, ProofEvidenceRole.contradiction);
    final moments = _distinctMoments(supporting);
    final claimKinds = claims.map((claim) => claim.kind).toSet();
    final change = _changeEvidence(claims);

    return ProofQualityReceipt(
      proofType: _proofType(claimKinds, contradictions.isNotEmpty),
      confidenceBand: confidenceBand,
      frequency: _frequency(moments),
      trend: _trend(moments, contradictions.length),
      strengthOverTime: _strength(moments, contradictions.length),
      supportingEvidence: List.unmodifiable(supporting),
      counterexamples: List.unmodifiable(counterexamples),
      contradictions: List.unmodifiable(contradictions),
      missingEvidence: _missingEvidence(
        moments: moments,
        contradictionCount: contradictions.length,
        claimKinds: claimKinds,
        change: change,
        now: now,
      ),
      firstOccurrence: moments.isEmpty ? null : moments.first.sourceDate,
      lastOccurrence: moments.isEmpty ? null : moments.last.sourceDate,
      thenEvidence: change?.then,
      nowEvidence: change?.now,
      unsupportedClaims: List.unmodifiable(
        unsupportedClaims.toList()
          ..sort((left, right) => left.name.compareTo(right.name)),
      ),
      configVersion: configVersion,
      generatedAt: now,
    );
  }

  ProofType _proofType(Set<ProofClaimKind> claimKinds, bool contradicted) {
    if (contradicted) return ProofType.unresolved;
    if (claimKinds.contains(ProofClaimKind.directionOfChange)) {
      return ProofType.change;
    }
    if (claimKinds.contains(ProofClaimKind.repeated)) {
      return ProofType.repeatedSignal;
    }
    return ProofType.currentObservation;
  }

  ProofFrequency _frequency(List<VerifiedEvidenceSnapshot> moments) {
    if (moments.isEmpty) return const ProofFrequency.none();
    return ProofFrequency(
      distinctMoments: moments.length,
      windowStart: moments.first.sourceDate,
      windowEnd: moments.last.sourceDate,
    );
  }

  ProofTrend _trend(
    List<VerifiedEvidenceSnapshot> moments,
    int contradictionCount,
  ) {
    final windows = _comparableWindows(moments);
    if (windows == null) return ProofTrend.insufficientEvidence;
    if (contradictionCount * 2 >= moments.length) return ProofTrend.mixed;
    final difference = windows.later.length - windows.earlier.length;
    if (difference > 0) return ProofTrend.increasing;
    if (difference < 0) return ProofTrend.decreasing;
    return ProofTrend.stable;
  }

  ProofStrengthOverTime _strength(
    List<VerifiedEvidenceSnapshot> moments,
    int contradictionCount,
  ) {
    final windows = _comparableWindows(moments);
    if (windows == null) return ProofStrengthOverTime.insufficientEvidence;
    if (contradictionCount * 2 >= moments.length) {
      return ProofStrengthOverTime.mixed;
    }
    final earlier = _averageWords(windows.earlier);
    final later = _averageWords(windows.later);
    final margin = thresholds.strengthMarginWords;
    if (later - earlier > margin) return ProofStrengthOverTime.stronger;
    if (earlier - later > margin) return ProofStrengthOverTime.weaker;
    return ProofStrengthOverTime.unchanged;
  }

  /// Splits the evidence at the midpoint of its own span so both halves cover
  /// the same amount of time. Returns null when the windows are not comparable.
  _ComparableWindows? _comparableWindows(
    List<VerifiedEvidenceSnapshot> moments,
  ) {
    if (moments.length < thresholds.minimumMomentsForTrend) return null;
    final first = moments.first.sourceDate;
    final span = moments.last.sourceDate.difference(first);
    if (span <= Duration.zero) return null;
    final midpoint = first.add(span ~/ 2);
    final earlier = moments
        .where((item) => !item.sourceDate.isAfter(midpoint))
        .toList();
    final later = moments
        .where((item) => item.sourceDate.isAfter(midpoint))
        .toList();
    if (earlier.isEmpty || later.isEmpty) return null;
    return _ComparableWindows(earlier: earlier, later: later);
  }

  List<MissingEvidenceReason> _missingEvidence({
    required List<VerifiedEvidenceSnapshot> moments,
    required int contradictionCount,
    required Set<ProofClaimKind> claimKinds,
    required _ChangeEvidence? change,
    required DateTime now,
  }) {
    final missing = <MissingEvidenceReason>[];
    if (moments.length < thresholds.minimumMomentsForRepeat) {
      missing.add(MissingEvidenceReason.needsAnotherDistinctSource);
    }
    if (moments.isNotEmpty &&
        moments
                .map(_wordCount)
                .reduce((left, right) => left < right ? left : right) <
            thresholds.minimumWordsForSpecificQuote) {
      missing.add(MissingEvidenceReason.needsMoreSpecificQuote);
    }
    if (moments.isNotEmpty &&
        now.difference(moments.last.sourceDate).inDays >
            thresholds.staleAfterDays) {
      missing.add(MissingEvidenceReason.needsNewerEvidence);
    }
    if (contradictionCount > 0) {
      missing.add(MissingEvidenceReason.needsContradictionResolution);
    }
    if (claimKinds.contains(ProofClaimKind.directionOfChange) &&
        change == null) {
      missing.add(MissingEvidenceReason.needsValidThenSource);
      missing.add(MissingEvidenceReason.needsValidNowSource);
    }
    return List.unmodifiable(missing);
  }

  _ChangeEvidence? _changeEvidence(List<VerifiedProofClaim> claims) {
    final change = claims
        .where((claim) => claim.kind == ProofClaimKind.directionOfChange)
        .firstOrNull;
    if (change == null) return null;
    final moments = _distinctMoments(
      _byRole(change.evidence, ProofEvidenceRole.support),
    );
    if (moments.length < 2) return null;
    return _ChangeEvidence(then: moments.first, now: moments.last);
  }

  static List<VerifiedEvidenceSnapshot> _byRole(
    List<VerifiedEvidenceSnapshot> evidence,
    ProofEvidenceRole role,
  ) => evidence.where((item) => item.role == role).toList();

  /// One moment counts once however many times it was cited, and ties break on
  /// the source id so the same inputs always produce the same receipt.
  static List<VerifiedEvidenceSnapshot> _distinctMoments(
    List<VerifiedEvidenceSnapshot> evidence,
  ) {
    final bySource = <String, VerifiedEvidenceSnapshot>{};
    for (final item in evidence) {
      final existing = bySource[item.sourceEntryId];
      if (existing == null || item.sourceDate.isBefore(existing.sourceDate)) {
        bySource[item.sourceEntryId] = item;
      }
    }
    return bySource.values.toList()..sort((left, right) {
      final byDate = left.sourceDate.compareTo(right.sourceDate);
      return byDate != 0
          ? byDate
          : left.sourceEntryId.compareTo(right.sourceEntryId);
    });
  }

  static double _averageWords(List<VerifiedEvidenceSnapshot> moments) =>
      moments.isEmpty
      ? 0
      : moments.map(_wordCount).reduce((left, right) => left + right) /
            moments.length;

  static int _wordCount(VerifiedEvidenceSnapshot snapshot) =>
      snapshot.quote.trim().isEmpty
      ? 0
      : snapshot.quote.trim().split(RegExp(r'\s+')).length;
}

class _ComparableWindows {
  const _ComparableWindows({required this.earlier, required this.later});

  final List<VerifiedEvidenceSnapshot> earlier;
  final List<VerifiedEvidenceSnapshot> later;
}

class _ChangeEvidence {
  const _ChangeEvidence({required this.then, required this.now});

  final VerifiedEvidenceSnapshot then;
  final VerifiedEvidenceSnapshot now;
}