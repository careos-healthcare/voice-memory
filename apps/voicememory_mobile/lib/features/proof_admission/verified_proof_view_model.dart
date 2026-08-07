import '../../security/user_content_safety.dart';
import 'archive_correction.dart';
import 'proof_admission_models.dart';

/// Customer-facing presentation data. It can only be constructed from the
/// immutable, admitted proof boundary—not parser or provider DTOs.
///
/// Every quantitative dimension is converted to a plain-language line here, so
/// no downstream widget is ever handed a raw score, a percentage, or a ranking
/// position it could render.
class VerifiedProofViewModel {
  const VerifiedProofViewModel({
    required this.proofId,
    required this.statement,
    required this.supportingEvidence,
    required this.counterexamples,
    required this.contradictions,
    required this.confidenceLabel,
    required this.missingEvidenceLines,
    required this.correctionLines,
    this.frequencyLine,
    this.trendLine,
    this.strengthLine,
    this.thenEvidence,
    this.nowEvidence,
    this.firstOccurrence,
    this.lastOccurrence,
    this.stale = false,
  });

  final String proofId;

  /// The single cautious observation shown on the compact card.
  final String statement;

  final List<VerifiedProofEvidenceViewModel> supportingEvidence;
  final List<VerifiedProofEvidenceViewModel> counterexamples;
  final List<VerifiedProofEvidenceViewModel> contradictions;

  /// A band word such as "Medium confidence", never a number.
  final String confidenceLabel;

  final List<String> missingEvidenceLines;
  final List<String> correctionLines;

  /// Null whenever the dimension was not established, so the detail surface can
  /// omit the whole section instead of printing an empty or invented value.
  final String? frequencyLine;
  final String? trendLine;
  final String? strengthLine;
  final VerifiedProofEvidenceViewModel? thenEvidence;
  final VerifiedProofEvidenceViewModel? nowEvidence;
  final DateTime? firstOccurrence;
  final DateTime? lastOccurrence;
  final bool stale;

  bool get hasChangeEvidence => thenEvidence != null && nowEvidence != null;

  bool get hasOccurrenceRange =>
      firstOccurrence != null && lastOccurrence != null;

  /// All evidence in one list, for surfaces that show a single evidence block.
  List<VerifiedProofEvidenceViewModel> get evidence => List.unmodifiable([
    ...supportingEvidence,
    ...counterexamples,
    ...contradictions,
  ]);

  factory VerifiedProofViewModel.fromVerifiedProof(
    VerifiedProof proof, {
    List<ArchiveCorrection> corrections = const [],
    bool stale = false,
  }) {
    final receipt = proof.qualityReceipt;

    return VerifiedProofViewModel(
      proofId: proof.proofId,
      // A user-preferred label always beats generated wording, and only ever
      // renames the proof: the evidence behind it is unchanged.
      statement:
          receipt.userConfirmedWording ?? proof.reflection.concreteObservation,
      supportingEvidence: List.unmodifiable(
        receipt.supportingEvidence.map(_evidence).toList(),
      ),
      counterexamples: List.unmodifiable(
        receipt.counterexamples.map(_evidence).toList(),
      ),
      contradictions: List.unmodifiable(
        receipt.contradictions.map(_evidence).toList(),
      ),
      confidenceLabel: confidenceLabelFor(proof.confidenceBand),
      missingEvidenceLines: List.unmodifiable(
        receipt.missingEvidence.map(missingEvidenceLineFor).toList(),
      ),
      correctionLines: List.unmodifiable(
        corrections
            .where((item) => !item.superseded)
            .map((item) => correctionLineFor(item.choice))
            .toList(),
      ),
      frequencyLine: frequencyLineFor(receipt.frequency),
      trendLine: trendLineFor(receipt.trend),
      strengthLine: strengthLineFor(receipt.strengthOverTime),
      thenEvidence: receipt.thenEvidence == null
          ? null
          : _evidence(receipt.thenEvidence!),
      nowEvidence: receipt.nowEvidence == null
          ? null
          : _evidence(receipt.nowEvidence!),
      firstOccurrence: receipt.firstOccurrence,
      lastOccurrence: receipt.lastOccurrence,
      stale: stale,
    );
  }

  static VerifiedProofEvidenceViewModel _evidence(
    VerifiedEvidenceSnapshot item,
  ) => VerifiedProofEvidenceViewModel(
    sourceEntryId: item.sourceEntryId,
    quote: UserContentSafety.safeSnippet(item.quote, maxChars: 180),
    sourceDate: item.sourceDate,
    role: item.role,
  );

  static String confidenceLabelFor(ProofConfidenceBand band) => switch (band) {
    ProofConfidenceBand.low => 'Low confidence',
    ProofConfidenceBand.medium => 'Medium confidence',
    ProofConfidenceBand.high => 'High confidence',
  };

  /// Counts stay counts. A sparse archive must never read as a rate.
  static String? frequencyLineFor(ProofFrequency frequency) {
    if (!frequency.established) return null;
    final moments = frequency.distinctMoments;
    final window = frequency.windowDays;
    if (window == null || window <= 0) {
      return 'Seen in $moments verified moments.';
    }
    return 'Seen in $moments verified moments over $window days.';
  }

  static String? trendLineFor(ProofTrend trend) => switch (trend) {
    ProofTrend.increasing => 'This is coming up more often than it was.',
    ProofTrend.decreasing => 'This is coming up less often than it was.',
    ProofTrend.stable => 'This is coming up about as often as it was.',
    ProofTrend.mixed => 'The evidence points in more than one direction.',
    ProofTrend.insufficientEvidence => null,
  };

  static String? strengthLineFor(ProofStrengthOverTime strength) =>
      switch (strength) {
        ProofStrengthOverTime.stronger =>
          'Your later moments describe this more specifically.',
        ProofStrengthOverTime.weaker =>
          'Your later moments describe this less specifically.',
        ProofStrengthOverTime.unchanged =>
          'Your moments describe this about as specifically as before.',
        ProofStrengthOverTime.mixed =>
          'The evidence is not consistent enough to compare.',
        ProofStrengthOverTime.insufficientEvidence => null,
      };

  static String missingEvidenceLineFor(
    MissingEvidenceReason missing,
  ) => switch (missing) {
    MissingEvidenceReason.needsAnotherDistinctSource =>
      'Needs another separate moment before this can be called a repeat.',
    MissingEvidenceReason.needsMoreSpecificQuote =>
      'The words behind this are short, so a more specific moment would help.',
    MissingEvidenceReason.needsNewerEvidence =>
      'The most recent moment behind this is old.',
    MissingEvidenceReason.needsContradictionResolution =>
      'Something you said contradicts this, and it is not resolved.',
    MissingEvidenceReason.needsValidThenSource =>
      'Needs an earlier moment to compare against.',
    MissingEvidenceReason.needsValidNowSource =>
      'Needs a recent moment to compare against.',
  };

  static String correctionLineFor(
    ArchiveCorrectionChoice choice,
  ) => switch (choice) {
    ArchiveCorrectionChoice.exactlyRight => 'You marked this exactly right.',
    ArchiveCorrectionChoice.partlyRight => 'You marked this partly right.',
    ArchiveCorrectionChoice.wrong => 'You marked this wrong.',
    ArchiveCorrectionChoice.wrongWording => 'You marked the wording wrong.',
    ArchiveCorrectionChoice.wrongEvidence => 'You marked the evidence wrong.',
    ArchiveCorrectionChoice.ignoreForever => 'You asked to stop seeing this.',
  };
}

class VerifiedProofEvidenceViewModel {
  const VerifiedProofEvidenceViewModel({
    required this.sourceEntryId,
    required this.quote,
    required this.sourceDate,
    required this.role,
  });

  final String sourceEntryId;
  final String quote;
  final DateTime sourceDate;
  final ProofEvidenceRole role;
}
