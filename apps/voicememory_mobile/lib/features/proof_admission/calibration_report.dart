import 'archive_correction.dart';
import 'proof_admission_models.dart';

/// Where a batch of feedback came from.
///
/// Kept as a required, closed set because the whole point of this report is
/// that the three never merge. A rate computed over fixtures says something
/// about the pipeline; a rate computed over real people says something about
/// the product; averaging them says nothing about either while sounding like
/// it says both.
enum CalibrationCohort {
  /// Deterministic fixtures. Proves behaviour, never quality.
  syntheticFixture,

  /// The team's own archives. Real text, unrepresentative population.
  internalTest,

  /// Real users who gave explicit research consent.
  consentedRealUser,
}

/// One admission outcome plus whatever the user said about it, reduced to
/// structure.
///
/// Every field is a band, a count or a closed-set enum. There is deliberately
/// no field that could carry a transcript, a quote, a proof statement, a
/// preferred wording, or an identifier that could be traced back to a person or
/// an entry — not because callers are careless, but because a report that
/// cannot hold those things cannot leak them.
class CalibrationSample {
  const CalibrationSample({
    required this.cohort,
    required this.outcome,
    this.choice,
    this.band,
    this.claimKind,
    this.distinctSourceCount = 0,
    this.contradictionCount = 0,
  });

  final CalibrationCohort cohort;
  final ProofAdmissionOutcome outcome;

  /// Null when the user has not corrected this proof.
  final ArchiveCorrectionChoice? choice;
  final ProofConfidenceBand? band;
  final ProofClaimKind? claimKind;
  final int distinctSourceCount;
  final int contradictionCount;

  /// Bands rather than raw counts, so a rare combination cannot single anyone
  /// out in a report that may be read by more people than wrote it.
  String get sourceCountBand => switch (distinctSourceCount) {
    <= 0 => 'none',
    1 => 'single',
    2 || 3 => 'few',
    _ => 'many',
  };
}

/// A local, offline summary of how admission is behaving.
///
/// This calculates rates. It does not act on them: nothing here writes a
/// weight, and nothing here decides a threshold. Changing production scoring
/// requires a versioned config change with a documented reason, a fixture
/// comparison and human review, and keeping the measurement separate from the
/// change is what makes that review meaningful.
class CalibrationReport {
  const CalibrationReport._(this.cohort, this._samples);

  /// Builds a report over a single cohort.
  ///
  /// Samples from other cohorts are dropped rather than merged, which is why
  /// the cohort is a constructor argument and not a grouping key.
  factory CalibrationReport.forCohort(
    CalibrationCohort cohort,
    Iterable<CalibrationSample> samples,
  ) => CalibrationReport._(
    cohort,
    List.unmodifiable(samples.where((sample) => sample.cohort == cohort)),
  );

  /// Below this, rates are reported as null rather than as numbers.
  ///
  /// Three corrections out of four is not a 75% wrong rate, but it reads
  /// exactly like one in a table, and a weight change argued from that table
  /// would be noise dressed as evidence.
  static const int minimumSampleSize = 20;

  final CalibrationCohort cohort;
  final List<CalibrationSample> _samples;

  int get sampleCount => _samples.length;

  /// True when this cohort has enough samples for its rates to mean anything.
  bool get isReportable => sampleCount >= minimumSampleSize;

  int get correctedCount =>
      _samples.where((sample) => sample.choice != null).length;

  /// Share of corrected proofs that received [choice], or null when the cohort
  /// is too small to report.
  double? rateFor(ArchiveCorrectionChoice choice) {
    if (!isReportable || correctedCount == 0) return null;
    final matching = _samples
        .where((sample) => sample.choice == choice)
        .length;
    return matching / correctedCount;
  }

  double? rateForOutcome(ProofAdmissionOutcome outcome) {
    if (!isReportable || sampleCount == 0) return null;
    return _samples.where((sample) => sample.outcome == outcome).length /
        sampleCount;
  }

  double? get suppressionRate =>
      rateForOutcome(ProofAdmissionOutcome.correctionSuppressed);

  double? get invalidEvidenceRate =>
      rateForOutcome(ProofAdmissionOutcome.invalidEvidence);

  /// Share of admitted proofs carrying at least one contradiction.
  double? get contradictionRate {
    if (!isReportable) return null;
    final admitted = _admitted;
    if (admitted.isEmpty) return null;
    return admitted.where((sample) => sample.contradictionCount > 0).length /
        admitted.length;
  }

  /// Share of corrected proofs the user accepted outright, per confidence band.
  ///
  /// This is the number worth watching: if `high` is not accepted more often
  /// than `low`, the bands are decorative and the scorer is not measuring what
  /// it claims to.
  Map<ProofConfidenceBand, double?> get acceptanceByBand => {
    for (final band in ProofConfidenceBand.values)
      band: _acceptance(
        _samples.where((sample) => sample.band == band).toList(),
      ),
  };

  Map<String, double?> get acceptanceBySourceCount {
    final grouped = <String, List<CalibrationSample>>{};
    for (final sample in _samples) {
      grouped.putIfAbsent(sample.sourceCountBand, () => []).add(sample);
    }
    return {
      for (final entry in grouped.entries)
        entry.key: _acceptance(entry.value),
    };
  }

  Map<ProofClaimKind, double?> get acceptanceByClaimKind {
    final grouped = <ProofClaimKind, List<CalibrationSample>>{};
    for (final sample in _samples) {
      final kind = sample.claimKind;
      if (kind == null) continue;
      grouped.putIfAbsent(kind, () => []).add(sample);
    }
    return {
      for (final entry in grouped.entries)
        entry.key: _acceptance(entry.value),
    };
  }

  /// The whole report as plain, inspectable data.
  ///
  /// Rendered by a developer tool, never by the product: none of this is
  /// meaningful to someone reading their own archive, and a screen full of
  /// rates is exactly the scoring dashboard the product is not allowed to grow.
  Map<String, dynamic> toJson() => {
    'cohort': cohort.name,
    'sampleCount': sampleCount,
    'correctedCount': correctedCount,
    'reportable': isReportable,
    'minimumSampleSize': minimumSampleSize,
    'choiceRates': {
      for (final choice in ArchiveCorrectionChoice.values)
        choice.name: rateFor(choice),
    },
    'suppressionRate': suppressionRate,
    'invalidEvidenceRate': invalidEvidenceRate,
    'contradictionRate': contradictionRate,
    'acceptanceByBand': {
      for (final entry in acceptanceByBand.entries)
        entry.key.name: entry.value,
    },
    'acceptanceBySourceCount': acceptanceBySourceCount,
    'acceptanceByClaimKind': {
      for (final entry in acceptanceByClaimKind.entries)
        entry.key.name: entry.value,
    },
  };

  List<CalibrationSample> get _admitted => _samples
      .where((sample) => sample.outcome == ProofAdmissionOutcome.admitted)
      .toList();

  double? _acceptance(List<CalibrationSample> samples) {
    if (!isReportable) return null;
    final corrected = samples.where((sample) => sample.choice != null).toList();
    if (corrected.isEmpty) return null;
    final accepted = corrected
        .where(
          (sample) => sample.choice == ArchiveCorrectionChoice.exactlyRight,
        )
        .length;
    return accepted / corrected.length;
  }
}
